import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @EnvironmentObject var scanner: PluginScanner
    @EnvironmentObject var manager: PluginManager
    var plugins: [Plugin]

    @State private var selectedDestination: URL?
    @State private var destinationBookmarkData: Data?
    @State private var isShowingFilePicker = false
    @State private var backupInProgress = false

    var totalBackupSize: Int64 {
        plugins.reduce(0) { $0 + $1.totalSize }
    }

    var formatCounts: [PluginFormat: Int] {
        var counts: [PluginFormat: Int] = [:]
        for plugin in plugins {
            for format in plugin.formats {
                counts[format, default: 0] += 1
            }
        }
        return counts
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("Backup All Plugins")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("This will backup all \(plugins.count) discovered plugins to the specified directory. Plugins will be organized into format folders (VST, VST3, AU, CLAP).")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Stats Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Backup Summary")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(plugins.count)")
                                    .font(.system(size: 32, weight: .bold))
                                Text("Total Plugins")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Divider()
                                .frame(height: 50)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(ByteCountFormatter.string(fromByteCount: totalBackupSize, countStyle: .file))
                                    .font(.system(size: 32, weight: .bold))
                                Text("Total Size")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Format breakdown
                            VStack(alignment: .trailing, spacing: 4) {
                                ForEach(PluginFormat.allCases, id: \.self) { format in
                                    if let count = formatCounts[format], count > 0 {
                                        HStack(spacing: 8) {
                                            Text(format.rawValue + " " + format.icon)
                                                .font(.caption)
                                            Text("\(count)")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Divider()

                    // Destination Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Backup Destination")
                            .font(.headline)
                            .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("All plugins will be backed up to this location:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)

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
                                .padding(.horizontal, 20)
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
                                .padding(.horizontal, 20)
                            }
                        }
                    }

                    Divider()
                        .padding(.top, 20)

                    // Backup Button
                    VStack(spacing: 12) {
                        Button(action: {
                            startBackup()
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.doc")
                                Text("Backup All Plugins")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedDestination != nil && !backupInProgress ? Color.accentColor : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedDestination == nil || backupInProgress || plugins.isEmpty)

                        if backupInProgress {
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("Backing up plugins...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // Start accessing the security-scoped resource
                    _ = url.startAccessingSecurityScopedResource()

                    // Save the bookmark data for later access
                    if let bookmarkData = try? url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess]) {
                        self.destinationBookmarkData = bookmarkData
                    }

                    selectedDestination = url
                }
            case .failure(let error):
                print("Error selecting folder: \(error)")
            }
        }
        .overlay(ProcessOverlay(manager: manager))
        .onDisappear {
            // Stop accessing the security-scoped resource when view disappears
            if let url = selectedDestination {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    private func startBackup() {
        guard let destination = selectedDestination else { return }

        backupInProgress = true
        manager.backupPlugins(plugins, to: destination) { success in
            backupInProgress = false
            if success {
                // Optionally show success message
                print("Backup completed successfully")
            }
        }
    }
}
