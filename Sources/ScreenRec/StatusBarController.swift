import AppKit

/// Icono en la barra de menús: clic izquierdo ejecuta la acción principal
/// (grabar/detener), clic derecho abre el menú. Muestra el tiempo al grabar.
@MainActor
final class StatusBarController: NSObject {
    private let item: NSStatusItem
    private unowned let controller: AppController
    private var timer: Timer?

    init(controller: AppController) {
        self.controller = controller
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = item.button {
            button.image = Self.symbol("record.circle")
            button.imagePosition = .imageLeft
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "ScreenRec — clic: grabar/detener · clic derecho: menú"
        }
        update(state: .idle)
    }

    private static func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "ScreenRec")
        image?.isTemplate = true
        return image
    }

    private static var recordingImage: NSImage? {
        let base = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: "Grabando")
        let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
        return base?.withSymbolConfiguration(config)
    }

    // MARK: - Clics y menú

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            controller.primaryAction()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let prefs = Preferences.shared

        switch controller.state {
        case .idle:
            addItem(to: menu, title: "Iniciar grabación", action: #selector(startFromMenu))
            addHint(to: menu, text: "Atajo: \(prefs.startShortcut.displayString)")
        case .selecting:
            addItem(to: menu, title: "Cancelar selección", action: #selector(cancelFromMenu))
        case .recording:
            addItem(to: menu, title: "Detener grabación", action: #selector(stopFromMenu))
            addHint(to: menu, text: "Atajo: \(prefs.stopShortcut.displayString)")
        case .busy:
            addHint(to: menu, text: "Guardando…")
        }

        menu.addItem(.separator())
        addItem(to: menu, title: "Ajustes…", action: #selector(openSettingsFromMenu))
        menu.addItem(.separator())
        addItem(to: menu, title: "Salir de ScreenRec", action: #selector(quitFromMenu))

        item.menu = menu
        item.button?.performClick(nil) // muestra el menú
        item.menu = nil // el clic izquierdo vuelve a ser acción directa
    }

    private func addItem(to menu: NSMenu, title: String, action: Selector) {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        menu.addItem(menuItem)
    }

    private func addHint(to menu: NSMenu, text: String) {
        menu.addItem(NSMenuItem(title: text, action: nil, keyEquivalent: ""))
    }

    @objc private func startFromMenu() { controller.startSelection() }
    @objc private func stopFromMenu() { controller.stopRecording() }
    @objc private func cancelFromMenu() { controller.primaryAction() }
    @objc private func openSettingsFromMenu() { controller.openSettings() }
    @objc private func quitFromMenu() { controller.quitRequested() }

    // MARK: - Estado visual

    func update(state: AppState) {
        timer?.invalidate()
        timer = nil
        guard let button = item.button else { return }
        switch state {
        case .idle:
            button.image = Self.symbol("record.circle")
            button.title = ""
        case .selecting:
            button.image = Self.symbol("plus.viewfinder")
            button.title = ""
        case .recording:
            button.image = Self.recordingImage
            refreshElapsed()
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in self.refreshElapsed() }
            }
        case .busy:
            button.image = Self.symbol("arrow.down.circle")
            button.title = ""
        }
    }

    /// Mensaje breve junto al icono (p. ej. «Guardado ✓»).
    func flash(_ text: String, seconds: Double = 2.5) {
        guard let button = item.button else { return }
        button.title = " " + text
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self, self.controller.state == .idle else { return }
            self.update(state: .idle)
        }
    }

    private func refreshElapsed() {
        guard let start = controller.recordingStart, let button = item.button else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        let text = String(format: " %d:%02d", elapsed / 60, elapsed % 60)
        button.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
        ])
    }
}
