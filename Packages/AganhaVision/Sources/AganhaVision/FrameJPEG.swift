import CoreImage
import CoreVideo
import Foundation

/// Converte um quadro da câmera em JPEG pequeno (para a pré-visualização na TV). Usar de uma fila só.
public final class FrameJPEG: @unchecked Sendable {
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    public init() {}

    /// `maxWidth` em pixels (reduz mantendo a proporção) e `quality` de 0 a 1.
    public func encode(_ buffer: CVPixelBuffer, maxWidth: Double = 640, quality: Double = 0.5) -> Data? {
        let image = CIImage(cvPixelBuffer: buffer)
        let width = image.extent.width
        guard width > 0 else { return nil }
        let scale = min(1, maxWidth / width)
        let scaled = scale < 1 ? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : image
        return context.jpegRepresentation(
            of: scaled, colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality]
        )
    }
}
