import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 470),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Ajustes de ScreenRec"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
