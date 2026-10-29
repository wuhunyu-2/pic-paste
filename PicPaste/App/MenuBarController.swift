import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let coordinator: AppCoordinator
    private var settingsWindow: NSWindow?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        statusItem.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "PicPaste")
        statusItem.button?.toolTip = "PicPaste · 截图 \(AppSettings.captureHotkeyDescription)"
        let menu = NSMenu()
        // Carbon owns the hotkey. Avoid registering a second, menu-local equivalent.
        menu.addItem(NSMenuItem(title: "截图（\(AppSettings.captureHotkeyDescription)）", action: #selector(capture), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "取消当前截图", action: #selector(cancelCapture), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 PicPaste", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    func showHotkeyRegistrationFailure(_ error: Error) {
        let warning = NSMenuItem(
            title: "全局快捷键不可用：\(error.localizedDescription)",
            action: nil,
            keyEquivalent: ""
        )
        warning.isEnabled = false
        statusItem.menu?.insertItem(warning, at: 1)
        statusItem.button?.toolTip = "PicPaste · 全局快捷键不可用，可从菜单栏操作"
    }

    @objc private func capture() { coordinator.requestCapture() }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 250),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "PicPaste 设置"
            window.contentView = NSHostingView(rootView: SettingsView())
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // AppKit objects must be invalidated on the main actor, not in deinit.
    func invalidate() {
        statusItem.menu = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}
