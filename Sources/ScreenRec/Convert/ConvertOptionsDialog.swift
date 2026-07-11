import AppKit

/// Diálogo modal que pregunta codec y calidad antes de convertir un vídeo.
@MainActor
enum ConvertOptionsDialog {
    struct Result {
        let codec: VideoCodecChoice
        let quality: QualityChoice
    }

    private static let codecOrder: [VideoCodecChoice] = [.h264, .hevc]
    private static let qualityOrder: [QualityChoice] = [.high, .medium, .low]

    /// Devuelve nil si el usuario cancela.
    static func present(fileName: String) -> Result? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Convertir vídeo con ScreenRec"
        alert.informativeText = "«\(fileName)» se convertirá a MP4 con el codec y la calidad que elijas."
        alert.addButton(withTitle: "Convertir")
        alert.addButton(withTitle: "Cancelar")

        let codecPopup = NSPopUpButton(frame: NSRect(x: 90, y: 34, width: 210, height: 26), pullsDown: false)
        codecPopup.addItems(withTitles: ["H.264 (más compatible)", "HEVC / H.265 (ocupa menos)"])
        codecPopup.selectItem(at: codecOrder.firstIndex(of: Preferences.shared.codec) ?? 0)

        let qualityPopup = NSPopUpButton(frame: NSRect(x: 90, y: 2, width: 210, height: 26), pullsDown: false)
        qualityPopup.addItems(withTitles: ["Alta", "Media", "Baja"])
        let currentQualityIndex = qualityOrder.firstIndex(of: Preferences.shared.quality) ?? 0
        qualityPopup.selectItem(at: currentQualityIndex)

        let codecLabel = NSTextField(labelWithString: "Codec:")
        codecLabel.frame = NSRect(x: 0, y: 38, width: 85, height: 20)
        codecLabel.alignment = .right
        let qualityLabel = NSTextField(labelWithString: "Calidad:")
        qualityLabel.frame = NSRect(x: 0, y: 6, width: 85, height: 20)
        qualityLabel.alignment = .right

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 62))
        accessory.addSubview(codecLabel)
        accessory.addSubview(codecPopup)
        accessory.addSubview(qualityLabel)
        accessory.addSubview(qualityPopup)
        alert.accessoryView = accessory

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let codec = codecOrder[safe: codecPopup.indexOfSelectedItem] ?? .h264
        let quality = qualityOrder[safe: qualityPopup.indexOfSelectedItem] ?? .high
        return Result(codec: codec, quality: quality)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
