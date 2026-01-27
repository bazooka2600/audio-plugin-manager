import Foundation
import Combine

class PluginScanner: ObservableObject {
    @Published var plugins: [Plugin] = []
    @Published var isScanning = false
    @Published var scanError: String?
    @Published var pluginGroups: [PluginGroup] = []

    private let fileManager = FileManager.default

    // Standard macOS plugin directories
    private let searchPaths: [String] = [
        "/Library/Audio/Plug-Ins/VST",
        "/Library/Audio/Plug-Ins/VST3",
        "/Library/Audio/Plug-Ins/Components",
        "/Library/Audio/Plug-Ins/CLAP",
        "~/Library/Audio/Plug-Ins/VST",
        "~/Library/Audio/Plug-Ins/VST3",
        "~/Library/Audio/Plug-Ins/Components",
        "~/Library/Audio/Plug-Ins/CLAP",
        "/System/Library/Audio/Plug-Ins/VST",
        "/System/Library/Audio/Plug-Ins/VST3",
        "/System/Library/Audio/Plug-Ins/Components",
        "/System/Library/Audio/Plug-Ins/CLAP"
    ]

    func scanForPlugins() {
        isScanning = true
        scanError = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var discoveredPlugins: [String: Plugin] = [:]

            for path in self.searchPaths {
                let expandedPath = NSString(string: path).expandingTildeInPath

                guard self.fileManager.fileExists(atPath: expandedPath) else {
                    continue
                }

                let pluginURL = URL(fileURLWithPath: expandedPath)

                if let enumerator = self.fileManager.enumerator(at: pluginURL, includingPropertiesForKeys: nil) {
                    for case let fileURL as URL in enumerator {
                        self.processPluginFile(fileURL, discoveredPlugins: &discoveredPlugins)
                    }
                }
            }

            // Group plugins by manufacturer and name
            let groupedPlugins = self.groupPlugins(Array(discoveredPlugins.values))

            DispatchQueue.main.async {
                self.plugins = Array(discoveredPlugins.values).sorted { $0.name < $1.name }
                self.pluginGroups = groupedPlugins
                self.isScanning = false
            }
        }
    }

    private func processPluginFile(_ url: URL, discoveredPlugins: inout [String: Plugin]) {
        let pathExtension = url.pathExtension.lowercased()

        guard pathExtension != "" else { return }

        var format: PluginFormat?

        switch pathExtension {
        case "vst":
            format = .vst2
        case "vst3":
            format = .vst3
        case "component":
            format = .au
        case "clap":
            format = .clap
        default:
            return
        }

        guard let pluginFormat = format else { return }

        let pluginName = url.deletingPathExtension().lastPathComponent
        let key = pluginName.lowercased()

        if var existingPlugin = discoveredPlugins[key] {
            existingPlugin.formats.insert(pluginFormat)
            existingPlugin.paths.append(url)
            discoveredPlugins[key] = existingPlugin
        } else {
            let (manufacturer, version) = extractPluginInfo(from: url)
            let newPlugin = Plugin(
                name: pluginName,
                formats: [pluginFormat],
                paths: [url],
                manufacturer: manufacturer,
                version: version
            )
            discoveredPlugins[key] = newPlugin
        }
    }

    private func extractPluginInfo(from url: URL) -> (String?, String?) {
        var manufacturer: String?
        var version: String?

        // Try different paths based on plugin format
        let pathExtension = url.pathExtension.lowercased()

        // For bundle formats (VST3, AU, component)
        if pathExtension == "vst3" || pathExtension == "component" {
            // Try Contents/Info.plist first
            var infoPlistPath = url.appendingPathComponent("Contents/Info.plist")

            if !fileManager.fileExists(atPath: infoPlistPath.path) {
                // Try root Info.plist for some plugins
                infoPlistPath = url.appendingPathComponent("Info.plist")
            }

            if let plistData = try? Data(contentsOf: infoPlistPath),
               let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {

                // Try multiple possible keys for manufacturer
                manufacturer = plist["CFBundleGetInfoString"] as? String
                    ?? plist["Manufacturer"] as? String
                    ?? (plist["CFBundleIdentifier"] as? String)?.split(separator: ".").first.map(String.init)

                // Try multiple possible keys for version
                version = plist["CFBundleShortVersionString"] as? String
                    ?? plist["CFBundleVersion"] as? String
                    ?? plist["PluginVersion"] as? String

                // Clean up manufacturer string if it contains extra info
                if let manufacturerString = manufacturer {
                    manufacturer = cleanManufacturerString(manufacturerString)
                }
            }
        }

        // For CLAP plugins
        if pathExtension == "clap" {
            let clapJsonPath = url.appendingPathComponent("clap.json")
            if let jsonData = try? Data(contentsOf: clapJsonPath),
               let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {

                manufacturer = json["manufacturer"] as? String
                version = json["version"] as? String
            }
        }

        // For VST2 plugins, try to extract from filename or directory structure
        if pathExtension == "vst" {
            // VST2 often doesn't have metadata, try to extract from filename
            let filename = url.deletingPathExtension().lastPathComponent
            if filename.contains(" ") {
                let parts = filename.split(separator: " ").map(String.init)
                if parts.count > 1 {
                    manufacturer = parts.first
                }
            }
        }

        return (manufacturer, version)
    }

    private func cleanManufacturerString(_ string: String) -> String? {
        // Remove common artifacts from manufacturer strings
        var cleaned = string
            .replacingOccurrences(of: "Copyright", with: "")
            .replacingOccurrences(of: "©", with: "")
            .replacingOccurrences(of: "\\(c\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\d{4}", with: "", options: .regularExpression)  // Remove years
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // If string is empty after cleaning, return nil
        return cleaned.isEmpty ? nil : cleaned
    }

    private func groupPlugins(_ plugins: [Plugin]) -> [PluginGroup] {
        let grouped = Dictionary(grouping: plugins) { plugin in
            plugin.manufacturer ?? "Unknown Manufacturer"
        }.map { name, plugins in
            PluginGroup(name: name, plugins: plugins.sorted { $0.name < $1.name })
        }.sorted { $0.name < $1.name }

        return grouped
    }

    func refreshScan() {
        plugins = []
        pluginGroups = []
        scanForPlugins()
    }

    func filterPluginsByFormat(_ format: PluginFormat?) -> [Plugin] {
        guard let format = format else {
            return plugins
        }
        return plugins.filter { $0.formats.contains(format) }
    }

    func getMultiFormatPlugins() -> [Plugin] {
        return plugins.filter { $0.hasMultipleFormats }
    }
}
