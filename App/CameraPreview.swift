import AganhaVision
import AVFoundation
import SwiftUI

/// Prévia da câmera (aspect-fit, para os esqueletos baterem com a imagem).
struct CameraPreview: UIViewRepresentable {
    let camera: CameraSession

    final class PreviewView: UIView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.addSublayer(previewLayer)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) não é usado") }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = camera.session
        view.previewLayer.videoGravity = .resizeAspect
        camera.bind(previewLayer: view.previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        camera.updateRotationCoordinator()
    }
}
