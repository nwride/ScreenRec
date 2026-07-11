import AVFoundation
import ScreenCaptureKit

/// Envuelve SCStream: captura el área pedida de un display y pasa los
/// fotogramas completos al VideoWriter.
final class CaptureEngine: NSObject, SCStreamOutput, SCStreamDelegate {
    private let writer: VideoWriter
    private var stream: SCStream?

    /// El stream se detuvo solo (p. ej. se desconectó el monitor).
    var onStoppedWithError: ((Error) -> Void)?

    init(writer: VideoWriter) {
        self.writer = writer
    }

    func start(displayID: CGDirectDisplayID,
               sourceRect: CGRect,
               pixelWidth: Int,
               pixelHeight: Int,
               fps: Int,
               showsCursor: Bool) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw RecordingError.displayNotFound
        }

        // Excluir del vídeo cualquier ventana de la propia app (borde, HUD…).
        let pid = ProcessInfo.processInfo.processIdentifier
        let ownWindows = content.windows.filter { $0.owningApplication?.processID == pid }
        let filter = SCContentFilter(display: display, excludingWindows: ownWindows)

        let configuration = SCStreamConfiguration()
        configuration.sourceRect = sourceRect
        configuration.width = pixelWidth
        configuration.height = pixelHeight
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        configuration.showsCursor = showsCursor
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.colorSpaceName = CGColorSpace.sRGB
        configuration.queueDepth = 8

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: writer.queue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        guard let stream else { return }
        self.stream = nil
        try? await stream.stopCapture()
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
        guard let attachments = (attachmentsArray as? [[SCStreamFrameInfo: Any]])?.first,
              let statusRaw = attachments[SCStreamFrameInfo.status] as? Int,
              let status = SCFrameStatus(rawValue: statusRaw),
              status == .complete else { return }
        writer.append(sampleBuffer)
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onStoppedWithError?(error)
    }
}
