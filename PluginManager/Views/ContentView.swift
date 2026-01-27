import SwiftUI

struct ContentView: View {
    @EnvironmentObject var scanner: PluginScanner
    @EnvironmentObject var manager: PluginManager

    @State private var selectedTab = 0
    @State private var selectedFormat: PluginFormat?
    @State private var searchText = ""
    @State private var showingRemovalDialog = false
    @State private var removalOption: RemovalOption = .trash
    @State private var showingBackupSheet = false

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
                onScan: { scanner.scanForPlugins() },
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

                BackupView(
                    plugins: scanner.plugins,
                    selectedPlugins: selectedPlugins
                )
                .tabItem {
                    Label("Backup", systemImage: "arrow.down.doc")
                }
                    .tag(2)
            }

            // Footer
            FooterView(
                selectedCount: selectedPlugins.count,
                onRemove: {
                    showingRemovalDialog = true
                },
                onBackup: {
                    showingBackupSheet = true
                }
            )
            .disabled(selectedPlugins.isEmpty || manager.isProcessing)
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $showingBackupSheet) {
            BackupSheetView(plugins: selectedPlugins)
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
}

struct HeaderView: View {
    let pluginCount: Int
    let selectedCount: Int
    let isScanning: Bool
    let onScan: () -> Void
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

            HStack(spacing: 12) {
                Button(action: onScan) {
                    Label("Scan", systemImage: "magnifyingglass")
                }
                .disabled(isScanning)

                Button(action: onRefresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isScanning)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct FooterView: View {
    let selectedCount: Int
    let onRemove: () -> Void
    let onBackup: () -> Void

    var body: some View {
        HStack {
            Text("\(selectedCount) plugin(s) selected")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 12) {
                Button(action: onBackup) {
                    Label("Backup Selected", systemImage: "arrow.down.doc")
                }

                Button(action: onRemove) {
                    Label("Remove Selected", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
            }
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

#Preview {
    ContentView()
        .environmentObject(PluginScanner())
        .environmentObject(PluginManager())
}
