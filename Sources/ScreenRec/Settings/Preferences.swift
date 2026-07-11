import AppKit

extension Notification.Name {
    /// Los atajos guardados han cambiado (hay que re-registrarlos).
    static let shortcutsChanged = Notification.Name("ScreenRec.shortcutsChanged")
    /// El usuario está grabando una combinación en Ajustes (pausar atajos globales).
    static let shortcutCaptureBegan = Notification.Name("ScreenRec.shortcutCaptureBegan")
    static let shortcutCaptureEnded = Notification.Name("ScreenRec.shortcutCaptureEnded")
}

enum AfterRecording: String { case ask, autosave }
enum VideoCodecChoice: String { case h264, hevc }
enum QualityChoice: String { case high, medium, low, custom }
enum CaptureResolution: String { case native, reduced }

/// Acceso tipado a UserDefaults. Las claves también las usa `@AppStorage` en Ajustes.
final class Preferences {
    static let shared = Preferences()

    enum Key {
        static let afterRecording     = "afterRecording"
        static let autosaveFolder     = "autosaveFolder"
        static let codec              = "codec"
        static let quality            = "quality"
        static let customMbps         = "customMbps"
        static let fps                = "fps"
        static let captureResolution  = "captureResolution"
        static let showsCursor        = "showsCursor"
        static let borderColor        = "borderColor"
        static let gifFPS             = "gifFPS"
        static let gifScale           = "gifScale"
        static let gifMaxMB           = "gifMaxMB"
        static let startKeyCode       = "startKeyCode"
        static let startModifiers     = "startModifiers"
        static let stopKeyCode        = "stopKeyCode"
        static let stopModifiers      = "stopModifiers"
        static let lastSaveDirectory  = "lastSaveDirectory"
    }

    private let d = UserDefaults.standard

    private init() {
        d.register(defaults: [
            Key.afterRecording: AfterRecording.ask.rawValue,
            Key.autosaveFolder: Self.desktopPath,
            Key.codec: VideoCodecChoice.h264.rawValue,
            Key.quality: QualityChoice.high.rawValue,
            Key.customMbps: 8.0,
            Key.fps: 30,
            Key.captureResolution: CaptureResolution.native.rawValue,
            Key.showsCursor: true,
            Key.borderColor: "1.0 0.27 0.23 1.0",
            Key.gifFPS: 10,
            Key.gifScale: 0.5,
            Key.gifMaxMB: 100,
            Key.startKeyCode: Int(Shortcut.defaultStart.keyCode),
            Key.startModifiers: Int(Shortcut.defaultStart.modifiers.rawValue),
            Key.stopKeyCode: Int(Shortcut.defaultStop.keyCode),
            Key.stopModifiers: Int(Shortcut.defaultStop.modifiers.rawValue),
        ])
    }

    static var desktopPath: String {
        let url = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        return (url ?? FileManager.default.homeDirectoryForCurrentUser).path
    }

    // MARK: - General

    var afterRecording: AfterRecording {
        AfterRecording(rawValue: d.string(forKey: Key.afterRecording) ?? "") ?? .ask
    }

    var autosaveFolderURL: URL {
        URL(fileURLWithPath: d.string(forKey: Key.autosaveFolder) ?? Self.desktopPath)
    }

    var lastSaveDirectoryURL: URL? {
        get {
            guard let path = d.string(forKey: Key.lastSaveDirectory) else { return nil }
            return URL(fileURLWithPath: path)
        }
        set { d.set(newValue?.path, forKey: Key.lastSaveDirectory) }
    }

    // MARK: - Vídeo

    var codec: VideoCodecChoice {
        VideoCodecChoice(rawValue: d.string(forKey: Key.codec) ?? "") ?? .h264
    }

    var quality: QualityChoice {
        QualityChoice(rawValue: d.string(forKey: Key.quality) ?? "") ?? .high
    }

    var customMbps: Double { d.double(forKey: Key.customMbps) }

    var fps: Int {
        let value = d.integer(forKey: Key.fps)
        return value > 0 ? value : 30
    }

    var captureResolution: CaptureResolution {
        CaptureResolution(rawValue: d.string(forKey: Key.captureResolution) ?? "") ?? .native
    }

    var showsCursor: Bool { d.bool(forKey: Key.showsCursor) }

    /// Bitrate en bits/s para las preferencias actuales y unas dimensiones/fps dados.
    func effectiveBitrate(pixelWidth: Int, pixelHeight: Int, fps: Int) -> Int {
        Self.bitrate(codec: codec, quality: quality, customMbps: customMbps,
                     pixelWidth: pixelWidth, pixelHeight: pixelHeight, fps: fps)
    }

    /// Bitrate en bits/s para unos parámetros explícitos (lo usa el transcoder).
    static func bitrate(codec: VideoCodecChoice, quality: QualityChoice, customMbps: Double,
                        pixelWidth: Int, pixelHeight: Int, fps: Int) -> Int {
        if quality == .custom {
            let mbps = customMbps > 0 ? customMbps : 8
            return Int(mbps * 1_000_000)
        }
        let bitsPerPixel: Double
        switch quality {
        case .medium: bitsPerPixel = 0.07
        case .low:    bitsPerPixel = 0.04
        default:      bitsPerPixel = 0.12
        }
        var rate = Double(pixelWidth) * Double(pixelHeight) * Double(fps) * bitsPerPixel
        if codec == .hevc { rate *= 0.65 }
        return Int(min(max(rate, 1_000_000), 60_000_000))
    }

    // MARK: - Recuadro

    var borderColor: NSColor {
        get {
            let raw = d.string(forKey: Key.borderColor) ?? ""
            let parts = raw.split(separator: " ").compactMap { Double($0) }
            guard parts.count == 4 else { return .systemRed }
            return NSColor(srgbRed: parts[0], green: parts[1], blue: parts[2], alpha: parts[3])
        }
        set {
            guard let c = newValue.usingColorSpace(.sRGB) else { return }
            d.set("\(c.redComponent) \(c.greenComponent) \(c.blueComponent) \(c.alphaComponent)",
                  forKey: Key.borderColor)
        }
    }

    // MARK: - GIF

    var gifFPS: Int {
        let value = d.integer(forKey: Key.gifFPS)
        return value > 0 ? value : 10
    }

    var gifScale: CGFloat {
        let value = d.double(forKey: Key.gifScale)
        return value > 0 ? CGFloat(value) : 0.5
    }

    /// Umbral (MB) por encima del cual se avisa antes de convertir a GIF.
    var gifMaxMB: Int {
        let value = d.integer(forKey: Key.gifMaxMB)
        return value > 0 ? value : 100
    }

    // MARK: - Atajos

    var startShortcut: Shortcut {
        get {
            Shortcut(keyCode: UInt32(d.integer(forKey: Key.startKeyCode)),
                     modifiers: NSEvent.ModifierFlags(rawValue: UInt(d.integer(forKey: Key.startModifiers))))
        }
        set {
            d.set(Int(newValue.keyCode), forKey: Key.startKeyCode)
            d.set(Int(newValue.modifiers.rawValue), forKey: Key.startModifiers)
            NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
        }
    }

    var stopShortcut: Shortcut {
        get {
            Shortcut(keyCode: UInt32(d.integer(forKey: Key.stopKeyCode)),
                     modifiers: NSEvent.ModifierFlags(rawValue: UInt(d.integer(forKey: Key.stopModifiers))))
        }
        set {
            d.set(Int(newValue.keyCode), forKey: Key.stopKeyCode)
            d.set(Int(newValue.modifiers.rawValue), forKey: Key.stopModifiers)
            NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
        }
    }
}
