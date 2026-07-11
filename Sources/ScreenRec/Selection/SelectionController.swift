import AppKit

/// Ventana transparente a pantalla completa donde se dibuja la selección.
final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        sharingType = .none
    }
}

/// Gestiona el modo selección: un overlay por pantalla, cursor en cruceta,
/// ESC o clic sin arrastre cancelan.
@MainActor
final class SelectionController {
    /// Rect en coordenadas globales de Cocoa + pantalla donde se hizo la selección.
    var onSelect: ((CGRect, NSScreen) -> Void)?
    var onCancel: (() -> Void)?

    private var windows: [SelectionWindow] = []
    private var keyMonitor: Any?
    private(set) var isActive = false

    func begin() {
        guard !isActive else { return }
        isActive = true
        NSApp.activate(ignoringOtherApps: true)

        for screen in NSScreen.screens {
            let window = SelectionWindow(screen: screen)
            let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onCommit = { [weak self] globalRect in
                self?.finish(rect: globalRect, screen: screen)
            }
            view.onCancel = { [weak self] in
                self?.cancel()
            }
            window.contentView = view
            window.orderFrontRegardless()
            windows.append(window)
        }

        // La ventana bajo el ratón recibe el teclado (para ESC).
        let mouse = NSEvent.mouseLocation
        let target = windows.first { $0.frame.contains(mouse) } ?? windows.first
        target?.makeKey()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.cancel()
                return nil
            }
            return event
        }
    }

    func cancel() {
        guard isActive else { return }
        tearDown()
        onCancel?()
    }

    private func finish(rect: CGRect, screen: NSScreen) {
        guard isActive else { return }
        tearDown()
        onSelect?(rect, screen)
    }

    private func tearDown() {
        isActive = false
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }
}
