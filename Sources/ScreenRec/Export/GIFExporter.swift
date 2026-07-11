import AVFoundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

enum GIFExportError: LocalizedError {
    case noVideoTrack
    case cannotCreateFile
    case finalizeFailed

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "El vídeo no tiene pista de imagen."
        case .cannotCreateFile: return "No se pudo crear el archivo GIF."
        case .finalizeFailed: return "No se pudo escribir el GIF completo."
        }
    }
}

/// Convierte un vídeo en un GIF animado re-muestreando a un fps fijo (rellenando
/// con el fotograma anterior los tramos sin cambios) y escalando. Trabaja en
/// streaming (un fotograma cada vez), así que la memoria queda acotada aunque el
/// vídeo sea largo.
enum GIFExporter {
    static func export(video url: URL,
                       to destination: URL,
                       fps: Int,
                       scale: CGFloat,
                       progress: @escaping (Double) -> Void) async throws {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw GIFExportError.noVideoTrack
        }
        try await Task.detached(priority: .userInitiated) {
            try encode(asset: asset,
                       track: track,
                       duration: duration,
                       destination: destination,
                       fps: fps,
                       scale: scale,
                       progress: progress)
        }.value
    }

    private static func encode(asset: AVAsset,
                               track: AVAssetTrack,
                               duration: Double,
                               destination: URL,
                               fps: Int,
                               scale: CGFloat,
                               progress: (Double) -> Void) throws {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw GIFExportError.noVideoTrack }
        reader.add(output)

        let frameInterval = 1.0 / Double(fps)
        let totalFrames = max(Int((duration * Double(fps)).rounded(.up)), 1)

        try? FileManager.default.removeItem(at: destination)
        guard let gif = CGImageDestinationCreateWithURL(destination as CFURL,
                                                        UTType.gif.identifier as CFString,
                                                        totalFrames,
                                                        nil) else {
            throw GIFExportError.cannotCreateFile
        }
        let fileProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0], // bucle infinito
        ]
        CGImageDestinationSetProperties(gif, fileProperties as CFDictionary)
        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameInterval,
                kCGImagePropertyGIFUnclampedDelayTime: frameInterval,
            ],
        ]

        let ciContext = CIContext()
        reader.startReading()

        var lastImage: CGImage?
        var written = 0

        func writeFrame(_ image: CGImage) {
            CGImageDestinationAddImage(gif, image, frameProperties as CFDictionary)
            written += 1
            progress(Double(written) / Double(totalFrames))
        }

        while written < totalFrames, let sample = output.copyNextSampleBuffer() {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }
            let pts = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            guard let image = makeCGImage(from: pixelBuffer, scale: scale, context: ciContext) else { continue }
            if lastImage == nil { lastImage = image }
            // Rellena la rejilla temporal hasta este fotograma con el anterior.
            while written < totalFrames, Double(written) * frameInterval < pts {
                writeFrame(lastImage ?? image)
            }
            lastImage = image
        }
        // Cola: repite el último fotograma hasta cubrir toda la duración.
        while written < totalFrames, let image = lastImage {
            writeFrame(image)
        }
        reader.cancelReading()

        guard written == totalFrames, CGImageDestinationFinalize(gif) else {
            try? FileManager.default.removeItem(at: destination)
            throw GIFExportError.finalizeFailed
        }
    }

    private static func makeCGImage(from pixelBuffer: CVPixelBuffer,
                                    scale: CGFloat,
                                    context: CIContext) -> CGImage? {
        var image = CIImage(cvPixelBuffer: pixelBuffer)
        if scale != 1 {
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        return context.createCGImage(image, from: image.extent)
    }
}
