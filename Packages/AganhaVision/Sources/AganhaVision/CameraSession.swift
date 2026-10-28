#if os(iOS)
import AVFoundation
import Foundation
import os

public enum CameraError: Error, Sendable {
    case denied
    case noCamera
    case cannotConfigure
}

/// O que a câmera realmente ficou usando (para o HUD do spike).
public struct CameraInfo: Sendable {
    public var deviceName: String
    public var width: Int
    public var height: Int
    public var centerStageSupported: Bool
    public var centerStageEnabled: Bool
}

/// Câmera frontal, 1280×720 @ 30 fps, Center Stage quando disponível.
/// Os quadros chegam já "em pé" e espelhados (como um espelho), iguais à prévia.
public final class CameraSession: NSObject, @unchecked Sendable {
    public let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "br.com.agacha.camera", qos: .userInitiated)
    private let output = AVCaptureVideoDataOutput()
    private let logger = Logger(subsystem: "br.com.agacha.vision", category: "camera")
    private let lock = NSLock()

    private var _onFrame: (@Sendable (CVPixelBuffer, TimeInterval) -> Void)?
    private var _device: AVCaptureDevice?
    private var configured = false
    private var centerStagePreferred = true

    @MainActor private var previewLayer: AVCaptureVideoPreviewLayer?
    @MainActor private var coordinator: AVCaptureDevice.RotationCoordinator?
    @MainActor private var observations: [NSKeyValueObservation] = []

    public override init() {
        super.init()
    }

    /// Chamado na fila da câmera, a cada quadro. Defina antes de `start()`.
    public var onFrame: (@Sendable (CVPixelBuffer, TimeInterval) -> Void)? {
        get { lock.withLock { _onFrame } }
        set { lock.withLock { _onFrame = newValue } }
    }

    private var device: AVCaptureDevice? {
        get { lock.withLock { _device } }
        set { lock.withLock { _device = newValue } }
    }

    public func start() async throws -> CameraInfo {
        guard await AVCaptureDevice.requestAccess(for: .video) else { throw CameraError.denied }
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let info = try self.configureIfNeeded()
                    if !self.session.isRunning { self.session.startRunning() }
                    continuation.resume(returning: info)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Liga/desliga o Center Stage (o enquadramento que segue a pessoa desloca as referências de postura).
    public func setCenterStage(enabled: Bool) -> CameraInfo? {
        lock.withLock { centerStagePreferred = enabled }
        guard let device, device.activeFormat.isCenterStageSupported else { return nil }
        AVCaptureDevice.centerStageControlMode = .app
        AVCaptureDevice.isCenterStageEnabled = enabled
        return info(for: device)
    }

    public func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    /// Liga a prévia à rotação automática (horizonte). Chamar depois que a prévia existe
    /// e de novo depois de `start()`.
    @MainActor
    public func bind(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        updateRotationCoordinator()
    }

    @MainActor
    public func updateRotationCoordinator() {
        guard let device, let previewLayer else { return }
        if coordinator?.device === device, coordinator?.previewLayer === previewLayer { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        self.coordinator = coordinator
        observations = [
            coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial]) { [weak self] _, _ in
                Task { @MainActor in self?.applyRotation() }
            },
            coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial]) { [weak self] _, _ in
                Task { @MainActor in self?.applyRotation() }
            }
        ]
    }

    // MARK: - Privado

    @MainActor
    private func applyRotation() {
        guard let coordinator else { return }
        let previewAngle = coordinator.videoRotationAngleForHorizonLevelPreview
        let captureAngle = coordinator.videoRotationAngleForHorizonLevelCapture
        if let connection = previewLayer?.connection, connection.isVideoRotationAngleSupported(previewAngle) {
            connection.videoRotationAngle = previewAngle
        }
        queue.async {
            if let connection = self.output.connection(with: .video),
               connection.isVideoRotationAngleSupported(captureAngle) {
                connection.videoRotationAngle = captureAngle
            }
        }
    }

    private func configureIfNeeded() throws -> CameraInfo {
        if configured, let device { return info(for: device) }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera],
            mediaType: .video, position: .front
        )
        guard let device = discovery.devices.first else { throw CameraError.noCamera }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.cannotConfigure }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { throw CameraError.cannotConfigure }
        session.addOutput(output)

        try configureFormat(of: device)

        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }

        self.device = device
        configured = true
        return info(for: device)
    }

    private func configureFormat(of device: AVCaptureDevice) throws {
        let candidates = device.formats.filter { format in
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return dims.width == 1280 && dims.height == 720
                && format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 30 }
        }
        let chosen = candidates.first(where: \.isCenterStageSupported) ?? candidates.first
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if let chosen { device.activeFormat = chosen }
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)

        if device.activeFormat.isCenterStageSupported {
            AVCaptureDevice.centerStageControlMode = .app
            AVCaptureDevice.isCenterStageEnabled = centerStagePreferred
        }
    }

    private func info(for device: AVCaptureDevice) -> CameraInfo {
        let dims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        return CameraInfo(
            deviceName: device.localizedName,
            width: Int(dims.width), height: Int(dims.height),
            centerStageSupported: device.activeFormat.isCenterStageSupported,
            centerStageEnabled: AVCaptureDevice.isCenterStageEnabled
        )
    }
}

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let handler = onFrame else { return }
        handler(pixelBuffer, CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds)
    }
}
#endif
