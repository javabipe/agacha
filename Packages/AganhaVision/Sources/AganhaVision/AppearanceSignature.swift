import AganhaCore
import CoreGraphics
import CoreVideo
import Foundation

/// Assinatura de cor da roupa (histograma de matiz + tons de cinza), usada para reconhecer
/// quem é quem à distância, no mesmo dia. Não identifica o rosto e não guarda imagem.
public struct AppearanceSignature: Codable, Sendable, Equatable {
    public static let hueBins = 12
    public static let grayBins = 4
    public static let binCount = hueBins + grayBins

    /// Soma 1.
    public let bins: [Float]

    public init(bins: [Float]) {
        self.bins = bins
    }

    /// 0 = idênticas, 1 = sem nada em comum (1 − interseção dos histogramas).
    public func distance(to other: AppearanceSignature) -> Double {
        guard bins.count == other.bins.count else { return 1 }
        var overlap: Float = 0
        for index in bins.indices { overlap += min(bins[index], other.bins[index]) }
        return Double(max(0, 1 - overlap))
    }

    public static func average(_ list: [AppearanceSignature]) -> AppearanceSignature? {
        guard let first = list.first else { return nil }
        var sum = [Float](repeating: 0, count: first.bins.count)
        for signature in list where signature.bins.count == sum.count {
            for index in sum.indices { sum[index] += signature.bins[index] }
        }
        let total = sum.reduce(0, +)
        guard total > 0 else { return nil }
        return AppearanceSignature(bins: sum.map { $0 / total })
    }

    // MARK: - Regiões

    /// Peito da pessoa em pé: entre ombros e quadris, parte central. Coordenadas em pixels.
    public static func torsoRect(of skeleton: Skeleton, imageSize: CGSize, minConfidence: Double = 0.3) -> CGRect? {
        guard let shoulders = skeleton.midpoint(of: [.leftShoulder, .rightShoulder], minConfidence: minConfidence),
              let left = skeleton.joints[.leftShoulder], let right = skeleton.joints[.rightShoulder],
              left.confidence >= minConfidence, right.confidence >= minConfidence
        else { return nil }
        let width = abs(left.x - right.x)
        let hips = skeleton.midpoint(of: [.leftHip, .rightHip], minConfidence: minConfidence)
        let bottom = hips?.y ?? (shoulders.y + width * 1.4)
        let top = shoulders.y + (bottom - shoulders.y) * 0.15
        let low = bottom - (bottom - shoulders.y) * 0.15
        guard low > top, width > 0.01 else { return nil }
        let rect = CGRect(x: shoulders.x - width * 0.3, y: top, width: width * 0.6, height: low - top)
        return CGRect(x: rect.minX * imageSize.width, y: rect.minY * imageSize.height,
                      width: rect.width * imageSize.width, height: rect.height * imageSize.height)
    }

    /// Roupa logo abaixo de um rosto (rosto em coordenadas normalizadas, origem no canto superior esquerdo).
    public static func rectBelowFace(_ face: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(x: (face.minX - 0.15 * face.width) * imageSize.width,
               y: (face.maxY + 0.35 * face.height) * imageSize.height,
               width: face.width * 1.3 * imageSize.width,
               height: face.height * 0.9 * imageSize.height)
    }

    // MARK: - Extração

    /// Calcula a assinatura de `rect` (pixels, origem no canto superior esquerdo).
    /// Aceita os formatos da câmera (YpCbCr 4:2:0 bi-planar) e BGRA.
    public static func extract(from buffer: CVPixelBuffer, rect: CGRect, grid: Int = 20) -> AppearanceSignature? {
        let size = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
        let region = rect.intersection(size).integral
        guard region.width >= 6, region.height >= 6 else { return nil }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let reader = PixelReader(buffer) else { return nil }

        var bins = [Float](repeating: 0, count: binCount)
        for gy in 0..<grid {
            for gx in 0..<grid {
                let x = Int(region.minX + (CGFloat(gx) + 0.5) / CGFloat(grid) * region.width)
                let y = Int(region.minY + (CGFloat(gy) + 0.5) / CGFloat(grid) * region.height)
                let (red, green, blue) = reader.rgb(x: x, y: y)
                add(red: red, green: green, blue: blue, to: &bins)
            }
        }
        let total = bins.reduce(0, +)
        guard total > 0 else { return nil }
        return AppearanceSignature(bins: bins.map { $0 / total })
    }

    private static func add(red: Float, green: Float, blue: Float, to bins: inout [Float]) {
        let maxValue = max(red, green, blue), minValue = min(red, green, blue)
        let delta = maxValue - minValue
        let saturation = maxValue == 0 ? 0 : delta / maxValue
        if saturation < 0.2 || maxValue < 0.18 {
            // Preto, cinza escuro, cinza claro, branco (pelo brilho).
            let gray = min(grayBins - 1, Int(maxValue * Float(grayBins)))
            bins[hueBins + gray] += 1
            return
        }
        var hue: Float
        if maxValue == red {
            hue = (green - blue) / delta
        } else if maxValue == green {
            hue = 2 + (blue - red) / delta
        } else {
            hue = 4 + (red - green) / delta
        }
        hue = (hue * 60).truncatingRemainder(dividingBy: 360)
        if hue < 0 { hue += 360 }
        // Reparte entre os dois grupos de matiz mais próximos para suavizar a fronteira.
        let position = hue / (360 / Float(hueBins)) - 0.5
        let lower = Int(floor(position))
        let share = position - Float(lower)
        bins[(lower + hueBins) % hueBins] += 1 - share
        bins[(lower + 1 + hueBins) % hueBins] += share
    }
}

/// Lê um pixel como RGB (0...1) de um CVPixelBuffer já bloqueado.
private struct PixelReader {
    enum Layout {
        case biPlanar(fullRange: Bool, luma: UnsafeMutableRawPointer, lumaStride: Int,
                      chroma: UnsafeMutableRawPointer, chromaStride: Int)
        case bgra(base: UnsafeMutableRawPointer, stride: Int)
    }

    let layout: Layout

    init?(_ buffer: CVPixelBuffer) {
        switch CVPixelBufferGetPixelFormatType(buffer) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            guard let luma = CVPixelBufferGetBaseAddressOfPlane(buffer, 0),
                  let chroma = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) else { return nil }
            layout = .biPlanar(fullRange: CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                               luma: luma, lumaStride: CVPixelBufferGetBytesPerRowOfPlane(buffer, 0),
                               chroma: chroma, chromaStride: CVPixelBufferGetBytesPerRowOfPlane(buffer, 1))
        case kCVPixelFormatType_32BGRA:
            guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
            layout = .bgra(base: base, stride: CVPixelBufferGetBytesPerRow(buffer))
        default:
            return nil
        }
    }

    func rgb(x: Int, y: Int) -> (Float, Float, Float) {
        switch layout {
        case let .biPlanar(fullRange, luma, lumaStride, chroma, chromaStride):
            let yValue = Float(luma.load(fromByteOffset: y * lumaStride + x, as: UInt8.self))
            let chromaOffset = (y / 2) * chromaStride + (x / 2) * 2
            let cb = Float(chroma.load(fromByteOffset: chromaOffset, as: UInt8.self)) - 128
            let cr = Float(chroma.load(fromByteOffset: chromaOffset + 1, as: UInt8.self)) - 128
            let luminance = fullRange ? yValue : (yValue - 16) * 255 / 219
            let scale: Float = fullRange ? 1 : 255 / 224
            let red = luminance + 1.402 * cr * scale
            let green = luminance - 0.344136 * cb * scale - 0.714136 * cr * scale
            let blue = luminance + 1.772 * cb * scale
            return (clamp(red / 255), clamp(green / 255), clamp(blue / 255))
        case let .bgra(base, stride):
            let offset = y * stride + x * 4
            let blue = Float(base.load(fromByteOffset: offset, as: UInt8.self))
            let green = Float(base.load(fromByteOffset: offset + 1, as: UInt8.self))
            let red = Float(base.load(fromByteOffset: offset + 2, as: UInt8.self))
            return (red / 255, green / 255, blue / 255)
        }
    }

    private func clamp(_ value: Float) -> Float { min(1, max(0, value)) }
}

/// Liga pessoas vistas de longe (por vaga) aos jogadores apresentados hoje, pela cor da roupa.
public enum AppearanceMatcher {
    /// Distância máxima aceita entre a roupa vista e a roupa da apresentação.
    public static let maxDistance = 0.4
    /// A melhor opção precisa ser melhor que a segunda por pelo menos isto; senão, é ambíguo.
    public static let minMargin = 0.08

    /// Devolve, para cada vaga, o id do jogador correspondente. Vagas ambíguas ficam de fora.
    public static func assign(slots: [ChildSlot: AppearanceSignature],
                              players: [String: AppearanceSignature]) -> [ChildSlot: String] {
        var pairs: [(distance: Double, slot: ChildSlot, player: String)] = []
        for (slot, seen) in slots {
            for (player, known) in players { pairs.append((seen.distance(to: known), slot, player)) }
        }
        pairs.sort { $0.distance < $1.distance }

        var result: [ChildSlot: String] = [:]
        var usedPlayers = Set<String>()
        for pair in pairs where pair.distance <= maxDistance {
            guard result[pair.slot] == nil, !usedPlayers.contains(pair.player) else { continue }
            // Margem: outro jogador livre quase tão parecido torna a escolha duvidosa.
            let rival = pairs.first {
                $0.slot == pair.slot && $0.player != pair.player && !usedPlayers.contains($0.player)
            }
            if let rival, rival.distance - pair.distance < minMargin { continue }
            result[pair.slot] = pair.player
            usedPlayers.insert(pair.player)
        }
        return result
    }
}
