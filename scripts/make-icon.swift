// Genera AppIcon.icns dibujado por código (esquinas de encuadre + punto de grabación).
// Uso: swift scripts/make-icon.swift build/AppIcon.icns
import AppKit

func render(size: Int) -> NSBitmapImageRep? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    let s = CGFloat(size)
    let inset = s * 0.08
    let bg = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let bgPath = NSBezierPath(roundedRect: bg, xRadius: s * 0.18, yRadius: s * 0.18)
    let gradient = NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.20, alpha: 1),
                              ending: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.12, alpha: 1))
    gradient?.draw(in: bgPath, angle: -90)

    // Esquinas de encuadre (motivo de la selección)
    let corner = s * 0.16
    let margin = s * 0.20
    let lineWidth = s * 0.035
    NSColor.white.withAlphaComponent(0.85).setStroke()
    let positions: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (margin, s - margin, 1, -1),   // arriba-izquierda
        (s - margin, s - margin, -1, -1), // arriba-derecha
        (margin, margin, 1, 1),        // abajo-izquierda
        (s - margin, margin, -1, 1),   // abajo-derecha
    ]
    for (x, y, dx, dy) in positions {
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: x, y: y + dy * corner))
        path.line(to: NSPoint(x: x, y: y))
        path.line(to: NSPoint(x: x + dx * corner, y: y))
        path.stroke()
    }

    // Punto rojo de grabación
    let radius = s * 0.14
    let dot = NSRect(x: s / 2 - radius, y: s / 2 - radius, width: radius * 2, height: radius * 2)
    NSColor(calibratedRed: 1.0, green: 0.27, blue: 0.23, alpha: 1).setFill()
    NSBezierPath(ovalIn: dot).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let args = CommandLine.arguments
guard args.count > 1 else {
    print("Uso: swift make-icon.swift <salida.icns>")
    exit(1)
}
let outputURL = URL(fileURLWithPath: args[1])
let iconsetURL = outputURL.deletingPathExtension().appendingPathExtension("iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, size) in variants {
    guard let rep = render(size: size), let png = rep.representation(using: .png, properties: [:]) else {
        print("No se pudo dibujar \(name)")
        exit(1)
    }
    try png.write(to: iconsetURL.appendingPathComponent("\(name).png"))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try task.run()
task.waitUntilExit()
try? FileManager.default.removeItem(at: iconsetURL)
guard task.terminationStatus == 0 else {
    print("iconutil falló")
    exit(1)
}
print("Icono generado en \(outputURL.path)")
