import Foundation
import SwiftUI
import Combine

enum RemovalOption {
    case trash
    case permanentDelete
}

@MainActor
class PluginManager: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var statusMessage = ""
    @Published var lastError: String?

    private let fileManager = FileManager.default

    // MARK: - Plugin Removal

    func removePlugins(_ plugins: [Plugin], option: RemovalOption, completion: @escaping (Bool) -> Void) {
        isProcessing = true
        statusMessage = "Preparing to remove plugins..."
        progress = 0.0
        lastError = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }

            var success = true
            let totalSteps = plugins.count
            var currentStep = 0

            for plugin in plugins {
                currentStep += 1
                DispatchQueue.main.async {
                    self.statusMessage = "Removing \(plugin.name)..."
                    self.progress = Double(currentStep) / Double(totalSteps)
                }

                let removed = self.removePlugin(plugin, option: option)
                if !removed {
                    success = false
                }
            }

            DispatchQueue.main.async {
                self.isProcessing = false
                self.statusMessage = success ? "Successfully removed \(plugins.count) plugin(s)" : "Completed with some errors"
                completion(success)
            }
        }
    }

    private func removePlugin(_ plugin: Plugin, option: RemovalOption) -> Bool {
        var success = true

        for path in plugin.paths {
            do {
                switch option {
                case .trash:
                    try fileManager.trashItem(at: path, resultingItemURL: nil)
                case .permanentDelete:
                    try fileManager.removeItem(at: path)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.lastError = "Failed to remove \(plugin.name): \(error.localizedDescription)"
                }
                success = false
            }
        }

        return success
    }

    // MARK: - Plugin Backup

    func backupPlugins(_ plugins: [Plugin], to destinationURL: URL, completion: @escaping (Bool) -> Void) {
        isProcessing = true
        statusMessage = "Preparing backup..."
        progress = 0.0
        lastError = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }

            // Create backup directory with timestamp
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            let backupFolder = destinationURL.appendingPathComponent("Plugin_Backup_\(timestamp)")

            do {
                try self.fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: true, attributes: nil)

                // Track backed up plugins for manifest
                var backedUpPlugins: [PluginFormat: [(name: String, path: String)]] = [:]

                var success = true
                let totalSteps = plugins.count
                var currentStep = 0

                for plugin in plugins {
                    currentStep += 1
                    DispatchQueue.main.async {
                        self.statusMessage = "Backing up \(plugin.name)..."
                        self.progress = Double(currentStep) / Double(totalSteps)
                    }

                    if let result = self.backupPlugin(plugin, to: backupFolder) {
                        for (format, name, path) in result {
                            backedUpPlugins[format, default: []].append((name: name, path: path))
                        }
                    } else {
                        success = false
                    }
                }

                // Create manifest file
                if !self.createBackupManifest(backedUpPlugins, at: backupFolder) {
                    DispatchQueue.main.async {
                        self.lastError = "Failed to create backup manifest"
                    }
                }

                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = success ? "Successfully backed up \(plugins.count) plugin(s)" : "Completed with some errors"
                    completion(success)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.lastError = "Failed to create backup directory: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }
    }

    // Returns array of (format, name, path) tuples for each backed up plugin
    private func backupPlugin(_ plugin: Plugin, to destinationURL: URL) -> [(PluginFormat, String, String)]? {
        var backedUpFiles: [(PluginFormat, String, String)] = []

        for path in plugin.paths {
            do {
                // Determine the format based on the file extension
                let format: PluginFormat
                switch path.pathExtension.lowercased() {
                case "vst":
                    format = .vst2
                case "vst3":
                    format = .vst3
                case "component":
                    format = .au
                case "clap":
                    format = .clap
                default:
                    format = .vst3 // Default fallback
                }

                // Create format-specific folder
                let formatFolder = destinationURL.appendingPathComponent(format.rawValue)
                try fileManager.createDirectory(at: formatFolder, withIntermediateDirectories: true, attributes: nil)

                let destination = formatFolder.appendingPathComponent(path.lastPathComponent)

                // Check if file already exists
                if fileManager.fileExists(atPath: destination.path) {
                    // Add a number to make it unique
                    var counter = 1
                    var uniqueDestination = destination
                    while fileManager.fileExists(atPath: uniqueDestination.path) {
                        let nameWithoutExt = destination.deletingPathExtension().lastPathComponent
                        let ext = destination.pathExtension
                        uniqueDestination = destination.deletingLastPathComponent()
                            .appendingPathComponent("\(nameWithoutExt)_\(counter)")
                            .appendingPathExtension(ext)
                        counter += 1
                    }
                    try fileManager.copyItem(at: path, to: uniqueDestination)
                    backedUpFiles.append((format, plugin.name, uniqueDestination.lastPathComponent))
                } else {
                    try fileManager.copyItem(at: path, to: destination)
                    backedUpFiles.append((format, plugin.name, destination.lastPathComponent))
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.lastError = "Failed to backup \(plugin.name): \(error.localizedDescription)"
                }
                return nil
            }
        }

        return backedUpFiles.isEmpty ? nil : backedUpFiles
    }

    private func createBackupManifest(_ backedUpPlugins: [PluginFormat: [(name: String, path: String)]], at backupFolder: URL) -> Bool {
        let manifestPath = backupFolder.appendingPathComponent("manifest.txt")

        var content = """
        Audio Plugin Backup Manifest
        Generated: \(Date())
        ================================

        """

        // Sort by format name
        let sortedFormats = backedUpPlugins.keys.sorted { $0.rawValue < $1.rawValue }

        for format in sortedFormats {
            if let plugins = backedUpPlugins[format], !plugins.isEmpty {
                content += "\n\(format.rawValue.uppercased()) PLUGINS (\(plugins.count) files)\n"
                content += String(repeating: "=", count: 50) + "\n\n"

                // Sort plugins alphabetically by name
                let sortedPlugins = plugins.sorted { $0.name < $1.name }

                for plugin in sortedPlugins {
                    content += "  • \(plugin.name)\n"
                    content += "    File: \(plugin.path)\n"
                }
                content += "\n"
            }
        }

        do {
            try content.write(to: manifestPath, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Failed to write manifest: \(error)")
            return false
        }
    }

    // MARK: - Size Calculation

    func calculateBackupSize(_ plugins: [Plugin]) -> Int64 {
        return plugins.reduce(0) { total, plugin in
            total + plugin.totalSize
        }
    }

    func formatBackupSize(_ size: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    // MARK: - Validation

    func validateBackupDestination(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

        return exists && isDirectory.boolValue
    }
}
