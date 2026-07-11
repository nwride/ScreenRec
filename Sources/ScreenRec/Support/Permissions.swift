import AppKit

enum Permissions {
    static var hasScreenCapture: Bool { CGPreflightScreenCaptureAccess() }

    /// Devuelve true si hay permiso de Grabación de pantalla. Si no lo hay,
    /// dispara la petición del sistema (solo aparece la primera vez) y muestra
    /// una alerta con instrucciones.
    @MainActor
    @discardableResult
    static func ensureScreenCapture() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        CGRequestScreenCaptureAccess()
        presentDeniedAlert()
        return false
    }

    @MainActor
    private static func presentDeniedAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "ScreenRec necesita permiso de Grabación de pantalla"
        alert.informativeText = """
        Actívalo en Ajustes del Sistema → Privacidad y seguridad → Grabación de \
        pantalla y audio del sistema.

        Después pulsa «Relanzar ScreenRec»: macOS solo aplica este permiso al \
        reiniciar la app.
        """
        alert.addButton(withTitle: "Abrir Ajustes del Sistema")
        alert.addButton(withTitle: "Relanzar ScreenRec")
        alert.addButton(withTitle: "Cancelar")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let pane = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            if let url = URL(string: pane) {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            relaunch()
        default:
            break
        }
    }

    static func relaunch() {
        let path = Bundle.main.bundlePath
        if path.hasSuffix(".app") {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-n", path]
            try? process.run()
        }
        NSApp.terminate(nil)
    }
}
