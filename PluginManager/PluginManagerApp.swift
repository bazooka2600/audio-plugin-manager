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
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Audio Plugin Manager") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationIcon: NSApp.applicationIconImage,
                        .applicationName: "Audio Plugin Manager",
                        .applicationVersion: "1.0",
                        .credits: NSAttributedString(
                            string: "Audio Plugin Manager\n\nManage your VST, VST2, VST3, AU, and CLAP plugins\n\nContact: github@bazooka.systems",
                            attributes: [
                                .font: NSFont.systemFont(ofSize: 12),
                                .paragraphStyle: {
                                    let style = NSMutableParagraphStyle()
                                    style.alignment = .center
                                    return style
                                }()
                            ]
                        )
                    ])
                }
            }
        }
    }
}
