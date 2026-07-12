import AppKit

enum AppState {
    case idle
    case selecting
    case recording
    case busy // finalizando o en el panel de guardado
}

/// Estado central de la app y cableado entre componentes.
@MainActor
final class AppController: NSObject {
    private(set) var state: AppState = .idle {
        didSet { statusBar?.update(state: state) }
    }
    private(set) var recordingStart: Date?

    private var statusBar: StatusBarController?
    private let hotkeys = HotkeyManager()
    private let selection = SelectionController()
    private let recorder = RecordingCoordinator()
    private let output = OutputHandler()
    private let trimmer = TrimmerController()
    private var settingsController: SettingsWindowController?
    private var startTask: Task<Void, Never>?

    override init() {
        super.init()
        statusBar = StatusBarController(controller: self)

        hotkeys.onStart = { [weak self] in self?.primaryAction() }
        hotkeys.onStop = { [weak self] in self?.stopRecording() }
        hotkeys.registerFromPreferences()

        selection.onSelect = { [weak self] rect, screen in
            self?.beginRecording(selection: rect, screen: screen)
        }
        selection.onCancel = { [weak self] in
            guard let self, self.state == .selecting else { return }
            self.state = .idle
        }

        recorder.onRuntimeError = { [weak self] error in
            self?.recordingInterrupted(error)
        }
    }

    /// Atajo 1 o clic izquierdo en la barra: inicia, cancela o detiene según el estado.
    func primaryAction() {
        switch state {
        case .idle:
            startSelection()
        case .selecting:
            selection.cancel()
        case .recording:
            stopRecording()
        case .busy:
            break
        }
    }

    func startSelection() {
        guard state == .idle else { return }
        guard Permissions.ensureScreenCapture() else { return }
        state = .selecting
        selection.begin()
    }

    private func beginRecording(selection rect: CGRect, screen: NSScreen) {
        guard state == .selecting else { return }
        state = .recording
        recordingStart = Date()
        startTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.recorder.start(selection: rect, screen: screen)
            } catch {
                self.recordingStart = nil
                self.state = .idle
                Self.presentError(title: "No se pudo iniciar la grabación", error: error)
            }
        }
    }

    func stopRecording() {
        guard state == .recording else { return }
        state = .busy
        Task { [weak self] in
            guard let self else { return }
            await self.startTask?.value // por si el arranque aún no terminó
            self.recordingStart = nil
            guard let result = await self.recorder.stop() else {
                self.state = .idle
                return
            }
            switch result {
            case .success(let url):
                var toSave = url
                if Preferences.shared.trimBeforeSaving {
                    toSave = await self.trimmer.trim(url: url)
                }
                await self.output.handle(tempURL: toSave, statusBar: self.statusBar)
            case .failure(let error):
                Self.presentError(title: "La grabación falló", error: error)
            }
            self.state = .idle
        }
    }

    private func recordingInterrupted(_ error: Error) {
        guard state == .recording else { return }
        Self.presentError(title: "La grabación se interrumpió", error: error)
        stopRecording() // intenta salvar lo grabado hasta ahora
    }

    func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController()
        }
        settingsController?.show()
    }

    func quitRequested() {
        if state == .recording {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Hay una grabación en curso"
            alert.informativeText = "Puedes detenerla y guardarla, o descartarla y salir."
            alert.addButton(withTitle: "Detener y guardar")
            alert.addButton(withTitle: "Descartar y salir")
            alert.addButton(withTitle: "Cancelar")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                stopRecording()
                return
            }
            if response == .alertSecondButtonReturn {
                recorder.cancelAndDiscard()
                NSApp.terminate(nil)
            }
            return
        }
        NSApp.terminate(nil)
    }

    static func presentError(title: String, error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
