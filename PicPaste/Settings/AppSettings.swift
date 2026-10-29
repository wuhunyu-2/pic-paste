import Carbon

/// P0 fixed shortcut. Editing/persistence are deferred to Issue #8.
enum AppSettings {
    static let defaultCaptureHotkey = HotkeyShortcut(
        keyCode: UInt32(kVK_ANSI_S),
        modifiers: UInt32(controlKey | optionKey | shiftKey)
    )
    static let captureHotkeyDescription = "⌃⌥⇧S"
}
