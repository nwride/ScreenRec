import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStandardEditMenu()
        controller = AppController()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
