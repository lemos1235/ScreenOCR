import SwiftUI

@main
struct Screen_OCRApp: App {
    // Use AppDelegate for menu bar setup and global hotkeys
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window scene. Our app is menu-bar based.
        Settings { // Provides an empty settings scene if needed,
                   // otherwise the app might not launch correctly as a pure agent.
            EmptyView()
        }
    }
}