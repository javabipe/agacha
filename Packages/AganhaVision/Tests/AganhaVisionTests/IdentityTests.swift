import AganhaCore
@testable import AganhaVision
import CoreGraphics
import CoreVideo
import Foundation
import Testing

@Suite struct IdentityTests {
    /// Imagem BGRA 100×100 com um retângulo de cor sólida (r, g, b em 0...255) e fundo cinza.
    private func image(shirt: (UInt8, UInt8, UInt8), shirtRect: CGRect = CGRect(x: 20, y: 20, width: 60, height: 60)) -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 100, 100, kCVPixelFormatType_32BGRA, nil, &buffer)
        let pixels = buffer!
        CVPixelBufferLockBaseAddress(pixels, [])
        defer { CVPixelBufferUnlockBaseAddress(pixels, []) }
        let base = CVPixelBufferGetBaseAddress(pixels)!
        let stride = CVPixelBufferGetBytesPerRow(pixels)
        for y in 0..<100 {
            for x in 0..<100 {
                let inside = shirtRect.contains(CGPoint(x: x, y: y))
                let (r, g, b) = inside ? shirt : (128, 128, 128)
                let pointer = base.advanced(by: y * stride + x * 4).assumingMemoryBound(to: UInt8.self)
                pointer[0] = b; pointer[1] = g; pointer[2] = r; pointer[3] = 255
            }
        }
        return pixels
    }

    private func signature(_ shirt: (UInt8, UInt8, UInt8)) -> AppearanceSignature {
        AppearanceSignature.extract(from: image(shirt: shirt), rect: CGRect(x: 25, y: 25, width: 50, height: 50))!
    }

    @Test func sameColourIsCloseAndDifferentColoursAreFar() {
        let red1 = signature((220, 30, 30)), red2 = signature((200, 50, 40))
        let blue = signature((30, 60, 220))
        #expect(red1.distance(to: red2) < 0.2)
        #expect(red1.distance(to: blue) > 0.8)
        #expect(abs(red1.bins.reduce(0, +) - 1) < 1e-4)
    }

    @Test func greysAndWhiteAreSeparatedFromColours() {
        let white = signature((245, 245, 245)), black = signature((15, 15, 15)), red = signature((220, 30, 30))
        #expect(white.distance(to: black) > 0.8)
        #expect(white.distance(to: red) > 0.8)
    }

    @Test func extractionIgnoresPixelsOutsideTheRectAndTinyRects() {
        let buffer = image(shirt: (220, 30, 30))
        let outside = AppearanceSignature.extract(from: buffer, rect: CGRect(x: 0, y: 0, width: 10, height: 10))
        let grey = signature((128, 128, 128))
        #expect(outside!.distance(to: grey) < 0.1)
        #expect(AppearanceSignature.extract(from: buffer, rect: CGRect(x: 0, y: 0, width: 3, height: 3)) == nil)
        #expect(AppearanceSignature.extract(from: buffer, rect: CGRect(x: 500, y: 500, width: 50, height: 50)) == nil)
    }

    @Test func torsoRectLiesBetweenShouldersAndHips() {
        let skeleton = makeSkeleton(centerX: 0.5)
        let rect = AppearanceSignature.torsoRect(of: skeleton, imageSize: CGSize(width: 1000, height: 1000))!
        #expect(rect.midX > 450 && rect.midX < 550)
        #expect(rect.minY > 300 && rect.maxY < 550)   // ombros em 0,3 e quadris em 0,55
        #expect(AppearanceSignature.torsoRect(of: Skeleton(joints: [:]), imageSize: CGSize(width: 10, height: 10)) == nil)
    }

    @Test func matcherAssignsSlotsToTheRightPlayers() {
        let red = signature((220, 30, 30)), blue = signature((30, 60, 220)), green = signature((30, 200, 60))
        let assigned = AppearanceMatcher.assign(slots: [0: blue, 1: red], players: ["paulo": red, "arthur": blue])
        #expect(assigned == [0: "arthur", 1: "paulo"])
        // Um jogador apresentado que não está na imagem não atrapalha.
        let partial = AppearanceMatcher.assign(slots: [2: green], players: ["paulo": red, "arthur": blue, "bia": green])
        #expect(partial == [2: "bia"])
    }

    @Test func matcherLeavesAmbiguousAndUnknownSlotsUnassigned() {
        let red = signature((220, 30, 30)), nearRed = signature((215, 35, 30)), blue = signature((30, 60, 220))
        // Duas camisas vermelhas iguais: não dá para saber quem é quem.
        let twins = AppearanceMatcher.assign(slots: [0: red], players: ["a": red, "b": nearRed])
        #expect(twins.isEmpty)
        // Roupa de cor que ninguém usava na apresentação.
        #expect(AppearanceMatcher.assign(slots: [0: blue], players: ["a": red]).isEmpty)
    }

    // MARK: - Decisão de rosto

    private let policy = FaceMatchPolicy.standard

    @Test func closeFaceMatchesTheKnownPlayer() {
        let decision = policy.decide([FaceCandidate(id: "paulo", distances: [0.4, 0.7], spread: 0.5),
                                      FaceCandidate(id: "arthur", distances: [3.0, 3.3], spread: 0.5)])
        guard case let .match(id, ratio) = decision else { Issue.record("\(decision)"); return }
        #expect(id == "paulo")
        #expect(ratio < 1)
    }

    @Test func farFaceIsUnknown() {
        let decision = policy.decide([FaceCandidate(id: "paulo", distances: [2.5], spread: 0.5)])
        #expect(decision == .unknown(bestRatio: 2.5 / 0.9))
        #expect(policy.decide([]) == .unknown(bestRatio: nil))
    }

    @Test func twoSimilarKnownPlayersAreAmbiguous() {
        let decision = policy.decide([FaceCandidate(id: "a", distances: [0.60], spread: 0.5),
                                      FaceCandidate(id: "b", distances: [0.65], spread: 0.5)])
        #expect(decision == .ambiguous)
    }

    @Test func thresholdGrowsWithThePlayersOwnVariation() {
        // Mesma distância: serve para quem varia muito, não serve para quem varia pouco.
        let loose = policy.decide([FaceCandidate(id: "a", distances: [1.5], spread: 1.2)])
        let tight = policy.decide([FaceCandidate(id: "a", distances: [1.5], spread: 0.1)])
        if case .match = loose {} else { Issue.record("deveria casar") }
        if case .unknown = tight {} else { Issue.record("deveria rejeitar") }
    }
}
