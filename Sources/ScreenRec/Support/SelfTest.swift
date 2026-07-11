import AppKit
import AVFoundation

/// Prueba de humo sin interfaz: graba unos segundos de una zona fija de la
/// pantalla principal y comprueba el archivo resultante. Útil para verificar
/// el motor de captura desde la terminal:
///
///     ScreenRec.app/Contents/MacOS/ScreenRec --selftest 3
enum SelfTest {
    static func main(arguments: [String]) -> Never {
        var seconds = 3.0
        if let index = arguments.firstIndex(of: "--selftest"),
           arguments.count > index + 1,
           let value = Double(arguments[index + 1]) {
            seconds = value
        }

        guard CGPreflightScreenCaptureAccess() else {
            print("SELFTEST: SIN PERMISO de grabación de pantalla para este proceso")
            exit(2)
        }
        let duration = seconds
        print("SELFTEST: permiso OK, grabando \(duration)s de la pantalla principal…")

        Task {
            do {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("ScreenRec-selftest-\(UUID().uuidString).mp4")
                let writer = try VideoWriter(url: url, width: 800, height: 600,
                                             codec: .h264, bitrate: 4_000_000, fps: 30)
                let engine = CaptureEngine(writer: writer)
                try await engine.start(displayID: CGMainDisplayID(),
                                       sourceRect: CGRect(x: 100, y: 100, width: 400, height: 300),
                                       pixelWidth: 800, pixelHeight: 600,
                                       fps: 30, showsCursor: true)
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                await engine.stop()
                let result = await writer.finish()
                switch result {
                case .success(let output):
                    let asset = AVAsset(url: output)
                    let duration = try await asset.load(.duration).seconds
                    var size = CGSize.zero
                    if let track = try await asset.loadTracks(withMediaType: .video).first {
                        size = try await track.load(.naturalSize)
                    }
                    let attrs = try? FileManager.default.attributesOfItem(atPath: output.path)
                    let bytes = (attrs?[.size] as? NSNumber)?.intValue ?? 0
                    print(String(format: "SELFTEST OK: %@ | %.2f s | %.0fx%.0f px | %d bytes | %d fotogramas",
                                 output.path, duration, size.width, size.height, bytes, writer.framesWritten))
                    exit(0)
                case .failure(let error):
                    print("SELFTEST FALLO al finalizar: \(error.localizedDescription)")
                    exit(1)
                }
            } catch {
                print("SELFTEST FALLO: \(error.localizedDescription)")
                exit(1)
            }
        }
        dispatchMain()
    }
}
