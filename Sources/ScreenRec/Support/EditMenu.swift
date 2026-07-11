import AppKit

/// Menú Edición mínimo para que ⌘C/⌘V/⌘X/⌘A funcionen en paneles de guardado y
/// campos de texto. Lo usan tanto la app normal como el modo de conversión CLI.
@MainActor
func installStandardEditMenu() {
    let mainMenu = NSMenu()
    let editItem = NSMenuItem()
    mainMenu.addItem(editItem)
    let edit = NSMenu(title: "Edición")
    edit.addItem(withTitle: "Deshacer", action: Selector(("undo:")), keyEquivalent: "z")
    edit.addItem(withTitle: "Rehacer", action: Selector(("redo:")), keyEquivalent: "Z")
    edit.addItem(.separator())
    edit.addItem(withTitle: "Cortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    edit.addItem(withTitle: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    edit.addItem(withTitle: "Pegar", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    edit.addItem(withTitle: "Seleccionar todo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editItem.submenu = edit
    NSApp.mainMenu = mainMenu
}
