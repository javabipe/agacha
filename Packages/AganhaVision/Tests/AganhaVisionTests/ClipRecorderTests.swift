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
        // Os segmentos fecham (e os velhos somem) um pouco depois de gravar: espera estabilizar.
        // (Os 4 guardados, o que está gravando e o arquivo temporário que o AVFoundation usa nele.)
        for _ in 0..<40 where recorder.storedFileCount > ClipRecorder.keptSegments + 2 {
            try? await Task.sleep(for: .milliseconds(100))
        }
        #expect(recorder.storedFileCount <= ClipRecorder.keptSegments + 2)
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

    @Test func exportsAnMP4FileThatSurvivesResume() async throws {
        let directory = tempDirectory()
        let recorder = ClipRecorder(directory: directory)
        recorder.start()
        await record(recorder, seconds: 6)
        let asset = try #require(await recorder.capture(seconds: 3))
        let url = FileManager.default.temporaryDirectory.appending(path: "export-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(await recorder.exportMP4(ReplayAsset(asset), to: url))
        recorder.resume()
        let data = try Data(contentsOf: url)
        #expect(data.count > 1000)
        #expect(String(bytes: data.subdata(in: 4..<8), encoding: .ascii) == "ftyp")
        recorder.stop()
    }

    @Test func exportsJPEGFramesAndLeavesNoFileBehind() async throws {
        let directory = tempDirectory()
        let recorder = ClipRecorder(directory: directory)
        recorder.start()
        await record(recorder, seconds: 6)
        let asset = try #require(await recorder.capture(seconds: 3))
        let frames = await recorder.exportFrames(ReplayAsset(asset), framesPerSecond: 8)
        #expect(frames.count >= 15)
        #expect(frames.allSatisfy { $0.count > 100 && $0.prefix(2) == Data([0xFF, 0xD8]) })
        recorder.resume()
        #expect(recorder.storedFileCount == 0)
        recorder.stop()
    }
}
