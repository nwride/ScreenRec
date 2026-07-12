import AppKit

let cliArgs = CommandLine.arguments
if cliArgs.contains("--convert-gif") || cliArgs.contains("--convert-video") {
    // Modo conversión (lo invocan las Acciones rápidas de Finder).
    ConversionApp.run(cliArgs)
} else if cliArgs.contains("--install-quick-actions") {
    exit(QuickActionsInstaller.install() ? 0 : 1)
} else if cliArgs.contains("--uninstall-quick-actions") {
    QuickActionsInstaller.uninstall()
    exit(0)
} else if cliArgs.contains("--selftest") {
    SelfTest.main(arguments: cliArgs)
} else if cliArgs.contains("--make-test-video") || cliArgs.contains("--to-gif") || cliArgs.contains("--to-mp4") || cliArgs.contains("--trim-test") {
    ConvertSelfTest.run(cliArgs)
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory) // solo barra de menús, sin Dock
    app.run()
}
