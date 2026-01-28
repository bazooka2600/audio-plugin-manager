import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var scanner: PluginScanner
    @EnvironmentObject var manager: PluginManager

    @State private var selectedTab = 0
    @State private var selectedFormat: PluginFormat?
    @State private var searchText = ""
    @State private var showingRemovalDialog = false
    @State private var removalOption: RemovalOption = .trash
    @State private var showingExportDialog = false

    var filteredPlugins: [Plugin] {
        let result = scanner.plugins.filter { plugin in
            let matchesSearch = searchText.isEmpty || plugin.name.localizedCaseInsensitiveContains(searchText)
            let matchesFormat = selectedFormat == nil || plugin.formats.contains(selectedFormat!)
            return matchesSearch && matchesFormat
        }
        return result
    }

    var selectedPlugins: [Plugin] {
        filteredPlugins.filter { $0.isSelected }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(
                pluginCount: filteredPlugins.count,
                selectedCount: selectedPlugins.count,
                isScanning: scanner.isScanning,
                onRefresh: { scanner.refreshScan() }
            )

            // Tab View
            TabView(selection: $selectedTab) {
                PluginListView(
                    plugins: filteredPlugins,
                    selectedFormat: $selectedFormat,
                    searchText: $searchText
                )
                .tabItem {
                    Label("All Plugins", systemImage: "music.note.list")
                }
                .tag(0)

                MultiFormatView(plugins: scanner.getMultiFormatPlugins())
                    .tabItem {
                        Label("Multi-Format", systemImage: "square.stack.3d.up")
                    }
                    .tag(1)

                BackupView(plugins: scanner.plugins)
                    .tabItem {
                        Label("Backup", systemImage: "arrow.down.doc")
                    }
                    .tag(2)
            }

            // Footer - conditionally show based on tab
            if selectedTab == 0 {
                // All Plugins tab - show Export footer
                ExportFooterView(
                    onExport: {
                        showingExportDialog = true
                    }
                )
            } else if selectedTab == 1 {
                // Multi-Format tab - show Remove footer
                FooterView(
                    selectedCount: selectedPlugins.count,
                    onRemove: {
                        showingRemovalDialog = true
                    }
                )
                .disabled(selectedPlugins.isEmpty || manager.isProcessing)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .fileExporter(
            isPresented: $showingExportDialog,
            document: ExportDocument(plugins: scanner.plugins),
            contentType: .plainText,
            defaultFilename: "plugins_manifest_\(getCurrentTimestamp())"
        ) { result in
            switch result {
            case .success(let url):
                print("Exported to: \(url.path)")
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
        .alert("Remove Plugins", isPresented: $showingRemovalDialog) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash") {
                removalOption = .trash
                performRemoval()
            }
            Button("Delete Permanently", role: .destructive) {
                removalOption = .permanentDelete
                performRemoval()
            }
        } message: {
            Text("Are you sure you want to remove \(selectedPlugins.count) plugin(s)? Choose an option below.")
        }
        .overlay(ProcessOverlay(manager: manager))
        .onAppear {
            if scanner.plugins.isEmpty {
                scanner.scanForPlugins()
            }
        }
    }

    private func performRemoval() {
        manager.removePlugins(selectedPlugins, option: removalOption) { success in
            if success {
                scanner.refreshScan()
            }
        }
    }

    private func getCurrentTimestamp() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return dateFormatter.string(from: Date())
    }
}

struct HeaderView: View {
    let pluginCount: Int
    let selectedCount: Int
    let isScanning: Bool
    let onRefresh: () -> Void

    var body: some View {
        HStack {
            Text("Audio Plugin Manager")
                .font(.system(size: 24, weight: .bold))

            Spacer()

            if isScanning {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Scanning...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: onRefresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(isScanning)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct FooterView: View {
    let selectedCount: Int
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Text("\(selectedCount) plugin(s) selected")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: onRemove) {
                Label("Remove Selected", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedCount == 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct ProcessOverlay: View {
    @ObservedObject var manager: PluginManager

    var body: some View {
        if manager.isProcessing {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView(value: manager.progress)
                        .frame(width: 300)

                    Text(manager.statusMessage)
                        .font(.body)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(12)
                .shadow(radius: 20)
            }
        }
    }
}

struct ExportFooterView: View {
    let onExport: () -> Void

    var body: some View {
        HStack {
            Text("Export plugin list to a text file")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: onExport) {
                Label("Export List", systemImage: "arrow.down.doc")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct ExportDocument: FileDocument {
    let plugins: [Plugin]

    static var readableContentTypes: [UTType] { [.plainText] }

    init(plugins: [Plugin]) {
        self.plugins = plugins
    }

    init(configuration: ReadConfiguration) throws {
        self.plugins = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let content = generateManifestContent()
        let data = content.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }

    private func generateManifestContent() -> String {
        var content = """
        Audio Plugin Manifest
        Generated: \(Date())
        ================================

        Total Plugins: \(plugins.count)

        """

        // Group by format
        let grouped = Dictionary(grouping: plugins) { plugin -> PluginFormat in
            // For multi-format plugins, use the first format
            plugin.formats.sorted(by: { $0.rawValue < $1.rawValue }).first ?? .vst3
        }

        let sortedFormats = grouped.keys.sorted { $0.rawValue < $1.rawValue }

        for format in sortedFormats {
            if let formatPlugins = grouped[format], !formatPlugins.isEmpty {
                content += "\n\(format.rawValue.uppercased()) PLUGINS (\(formatPlugins.count))\n"
                content += String(repeating: "=", count: 50) + "\n\n"

                let sortedPlugins = formatPlugins.sorted { $0.name < $1.name }

                for plugin in sortedPlugins {
                    content += "  • \(plugin.name)\n"

                    if let manufacturer = plugin.manufacturer {
                        content += "    Manufacturer: \(manufacturer)\n"
                    }

                    if let version = plugin.version {
                        content += "    Version: \(version)\n"
                    }

                    content += "    Size: \(plugin.formattedSize)\n"
                    content += "    Formats: \(plugin.formatList)\n"

                    if plugin.paths.count == 1 {
                        content += "    Location: \(plugin.paths[0].path)\n"
                    } else {
                        content += "    Locations (\(plugin.paths.count)):\n"
                        for (index, path) in plugin.paths.enumerated() {
                            content += "      \(index + 1). \(path.path)\n"
                        }
                    }

                    content += "\n"
                }
            }
        }

        return content
    }
}

#Preview {
    ContentView()
        .environmentObject(PluginScanner())
        .environmentObject(PluginManager())
}
