import AppKit
import SwiftUI

/// Panel flotante con barra de progreso (conversión de vídeo / GIF).
@MainActor
final class ProgressHUD: ObservableObject {
    @Published var fraction: Double = 0
    @Published var label: String

    private var panel: NSPanel?

    init(label: String) {
        self.label = label
    }

    func show() {
        guard panel == nil else { return }
        let hosting = NSHostingView(rootView: ProgressHUDView(model: self))
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 90),
                            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.contentView = hosting
        panel.center()
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }
}

private struct ProgressHUDView: View {
    @ObservedObject var model: ProgressHUD

    var body: some View {
        VStack(spacing: 10) {
            Text(model.label)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            ProgressView(value: min(max(model.fraction, 0), 1))
                .progressViewStyle(.linear)
                .frame(width: 240)
        }
        .padding(20)
        .frame(width: 300)
    }
}
