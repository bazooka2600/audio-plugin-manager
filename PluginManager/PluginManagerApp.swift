import SwiftUI

@main
struct PluginManagerApp: App {
    @StateObject private var pluginScanner = PluginScanner()
    @StateObject private var pluginManager = PluginManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pluginScanner)
                .environmentObject(pluginManager)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
