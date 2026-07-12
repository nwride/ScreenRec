import AppKit
import SwiftUI

struct SettingsView: View {
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("General").tag(0)
                Text("Vídeo").tag(1)
                Text("Recuadro").tag(2)
                Text("GIF").tag(3)
                Text("Atajos").tag(4)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.horizontal, .top], 14)
            .padding(.bottom, 6)

            Group {
                switch tab {
                case 0: GeneralPane()
                case 1: VideoPane()
                case 2: BorderPane()
                case 3: GIFPane()
                default: ShortcutsPane()
                }
            }
        }
        .frame(width: 560, height: 500)
    }
}

// MARK: - General

private struct GeneralPane: View {
    @AppStorage(Preferences.Key.afterRecording) private var afterRecording = AfterRecording.ask.rawValue
    @AppStorage(Preferences.Key.trimBeforeSaving) private var trimBeforeSaving = false
    @AppStorage(Preferences.Key.autosaveFolder) private var autosaveFolder = Preferences.desktopPath
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var quickActionsInstalled = QuickActionsInstaller.isInstalled

    var body: some View {
        Form {
            Section {
                Picker("Al terminar de grabar:", selection: $afterRecording) {
                    Text("Preguntar dónde guardar").tag(AfterRecording.ask.rawValue)
                    Text("Guardar en una carpeta fija").tag(AfterRecording.autosave.rawValue)
                }
                if afterRecording == AfterRecording.autosave.rawValue {
                    HStack {
                        Text("Carpeta:")
                        Spacer()
                        Text((autosaveFolder as NSString).abbreviatingWithTildeInPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundColor(.secondary)
                        Button("Elegir…") { chooseFolder() }
                    }
                }
            }

            Section {
                Toggle("Recortar antes de guardar", isOn: $trimBeforeSaving)
            } footer: {
                Text("Al terminar de grabar, abre un editor para acortar el comienzo o el final antes de guardar (TrimmingCut).")
            }

            Section {
                Toggle("Abrir ScreenRec al iniciar sesión", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        launchAtLogin = LaunchAtLogin.set(newValue)
                    }
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Convertir vídeos con el clic derecho")
                        Text(quickActionsInstalled ? "Instaladas en Finder → Acciones rápidas" : "No instaladas")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(quickActionsInstalled ? "Quitar" : "Instalar") {
                        toggleQuickActions(install: !quickActionsInstalled)
                    }
                }
            } footer: {
                Text("Añade «Convertir vídeo / a GIF con ScreenRec» al clic derecho sobre archivos de vídeo en Finder.")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            quickActionsInstalled = QuickActionsInstaller.isInstalled
        }
    }

    private func toggleQuickActions(install: Bool) {
        if install {
            guard QuickActionsInstaller.install() else {
                quickActionsInstalled = QuickActionsInstaller.isInstalled
                return
            }
            quickActionsInstalled = true
            let alert = NSAlert()
            alert.messageText = "Acciones de clic derecho instaladas"
            alert.informativeText = "Aparecen al hacer clic derecho en un vídeo → Acciones rápidas. Si no salen al momento, hay que reiniciar Finder."
            alert.addButton(withTitle: "Reiniciar Finder ahora")
            alert.addButton(withTitle: "Más tarde")
            if alert.runModal() == .alertFirstButtonReturn {
                QuickActionsInstaller.relaunchFinder()
            }
        } else {
            QuickActionsInstaller.uninstall()
            quickActionsInstalled = false
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: autosaveFolder)
        panel.prompt = "Usar esta carpeta"
        if panel.runModal() == .OK, let url = panel.url {
            autosaveFolder = url.path
        }
    }
}

// MARK: - Vídeo

private struct VideoPane: View {
    @AppStorage(Preferences.Key.codec) private var codec = VideoCodecChoice.h264.rawValue
    @AppStorage(Preferences.Key.quality) private var quality = QualityChoice.high.rawValue
    @AppStorage(Preferences.Key.customMbps) private var customMbps = 8.0
    @AppStorage(Preferences.Key.fps) private var fps = 30
    @AppStorage(Preferences.Key.captureResolution) private var resolution = CaptureResolution.native.rawValue
    @AppStorage(Preferences.Key.showsCursor) private var showsCursor = true

    var body: some View {
        Form {
            Section {
                Picker("Codec:", selection: $codec) {
                    Text("H.264 (más compatible)").tag(VideoCodecChoice.h264.rawValue)
                    Text("HEVC / H.265 (ocupa menos)").tag(VideoCodecChoice.hevc.rawValue)
                }
                Picker("Calidad (bitrate):", selection: $quality) {
                    Text("Alta").tag(QualityChoice.high.rawValue)
                    Text("Media").tag(QualityChoice.medium.rawValue)
                    Text("Baja").tag(QualityChoice.low.rawValue)
                    Text("Personalizada").tag(QualityChoice.custom.rawValue)
                }
                if quality == QualityChoice.custom.rawValue {
                    HStack {
                        Text("Bitrate:")
                        Slider(value: $customMbps, in: 1...50, step: 1)
                        Text("\(Int(customMbps)) Mb/s")
                            .frame(width: 60, alignment: .trailing)
                            .foregroundColor(.secondary)
                    }
                }
                Picker("Fotogramas por segundo:", selection: $fps) {
                    Text("15").tag(15)
                    Text("24").tag(24)
                    Text("30").tag(30)
                    Text("60").tag(60)
                }
                Picker("Resolución:", selection: $resolution) {
                    Text("Nativa (Retina, 2x)").tag(CaptureResolution.native.rawValue)
                    Text("Reducida (1x, ocupa menos)").tag(CaptureResolution.reduced.rawValue)
                }
                Toggle("Grabar el puntero del ratón", isOn: $showsCursor)
            } footer: {
                Text("Los cambios se aplican a partir de la siguiente grabación.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Recuadro

private struct BorderPane: View {
    @State private var color: Color

    init() {
        _color = State(initialValue: Color(nsColor: Preferences.shared.borderColor))
    }

    var body: some View {
        Form {
            Section {
                ColorPicker("Color del recuadro durante la grabación:", selection: $color, supportsOpacity: true)
                    .onChange(of: color) { newValue in
                        Preferences.shared.borderColor = NSColor(newValue)
                    }
            } footer: {
                Text("Este borde se muestra alrededor del área mientras grabas; no aparece en el vídeo.")
            }

            Section("Vista previa") {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .underPageBackgroundColor))
                    Rectangle()
                        .strokeBorder(color, lineWidth: 3)
                        .frame(width: 220, height: 120)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 170)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - GIF

private struct GIFPane: View {
    @AppStorage(Preferences.Key.gifFPS) private var gifFPS = 10
    @AppStorage(Preferences.Key.gifScale) private var gifScale = 0.5
    @AppStorage(Preferences.Key.gifMaxMB) private var gifMaxMB = 100
    @AppStorage(Preferences.Key.gifSaveNextToSource) private var gifSaveNextToSource = true

    var body: some View {
        Form {
            Section {
                Toggle("Guardar el GIF junto al vídeo original", isOn: $gifSaveNextToSource)
            } footer: {
                Text("Al convertir a GIF desde el clic derecho, guarda el GIF en la misma carpeta que el vídeo, sin preguntar. Desmárcalo para elegir la ubicación cada vez.")
            }

            Section {
                Picker("Fotogramas por segundo:", selection: $gifFPS) {
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("15").tag(15)
                }
                Picker("Escala:", selection: $gifScale) {
                    Text("100 %").tag(1.0)
                    Text("75 %").tag(0.75)
                    Text("50 %").tag(0.5)
                }
                HStack {
                    Text("Avisar si el GIF supera:")
                    Spacer()
                    TextField("", value: $gifMaxMB, format: .number)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                    Text("MB")
                }
            } header: {
                Text("Ajustes de «Convertir a GIF con ScreenRec» (clic derecho → Acciones rápidas).")
            } footer: {
                Text("Si la conversión estimada supera ese tamaño, ScreenRec avisa antes de empezar (y cancela por defecto) para no bloquear el sistema con vídeos largos. Para PowerPoint, insertar el MP4 directamente suele pesar mucho menos que un GIF.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Atajos

private struct ShortcutsPane: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Iniciar selección / grabación:")
                    Spacer()
                    HotkeyRecorder(kind: .start)
                        .frame(width: 160, height: 26)
                }
                HStack {
                    Text("Detener grabación:")
                    Spacer()
                    HotkeyRecorder(kind: .stop)
                        .frame(width: 160, height: 26)
                }
                HStack {
                    Spacer()
                    Button("Restaurar atajos por defecto") {
                        Preferences.shared.startShortcut = .defaultStart
                        Preferences.shared.stopShortcut = .defaultStop
                    }
                }
            } footer: {
                Text("Haz clic en un campo y pulsa la combinación (debe incluir ⌃, ⌥ o ⌘). ESC cancela. Los atajos funcionan con cualquier app en primer plano.")
            }
        }
        .formStyle(.grouped)
    }
}
