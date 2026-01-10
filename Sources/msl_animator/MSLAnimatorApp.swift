import SwiftUI

@main
struct MSLAnimatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("Shader Studio") {
            ContentView()
                .environmentObject(appState)
        }
        WindowGroup("Presentation", id: "presentation") {
            PresentationView()
                .environmentObject(appState)
        }
        WindowGroup("Video Source", id: "video-source") {
            CleanOutputView()
                .environmentObject(appState)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    appState.loadShader()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save...") {
                    appState.saveShader()
                }
                .keyboardShortcut("s", modifiers: .command)
            }

            CommandMenu("Video Source") {
                Button("Open Output Window") {
                    NotificationCenter.default.post(name: .openVideoSource, object: nil)
                }
            }

            // Export Menu
            CommandMenu("Export") {
                Button("Save Image...") {
                    appState.saveImage()
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("Export Movie...") {
                    appState.showExportDialog = true
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}

extension Notification.Name {
    static let openVideoSource = Notification.Name("OpenVideoSource")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
