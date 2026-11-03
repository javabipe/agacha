@testable import AganhaVision
import AVFoundation
import CoreVideo
import Foundation
import Testing

@Suite(.serialized) struct ClipRecorderTests {
    private func frame(_ shade: UInt8) -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 160, 120, kCVPixelFormatType_32BGRA, nil, &buffer)
        let pixels = buffer!
        CVPixelBufferLockBaseAddress(pixels, [])
        memset(CVPixelBufferGetBaseAddress(pixels), Int32(shade), CVPixelBufferGetBytesPerRow(pixels) * 120)
        CVPixelBufferUnlockBaseAddress(pixels, [])
        return pixels
    }

    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "clip-test-\(UUID().uuidString)")
    }

    private func record(_ recorder: ClipRecorder, seconds: Double, from start: Double = 0) async {
        var time = start
        var index = 0
        while time < start + seconds {
            recorder.append(frame(UInt8(index % 255)), at: time)
            time += 1.0 / 30
            index += 1
            if index % 15 == 0 { try? await Task.sleep(for: .milliseconds(5)) }
        }
    }

    @Test func capturesTheRecentSecondsAndCleansUp() async throws {
        let directory = tempDirectory()
        let recorder = ClipRecorder(directory: directory)
        recorder.start()
        await record(recorder, seconds: 7)
        let asset = await recorder.capture(seconds: 3)
        let duration = try await #require(asset).load(.duration).seconds
        #expect(duration >= 2.5)
        #expect(duration <= 6.5)
        #expect(recorder.storedFileCount > 0)

        recorder.resume()
        #expect(recorder.storedFileCount == 0)
        recorder.stop()
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func oldSegmentsAreDeletedWhileRecording() async {
        let directory = tempDirectory()
        let recorder = ClipRecorder(directory: directory)
        recorder.start()
        await record(recorder, seconds: 14)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(recorder.storedFileCount <= ClipRecorder.keptSegments + 1)
        recorder.stop()
    }

    @Test func nothingRecordedBeforeStartOrAfterStop() async {
        let directory = tempDirectory()
        let recorder = ClipRecorder(directory: directory)
        await record(recorder, seconds: 1)
        #expect(recorder.storedFileCount == 0)
        recorder.start()
        recorder.stop()
        await record(recorder, seconds: 1)
        #expect(recorder.storedFileCount == 0)
        #expect(await recorder.capture(seconds: 2) == nil)
    }

    @Test func frozenRecorderIgnoresNewFramesUntilResumed() async {
        let recorder = ClipRecorder(directory: tempDirectory())
        recorder.start()
        await record(recorder, seconds: 3)
        _ = await recorder.capture(seconds: 2)
        let before = recorder.storedFileCount
        await record(recorder, seconds: 3, from: 10)
        #expect(recorder.storedFileCount == before)
        recorder.resume()
        await record(recorder, seconds: 1, from: 20)
        #expect(recorder.storedFileCount >= 1)
        recorder.stop()
    }
}
