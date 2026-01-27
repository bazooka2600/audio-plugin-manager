import SwiftUI

struct MultiFormatView: View {
    @EnvironmentObject var scanner: PluginScanner
    var plugins: [Plugin]

    @State private var searchText = ""
    @State private var expandedPlugin: Plugin?

    var filteredPlugins: [Plugin] {
        plugins.filter { plugin in
            searchText.isEmpty || plugin.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var groupedPlugins: [(manufacturer: String, plugins: [Plugin])] {
        let grouped = Dictionary(grouping: filteredPlugins) { plugin in
            plugin.manufacturer ?? "Unknown Manufacturer"
        }
        return grouped.map { (manufacturer: $0.key, plugins: $0.value) }
            .sorted { $0.manufacturer < $1.manufacturer }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with info
            HStack {
                VStack(alignment: .leading) {
                    Text("Multi-Format Plugins")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("\(plugins.count) plugins available in multiple formats")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search plugins...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .frame(width: 200)
            }
            .padding(20)

            Divider()

            // Plugin List grouped by manufacturer
            if plugins.isEmpty && !scanner.isScanning {
                emptyView
            } else if filteredPlugins.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("No Results")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text("Try adjusting your search")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedPlugins, id: \.manufacturer) { group in
                            ManufacturerSection(
                                manufacturer: group.manufacturer,
                                plugins: group.plugins,
                                expandedPlugin: $expandedPlugin
                            )
                        }
                    }
                }
            }
        }
    }

    var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Multi-Format Plugins")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Plugins that are available in multiple formats will appear here")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ManufacturerSection: View {
    let manufacturer: String
    let plugins: [Plugin]
    @Binding var expandedPlugin: Plugin?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Manufacturer header
            HStack {
                Text(manufacturer)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("(\(plugins.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Plugins in this manufacturer group
            ForEach(plugins) { plugin in
                MultiFormatPluginRow(
                    plugin: plugin,
                    isExpanded: expandedPlugin?.id == plugin.id,
                    onToggle: {
                        withAnimation {
                            expandedPlugin = expandedPlugin?.id == plugin.id ? nil : plugin
                        }
                    }
                )

                if plugin.id != plugins.last?.id {
                    Divider()
                }
            }

            // Spacer between manufacturer groups
            Divider()
                .padding(.vertical, 8)
        }
    }
}

struct MultiFormatPluginRow: View {
    @EnvironmentObject var scanner: PluginScanner
    let plugin: Plugin
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // Checkbox
                    Button(action: {
                        toggleSelection()
                    }) {
                        Image(systemName: plugin.isSelected ? "checkmark.square.fill" : "square")
                            .foregroundColor(plugin.isSelected ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)

                    // Plugin info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(plugin.name)
                                .font(.body)
                                .fontWeight(.medium)

                            Spacer()

                            Text(plugin.formattedSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 8) {
                            // Format badges
                            HStack(spacing: 4) {
                                ForEach(Array(plugin.formats), id: \.self) { format in
                                    Text(format.rawValue + " " + format.icon)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(4)
                                }
                            }

                            if let manufacturer = plugin.manufacturer {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(manufacturer)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Chevron
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Installed Formats")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    ForEach(Array(plugin.formats), id: \.self) { format in
                        formatRow(format)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .background(isExpanded ? Color(nsColor: .alternatingContentBackgroundColors.first ?? .controlBackgroundColor) : Color.clear)
    }

    func formatRow(_ format: PluginFormat) -> some View {
        HStack {
            Text(format.rawValue + " " + format.icon)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                if let path = plugin.paths.first(where: { $0.pathExtension.lowercased() == format.fileExtension.replacingOccurrences(of: ".", with: "") }) {
                    Text(path.path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func toggleSelection() {
        if let index = scanner.plugins.firstIndex(where: { $0.id == plugin.id }) {
            scanner.plugins[index].isSelected.toggle()
        }
    }
}

#Preview {
    MultiFormatView(plugins: [])
        .environmentObject(PluginScanner())
}
