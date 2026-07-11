import AVFoundation

enum ConversionError: LocalizedError {
    case noVideoTrack
    case readerFailed(String)
    case writerFailed(String)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "El archivo no contiene una pista de vídeo."
        case .readerFailed(let message):
            return "No se pudo leer el vídeo de origen: \(message)"
        case .writerFailed(let message):
            return "No se pudo escribir el vídeo convertido: \(message)"
        }
    }
}

/// Re-codifica un archivo de vídeo a MP4 con el codec y la calidad elegidos,
/// conservando resolución, fps y el audio (re-codificado a AAC) si existe.
enum VideoTranscoder {
    static func transcode(source: URL,
                          destination: URL,
                          codec: VideoCodecChoice,
                          quality: QualityChoice,
                          customMbps: Double,
                          progress: @escaping (Double) -> Void) async throws {
        let asset = AVAsset(url: source)
        let duration = try await asset.load(.duration)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ConversionError.noVideoTrack
        }
        let audioTrack = try await asset.loadTracks(withMediaType: .audio).first
        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let nominalFPS = try await videoTrack.load(.nominalFrameRate)
        let fps = nominalFPS > 0 ? Int(nominalFPS.rounded()) : 30

        var width = Int(abs(naturalSize.width).rounded()); width -= width % 2; width = max(width, 2)
        var height = Int(abs(naturalSize.height).rounded()); height -= height % 2; height = max(height, 2)
        let bitrate = Preferences.bitrate(codec: codec, quality: quality, customMbps: customMbps,
                                          pixelWidth: width, pixelHeight: height, fps: fps)

        try? FileManager.default.removeItem(at: destination)
        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)

        // Vídeo: decodificar a BGRA y re-comprimir con el codec elegido.
        let videoOut = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        videoOut.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOut) else { throw ConversionError.readerFailed("pista de vídeo no legible") }
        reader.add(videoOut)

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
        let videoIn = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: codecType,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: compression,
        ])
        videoIn.expectsMediaDataInRealTime = false
        videoIn.transform = transform // conserva la orientación original
        guard writer.canAdd(videoIn) else { throw ConversionError.writerFailed("configuración de vídeo no válida") }
        writer.add(videoIn)

        // Audio (opcional): decodificar a PCM y re-comprimir a AAC.
        var audioOut: AVAssetReaderTrackOutput?
        var audioIn: AVAssetWriterInput?
        if let audioTrack {
            let aOut = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
            ])
            aOut.alwaysCopiesSampleData = false
            if reader.canAdd(aOut) {
                reader.add(aOut)
                let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 2,
                    AVSampleRateKey: 44_100,
                    AVEncoderBitRateKey: 128_000,
                ])
                aIn.expectsMediaDataInRealTime = false
                if writer.canAdd(aIn) {
                    writer.add(aIn)
                    audioOut = aOut
                    audioIn = aIn
                }
            }
        }

        guard reader.startReading() else {
            throw ConversionError.readerFailed(reader.error?.localizedDescription ?? "desconocido")
        }
        guard writer.startWriting() else {
            throw ConversionError.writerFailed(writer.error?.localizedDescription ?? "desconocido")
        }
        writer.startSession(atSourceTime: .zero)

        let totalSeconds = duration.seconds

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let group = DispatchGroup()

            group.enter()
            videoIn.requestMediaDataWhenReady(on: DispatchQueue(label: "io.github.nwride.ScreenRec.transcode.video")) {
                while videoIn.isReadyForMoreMediaData {
                    if let sample = videoOut.copyNextSampleBuffer() {
                        let pts = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                        videoIn.append(sample)
                        if totalSeconds > 0 { progress(min(pts / totalSeconds, 1)) }
                    } else {
                        videoIn.markAsFinished()
                        group.leave()
                        break
                    }
                }
            }

            if let audioIn, let audioOut {
                group.enter()
                audioIn.requestMediaDataWhenReady(on: DispatchQueue(label: "io.github.nwride.ScreenRec.transcode.audio")) {
                    while audioIn.isReadyForMoreMediaData {
                        if let sample = audioOut.copyNextSampleBuffer() {
                            audioIn.append(sample)
                        } else {
                            audioIn.markAsFinished()
                            group.leave()
                            break
                        }
                    }
                }
            }

            group.notify(queue: DispatchQueue(label: "io.github.nwride.ScreenRec.transcode.finish")) {
                if reader.status == .failed {
                    writer.cancelWriting()
                    try? FileManager.default.removeItem(at: destination)
                    continuation.resume(throwing: ConversionError.readerFailed(reader.error?.localizedDescription ?? "desconocido"))
                    return
                }
                writer.finishWriting {
                    if writer.status == .completed {
                        progress(1)
                        continuation.resume(returning: ())
                    } else {
                        try? FileManager.default.removeItem(at: destination)
                        continuation.resume(throwing: ConversionError.writerFailed(writer.error?.localizedDescription ?? "estado \(writer.status.rawValue)"))
                    }
                }
            }
        }
    }
}
