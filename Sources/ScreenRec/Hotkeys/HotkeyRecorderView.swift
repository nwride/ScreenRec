import AppKit
import SwiftUI

enum HotkeyKind {
    case start
    case stop
}

/// Campo de Ajustes para grabar una combinación de teclas.
struct HotkeyRecorder: NSViewRepresentable {
    let kind: HotkeyKind

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.kind = kind
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {}
}

final class RecorderNSView: NSView {
    var kind: HotkeyKind = .start

    private var capturing = false {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 160, height: 26) }
    override var acceptsFirstResponder: Bool { true }

    private var shortcut: Shortcut {
        get {
            if kind == .start { return Preferences.shared.startShortcut }
            return Preferences.shared.stopShortcut
        }
        set {
            if kind == .start {
                Preferences.shared.startShortcut = newValue
            } else {
                Preferences.shared.stopShortcut = newValue
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        if capturing {
            endCapture()
        } else {
            beginCapture()
        }
    }

    private func beginCapture() {
        window?.makeFirstResponder(self)
        capturing = true
        // pausa los atajos globales mientras se captura la combinación
        NotificationCenter.default.post(name: .shortcutCaptureBegan, object: nil)
    }

    private func endCapture() {
        guard capturing else { return }
        capturing = false
        NotificationCenter.default.post(name: .shortcutCaptureEnded, object: nil)
    }

    override func resignFirstResponder() -> Bool {
        endCapture()
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard capturing else {
            super.keyDown(with: event)
            return
        }
        handleCaptured(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard capturing, event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }
        handleCaptured(event)
        return true
    }

    private func handleCaptured(_ event: NSEvent) {
        if event.keyCode == 53 { // ESC cancela sin cambiar nada
            endCapture()
            return
        }
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let required: NSEvent.ModifierFlags = [.command, .control, .option]
        guard !mods.intersection(required).isEmpty else {
            NSSound.beep() // exige ⌃, ⌥ o ⌘ para no chocar con la escritura normal
            return
        }
        shortcut = Shortcut(keyCode: UInt32(event.keyCode), modifiers: mods)
        endCapture()
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
        if capturing {
            NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.2).setFill()
        } else {
            NSColor.controlBackgroundColor.setFill()
        }
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        var text = shortcut.displayString
        var color = NSColor.labelColor
        if capturing {
            text = "Pulsa la combinación…"
            color = NSColor.secondaryLabelColor
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: color,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        string.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                                y: (bounds.height - size.height) / 2))
    }
}
