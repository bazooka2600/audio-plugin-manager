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
                // Pre-calculate sizes for all plugins to enable fast sorting
                var plugins = Array(discoveredPlugins.values).map { plugin -> Plugin in
                    var cachedPlugin = plugin
                    cachedPlugin.cachedSizeForSorting = String(format: "%012lld", cachedPlugin.totalSize)
                    return cachedPlugin
                }
                plugins = plugins.sorted { $0.name < $1.name }
                self.plugins = plugins
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

        // Extract a better plugin name from the path
        let pluginName = extractPluginName(from: url, format: pluginFormat)

        // Create a unique key using name and first path to avoid collisions
        let key = "\(pluginName.lowercased())_\(url.path.hashValue)"

        // Check if we already have this plugin by name (not by key)
        if let existingEntry = discoveredPlugins.first(where: { $0.value.name == pluginName }) {
            var existingPlugin = existingEntry.value
            existingPlugin.formats.insert(pluginFormat)
            if !existingPlugin.paths.contains(where: { $0.path == url.path }) {
                existingPlugin.paths.append(url)
            }

            // Extract info from this file to potentially fill in missing data
            let (manufacturer, version) = extractPluginInfo(from: url)

            // Use manufacturer from this file if existing plugin doesn't have one
            if existingPlugin.manufacturer == nil, manufacturer != nil {
                existingPlugin.manufacturer = manufacturer
            }

            // Use version from this file if existing plugin doesn't have one
            if existingPlugin.version == nil, version != nil {
                existingPlugin.version = version
            }

            discoveredPlugins[existingEntry.key] = existingPlugin
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

    private func extractPluginName(from url: URL, format: PluginFormat) -> String {
        // First, try to get the name from Info.plist if available
        if let plistName = getNameFromInfoPlist(url) {
            return plistName
        }

        // Fall back to the directory/file name
        var name = url.deletingPathExtension().lastPathComponent

        // Remove common suffixes that aren't part of the name
        let suffixesToRemove = [" [VST3]", " [VST]", " [AU]", " [CLAP]", " (VST3)", " (VST)", " (AU)", " (CLAP)"]
        for suffix in suffixesToRemove {
            name = name.replacingOccurrences(of: suffix, with: "")
        }

        // If the name is generic, try to use the parent directory
        if name.lowercased() == "plugin" || name.isEmpty {
            if let parent = url.deletingLastPathComponent().lastPathComponent.components(separatedBy: ".").first {
                return parent
            }
        }

        return name.isEmpty ? "Unknown Plugin" : name
    }

    private func getNameFromInfoPlist(_ url: URL) -> String? {
        let plistPaths = [
            url.appendingPathComponent("Contents/Info.plist"),
            url.appendingPathComponent("Info.plist")
        ]

        for plistPath in plistPaths {
            if let plistData = try? Data(contentsOf: plistPath),
               let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {

                // Try multiple possible keys for the plugin name
                if let name = plist["CFBundleName"] as? String, !name.isEmpty {
                    return name
                }
                if let name = plist["CFBundleDisplayName"] as? String, !name.isEmpty {
                    return name
                }
            }
        }
        return nil
    }

    private func extractPluginInfo(from url: URL) -> (String?, String?) {
        var manufacturer: String?
        var version: String?

        // Try different paths based on plugin format
        let pathExtension = url.pathExtension.lowercased()

        // For bundle formats (VST3, AU, component, VST2)
        if pathExtension == "vst3" || pathExtension == "component" || pathExtension == "vst" {
            // Try multiple plist locations
            let plistPaths = [
                url.appendingPathComponent("Contents/Info.plist"),
                url.appendingPathComponent("Resources/Info.plist"),
                url.appendingPathComponent("Info.plist")
            ]

            for plistPath in plistPaths {
                if fileManager.fileExists(atPath: plistPath.path),
                   let plistData = try? Data(contentsOf: plistPath),
                   let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {

                    // Extract manufacturer with multiple fallbacks
                    if manufacturer == nil {
                        // PRIORITIZE CFBundleIdentifier parts (most reliable)
                        if let bundleId = plist["CFBundleIdentifier"] as? String {
                            let parts = bundleId.split(separator: ".").map(String.init)
                            if parts.count >= 2 && (parts[0] == "com" || parts[0] == "net" || parts[0] == "org") {
                                let extracted = capitalizeManufacturer(parts[1])
                                // Only use if it's a known manufacturer or reasonably long
                                if extracted.count > 2 {
                                    manufacturer = extracted
                                }
                            }
                        }

                        // If still no manufacturer, try explicit fields
                        if manufacturer == nil {
                            manufacturer = plist["Manufacturer"] as? String
                        }
                        if manufacturer == nil {
                            manufacturer = plist["mf"] as? String
                        }
                        if manufacturer == nil {
                            manufacturer = plist["vendor"] as? String
                        }
                        if manufacturer == nil {
                            manufacturer = plist["company"] as? String
                        }

                        // Try CFBundleGetInfoString as last resort
                        if manufacturer == nil, let infoString = plist["CFBundleGetInfoString"] as? String {
                            manufacturer = extractManufacturerFromInfoString(infoString)
                        }
                    }

                    // Extract version with multiple fallbacks
                    if version == nil {
                        version = plist["CFBundleShortVersionString"] as? String
                        version = version ?? plist["CFBundleVersion"] as? String
                        version = version ?? plist["PluginVersion"] as? String
                        version = version ?? plist["version"] as? String
                    }

                    // If we found both, break
                    if manufacturer != nil && version != nil {
                        break
                    }
                }
            }

            // Clean up manufacturer string if it contains extra info
            if let manufacturerString = manufacturer {
                manufacturer = cleanManufacturerString(manufacturerString)
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

        // For VST2 plugins, try to extract from filename
        // But DON'T set manufacturer from filename - it's unreliable and can override better data from VST3/AU versions
        // Only extract version if possible
        if pathExtension == "vst" && version == nil {
            let filename = url.deletingPathExtension().lastPathComponent
            let parts = filename.split(separator: " ").map(String.init)
            if parts.count > 1 {
                // Common pattern: "Manufacturer PluginName" or "PluginName Version"
                // Try to find version-like patterns (e.g., "v1.0", "1.0.0")
                for part in parts {
                    if part.range(of: "^\\d+\\.\\d+", options: .regularExpression) != nil {
                        version = String(part)
                        break
                    }
                }
            }
        }

        // Fallback: try to extract from directory name ONLY if we still don't have a manufacturer
        // This is less reliable than bundle identifiers
        if manufacturer == nil {
            let dirName = url.deletingLastPathComponent().lastPathComponent
            // Only extract if the directory name looks like a manufacturer (not "VST3", "Components", etc.)
            if !["VST3", "VST", "Components", "CLAP", "AU"].contains(dirName) {
                manufacturer = extractManufacturerFromDirectoryName(dirName)
            }
        }

        return (manufacturer, version)
    }

    private func capitalizeManufacturer(_ name: String) -> String {
        // Known manufacturer name mappings (exact lowercase matches)
        let knownManufacturers: [String: String] = [
            "arturia": "Arturia",
            "fabfilter": "FabFilter",
            "native-instruments": "Native Instruments",
            "sonicacademy": "Sonic Academy",
            "newfangledaudio": "Newfangled Audio",
            "babyaudio": "BABY Audio",
            "scalermusic": "Scaler Music",
            "sugar-bytes": "Sugar Bytes",
            "steinberg": "Steinberg",
            "waves": "Waves",
            "universalaudio": "Universal Audio",
            "ableton": "Ableton",
            "imageline": "Image-Line",
            "nativeinstruments": "Native Instruments",
            "xfer": "Xfer",
            "serum": "Xfer",  // Serum is by Xfer
            "u-he": "u-he",
            "uhe": "u-he",
            "izotope": "iZotope",
            "spectrasonics": "Spectrasonics",
            "softube": "Softube",
            "soundtoys": "Soundtoys",
            "valhalladsp": "Valhalla DSP",
            "valhalla": "Valhalla DSP",
            "pa": "Plugin Alliance",
            "pluginalliance": "Plugin Alliance",
            "brainworx": "Brainworx",
            "unified": "Plugin Alliance",
            "ssl": "Solid State Logic",
            "nik": "Nik",
            "dmg": "DMG Audio",
            "dmgaudio": "DMG Audio",
            "klanghelm": "Klanghelm",
            "tokyodawn": "Tokyo Dawn",
            "kara": "Kara",
            "kilohearts": "Kilohearts",
            "acustica": "Acustica Audio",
            "neoverb": "iZotope",
            "overloud": "Overloud",
            "xlnaudio": "XLN Audio",
            "xln": "XLN Audio",
            "addictive": "XLN Audio",  // Addictive products are by XLN Audio
            "strymon": "Strymon",
            "toontrack": "Toontrack",
            "waldorf": "Waldorf"
        ]

        let lowercase = name.lowercased()

        // Check if we have a known mapping
        if let known = knownManufacturers[lowercase] {
            return known
        }

        // Universal capitalization for any company name
        // This handles cases like "toontrack" -> "Toontrack", "waldorf" -> "Waldorf"
        return capitalizeCompanyName(name)
    }

    private func capitalizeCompanyName(_ name: String) -> String {
        // First, try to capitalize with common patterns
        // Split by hyphens and capitalize each part
        let parts = name.split(separator: "-").map { part in
            capitalizeWord(String(part))
        }

        if parts.count == 1 {
            return parts[0]
        }

        return parts.joined(separator: " ")
    }

    private func capitalizeWord(_ word: String) -> String {
        guard !word.isEmpty else { return word }

        // Capitalize first letter
        var chars = Array(word)
        chars[0] = Character(chars[0].uppercased())

        // For all-caps words or mixed case, preserve the original casing
        // For lowercase words, apply smart capitalization
        if word.dropFirst().allSatisfy({ $0.isLowercase }) {
            // All lowercase after first letter - likely needs proper capitalization
            // Common patterns to fix
            let patterns: [(String, String)] = [
                ("toontrack", "Toontrack"),
                ("waldorf", "Waldorf"),
                ("nativeinstruments", "Native Instruments"),
                ("spectrasonics", "Spectrasonics"),
                ("izotope", "iZotope"),
                ("soundtoys", "SoundToys"),
                ("softube", "Softube"),
                ("steinberg", "Steinberg"),
                ("waves", "Waves"),
                ("ableton", "Ableton"),
                ("imageline", "Image-Line"),
                ("universalaudio", "Universal Audio"),
                ("valhalla", "Valhalla"),
                ("dmgaudio", "DMG Audio"),
                ("kilohearts", "Kilohearts"),
                ("tokyodawn", "Tokyo Dawn"),
                ("sugar-bytes", "Sugar Bytes"),
                ("babyaudio", "Baby Audio")  // Fix casing
            ]

            let lowerWord = String(word.lowercased())
            for (pattern, replacement) in patterns {
                if lowerWord == pattern {
                    return replacement
                }
            }

            // Default: just capitalize first letter, keep rest as is
            return String(chars)
        }

        // Mixed case or has caps - preserve it
        return String(chars)
    }

    private func extractManufacturerFromInfoString(_ infoString: String) -> String? {
        // Try to extract manufacturer from info strings like "Native Instruments Plugin Name"
        let patterns = [
            "^([A-Z][a-zA-Z\\s&]+)\\s+",  // Words at start
            "by\\s+([A-Z][a-zA-Z\\s&]+)",    // "by Manufacturer"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: infoString, range: NSRange(infoString.startIndex..., in: infoString)),
               let range = Range(match.range(at: 1), in: infoString) {
                return String(infoString[range]).trimmingCharacters(in: .whitespaces)
            }
        }

        return nil
    }

    private func extractManufacturerFromDirectoryName(_ dirName: String) -> String? {
        // Try to extract from patterns like "Manufacturer-PluginName" or "Manufacturer PluginName"
        let patterns = [
            "^([A-Z][a-zA-Z]+)[\\s-]+",  // Word at start
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: dirName, range: NSRange(dirName.startIndex..., in: dirName)),
               let range = Range(match.range(at: 1), in: dirName) {
                return String(dirName[range]).trimmingCharacters(in: .whitespaces)
            }
        }

        return nil
    }

    private func cleanManufacturerString(_ string: String) -> String? {
        var cleaned = string

        // Only remove copyright-related artifacts at the end
        let trailingPatterns = [
            " Copyright.*",
            " ©.*",
            " \\(c\\).*",
            " \\d{4}.*",  // years and everything after
            " All Rights Reserved.*",
            " Ltd\\.?",
            " Inc\\.?",
            " GmbH",
            " LLC",
        ]

        for pattern in trailingPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove leading "com " if present
        if cleaned.lowercased().starts(with: "com ") {
            cleaned = String(cleaned.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        }

        // Remove trailing ".vst3" or similar extensions
        cleaned = cleaned.replacingOccurrences(of: "\\.vst3$", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\.vst$", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\.component$", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\.clap$", with: "", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // If cleaned is just "com" or too short, return nil
        if cleaned.isEmpty || cleaned.count <= 2 || cleaned.lowercased() == "com" {
            return nil
        }

        return cleaned
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
