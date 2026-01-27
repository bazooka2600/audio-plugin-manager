import SwiftUI

struct PluginListView: View {
    @EnvironmentObject var scanner: PluginScanner

    var plugins: [Plugin]
    @Binding var selectedFormat: PluginFormat?
    @Binding var searchText: String

    @State private var sortOption: SortOption = .name
    @State private var sortAscending = true

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case size = "Size"
        case formats = "Formats"
    }

    var sortedPlugins: [Plugin] {
        let sorted = plugins.sorted { p1, p2 in
            switch sortOption {
            case .name:
                return sortAscending ? p1.name < p2.name : p1.name > p2.name
            case .size:
                return sortAscending ? p1.totalSize < p2.totalSize : p1.totalSize > p2.totalSize
            case .formats:
                return sortAscending ? p1.formats.count < p2.formats.count : p1.formats.count > p2.formats.count
            }
        }
        return sorted
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter Bar with search
            FilterBar(
                selectedFormat: $selectedFormat,
                sortOption: $sortOption,
                sortAscending: $sortAscending,
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
        Table(sortedPlugins) {
            TableColumn("") { plugin in
                Checkbox(plugin: plugin)
            }
            .width(30)

            TableColumn("Name") { plugin in
                HStack {
                    Text(plugin.name)
                        .font(.body)
                    if plugin.hasMultipleFormats {
                        Image(systemName: "square.stack.3d.up")
                            .foregroundColor(.accentColor)
                            .help("Multiple formats available")
                    }
                }
            }

            TableColumn("Formats") { plugin in
                HStack(spacing: 4) {
                    ForEach(Array(plugin.formats), id: \.self) { format in
                        Text(format.rawValue + " " + format.icon)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                }
            }

            TableColumn("Manufacturer") { plugin in
                Text(plugin.manufacturer ?? "Unknown")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TableColumn("Version") { plugin in
                Text(plugin.version ?? "N/A")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TableColumn("Size") { plugin in
                Text(plugin.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TableColumn("Location") { plugin in
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(plugin.paths.prefix(2), id: \.self) { path in
                        Text(path.path)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    if plugin.paths.count > 2 {
                        Text("+ \(plugin.paths.count - 2) more")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
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
    @Binding var sortOption: PluginListView.SortOption
    @Binding var sortAscending: Bool
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

            // Sort Options
            Picker("Sort", selection: $sortOption) {
                ForEach(PluginListView.SortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            Button(action: {
                sortAscending.toggle()
            }) {
                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
            }
            .help("Sort order")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
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
