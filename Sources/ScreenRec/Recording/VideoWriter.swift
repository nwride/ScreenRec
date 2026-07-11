import AVFoundation
import CoreMedia

enum RecordingError: LocalizedError {
    case displayNotFound
    case writerStartFailed(String)
    case writerFinishFailed(String)
    case noFramesCaptured

    var errorDescription: String? {
        switch self {
        case .displayNotFound:
            return "No se encontró la pantalla que se iba a grabar."
        case .writerStartFailed(let message):
            return "No se pudo crear el archivo de vídeo: \(message)"
        case .writerFinishFailed(let message):
            return "No se pudo finalizar el archivo de vídeo: \(message)"
        case .noFramesCaptured:
            return "No se capturó ningún fotograma. Comprueba el permiso de Grabación de pantalla."
        }
    }
}

/// Codifica los fotogramas que entrega ScreenCaptureKit con AVAssetWriter
/// (control total de codec y bitrate).
final class VideoWriter {
    /// Cola de trabajo: es también la sampleHandlerQueue del SCStream.
    let queue = DispatchQueue(label: "io.github.nwride.ScreenRec.writer")

    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private var sessionStarted = false
    private var lastPixelBuffer: CVPixelBuffer?
    private var lastFormatDescription: CMFormatDescription?
    private var lastPTS = CMTime.invalid
    private(set) var framesWritten = 0

    init(url: URL, width: Int, height: Int, codec: VideoCodecChoice, bitrate: Int, fps: Int) throws {
        try? FileManager.default.removeItem(at: url)
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        var compression: [String: Any] = [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoExpectedSourceFrameRateKey: fps,
            AVVideoMaxKeyFrameIntervalKey: max(fps * 2, 1),
            AVVideoAllowFrameReorderingKey: false,
        ]
        let codecType: AVVideoCodecType
        switch codec {
        case .h264:
            codecType = .h264
            compression[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
        case .hevc:
            codecType = .hevc
        }
        let settings: [String: Any] = [
            AVVideoCodecKey: codecType,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: compression,
        ]
        input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else {
            throw RecordingError.writerStartFailed("configuración de vídeo no válida")
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw RecordingError.writerStartFailed(writer.error?.localizedDescription ?? "error desconocido")
        }
    }

    /// Debe llamarse desde `queue` (el stream ya entrega ahí sus buffers).
    func append(_ sampleBuffer: CMSampleBuffer) {
        guard writer.status == .writing else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if !sessionStarted {
            writer.startSession(atSourceTime: pts)
            sessionStarted = true
        }
        guard input.isReadyForMoreMediaData else { return }
        if input.append(sampleBuffer) {
            framesWritten += 1
            lastPTS = pts
            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                lastPixelBuffer = pixelBuffer
                lastFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
            }
        }
    }

    /// Cierra el archivo. Antes reescribe el último fotograma con el instante
    /// actual: ScreenCaptureKit solo emite fotogramas cuando la pantalla cambia,
    /// así que sin esto la duración no cubriría un tramo final estático.
    func finish() async -> Result<URL, Error> {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard sessionStarted, framesWritten > 0 else {
                    writer.cancelWriting()
                    try? FileManager.default.removeItem(at: writer.outputURL)
                    continuation.resume(returning: .failure(RecordingError.noFramesCaptured))
                    return
                }
                appendTailFrame()
                input.markAsFinished()
                writer.finishWriting { [self] in
                    if writer.status == .completed {
                        continuation.resume(returning: .success(writer.outputURL))
                    } else {
                        let message = writer.error?.localizedDescription ?? "estado \(writer.status.rawValue)"
                        continuation.resume(returning: .failure(RecordingError.writerFinishFailed(message)))
                    }
                }
            }
        }
    }

    /// Descarta la grabación y borra el archivo temporal.
    func cancel() {
        queue.async { [self] in
            if writer.status == .writing { writer.cancelWriting() }
            try? FileManager.default.removeItem(at: writer.outputURL)
        }
    }

    private func appendTailFrame() {
        let now = CMClockGetTime(CMClockGetHostTimeClock())
        guard let pixelBuffer = lastPixelBuffer,
              let format = lastFormatDescription,
              lastPTS.isValid,
              now > lastPTS,
              (now - lastPTS).seconds > 0.05,
              input.isReadyForMoreMediaData else { return }
        var timing = CMSampleTimingInfo(duration: .invalid,
                                        presentationTimeStamp: now,
                                        decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        let status = CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                              imageBuffer: pixelBuffer,
                                                              formatDescription: format,
                                                              sampleTiming: &timing,
                                                              sampleBufferOut: &sample)
        if status == noErr, let sample {
            input.append(sample)
        }
    }
}
