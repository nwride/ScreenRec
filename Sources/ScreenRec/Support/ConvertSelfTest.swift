import AVFoundation
import AppKit

/// Arnés de pruebas por línea de comandos para el motor de conversión (no toca
/// la interfaz ni requiere permisos). Ejercita el transcoder y el exportador de
/// GIF sobre un vídeo sintético:
///
///     ScreenRec --make-test-video /tmp/t.mp4 3
///     ScreenRec --to-gif /tmp/t.mp4 /tmp/t.gif
///     ScreenRec --to-mp4 /tmp/t.mp4 /tmp/t-hevc.mp4 hevc medium
enum ConvertSelfTest {
    static func run(_ args: [String]) -> Never {
        if args.contains("--make-test-video") {
            makeTestVideo(args)
        } else if args.contains("--to-gif") {
            toGIF(args)
        } else if args.contains("--to-mp4") {
            toMP4(args)
        } else {
            print("modo de prueba desconocido")
            exit(2)
        }
    }

    // MARK: - Generar vídeo sintético

    private static func makeTestVideo(_ args: [String]) -> Never {
        guard let idx = args.firstIndex(of: "--make-test-video"), args.count > idx + 1 else {
            print("uso: --make-test-video <salida.mp4> [segundos]")
            exit(2)
        }
        let out = URL(fileURLWithPath: args[idx + 1])
        let seconds = (args.count > idx + 2 ? Double(args[idx + 2]) : nil) ?? 3.0
        let width = 320, height = 240, fps = 20
        try? FileManager.default.removeItem(at: out)
        do {
            let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
            ])
            input.expectsMediaDataInRealTime = false
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ])
            guard writer.canAdd(input) else { print("no se pudo añadir input"); exit(1) }
            writer.add(input)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            let total = Int(seconds * Double(fps))
            for i in 0..<total {
                while !input.isReadyForMoreMediaData { usleep(1000) }
                guard let pixelBuffer = makePixelBuffer(width: width, height: height, frame: i, total: total) else { continue }
                let pts = CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps))
                adaptor.append(pixelBuffer, withPresentationTime: pts)
            }
            input.markAsFinished()
            let semaphore = DispatchSemaphore(value: 0)
            writer.finishWriting { semaphore.signal() }
            semaphore.wait()
            if writer.status == .completed {
                print("TEST VIDEO OK: \(out.path) (\(seconds)s, \(width)x\(height))")
                exit(0)
            } else {
                print("TEST VIDEO FALLO: \(writer.error?.localizedDescription ?? "?")")
                exit(1)
            }
        } catch {
            print("TEST VIDEO FALLO: \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func makePixelBuffer(width: Int, height: Int, frame: Int, total: Int) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, nil, &pb)
        guard let buffer = pb else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                  width: width, height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
        ctx.setFillColor(NSColor.systemBlue.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let t = CGFloat(frame) / CGFloat(max(total - 1, 1))
        let x = t * CGFloat(width - 60)
        ctx.setFillColor(NSColor.systemYellow.cgColor)
        ctx.fill(CGRect(x: x, y: 90, width: 60, height: 60))
        return buffer
    }

    // MARK: - Conversiones

    private static func toGIF(_ args: [String]) -> Never {
        guard let idx = args.firstIndex(of: "--to-gif"), args.count > idx + 2 else {
            print("uso: --to-gif <entrada> <salida.gif>")
            exit(2)
        }
        let input = URL(fileURLWithPath: args[idx + 1])
        let output = URL(fileURLWithPath: args[idx + 2])
        Task {
            do {
                let estimate = try await GIFSizeEstimator.estimate(for: input, fps: 10, scale: 0.5)
                try await GIFExporter.export(video: input, to: output, fps: 10, scale: 0.5) { _ in }
                let attrs = try? FileManager.default.attributesOfItem(atPath: output.path)
                let bytes = (attrs?[.size] as? Int) ?? 0
                print(String(format: "GIF OK: %@ | %d bytes reales | estimado %.1f MB, %d fotogramas",
                             output.path, bytes, estimate.estimatedMB, estimate.frames))
                exit(0)
            } catch {
                print("GIF FALLO: \(error.localizedDescription)")
                exit(1)
            }
        }
        dispatchMain()
    }

    private static func toMP4(_ args: [String]) -> Never {
        guard let idx = args.firstIndex(of: "--to-mp4"), args.count > idx + 2 else {
            print("uso: --to-mp4 <entrada> <salida.mp4> [h264|hevc] [high|medium|low]")
            exit(2)
        }
        let input = URL(fileURLWithPath: args[idx + 1])
        let output = URL(fileURLWithPath: args[idx + 2])
        let codec: VideoCodecChoice = (args.count > idx + 3 && args[idx + 3] == "hevc") ? .hevc : .h264
        let quality: QualityChoice = {
            guard args.count > idx + 4 else { return .high }
            return QualityChoice(rawValue: args[idx + 4]) ?? .high
        }()
        Task {
            do {
                try await VideoTranscoder.transcode(source: input, destination: output,
                                                    codec: codec, quality: quality, customMbps: 8) { _ in }
                let attrs = try? FileManager.default.attributesOfItem(atPath: output.path)
                let bytes = (attrs?[.size] as? Int) ?? 0
                print("MP4 OK: \(output.path) | codec \(codec.rawValue) | \(bytes) bytes")
                exit(0)
            } catch {
                print("MP4 FALLO: \(error.localizedDescription)")
                exit(1)
            }
        }
        dispatchMain()
    }
}
