import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    var body: some View {
        VStack(spacing: 24) {
            // App Icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            VStack(spacing: 8) {
                Text("Audio Plugin Manager")
                    .font(.system(size: 24, weight: .bold))

                Text("Version 1.0")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(width: 300)

            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("A native macOS application for managing")
                        .foregroundColor(.secondary)

                    Text("audio plugins (VST, VST2, VST3, AU, CLAP)")
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 8) {
                    Button(action: {
                        if let url = URL(string: "mailto:github@bazooka.systems") {
                            openURL(url)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "envelope.fill")
                            Text("github@bazooka.systems")
                        }
                        .font(.body)
                    }
                    .buttonStyle(.link)

                    Text("Contact for support and feedback")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
        .padding(30)
        .frame(width: 450, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    AboutView()
}
