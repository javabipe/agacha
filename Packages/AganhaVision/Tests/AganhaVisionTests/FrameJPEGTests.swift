@testable import AganhaVision
import CoreVideo
import Foundation
import Testing

@Suite struct FrameJPEGTests {
    private func buffer(width: Int, height: Int) -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
        let pixels = buffer!
        CVPixelBufferLockBaseAddress(pixels, [])
        memset(CVPixelBufferGetBaseAddress(pixels), 180, CVPixelBufferGetBytesPerRow(pixels) * height)
        CVPixelBufferUnlockBaseAddress(pixels, [])
        return pixels
    }

    @Test func producesAJPEGSmallerThanTheOriginal() throws {
        let data = try #require(FrameJPEG().encode(buffer(width: 1280, height: 720), maxWidth: 640))
        #expect(data.prefix(2) == Data([0xFF, 0xD8]))   // começo de um JPEG
        #expect(data.suffix(2) == Data([0xFF, 0xD9]))   // fim de um JPEG
        #expect(data.count < 1280 * 720)
    }

    @Test func downscalesWideFramesAndKeepsSmallOnes() throws {
        let encoder = FrameJPEG()
        let big = try #require(encoder.encode(buffer(width: 1280, height: 720), maxWidth: 320, quality: 0.5))
        let small = try #require(encoder.encode(buffer(width: 200, height: 100), maxWidth: 640, quality: 0.5))
        #expect(!big.isEmpty && !small.isEmpty)
    }
}
