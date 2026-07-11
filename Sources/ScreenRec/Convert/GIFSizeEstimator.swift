import AVFoundation

/// Estimación previa del GIF resultante, para avisar antes de lanzar una
/// conversión que pueda tardar mucho o llenar el disco (p. ej. un vídeo de 1 h).
struct GIFEstimate {
    var durationSeconds: Double
    var frames: Int
    var pixelWidth: Int
    var pixelHeight: Int
    var estimatedMB: Double
}

enum GIFSizeEstimator {
    /// Bytes por píxel y fotograma tras la compresión LZW del GIF. Es un valor
    /// deliberadamente prudente: preferimos sobreestimar y avisar de más que dejar
    /// pasar una conversión gigantesca. El contenido real varía mucho.
    private static let bytesPerPixelPerFrame = 0.4

    static func estimate(for url: URL, fps: Int, scale: CGFloat) async throws -> GIFEstimate {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw GIFExportError.noVideoTrack
        }
        let naturalSize = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let displaySize = naturalSize.applying(transform)
        let srcW = abs(displaySize.width)
        let srcH = abs(displaySize.height)

        let width = max(Int((srcW * scale).rounded()), 1)
        let height = max(Int((srcH * scale).rounded()), 1)
        let frames = max(Int((duration * Double(fps)).rounded(.up)), 1)

        let bytes = Double(frames) * Double(width) * Double(height) * bytesPerPixelPerFrame
        let mb = bytes / (1024 * 1024)

        return GIFEstimate(durationSeconds: duration,
                           frames: frames,
                           pixelWidth: width,
                           pixelHeight: height,
                           estimatedMB: mb)
    }
}
