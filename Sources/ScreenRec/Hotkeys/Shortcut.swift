import AppKit
import Carbon.HIToolbox

/// Una combinación de teclas global (código de tecla + modificadores).
struct Shortcut: Equatable {
    var keyCode: UInt32
    var modifiers: NSEvent.ModifierFlags

    static let defaultStart = Shortcut(keyCode: UInt32(kVK_ANSI_R), modifiers: [.control, .option])
    static let defaultStop = Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: [.control, .option])

    static func == (lhs: Shortcut, rhs: Shortcut) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers.rawValue == rhs.modifiers.rawValue
    }

    /// Modificadores en el formato que espera Carbon (RegisterEventHotKey).
    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifiers.contains(.command) { value |= UInt32(cmdKey) }
        if modifiers.contains(.option) { value |= UInt32(optionKey) }
        if modifiers.contains(.control) { value |= UInt32(controlKey) }
        if modifiers.contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }

    /// Texto tipo "⌃⌥R" para mostrar en la interfaz.
    var displayString: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + Self.keyName(for: keyCode)
    }

    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Espacio"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            return layoutKeyName(for: keyCode) ?? "tecla \(keyCode)"
        }
    }

    /// Nombre de la tecla según la distribución de teclado activa (soporta ISO español).
    private static func layoutKeyName(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let rawLayoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(rawLayoutData).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = layoutData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> OSStatus in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(layout,
                                  UInt16(keyCode),
                                  UInt16(kUCKeyActionDisplay),
                                  0,
                                  UInt32(LMGetKbdType()),
                                  UInt32(kUCKeyTranslateNoDeadKeysMask),
                                  &deadKeyState,
                                  chars.count,
                                  &length,
                                  &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        let name = String(utf16CodeUnits: chars, count: length).uppercased()
        return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name
    }
}
