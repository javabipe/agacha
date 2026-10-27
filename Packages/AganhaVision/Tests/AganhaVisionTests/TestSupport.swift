@testable import AganhaVision
import Foundation

/// Esqueleto sintético: tronco de 0.25 de comprimento; `hipDrop` desce o quadril (e o resto abaixo dele).
func makeSkeleton(centerX: Double = 0.5, hipDrop: Double = 0, confidence: Double = 0.9) -> Skeleton {
    func joint(_ x: Double, _ y: Double) -> Joint { Joint(x: x, y: y, confidence: confidence) }
    let hipY = 0.55 + hipDrop
    return Skeleton(joints: [
        .nose: joint(centerX, 0.2 + hipDrop * 0.5),
        .leftShoulder: joint(centerX - 0.05, 0.3 + hipDrop * 0.5),
        .rightShoulder: joint(centerX + 0.05, 0.3 + hipDrop * 0.5),
        .leftHip: joint(centerX - 0.04, hipY),
        .rightHip: joint(centerX + 0.04, hipY),
        .leftKnee: joint(centerX - 0.04, 0.75),
        .rightKnee: joint(centerX + 0.04, 0.75),
        .leftAnkle: joint(centerX - 0.04, 0.95),
        .rightAnkle: joint(centerX + 0.04, 0.95)
    ])
}

let frameStep = 1.0 / 30
