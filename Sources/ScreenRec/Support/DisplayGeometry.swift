import AppKit

/// Conversión entre coordenadas de Cocoa (origen abajo-izquierda, globales) y las
/// que espera ScreenCaptureKit (locales al display, origen arriba-izquierda).
enum DisplayGeometry {
    static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let number = screen.deviceDescription[key] as? NSNumber {
            return number.uint32Value
        }
        return CGMainDisplayID()
    }

    struct CaptureGeometry {
        /// Zona a capturar en puntos, relativa al display, origen arriba-izquierda.
        var sourceRect: CGRect
        /// Dimensiones del vídeo en píxeles (siempre pares: requisito del encoder).
        var pixelWidth: Int
        var pixelHeight: Int
    }

    /// `selection` llega en coordenadas globales de Cocoa y ya recortada a la pantalla.
    static func captureGeometry(selection: CGRect, screen: NSScreen, pointScale: CGFloat) -> CaptureGeometry {
        let frame = screen.frame
        let clamped = selection.intersection(frame)
        let localX = clamped.minX - frame.minX
        let localTopY = frame.maxY - clamped.maxY
        var width = Int((clamped.width * pointScale).rounded())
        var height = Int((clamped.height * pointScale).rounded())
        width -= width % 2
        height -= height % 2
        width = max(width, 2)
        height = max(height, 2)
        let source = CGRect(x: localX, y: localTopY, width: clamped.width, height: clamped.height)
        return CaptureGeometry(sourceRect: source, pixelWidth: width, pixelHeight: height)
    }
}
