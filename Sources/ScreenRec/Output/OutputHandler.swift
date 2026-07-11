import AppKit
import UniformTypeIdentifiers

/// Decide qué hacer con el vídeo terminado: preguntar con un panel de guardado
/// o guardarlo directamente en la carpeta fija.
@MainActor
final class OutputHandler: NSObject {
    func handle(tempURL: URL, statusBar: StatusBarController?) async {
        switch Preferences.shared.afterRecording {
        case .autosave:
            await autosave(tempURL: tempURL, statusBar: statusBar)
        case .ask:
            await askAndSave(tempURL: tempURL)
        }
    }

    // MARK: - Preguntar dónde guardar

    private func askAndSave(tempURL: URL) async {
        NSApp.activate(ignoringOtherApps: true)
        while true {
            let panel = NSSavePanel()
            panel.title = "Guardar grabación"
            panel.nameFieldStringValue = Self.defaultBaseName() + ".mp4"
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            panel.allowedContentTypes = [.mpeg4Movie]
            if let directory = Preferences.shared.lastSaveDirectoryURL {
                panel.directoryURL = directory
            }

            let response = panel.runModal()

            if response == .OK, let destination = panel.url {
                Preferences.shared.lastSaveDirectoryURL = destination.deletingLastPathComponent()
                let saved = deliver(tempURL: tempURL, to: destination, deleteOriginal: true)
                if saved { return }
                continue // falló: volver a preguntar
            }

            // Canceló el panel → confirmar descarte
            let alert = NSAlert()
            alert.messageText = "¿Descartar la grabación?"
            alert.informativeText = "La grabación todavía no se ha guardado."
            alert.addButton(withTitle: "Volver a guardar")
            alert.addButton(withTitle: "Descartar")
            if alert.runModal() == .alertSecondButtonReturn {
                try? FileManager.default.removeItem(at: tempURL)
                return
            }
        }
    }

    // MARK: - Guardado automático

    private func autosave(tempURL: URL, statusBar: StatusBarController?) async {
        let folder = Preferences.shared.autosaveFolderURL
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = Self.uniqueURL(folder: folder, base: Self.defaultBaseName(), ext: "mp4")
        if deliver(tempURL: tempURL, to: destination, deleteOriginal: true) {
            statusBar?.flash("Guardado ✓")
        }
    }

    // MARK: - Entrega

    /// Mueve (o copia) el vídeo al destino. Devuelve true si fue bien.
    private func deliver(tempURL: URL, to destination: URL, deleteOriginal: Bool) -> Bool {
        do {
            try? FileManager.default.removeItem(at: destination)
            if deleteOriginal {
                do {
                    try FileManager.default.moveItem(at: tempURL, to: destination)
                } catch {
                    try FileManager.default.copyItem(at: tempURL, to: destination)
                    try? FileManager.default.removeItem(at: tempURL)
                }
            } else {
                try FileManager.default.copyItem(at: tempURL, to: destination)
            }
            return true
        } catch {
            AppController.presentError(title: "No se pudo guardar la grabación", error: error)
            return false
        }
    }

    // MARK: - Nombres

    private static func defaultBaseName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyy-MM-dd 'a las' HH.mm.ss"
        return "ScreenRec \(formatter.string(from: Date()))"
    }

    private static func uniqueURL(folder: URL, base: String, ext: String) -> URL {
        var url = folder.appendingPathComponent(base).appendingPathExtension(ext)
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base) \(counter)").appendingPathExtension(ext)
            counter += 1
        }
        return url
    }
}
