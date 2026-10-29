import AppKit
import SwiftUI

@main
struct PicPasteApp: App {
    @NSApplicationDelegateAdaptor(PicPasteDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class PicPasteDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = AppCoordinator()
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController(coordinator: coordinator)
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBar = nil
    }
}
