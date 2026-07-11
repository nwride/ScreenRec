import AppKit

/// Instala/desinstala las dos Acciones rápidas de Finder que llaman al modo de
/// conversión de ScreenRec. Genera el mismo `.workflow` que
/// `scripts/install-quick-actions.sh`, para que una instalación limpia (DMG/PKG)
/// pueda activarlas desde Ajustes sin usar la terminal.
enum QuickActionsInstaller {
    static let videoName = "Convertir vídeo con ScreenRec"
    static let gifName = "Convertir a GIF con ScreenRec"

    private static var servicesDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Services", isDirectory: true)
    }

    private static func workflowURL(_ name: String) -> URL {
        servicesDir.appendingPathComponent("\(name).workflow", isDirectory: true)
    }

    static var isInstalled: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: workflowURL(videoName).path)
            && fm.fileExists(atPath: workflowURL(gifName).path)
    }

    @discardableResult
    static func install() -> Bool {
        do {
            try writeWorkflow(name: videoName, title: videoName, flag: "--convert-video")
            try writeWorkflow(name: gifName, title: gifName, flag: "--convert-gif")
            flushServices()
            return true
        } catch {
            NSLog("ScreenRec: no se pudieron instalar las Acciones rápidas: %@", error.localizedDescription)
            return false
        }
    }

    static func uninstall() {
        try? FileManager.default.removeItem(at: workflowURL(videoName))
        try? FileManager.default.removeItem(at: workflowURL(gifName))
        flushServices()
    }

    /// Reinicia Finder para que el menú contextual recoja los cambios al instante.
    static func relaunchFinder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]
        try? process.run()
    }

    // MARK: - Escritura

    private static func writeWorkflow(name: String, title: String, flag: String) throws {
        let base = workflowURL(name)
        let contents = base.appendingPathComponent("Contents", isDirectory: true)
        try? FileManager.default.removeItem(at: base)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try infoPlist(title: title).write(to: contents.appendingPathComponent("Info.plist"),
                                          atomically: true, encoding: .utf8)
        try documentWflow(flag: flag).write(to: contents.appendingPathComponent("document.wflow"),
                                            atomically: true, encoding: .utf8)
    }

    private static func flushServices() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/pbs")
        process.arguments = ["-flush"]
        try? process.run()
        process.waitUntilExit()
    }

    private static func infoPlist(title: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \t<key>NSServices</key>
        \t<array>
        \t\t<dict>
        \t\t\t<key>NSMenuItem</key>
        \t\t\t<dict>
        \t\t\t\t<key>default</key>
        \t\t\t\t<string>\(title)</string>
        \t\t\t</dict>
        \t\t\t<key>NSMessage</key>
        \t\t\t<string>runWorkflowAsService</string>
        \t\t\t<key>NSRequiredContext</key>
        \t\t\t<dict>
        \t\t\t\t<key>NSApplicationIdentifier</key>
        \t\t\t\t<string>com.apple.finder</string>
        \t\t\t</dict>
        \t\t\t<key>NSSendFileTypes</key>
        \t\t\t<array>
        \t\t\t\t<string>public.movie</string>
        \t\t\t</array>
        \t\t</dict>
        \t</array>
        </dict>
        </plist>
        """
    }

    private static func documentWflow(flag: String) -> String {
        let u1 = UUID().uuidString
        let u2 = UUID().uuidString
        let u3 = UUID().uuidString
        let command = """
        app="/Applications/ScreenRec.app"
        if [ ! -x "$app/Contents/MacOS/ScreenRec" ]; then
          app="$(mdfind "kMDItemCFBundleIdentifier == 'io.github.nwride.ScreenRec'" 2>/dev/null | head -1)"
        fi
        "$app/Contents/MacOS/ScreenRec" \(flag) "$@"
        """
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \t<key>AMApplicationBuild</key>
        \t<string>523</string>
        \t<key>AMApplicationVersion</key>
        \t<string>2.10</string>
        \t<key>AMDocumentVersion</key>
        \t<string>2</string>
        \t<key>actions</key>
        \t<array>
        \t\t<dict>
        \t\t\t<key>action</key>
        \t\t\t<dict>
        \t\t\t\t<key>AMAccepts</key>
        \t\t\t\t<dict>
        \t\t\t\t\t<key>Container</key>
        \t\t\t\t\t<string>List</string>
        \t\t\t\t\t<key>Optional</key>
        \t\t\t\t\t<true/>
        \t\t\t\t\t<key>Types</key>
        \t\t\t\t\t<array>
        \t\t\t\t\t\t<string>com.apple.cocoa.string</string>
        \t\t\t\t\t</array>
        \t\t\t\t</dict>
        \t\t\t\t<key>AMActionVersion</key>
        \t\t\t\t<string>2.0.3</string>
        \t\t\t\t<key>AMApplication</key>
        \t\t\t\t<array>
        \t\t\t\t\t<string>Automator</string>
        \t\t\t\t</array>
        \t\t\t\t<key>AMParameterProperties</key>
        \t\t\t\t<dict>
        \t\t\t\t\t<key>COMMAND_STRING</key>
        \t\t\t\t\t<dict/>
        \t\t\t\t\t<key>CheckedForUserDefaultShell</key>
        \t\t\t\t\t<dict/>
        \t\t\t\t\t<key>inputMethod</key>
        \t\t\t\t\t<dict/>
        \t\t\t\t\t<key>shell</key>
        \t\t\t\t\t<dict/>
        \t\t\t\t\t<key>source</key>
        \t\t\t\t\t<dict/>
        \t\t\t\t</dict>
        \t\t\t\t<key>AMProvides</key>
        \t\t\t\t<dict>
        \t\t\t\t\t<key>Container</key>
        \t\t\t\t\t<string>List</string>
        \t\t\t\t\t<key>Types</key>
        \t\t\t\t\t<array>
        \t\t\t\t\t\t<string>com.apple.cocoa.string</string>
        \t\t\t\t\t</array>
        \t\t\t\t</dict>
        \t\t\t\t<key>ActionBundlePath</key>
        \t\t\t\t<string>/System/Library/Automator/Run Shell Script.action</string>
        \t\t\t\t<key>ActionName</key>
        \t\t\t\t<string>Ejecutar script de Shell</string>
        \t\t\t\t<key>ActionParameters</key>
        \t\t\t\t<dict>
        \t\t\t\t\t<key>COMMAND_STRING</key>
        \t\t\t\t\t<string>\(command)</string>
        \t\t\t\t\t<key>CheckedForUserDefaultShell</key>
        \t\t\t\t\t<true/>
        \t\t\t\t\t<key>inputMethod</key>
        \t\t\t\t\t<integer>1</integer>
        \t\t\t\t\t<key>shell</key>
        \t\t\t\t\t<string>/bin/zsh</string>
        \t\t\t\t\t<key>source</key>
        \t\t\t\t\t<string></string>
        \t\t\t\t</dict>
        \t\t\t\t<key>BundleIdentifier</key>
        \t\t\t\t<string>com.apple.Automator.RunShellScript</string>
        \t\t\t\t<key>CFBundleVersion</key>
        \t\t\t\t<string>2.0.3</string>
        \t\t\t\t<key>CanShowSelectedItemsWhenRun</key>
        \t\t\t\t<false/>
        \t\t\t\t<key>CanShowWhenRun</key>
        \t\t\t\t<true/>
        \t\t\t\t<key>Category</key>
        \t\t\t\t<array>
        \t\t\t\t\t<string>AMCategoryUtilities</string>
        \t\t\t\t</array>
        \t\t\t\t<key>Class Name</key>
        \t\t\t\t<string>RunShellScriptAction</string>
        \t\t\t\t<key>InputUUID</key>
        \t\t\t\t<string>\(u1)</string>
        \t\t\t\t<key>Keywords</key>
        \t\t\t\t<array>
        \t\t\t\t\t<string>Shell</string>
        \t\t\t\t\t<string>Script</string>
        \t\t\t\t\t<string>Command</string>
        \t\t\t\t\t<string>Run</string>
        \t\t\t\t\t<string>Unix</string>
        \t\t\t\t</array>
        \t\t\t\t<key>OutputUUID</key>
        \t\t\t\t<string>\(u2)</string>
        \t\t\t\t<key>UUID</key>
        \t\t\t\t<string>\(u3)</string>
        \t\t\t\t<key>UnlocalizedApplications</key>
        \t\t\t\t<array>
        \t\t\t\t\t<string>Automator</string>
        \t\t\t\t</array>
        \t\t\t\t<key>arguments</key>
        \t\t\t\t<dict>
        \t\t\t\t\t<key>0</key>
        \t\t\t\t\t<dict>
        \t\t\t\t\t\t<key>default value</key>
        \t\t\t\t\t\t<integer>0</integer>
        \t\t\t\t\t\t<key>name</key>
        \t\t\t\t\t\t<string>inputMethod</string>
        \t\t\t\t\t\t<key>required</key>
        \t\t\t\t\t\t<string>0</string>
        \t\t\t\t\t\t<key>type</key>
        \t\t\t\t\t\t<string>0</string>
        \t\t\t\t\t\t<key>uuid</key>
        \t\t\t\t\t\t<string>0</string>
        \t\t\t\t\t</dict>
        \t\t\t\t\t<key>1</key>
        \t\t\t\t\t<dict>
        \t\t\t\t\t\t<key>default value</key>
        \t\t\t\t\t\t<string></string>
        \t\t\t\t\t\t<key>name</key>
        \t\t\t\t\t\t<string>source</string>
        \t\t\t\t\t\t<key>required</key>
        \t\t\t\t\t\t<string>0</string>
        \t\t\t\t\t\t<key>type</key>
        \t\t\t\t\t\t<string>0</string>
        \t\t\t\t\t\t<key>uuid</key>
        \t\t\t\t\t\t<string>1</string>
        \t\t\t\t\t</dict>
        \t\t\t\t\t<key>2</key>
        \t\t\t\t\t<dict>
        \t\t\t\t\t\t<key>default value</key>
        \t\t\t\t\t\t<false/>
        \t\t\t\t\t\t<key>name</key>
        \t\t\t\t\t\t<string>CheckedForUserDefaultShell</string>
        \t\t\t\t\t\t<key>required</key>
        \t\t\t\t\t\t<string>0</string>
        \t\t\t\t\t\t<key>type</key>
        \t\t\t\t\t\t<string>0</string>
        \t\t\t\t\t\t<key>uuid</key>
        \t\t\t\t\t\t<string>2</string>
        \t\t\t\t\t</dict>
        \t\t\t\t\t<key>3</key>
        \t\t\t\t\t<dict>
        \t\t\t\t\t\t<key>default value</key>
        \t\t\t\t\t\t<string></string>
        \t\t\t\t\t\t<key>name</key>
        \t\t\t\t\t\t<string>COMMAND_STRING</string>
        \t\t\t\t\t\t<key>required</key>
        \t\t\t\t\t\t<string>0</string>
        \t\t\t\t\t\t<key>type</key>
        \t\t\t\t\t\t<string>0</string>
        \t\t\t\t\t\t<key>uuid</key>
        \t\t\t\t\t\t<string>3</string>
        \t\t\t\t\t</dict>
        \t\t\t\t\t<key>4</key>
        \t\t\t\t\t<dict>
        \t\t\t\t\t\t<key>default value</key>
        \t\t\t\t\t\t<string>/bin/sh</string>
        \t\t\t\t\t\t<key>name</key>
        \t\t\t\t\t\t<string>shell</string>
        \t\t\t\t\t\t<key>required</key>
        \t\t\t\t\t\t<string>0</string>
        \t\t\t\t\t\t<key>type</key>
        \t\t\t\t\t\t<string>0</string>
        \t\t\t\t\t\t<key>uuid</key>
        \t\t\t\t\t\t<string>4</string>
        \t\t\t\t\t</dict>
        \t\t\t\t</dict>
        \t\t\t\t<key>isViewVisible</key>
        \t\t\t\t<integer>1</integer>
        \t\t\t\t<key>location</key>
        \t\t\t\t<string>309.000000:253.000000</string>
        \t\t\t\t<key>nibPath</key>
        \t\t\t\t<string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
        \t\t\t</dict>
        \t\t\t<key>isViewVisible</key>
        \t\t\t<integer>1</integer>
        \t\t</dict>
        \t</array>
        \t<key>connectors</key>
        \t<dict/>
        \t<key>workflowMetaData</key>
        \t<dict>
        \t\t<key>applicationBundleIDsByProvider</key>
        \t\t<dict/>
        \t\t<key>applicationPaths</key>
        \t\t<array/>
        \t\t<key>inputTypeIdentifier</key>
        \t\t<string>com.apple.Automator.fileSystemObject</string>
        \t\t<key>outputTypeIdentifier</key>
        \t\t<string>com.apple.Automator.nothing</string>
        \t\t<key>presentationMode</key>
        \t\t<integer>11</integer>
        \t\t<key>processesInput</key>
        \t\t<false/>
        \t\t<key>serviceApplicationBundleID</key>
        \t\t<string>com.apple.finder</string>
        \t\t<key>serviceApplicationPath</key>
        \t\t<string>/System/Library/CoreServices/Finder.app</string>
        \t\t<key>serviceInputTypeIdentifier</key>
        \t\t<string>com.apple.Automator.fileSystemObject</string>
        \t\t<key>serviceOutputTypeIdentifier</key>
        \t\t<string>com.apple.Automator.nothing</string>
        \t\t<key>serviceProcessesInput</key>
        \t\t<false/>
        \t\t<key>systemImageName</key>
        \t\t<string>NSActionTemplate</string>
        \t\t<key>useAutomaticInputType</key>
        \t\t<false/>
        \t\t<key>workflowTypeIdentifier</key>
        \t\t<string>com.apple.Automator.servicesMenu</string>
        \t</dict>
        </dict>
        </plist>
        """
    }
}
