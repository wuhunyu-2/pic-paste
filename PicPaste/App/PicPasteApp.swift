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
    private let hotkeys = GlobalHotkeyManager(backend: CarbonHotkeyBackend())
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController(coordinator: coordinator)
        do {
            try hotkeys.register(AppSettings.defaultCaptureHotkey) { [weak self] in
                self?.coordinator.requestCapture()
            }
        } catch {
            menuBar?.showHotkeyRegistrationFailure(error)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeys.invalidate()
        menuBar?.invalidate()
        menuBar = nil
    }
}
