import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @EnvironmentObject var scanner: PluginScanner
    var plugins: [Plugin]
    var selectedPlugins: [Plugin]

    @State private var searchText = ""

    var filteredPlugins: [Plugin] {
        selectedPlugins.filter { plugin in
            searchText.isEmpty || plugin.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var totalBackupSize: Int64 {
        selectedPlugins.reduce(0) { $0 + $1.totalSize }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Backup Plugins")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Plugins selected in the All Plugins tab will be backed up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search selected plugins...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .frame(width: 220)
            }
            .padding(20)

            Divider()

            // Stats bar
            HStack {
                if selectedPlugins.isEmpty {
                    Text("No plugins selected - go to All Plugins tab to select plugins")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("\(selectedPlugins.count) plugin(s) selected for backup")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if totalBackupSize > 0 {
                        Text("Total size: \(ByteCountFormatter.string(fromByteCount: totalBackupSize, countStyle: .file))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            // Plugin list
            if selectedPlugins.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("No Plugins Selected")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("To backup plugins:")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Text("1. Go to the 'All Plugins' tab")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("2. Select plugins using the checkboxes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("3. Click 'Backup Selected' in the footer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredPlugins) { plugin in
                            BackupPluginRow(plugin: plugin)

                            if plugin.id != filteredPlugins.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
}

struct BackupPluginRow: View {
    let plugin: Plugin

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(plugin.name)
                    .font(.body)

                HStack(spacing: 8) {
                    ForEach(Array(plugin.formats), id: \.self) { format in
                        Text(format.rawValue + " " + format.icon)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(plugin.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.05))
    }
}

struct BackupSheetView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: PluginManager

    let plugins: [Plugin]
    @State private var selectedDestination: URL?
    @State private var isShowingFilePicker = false
    @State private var backupInProgress = false
    @State private var backupComplete = false
    @State private var backupError: String?

    var totalSize: Int64 {
        plugins.reduce(0) { $0 + $1.totalSize }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Backup Plugins")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Select a destination folder for the backup")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Plugin summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Backup Summary")
                    .font(.headline)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(plugins.count) plugin(s)")
                            .font(.body)
                        Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        ForEach(plugins.prefix(3), id: \.id) { plugin in
                            Text(plugin.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if plugins.count > 3 {
                            Text("+ \(plugins.count - 3) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }

            // Destination selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Destination")
                    .font(.headline)

                if let destination = selectedDestination {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(destination.lastPathComponent)
                                .font(.body)
                            Text(destination.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Change") {
                            isShowingFilePicker = true
                        }
                        .buttonStyle(.link)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                } else {
                    Button(action: {
                        isShowingFilePicker = true
                    }) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text("Select Destination Folder")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error = backupError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            if backupComplete {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Backup completed successfully!")
                        .font(.body)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(backupInProgress)

                Button("Backup") {
                    startBackup()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedDestination == nil || backupInProgress || backupComplete)
            }
        }
        .padding(24)
        .frame(width: 500, height: 400)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedDestination = url
                }
            case .failure(let error):
                backupError = error.localizedDescription
            }
        }
    }

    private func startBackup() {
        guard let destination = selectedDestination else { return }

        backupInProgress = true
        backupError = nil

        manager.backupPlugins(plugins, to: destination) { success in
            backupInProgress = false
            if success {
                backupComplete = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    BackupView(
        plugins: [],
        selectedPlugins: []
    )
    .environmentObject(PluginScanner())
}
