import AganhaCore
import CoreGraphics
import Foundation

/// Um instante da partida: as juntas de cada jogador (só números; nenhuma imagem), nos mesmos nomes curtos que a TV usa.
public struct PoseFrame: Sendable, Equatable {
    public let time: Double
    /// Por vaga: junta → [x, y] normalizados (0...1, y para baixo).
    public let figures: [ChildSlot: [String: [Double]]]

    public init(time: Double, figures: [ChildSlot: [String: [Double]]]) {
        self.time = time
        self.figures = figures
    }
}

/// Retângulo que cobre todos os jogadores, em "unidades de altura da imagem" (x já multiplicado pela proporção da câmera).
public struct PoseFraming: Sendable, Equatable {
    public var minX: Double
    public var minY: Double
    public var width: Double
    public var height: Double

    public var aspect: Double { width / height }

    public init(minX: Double, minY: Double, width: Double, height: Double) {
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
    }
}

/// Grava as posições dos jogadores durante a partida (≈12 por segundo, no máximo 60 s) para depois montar um vídeo só de avatares.
public struct PoseTimeline: Sendable {
    public static let framesPerSecond = 12.0
    public static let maxSeconds = 60.0
    public static let jointKeys: [JointName: String] = [
        .nose: "n", .leftEye: "ley", .rightEye: "rey", .leftEar: "lea", .rightEar: "rea",
        .leftShoulder: "ls", .rightShoulder: "rs", .leftElbow: "le", .rightElbow: "re",
        .leftWrist: "lw", .rightWrist: "rw", .leftHip: "lh", .rightHip: "rh",
        .leftKnee: "lk", .rightKnee: "rk", .leftAnkle: "la", .rightAnkle: "ra"
    ]

    public private(set) var frames: [PoseFrame] = []
    /// Largura / altura da câmera.
    public private(set) var aspect = 4.0 / 3.0
    private var lastTime = -Double.infinity

    public init() {}

    public var duration: Double { (frames.last?.time ?? 0) - (frames.first?.time ?? 0) }

    public mutating func clear() {
        frames = []
        lastTime = -.infinity
    }

    public mutating func append(_ analysis: FrameAnalysis, minConfidence: Double = 0.2) {
        guard analysis.timestamp - lastTime >= 1 / Self.framesPerSecond, analysis.imageSize.height > 0 else { return }
        var figures: [ChildSlot: [String: [Double]]] = [:]
        for person in analysis.people {
            guard let slot = person.slot else { continue }
            var joints: [String: [Double]] = [:]
            for (joint, key) in Self.jointKeys {
                if let value = person.skeleton.joints[joint], value.confidence > minConfidence { joints[key] = [value.x, value.y] }
            }
            if !joints.isEmpty { figures[slot] = joints }
        }
        guard !figures.isEmpty else { return }
        lastTime = analysis.timestamp
        aspect = Double(analysis.imageSize.width / analysis.imageSize.height)
        frames.append(PoseFrame(time: analysis.timestamp, figures: figures))
        while let first = frames.first, analysis.timestamp - first.time > Self.maxSeconds { frames.removeFirst() }
    }

    /// Recorte (com margem) que cobre todos os jogadores durante toda a partida, na proporção `targetAspect` (largura/altura).
    public func framing(targetAspect: Double) -> PoseFraming? {
        var minX = Double.infinity, maxX = -Double.infinity, minY = Double.infinity, maxY = -Double.infinity
        for frame in frames {
            for joints in frame.figures.values {
                for point in joints.values where point.count == 2 {
                    minX = min(minX, point[0] * aspect)
                    maxX = max(maxX, point[0] * aspect)
                    minY = min(minY, point[1])
                    maxY = max(maxY, point[1])
                }
            }
        }
        guard minX.isFinite, maxX > minX, maxY > minY else { return nil }
        var width = (maxX - minX) * 1.3, height = (maxY - minY) * 1.25
        width = max(width, 0.25)
        height = max(height, 0.35)
        if width / height > targetAspect { height = width / targetAspect } else { width = height * targetAspect }
        let centerX = (minX + maxX) / 2, centerY = (minY + maxY) / 2 + height * 0.02
        return PoseFraming(minX: centerX - width / 2, minY: centerY - height / 2, width: width, height: height)
    }
}
