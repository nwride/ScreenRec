import AppKit

/// Recuadro de color que rodea el área mientras se graba. Es click-through,
/// queda fuera del área capturada y además se excluye de la captura
/// (sharingType = .none), así que nunca aparece en el vídeo.
final class BorderWindow: NSWindow {
    static let borderWidth: CGFloat = 3

    init(around rect: CGRect, color: NSColor) {
        let outset = rect.insetBy(dx: -(Self.borderWidth + 1), dy: -(Self.borderWidth + 1))
        super.init(contentRect: outset, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        sharingType = .none
        isReleasedWhenClosed = false
        contentView = BorderView(color: color)
        orderFrontRegardless()
    }
}

private final class BorderView: NSView {
    private let color: NSColor

    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("no implementado") }

    override func draw(_ dirtyRect: NSRect) {
        let width = BorderWindow.borderWidth
        let path = NSBezierPath(rect: bounds.insetBy(dx: 1 + width / 2, dy: 1 + width / 2))
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }
}
