import AppKit
import UniformTypeIdentifiers

/// Orquesta las conversiones lanzadas desde las Acciones rápidas de Finder:
/// diálogo/estimación → destino → HUD de progreso → transcoder/exportador → avisos.
/// Se ejecuta en un proceso corto (modo `--convert-*`) que termina al acabar.
@MainActor
final class ConversionCoordinator {
    static let shared = ConversionCoordinator()

    // MARK: - Vídeo → vídeo

    func convertVideos(_ urls: [URL]) async {
        let videos = urls.filter { $0.isFileURL }
        guard !videos.isEmpty else { return }

        let label = videos.count == 1 ? videos[0].lastPathComponent : "\(videos.count) vídeos"
        guard let options = ConvertOptionsDialog.present(fileName: label) else { return }

        for url in videos {
            guard let destination = askDestination(for: url, ext: "mp4", suffix: " convertido") else { continue }
            let hud = ProgressHUD(label: "Convirtiendo \(url.lastPathComponent)…")
            hud.show()
            do {
                try await VideoTranscoder.transcode(source: url,
                                                    destination: destination,
                                                    codec: options.codec,
                                                    quality: options.quality,
                                                    customMbps: Preferences.shared.customMbps) { fraction in
                    Task { @MainActor in hud.fraction = fraction }
                }
                hud.close()
                revealInFinder(destination)
            } catch {
                hud.close()
                presentError(title: "No se pudo convertir el vídeo", error: error)
            }
        }
    }

    // MARK: - Vídeo → GIF

    func convertToGIFs(_ urls: [URL]) async {
        let videos = urls.filter { $0.isFileURL }
        guard !videos.isEmpty else { return }

        let prefs = Preferences.shared
        for url in videos {
            let estimate: GIFEstimate
            do {
                estimate = try await GIFSizeEstimator.estimate(for: url, fps: prefs.gifFPS, scale: prefs.gifScale)
            } catch {
                presentError(title: "No se pudo analizar el vídeo", error: error)
                continue
            }
            if estimate.estimatedMB > Double(prefs.gifMaxMB) {
                guard confirmLargeGIF(fileName: url.lastPathComponent, estimate: estimate, limitMB: prefs.gifMaxMB) else {
                    continue // por defecto se cancela
                }
            }
            let destination: URL
            if prefs.gifSaveNextToSource {
                // Guardar junto al vídeo original, sin preguntar.
                destination = Self.uniqueURL(folder: url.deletingLastPathComponent(),
                                             base: url.deletingPathExtension().lastPathComponent,
                                             ext: "gif")
            } else {
                guard let chosen = askDestination(for: url, ext: "gif", suffix: "") else { continue }
                destination = chosen
            }
            let hud = ProgressHUD(label: "Exportando GIF de \(url.lastPathComponent)…")
            hud.show()
            do {
                try await GIFExporter.export(video: url,
                                             to: destination,
                                             fps: prefs.gifFPS,
                                             scale: prefs.gifScale) { fraction in
                    Task { @MainActor in hud.fraction = fraction }
                }
                hud.close()
                revealInFinder(destination)
            } catch {
                hud.close()
                presentError(title: "No se pudo crear el GIF", error: error)
            }
        }
    }

    // MARK: - Auxiliares

    private func askDestination(for source: URL, ext: String, suffix: String) -> URL? {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSSavePanel()
        panel.title = "Guardar conversión"
        panel.directoryURL = source.deletingLastPathComponent()
        panel.nameFieldStringValue = source.deletingPathExtension().lastPathComponent + suffix + "." + ext
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        if let type = UTType(filenameExtension: ext) {
            panel.allowedContentTypes = [type]
        }
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Aviso cuando el GIF estimado supera el límite. Por defecto (Return) cancela.
    private func confirmLargeGIF(fileName: String, estimate: GIFEstimate, limitMB: Int) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let minutes = Int(estimate.durationSeconds / 60)
        let seconds = Int(estimate.durationSeconds.truncatingRemainder(dividingBy: 60))
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "«\(fileName)» es demasiado largo para GIF"
        alert.informativeText = """
        Duración \(minutes) min \(seconds) s → el GIF ocuparía aproximadamente \
        \(Int(estimate.estimatedMB)) MB (\(estimate.frames) fotogramas), por encima del \
        límite de \(limitMB) MB.

        Un GIF así puede tardar mucho, llenar el disco y ralentizar PowerPoint. Para \
        una presentación suele ser mejor insertar el vídeo MP4 directamente.

        Puedes reducir el tamaño bajando los fps o la escala del GIF en Ajustes.
        """
        alert.addButton(withTitle: "Cancelar")             // por defecto (Return)
        alert.addButton(withTitle: "Convertir igualmente")
        return alert.runModal() == .alertSecondButtonReturn
    }

    private func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// URL única en `folder` (añade « 2», « 3»… si el archivo ya existe).
    private static func uniqueURL(folder: URL, base: String, ext: String) -> URL {
        var url = folder.appendingPathComponent(base).appendingPathExtension(ext)
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base) \(counter)").appendingPathExtension(ext)
            counter += 1
        }
        return url
    }

    private func presentError(title: String, error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
