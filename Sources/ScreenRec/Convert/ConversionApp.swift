import AppKit

enum ConversionMode { case video, gif }

/// Modo GUI de un solo uso, invocado por las Acciones rápidas de Finder:
///
///     ScreenRec --convert-gif   <archivo> [<archivo>…]
///     ScreenRec --convert-video <archivo> [<archivo>…]
///
/// Levanta una app accessory (sin icono en la barra), realiza las conversiones
/// mostrando diálogo/panel/HUD y termina al acabar. Es un proceso aparte del
/// ScreenRec de la barra de menús, así que no interfiere con él.
enum ConversionApp {
    static func run(_ args: [String]) -> Never {
        let mode: ConversionMode = args.contains("--convert-gif") ? .gif : .video
        let flag = mode == .gif ? "--convert-gif" : "--convert-video"
        let files = fileArguments(after: flag, in: args)

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = ConversionAppDelegate(mode: mode, files: files)
        app.delegate = delegate
        app.run()
        exit(0)
    }

    private static func fileArguments(after flag: String, in args: [String]) -> [URL] {
        guard let index = args.firstIndex(of: flag) else { return [] }
        return args[(index + 1)...]
            .filter { !$0.hasPrefix("--") }
            .map { URL(fileURLWithPath: $0) }
    }
}

final class ConversionAppDelegate: NSObject, NSApplicationDelegate {
    private let mode: ConversionMode
    private let files: [URL]

    init(mode: ConversionMode, files: [URL]) {
        self.mode = mode
        self.files = files
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStandardEditMenu()
        NSApp.activate(ignoringOtherApps: true)
        Task { @MainActor in
            if files.isEmpty {
                let alert = NSAlert()
                alert.messageText = "No se recibió ningún vídeo para convertir"
                alert.runModal()
            } else {
                switch mode {
                case .video: await ConversionCoordinator.shared.convertVideos(files)
                case .gif:   await ConversionCoordinator.shared.convertToGIFs(files)
                }
            }
            NSApp.terminate(nil)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
