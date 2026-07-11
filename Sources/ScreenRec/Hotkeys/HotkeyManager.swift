import AppKit
import Carbon.HIToolbox

/// Atajos globales con Carbon (RegisterEventHotKey): funcionan con cualquier app
/// en primer plano y no requieren permiso de Accesibilidad.
final class HotkeyManager {
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?

    private var handlerRef: EventHandlerRef?
    private var startRef: EventHotKeyRef?
    private var stopRef: EventHotKeyRef?
    private static let signature: OSType = 0x5352_6563 // 'SRec'
    private static let startID: UInt32 = 1
    private static let stopID: UInt32 = 2

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, eventRef, userData in
            guard let eventRef, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(eventRef,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hotKeyID)
            guard status == noErr, hotKeyID.signature == HotkeyManager.signature else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.dispatch(id: hotKeyID.id)
            return noErr
        }
        InstallEventHandler(GetEventDispatcherTarget(),
                            callback,
                            1,
                            &eventType,
                            Unmanaged.passUnretained(self).toOpaque(),
                            &handlerRef)

        let center = NotificationCenter.default
        center.addObserver(forName: .shortcutsChanged, object: nil, queue: .main) { [weak self] _ in
            self?.registerFromPreferences()
        }
        center.addObserver(forName: .shortcutCaptureBegan, object: nil, queue: .main) { [weak self] _ in
            self?.unregister()
        }
        center.addObserver(forName: .shortcutCaptureEnded, object: nil, queue: .main) { [weak self] _ in
            self?.registerFromPreferences()
        }
    }

    deinit {
        unregister()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    private func dispatch(id: UInt32) {
        DispatchQueue.main.async { [weak self] in
            if id == Self.startID { self?.onStart?() }
            if id == Self.stopID { self?.onStop?() }
        }
    }

    func registerFromPreferences() {
        unregister()
        register(Preferences.shared.startShortcut, id: Self.startID, into: &startRef)
        register(Preferences.shared.stopShortcut, id: Self.stopID, into: &stopRef)
    }

    private func register(_ shortcut: Shortcut, id: UInt32, into ref: inout EventHotKeyRef?) {
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(shortcut.keyCode,
                                         shortcut.carbonModifiers,
                                         hotKeyID,
                                         GetEventDispatcherTarget(),
                                         0,
                                         &ref)
        if status != noErr {
            NSLog("ScreenRec: no se pudo registrar el atajo %@ (error %d)",
                  shortcut.displayString, status)
        }
    }

    private func unregister() {
        if let startRef { UnregisterEventHotKey(startRef) }
        if let stopRef { UnregisterEventHotKey(stopRef) }
        startRef = nil
        stopRef = nil
    }
}
