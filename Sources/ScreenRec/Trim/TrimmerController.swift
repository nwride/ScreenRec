import AppKit
import AVKit

/// Muestra un editor de recorte (la UI nativa de macOS, la misma de QuickTime)
/// sobre la grabación recién terminada. Devuelve la URL a guardar: el vídeo
/// recortado si el usuario recorta, o el original si cancela el recorte.
@MainActor
final class TrimmerController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var player: AVPlayer?
    private var playerView: AVPlayerView?
    private var statusObservation: NSKeyValueObservation?
    private var continuation: CheckedContinuation<URL, Never>?
    private var sourceURL: URL = URL(fileURLWithPath: "/")
    private var finished = false

    /// Presenta el editor y espera a que el usuario recorte o cancele.
    func trim(url: URL) async -> URL {
        sourceURL = url
        finished = false
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.present(url: url)
        }
    }

    private func present(url: URL) {
        let player = AVPlayer(url: url)
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .inline
        playerView.showsFrameSteppingButtons = true

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 480),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Recortar grabación — ajusta inicio y fin, y pulsa Recortar"
        window.contentView = playerView
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false

        self.window = window
        self.player = player
        self.playerView = playerView

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // beginTrimming necesita el item cargado; espera a readyToPlay.
        statusObservation = player.currentItem?.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    self.statusObservation = nil
                    self.startTrimming()
                case .failed:
                    self.statusObservation = nil
                    self.finish(with: self.sourceURL) // sin poder recortar: guardar completo
                default:
                    break
                }
            }
        }
    }

    /// Inicia el recorte. `canBeginTrimming` puede tardar un instante en estar
    /// listo tras cargar el vídeo, así que reintenta ~1,5 s antes de rendirse.
    private func startTrimming(retriesLeft: Int = 12) {
        guard !finished, let playerView else { return }
        if playerView.canBeginTrimming {
            playerView.beginTrimming { [weak self] result in
                guard let self else { return }
                Task { @MainActor in
                    if result == .okButton {
                        self.exportTrimmedRange()
                    } else {
                        self.finish(with: self.sourceURL) // cancelar recorte = guardar completo
                    }
                }
            }
        } else if retriesLeft > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                self?.startTrimming(retriesLeft: retriesLeft - 1)
            }
        } else {
            finish(with: sourceURL) // no se pudo recortar: guardar completo
        }
    }

    private func exportTrimmedRange() {
        guard let item = player?.currentItem else {
            finish(with: sourceURL)
            return
        }
        let duration = item.duration
        var start = item.reversePlaybackEndTime
        var end = item.forwardPlaybackEndTime
        if !start.isValid || CMTimeCompare(start, .zero) < 0 { start = .zero }
        if !end.isValid || CMTimeCompare(end, duration) > 0 { end = duration }

        // Si no se recortó nada (rango completo), guardar el original tal cual.
        let trimmedStart = CMTimeCompare(start, .zero) > 0
        let trimmedEnd = CMTimeCompare(end, duration) < 0
        guard (trimmedStart || trimmedEnd), CMTimeCompare(start, end) < 0 else {
            finish(with: sourceURL)
            return
        }

        let range = CMTimeRange(start: start, end: end)
        let destination = Self.makeTempURL()
        let hud = ProgressHUD(label: "Recortando…")
        hud.show()
        let source = sourceURL
        Task { @MainActor in
            do {
                try await VideoTrimmer.export(source: source, range: range, to: destination) { fraction in
                    Task { @MainActor in hud.fraction = fraction }
                }
                hud.close()
                try? FileManager.default.removeItem(at: source) // el recorte sustituye al original
                self.finish(with: destination)
            } catch {
                hud.close()
                AppController.presentError(title: "No se pudo recortar la grabación", error: error)
                self.finish(with: source) // en caso de error, guardar el original
            }
        }
    }

    private func finish(with url: URL) {
        guard !finished else { return }
        finished = true
        statusObservation = nil
        player?.pause()
        window?.delegate = nil
        window?.orderOut(nil)
        window?.close()
        window = nil
        player = nil
        playerView = nil
        if let continuation {
            self.continuation = nil
            continuation.resume(returning: url)
        }
    }

    // Cerrar la ventana equivale a cancelar el recorte (guardar completo).
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        finish(with: sourceURL)
        return false
    }

    private static func makeTempURL() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ScreenRec", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("recorte-\(UUID().uuidString).mp4")
    }
}
