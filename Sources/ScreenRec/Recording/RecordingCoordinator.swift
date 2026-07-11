import AppKit

/// Orquesta una grabación completa: geometría, borde visual, stream y escritor.
@MainActor
final class RecordingCoordinator {
    private var engine: CaptureEngine?
    private var writer: VideoWriter?
    private var borderWindow: BorderWindow?
    private var activity: NSObjectProtocol?
    private(set) var isRecording = false

    /// La grabación se cortó sola (monitor desconectado, error del stream…).
    var onRuntimeError: ((Error) -> Void)?

    func start(selection: CGRect, screen: NSScreen) async throws {
        let prefs = Preferences.shared
        var pointScale: CGFloat = 1
        if prefs.captureResolution == .native {
            pointScale = screen.backingScaleFactor
        }
        let geometry = DisplayGeometry.captureGeometry(selection: selection,
                                                       screen: screen,
                                                       pointScale: pointScale)
        let fps = prefs.fps
        let bitrate = prefs.effectiveBitrate(pixelWidth: geometry.pixelWidth,
                                             pixelHeight: geometry.pixelHeight,
                                             fps: fps)

        // El borde aparece al instante; la captura tarda unas décimas en arrancar.
        let border = BorderWindow(around: selection, color: prefs.borderColor)
        borderWindow = border

        let url = Self.makeTempURL()
        var pendingWriter: VideoWriter?
        do {
            let writer = try VideoWriter(url: url,
                                         width: geometry.pixelWidth,
                                         height: geometry.pixelHeight,
                                         codec: prefs.codec,
                                         bitrate: bitrate,
                                         fps: fps)
            pendingWriter = writer
            let engine = CaptureEngine(writer: writer)
            engine.onStoppedWithError = { [weak self] error in
                guard let self else { return }
                Task { @MainActor in
                    guard self.isRecording else { return }
                    self.onRuntimeError?(error)
                }
            }
            try await engine.start(displayID: DisplayGeometry.displayID(of: screen),
                                   sourceRect: geometry.sourceRect,
                                   pixelWidth: geometry.pixelWidth,
                                   pixelHeight: geometry.pixelHeight,
                                   fps: fps,
                                   showsCursor: prefs.showsCursor)
            self.writer = writer
            self.engine = engine
            isRecording = true
            activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled],
                                                             reason: "Grabando la pantalla")
        } catch {
            border.close()
            borderWindow = nil
            pendingWriter?.cancel()
            throw error
        }
    }

    /// Detiene y finaliza. Devuelve nil si no había grabación en marcha.
    func stop() async -> Result<URL, Error>? {
        guard isRecording, let engine, let writer else { return nil }
        isRecording = false
        borderWindow?.close()
        borderWindow = nil
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        await engine.stop()
        let result = await writer.finish()
        self.engine = nil
        self.writer = nil
        return result
    }

    /// Aborta y borra el temporal (por ejemplo al salir de la app grabando).
    func cancelAndDiscard() {
        isRecording = false
        borderWindow?.close()
        borderWindow = nil
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        let engine = self.engine
        let writer = self.writer
        self.engine = nil
        self.writer = nil
        Task {
            await engine?.stop()
            writer?.cancel()
        }
    }

    private static func makeTempURL() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ScreenRec", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("grabacion-\(UUID().uuidString).mp4")
    }
}
