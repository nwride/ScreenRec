import AppKit

/// Dibuja el velo oscuro, el recuadro de arrastre con sus medidas y la pista
/// inicial. Devuelve la selección en coordenadas globales.
final class SelectionView: NSView {
    var onCommit: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var dragOrigin: NSPoint?
    private var selectionRect: NSRect = .zero
    private var isDragging = false
    private let minSize: CGFloat = 16

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NSCursor.crosshair.set()
    }

    // MARK: - Ratón

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        dragOrigin = convert(event.locationInWindow, from: nil)
        isDragging = false
        selectionRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin else { return }
        let p = convert(event.locationInWindow, from: nil)
        var rect = NSRect(x: min(origin.x, p.x),
                          y: min(origin.y, p.y),
                          width: abs(p.x - origin.x),
                          height: abs(p.y - origin.y))
        rect = rect.intersection(bounds)
        if rect.isNull { rect = .zero }
        selectionRect = rect
        if rect.width > 4, rect.height > 4 { isDragging = true }
        NSCursor.crosshair.set()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { dragOrigin = nil }
        guard isDragging else {
            onCancel?() // clic sin arrastre = cancelar
            return
        }
        var rect = selectionRect.integral.intersection(bounds)
        // dimensiones pares en puntos → píxeles pares con escala 1x y 2x
        rect.size.width = CGFloat(Int(rect.width) - Int(rect.width) % 2)
        rect.size.height = CGFloat(Int(rect.height) - Int(rect.height) % 2)
        guard rect.width >= minSize, rect.height >= minSize, let window else {
            onCancel?()
            return
        }
        let global = rect.offsetBy(dx: window.frame.minX, dy: window.frame.minY)
        onCommit?(global)
    }

    override func keyDown(with event: NSEvent) {
        // ESC lo gestiona el monitor del controlador; se sobreescribe para evitar el beep
    }

    // MARK: - Dibujo

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.25).setFill()
        bounds.fill()

        if isDragging {
            // agujero transparente en la zona seleccionada
            NSColor.clear.setFill()
            selectionRect.fill(using: .copy)

            let stroke = NSBezierPath(rect: selectionRect.insetBy(dx: -0.5, dy: -0.5))
            stroke.lineWidth = 1
            NSColor.white.setStroke()
            stroke.stroke()

            let text = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
            drawChip(text: text,
                     at: NSPoint(x: selectionRect.maxX, y: selectionRect.minY - 10),
                     anchor: .topRight)
        } else {
            drawChip(text: "Arrastra para seleccionar el área que quieres grabar  ·  ESC para cancelar",
                     at: NSPoint(x: bounds.midX, y: bounds.midY),
                     anchor: .center)
        }
    }

    private enum ChipAnchor { case center, topRight }

    private func drawChip(text: String, at point: NSPoint, anchor: ChipAnchor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        var origin: NSPoint
        switch anchor {
        case .center:
            origin = NSPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
        case .topRight:
            origin = NSPoint(x: point.x - size.width, y: point.y - size.height)
        }
        origin.x = max(10, min(origin.x, bounds.maxX - size.width - 10))
        origin.y = max(10, min(origin.y, bounds.maxY - size.height - 10))

        let paddingX: CGFloat = 8
        let paddingY: CGFloat = 4
        let background = NSRect(x: origin.x - paddingX,
                                y: origin.y - paddingY,
                                width: size.width + paddingX * 2,
                                height: size.height + paddingY * 2)
        let path = NSBezierPath(roundedRect: background, xRadius: 6, yRadius: 6)
        NSColor.black.withAlphaComponent(0.65).setFill()
        path.fill()
        string.draw(at: origin)
    }
}
