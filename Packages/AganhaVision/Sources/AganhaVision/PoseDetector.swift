import CoreVideo
import Foundation
import Vision

/// Envolve `VNDetectHumanBodyPoseRequest`. Espera um buffer já "em pé" (e espelhado, se for a frontal),
/// de modo que as coordenadas devolvidas batam com o que aparece na prévia.
public struct PoseDetector: Sendable {
    private static let mapping: [(JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.nose, .nose),
        (.leftShoulder, .leftShoulder), (.rightShoulder, .rightShoulder),
        (.leftElbow, .leftElbow), (.rightElbow, .rightElbow),
        (.leftWrist, .leftWrist), (.rightWrist, .rightWrist),
        (.leftHip, .leftHip), (.rightHip, .rightHip),
        (.leftKnee, .leftKnee), (.rightKnee, .rightKnee),
        (.leftAnkle, .leftAnkle), (.rightAnkle, .rightAnkle)
    ]

    public init() {}

    public func detect(in pixelBuffer: CVPixelBuffer) throws -> [Skeleton] {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try handler.perform([request])
        return (request.results ?? []).map(Self.skeleton(from:))
    }

    private static func skeleton(from observation: VNHumanBodyPoseObservation) -> Skeleton {
        var joints: [JointName: Joint] = [:]
        for (name, visionName) in mapping {
            guard let point = try? observation.recognizedPoint(visionName), point.confidence > 0 else { continue }
            // Vision tem origem no canto inferior esquerdo; invertemos y.
            joints[name] = Joint(x: point.location.x, y: 1 - point.location.y, confidence: Double(point.confidence))
        }
        return Skeleton(joints: joints)
    }
}
