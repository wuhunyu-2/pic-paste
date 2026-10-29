import Carbon
import Foundation

/// A Carbon virtual-key code and Carbon modifier mask (not AppKit NSEvent flags).
struct HotkeyShortcut: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
}

@MainActor
protocol HotkeyBackend: AnyObject {
    /// Returns a unique registration token. A failed registration must not alter existing tokens.
    func register(_ shortcut: HotkeyShortcut, onTrigger: @escaping @MainActor () -> Void) throws -> UInt32
    func unregister(_ token: UInt32)
    func shutdown()
}

/// Keeps the previous shortcut usable until a replacement has registered successfully.
@MainActor
final class GlobalHotkeyManager {
    private let backend: any HotkeyBackend
    private var current: (shortcut: HotkeyShortcut, token: UInt32)?

    init(backend: any HotkeyBackend) {
        self.backend = backend
    }

    var registeredShortcut: HotkeyShortcut? { current?.shortcut }

    func register(_ shortcut: HotkeyShortcut, onTrigger: @escaping @MainActor () -> Void) throws {
        guard current?.shortcut != shortcut else { return }

        // Register first: on collision the old token/action remain untouched.
        let replacement = try backend.register(shortcut, onTrigger: onTrigger)
        let previous = current
        current = (shortcut, replacement)
        if let previous {
            backend.unregister(previous.token)
        }
    }

    func invalidate() {
        if let current {
            backend.unregister(current.token)
        }
        current = nil
        backend.shutdown()
    }
}

enum HotkeyRegistrationError: Error, LocalizedError {
    case eventHandler(OSStatus)
    case shortcut(OSStatus)

    var errorDescription: String? {
        switch self {
        case .eventHandler(let code):
            return "无法启动系统快捷键监听（错误码 \(code)）。"
        case .shortcut(let code):
            return "截图快捷键可能已被系统或其他应用占用（错误码 \(code)）。"
        }
    }
}

/// Carbon's application event handler executes on the main event loop.
/// It only observes registered shortcut events, never raw keyboard input.
@MainActor
final class CarbonHotkeyBackend: HotkeyBackend {
    private struct Entry {
        let reference: EventHotKeyRef
        let action: @MainActor () -> Void
    }

    private static let signature: OSType = 0x50435050 // 'PCPP'
    private var nextToken: UInt32 = 1
    private var entries: [UInt32: Entry] = [:]
    private var eventHandler: EventHandlerRef?

    func register(_ shortcut: HotkeyShortcut, onTrigger: @escaping @MainActor () -> Void) throws -> UInt32 {
        try ensureHandlerInstalled()

        let token = nextToken
        let identifier = EventHotKeyID(signature: Self.signature, id: token)
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            throw HotkeyRegistrationError.shortcut(status)
        }

        nextToken &+= 1
        entries[token] = Entry(reference: reference, action: onTrigger)
        return token
    }

    func unregister(_ token: UInt32) {
        guard let entry = entries.removeValue(forKey: token) else { return }
        UnregisterEventHotKey(entry.reference)
    }

    func shutdown() {
        for token in Array(entries.keys) {
            unregister(token)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func ensureHandlerInstalled() throws {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: UInt32(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var installed: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotkeyEventCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &installed
        )
        guard status == noErr, let installed else {
            throw HotkeyRegistrationError.eventHandler(status)
        }
        eventHandler = installed
    }

    fileprivate func receive(token: UInt32, signature: OSType) -> OSStatus {
        guard signature == Self.signature, let entry = entries[token] else {
            return OSStatus(eventNotHandledErr)
        }
        entry.action()
        return noErr
    }
}

private func carbonHotkeyEventCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    // Installed on the application event target: Carbon invokes this on the
    // main thread. Extract raw event data BEFORE entering @MainActor so that
    // Swift 6 does not transfer non-Sendable Carbon pointers across isolation.
    guard let event, let userData, Thread.isMainThread else {
        return OSStatus(eventNotHandledErr)
    }
    var identifier = EventHotKeyID(signature: 0, id: 0)
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &identifier
    )
    guard status == noErr else { return OSStatus(eventNotHandledErr) }

    let backendAddress = UInt(bitPattern: userData)
    let token = identifier.id
    let signature = identifier.signature
    return MainActor.assumeIsolated {
        guard let pointer = UnsafeMutableRawPointer(bitPattern: backendAddress) else {
            return OSStatus(eventNotHandledErr)
        }
        let backend = Unmanaged<CarbonHotkeyBackend>.fromOpaque(pointer).takeUnretainedValue()
        return backend.receive(token: token, signature: signature)
    }
}
