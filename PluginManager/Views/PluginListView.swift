import SwiftUI

struct PluginListView: View {
    @EnvironmentObject var scanner: PluginScanner

    var plugins: [Plugin]
    @Binding var selectedFormat: PluginFormat?
    @Binding var searchText: String

    @State private var displayPlugins: [Plugin] = []
    @State private var sortOrder: [KeyPathComparator<Plugin>] = [
        KeyPathComparator(\Plugin.name, order: .forward)
    ]
    @State private var selectedPluginIDs: Set<UUID> = []
    @State private var showingDetailSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Filter Bar with search
            FilterBar(
                selectedFormat: $selectedFormat,
                searchText: $searchText,
                onSelectAll: selectAllVisible,
                onDeselectAll: deselectAllVisible
            )

            // Plugin List
            if plugins.isEmpty && !scanner.isScanning {
                emptyView
            } else {
                pluginList
            }
        }
        .sheet(isPresented: $showingDetailSheet) {
            if let selectedID = selectedPluginIDs.first,
               let plugin = displayPlugins.first(where: { $0.id == selectedID }) {
                PluginDetailSheet(plugin: plugin)
            }
        }
        .onAppear {
            displayPlugins = plugins
        }
        .onChange(of: plugins) { newValue in
            displayPlugins = newValue
        }
    }

    private func selectAllVisible() {
        for index in scanner.plugins.indices {
            if plugins.contains(where: { $0.id == scanner.plugins[index].id }) {
                scanner.plugins[index].isSelected = true
            }
        }
    }

    private func deselectAllVisible() {
        for index in scanner.plugins.indices {
            if plugins.contains(where: { $0.id == scanner.plugins[index].id }) {
                scanner.plugins[index].isSelected = false
            }
        }
    }

    var pluginList: some View {
        Table(displayPlugins, selection: $selectedPluginIDs, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name)
            TableColumn("Manufacturer", value: \.manufacturerForSorting)
            TableColumn("Version", value: \.versionForSorting)
            TableColumn("Size", value: \.sizeForSorting) { plugin in
                Text(plugin.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .onChange(of: sortOrder) { newValue in
            applySort(from: newValue)
        }
        .onChange(of: selectedPluginIDs) { newValue in
            if !newValue.isEmpty {
                showingDetailSheet = true
            }
        }
    }

    private func applySort(from descriptors: [KeyPathComparator<Plugin>]) {
        guard let descriptor = descriptors.first else { return }

        displayPlugins.sort { p1, p2 in
            let ascending = descriptor.order == .forward

            switch descriptor.keyPath {
            case \.name:
                let v1 = p1.name
                let v2 = p2.name
                return ascending ? v1 < v2 : v1 > v2

            case \.manufacturerForSorting:
                let v1 = p1.manufacturerForSorting
                let v2 = p2.manufacturerForSorting
                return ascending ? v1 < v2 : v1 > v2

            case \.versionForSorting:
                let v1 = p1.versionForSorting
                let v2 = p2.versionForSorting
                return ascending ? v1 < v2 : v1 > v2

            case \.sizeForSorting:
                let v1 = p1.sizeForSorting
                let v2 = p2.sizeForSorting
                return ascending ? v1 < v2 : v1 > v2

            default:
                return false
            }
        }
    }

    var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Plugins Found")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Click 'Scan' to search for plugins on your system")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct Checkbox: View {
    @EnvironmentObject var scanner: PluginScanner
    let plugin: Plugin

    var body: some View {
        Button(action: {
            toggleSelection()
        }) {
            Image(systemName: plugin.isSelected ? "checkmark.square.fill" : "square")
                .foregroundColor(plugin.isSelected ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func toggleSelection() {
        if let index = scanner.plugins.firstIndex(where: { $0.id == plugin.id }) {
            scanner.plugins[index].isSelected.toggle()
        }
    }
}

struct FilterBar: View {
    @Binding var selectedFormat: PluginFormat?
    @Binding var searchText: String
    var onSelectAll: () -> Void
    var onDeselectAll: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Search Box
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search plugins...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
            .frame(minWidth: 200, maxWidth: 300)

            // Select All / Deselect All
            HStack(spacing: 4) {
                Button("Select All", action: onSelectAll)
                    .help("Select all visible plugins")
                Button("Deselect", action: onDeselectAll)
                    .help("Deselect all visible plugins")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            // Format Filter
            Menu {
                Button("All Formats") {
                    selectedFormat = nil
                }
                Divider()
                ForEach(PluginFormat.allCases, id: \.self) { format in
                    Button {
                        selectedFormat = format == selectedFormat ? nil : format
                    } label: {
                        HStack {
                            Text(format.rawValue + " " + format.icon)
                            if selectedFormat == format {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedFormat.map { "\($0.rawValue) \($0.icon)" } ?? "All Formats")
                        .foregroundColor(selectedFormat != nil ? .primary : .secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct PluginDetailSheet: View {
    let plugin: Plugin
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plugin.name)
                        .font(.title)
                        .fontWeight(.bold)

                    HStack(spacing: 8) {
                        ForEach(Array(plugin.formats), id: \.self) { format in
                            Text(format.rawValue + " " + format.icon)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .cornerRadius(6)
                        }

                        if let manufacturer = plugin.manufacturer {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(manufacturer)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let version = plugin.version {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(version)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Size info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Size")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(plugin.formattedSize)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        if plugin.hasMultipleFormats {
                            HStack(spacing: 4) {
                                Image(systemName: "square.stack.3d.up")
                                Text("Multi-format plugin")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)

                    // All locations
                    VStack(alignment: .leading, spacing: 12) {
                        Text("All Locations (\(plugin.paths.count))")
                            .font(.headline)
                            .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(plugin.paths.enumerated()), id: \.offset) { index, path in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("\(index + 1).")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 30, alignment: .trailing)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(path.path)
                                                .font(.body)
                                                .textSelection(.enabled)

                                            if let attrs = try? FileManager.default.attributesOfItem(atPath: path.path) {
                                                let size = (attrs[.size] as? Int64) ?? 0
                                                let type = (attrs[.type] as? FileAttributeType) ?? .typeUnknown

                                                HStack(spacing: 8) {
                                                    Text(type == .typeDirectory ? "📁" : "📄")
                                                        .font(.caption2)
                                                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)

                                                    if type == .typeDirectory {
                                                        if let contents = try? FileManager.default.contentsOfDirectory(atPath: path.path) {
                                                            Text("(\(contents.count) items)")
                                                                .font(.caption2)
                                                                .foregroundColor(.secondary)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    Divider().padding(.leading, 40)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 700, height: 500)
    }
}

#Preview {
    PluginListView(
        plugins: [],
        selectedFormat: .constant(nil),
        searchText: .constant("")
    )
    .environmentObject(PluginScanner())
}
