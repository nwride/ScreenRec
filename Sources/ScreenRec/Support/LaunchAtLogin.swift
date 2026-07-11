import Foundation
import ServiceManagement

/// Arranque automático al iniciar sesión, vía SMAppService (macOS 13+).
/// El estado lo guarda el propio sistema, no UserDefaults.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Activa o desactiva el arranque. Devuelve el estado real resultante.
    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("ScreenRec: no se pudo cambiar el arranque al iniciar sesión: %@",
                  error.localizedDescription)
        }
        return isEnabled
    }
}
