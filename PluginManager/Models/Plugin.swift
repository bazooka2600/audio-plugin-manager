import Foundation

enum PluginFormat: String, CaseIterable, Codable {
    case vst2 = "VST2"
    case vst3 = "VST3"
    case au = "AU"
    case clap = "CLAP"

    var fileExtension: String {
        switch self {
        case .vst2: return ".vst"
        case .vst3: return ".vst3"
        case .au: return ".component"
        case .clap: return ".clap"
        }
    }

    var icon: String {
        switch self {
        case .vst2: return "🎛️"
        case .vst3: return "🎼"
        case .au: return "🎵"
        case .clap: return "🎹"
        }
    }
}

struct Plugin: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var formats: Set<PluginFormat>
    var paths: [URL]
    var manufacturer: String?
    var version: String?
    var isSelected: Bool = false
    var isBackingUp: Bool = false

    // Optional cached size for sorting - can be set after initial scan
    var cachedSizeForSorting: String?

    init(
        id: UUID = UUID(),
        name: String,
        formats: Set<PluginFormat>,
        paths: [URL],
        manufacturer: String? = nil,
        version: String? = nil
    ) {
        self.id = id
        self.name = name
        self.formats = formats
        self.paths = paths
        self.manufacturer = manufacturer
        self.version = version
        self.cachedSizeForSorting = nil
    }

    var hasMultipleFormats: Bool {
        formats.count > 1
    }

    var formatList: String {
        formats.map { $0.rawValue }.sorted().joined(separator: ", ")
    }

    var totalSize: Int64 {
        paths.reduce(0) { total, url in
            return total + directorySize(url)
        }
    }

    private func directorySize(_ url: URL) -> Int64 {
        let fileManager = FileManager.default

        // Check if it's a directory (bundle)
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            var totalSize: Int64 = 0

            if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }

            return totalSize
        } else {
            // It's a file, get its size directly
            if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
               let fileSize = attributes[.size] as? Int64 {
                return fileSize
            }
            return 0
        }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var manufacturerForSorting: String {
        manufacturer ?? "Unknown"
    }

    var versionForSorting: String {
        version ?? "N/A"
    }

    var sizeForSorting: String {
        // Use cached value if available, otherwise calculate and cache it
        if let cached = cachedSizeForSorting {
            return cached
        }
        let formatted = String(format: "%012lld", totalSize)
        return formatted
    }
}

struct PluginGroup: Identifiable {
    let id = UUID()
    var name: String
    var plugins: [Plugin]
}
