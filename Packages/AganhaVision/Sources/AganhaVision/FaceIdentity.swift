import CoreGraphics
import CoreVideo
import Foundation
import Vision

/// "Impressão" de um rosto: o vetor de características do Vision. Fica só no aparelho.
/// Não é uma imagem e não dá para reconstruir o rosto a partir dela.
public struct FacePrint: Codable, Sendable, Equatable {
    public let data: Data
    public let revision: Int

    init?(observation: VNFeaturePrintObservation, revision: Int) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true) else {
            return nil
        }
        self.data = data
        self.revision = revision
    }

    private var observation: VNFeaturePrintObservation? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data)
    }

    /// Distância entre dois rostos (menor = mais parecidos). nil se não forem comparáveis.
    public func distance(to other: FacePrint) -> Double? {
        guard revision == other.revision, let first = observation, let second = other.observation else { return nil }
        var value: Float = 0
        guard (try? first.computeDistance(&value, to: second)) != nil else { return nil }
        return Double(value)
    }
}

/// Um rosto visto num quadro da câmera.
public struct FaceScan: Sendable {
    /// Coordenadas normalizadas, origem no canto superior esquerdo.
    public let boundingBox: CGRect
    /// 0...1 (nitidez, iluminação, pose) segundo o Vision.
    public let quality: Double
    /// Rotação lateral da cabeça em radianos (0 = de frente).
    public let yaw: Double
    public let print: FacePrint?
    /// Cor da roupa logo abaixo do rosto.
    public let clothing: AppearanceSignature?

    /// Rosto de frente, grande e nítido o bastante para guardar/comparar.
    public var isGood: Bool {
        boundingBox.width >= FaceScanner.minWidth && quality >= FaceScanner.minQuality && abs(yaw) <= FaceScanner.maxYaw
    }
}

/// Detecta o rosto maior do quadro e gera a impressão. Usar sempre da mesma fila (a da câmera).
public final class FaceScanner: @unchecked Sendable {
    public static let minWidth = 0.14
    public static let minQuality = 0.3
    public static let maxYaw = 0.45
    /// No máximo uma impressão a cada tantos segundos (é a parte cara).
    public static let printInterval = 0.25

    private var lastPrint = Date.distantPast

    public init() {}

    public func scan(_ buffer: CVPixelBuffer) -> FaceScan? {
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
        let quality = VNDetectFaceCaptureQualityRequest()
        guard (try? handler.perform([quality])) != nil,
              let face = quality.results?.max(by: { area($0.boundingBox) < area($1.boundingBox) })
        else { return nil }

        let box = face.boundingBox   // origem no canto inferior esquerdo
        let topLeft = CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
        let imageSize = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
        let scan = FaceScan(boundingBox: topLeft, quality: Double(face.faceCaptureQuality ?? 0),
                            yaw: face.yaw?.doubleValue ?? 0, print: nil,
                            clothing: AppearanceSignature.extract(from: buffer,
                                                                  rect: AppearanceSignature.rectBelowFace(topLeft, imageSize: imageSize)))
        guard scan.isGood, Date().timeIntervalSince(lastPrint) >= Self.printInterval else { return scan }

        let request = VNGenerateImageFeaturePrintRequest()
        request.imageCropAndScaleOption = .scaleFill
        request.regionOfInterest = padded(box)
        guard (try? handler.perform([request])) != nil, let observation = request.results?.first else { return scan }
        lastPrint = Date()
        return FaceScan(boundingBox: scan.boundingBox, quality: scan.quality, yaw: scan.yaw,
                        print: FacePrint(observation: observation, revision: request.revision), clothing: scan.clothing)
    }

    private func area(_ rect: CGRect) -> CGFloat { rect.width * rect.height }

    /// Um pouco de margem em volta do rosto (testa, queixo, orelhas), dentro do quadro.
    private func padded(_ box: CGRect) -> CGRect {
        let grown = box.insetBy(dx: -box.width * 0.2, dy: -box.height * 0.2)
        return grown.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}

/// Um jogador conhecido, como a regra de decisão enxerga: distâncias do rosto visto até cada
/// impressão guardada, e o quanto as impressões dele variam entre si.
public struct FaceCandidate: Sendable, Equatable {
    public let id: String
    public let distances: [Double]
    /// Maior distância entre as próprias impressões guardadas (0 se só houver uma).
    public let spread: Double

    public init(id: String, distances: [Double], spread: Double) {
        self.id = id
        self.distances = distances
        self.spread = spread
    }
}

public enum FaceDecision: Sendable, Equatable {
    case match(id: String, ratio: Double)
    case unknown(bestRatio: Double?)
    /// Dois jogadores conhecidos parecidos demais com o rosto visto: não arrisca.
    case ambiguous
}

/// Decide se um rosto visto é de alguém já conhecido. A distância do Vision não tem escala fixa,
/// então o limite de cada jogador é relativo à variação das impressões dele.
public struct FaceMatchPolicy: Sendable, Equatable {
    /// Limite = max(`floor`, `spreadFactor` × variação do jogador).
    public var spreadFactor = 1.6
    public var floor = 0.9
    /// Diferença mínima entre o melhor e o segundo melhor (em "razões").
    public var margin = 0.15

    public static let standard = FaceMatchPolicy()

    public init() {}

    public func threshold(spread: Double) -> Double { max(floor, spreadFactor * spread) }

    public func decide(_ candidates: [FaceCandidate]) -> FaceDecision {
        let ratios = candidates.compactMap { candidate -> (id: String, ratio: Double)? in
            guard let best = candidate.distances.min() else { return nil }
            return (candidate.id, best / threshold(spread: candidate.spread))
        }.sorted { $0.ratio < $1.ratio }
        guard let best = ratios.first else { return .unknown(bestRatio: nil) }
        guard best.ratio <= 1 else { return .unknown(bestRatio: best.ratio) }
        if ratios.count > 1, ratios[1].ratio - best.ratio < margin, ratios[1].ratio <= 1 { return .ambiguous }
        return .match(id: best.id, ratio: best.ratio)
    }

    /// Variação entre as impressões de um jogador (maior distância entre pares).
    public static func spread(of prints: [FacePrint]) -> Double {
        var widest = 0.0
        for (index, first) in prints.enumerated() {
            for second in prints.dropFirst(index + 1) {
                if let distance = first.distance(to: second) { widest = max(widest, distance) }
            }
        }
        return widest
    }
}
