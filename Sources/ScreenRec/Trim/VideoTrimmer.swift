import AVFoundation

enum TrimError: LocalizedError {
    case cannotCreateSession
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .cannotCreateSession:
            return "No se pudo preparar el recorte del vídeo."
        case .exportFailed(let message):
            return "No se pudo exportar el vídeo recortado: \(message)"
        }
    }
}

/// Exporta el rango seleccionado de un vídeo a un archivo nuevo (recorte
/// fotograma-a-fotograma con AVAssetExportSession).
enum VideoTrimmer {
    static func export(source: URL,
                       range: CMTimeRange,
                       to destination: URL,
                       progress: @escaping (Double) -> Void) async throws {
        let asset = AVAsset(url: source)
        // Prioriza máxima calidad (recorte fotograma-a-fotograma); si no es
        // compatible, cae a passthrough. Crear con un preset incompatible da nil.
        let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
            ?? AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
        guard let export else {
            throw TrimError.cannotCreateSession
        }
        try? FileManager.default.removeItem(at: destination)
        export.outputURL = destination
        export.outputFileType = .mp4
        export.timeRange = range

        // Progreso: sondea export.progress mientras dura la exportación.
        let progressTask = Task { @MainActor in
            while !Task.isCancelled {
                progress(Double(export.progress))
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        defer { progressTask.cancel() }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            export.exportAsynchronously {
                switch export.status {
                case .completed:
                    continuation.resume(returning: ())
                case .cancelled:
                    continuation.resume(throwing: TrimError.exportFailed("cancelado"))
                default:
                    continuation.resume(throwing: TrimError.exportFailed(export.error?.localizedDescription ?? "estado \(export.status.rawValue)"))
                }
            }
        }
        progress(1)
    }
}
