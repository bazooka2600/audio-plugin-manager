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
    }

    var hasMultipleFormats: Bool {
        formats.count > 1
    }

    var formatList: String {
        formats.map { $0.rawValue }.sorted().joined(separator: ", ")
    }

    var totalSize: Int64 {
        paths.reduce(0) { total, url in
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let fileSize = attributes[.size] as? Int64 {
                return total + fileSize
            }
            return total
        }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

struct PluginGroup: Identifiable {
    let id = UUID()
    var name: String
    var plugins: [Plugin]
}
