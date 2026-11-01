#if os(iOS)
import AVFoundation
import Foundation
import os
import Speech

/// Escuta uma criança dizer o nome. O reconhecimento é **somente no aparelho**
/// (`requiresOnDeviceRecognition`): se o aparelho não tiver o idioma offline, não escuta.
/// Nada do áudio é gravado em disco nem enviado.
@MainActor
public final class NameListener {
    public enum Unavailable: Error {
        case permissionDenied
        case noOnDeviceRecognition
    }

    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var _text = ""
        private var _changedAt = Date.distantPast
        private var _isFinal = false

        var snapshot: (text: String, changedAt: Date, isFinal: Bool) {
            lock.withLock { (_text, _changedAt, _isFinal) }
        }

        func update(text: String, isFinal: Bool) {
            lock.withLock {
                if text != _text { _changedAt = Date() }
                _text = text
                _isFinal = _isFinal || isFinal
            }
        }
    }

    private final class RequestBox: @unchecked Sendable {
        let request = SFSpeechAudioBufferRecognitionRequest()
    }

    private let recognizer: SFSpeechRecognizer?
    private let logger = Logger(subsystem: "br.com.agacha.audio", category: "names")

    public init(locale: String = "pt-BR") {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
    }

    /// Dá para reconhecer sem rede neste aparelho?
    public var supportsOnDevice: Bool { recognizer?.supportsOnDeviceRecognition ?? false }

    /// Pede as permissões de microfone e reconhecimento de fala (uma vez; depois só consulta).
    public func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// Escuta até `maxDuration` s, ou até a pessoa falar e ficar `silence` s quieta. Devolve o que ouviu.
    public func listen(maxDuration: TimeInterval = 7, silence: TimeInterval = 1.1,
                       onPartial: ((String) -> Void)? = nil) async throws -> String {
        guard let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            throw Unavailable.noOnDeviceRecognition
        }
        guard await requestPermissions() else { throw Unavailable.permissionDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        defer { try? session.setCategory(.playback, mode: .default) }

        let engine = AVAudioEngine()
        let requestBox = RequestBox()
        requestBox.request.requiresOnDeviceRecognition = true
        requestBox.request.shouldReportPartialResults = true
        let box = Box()

        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            requestBox.request.append(buffer)
        }
        engine.prepare()
        try engine.start()

        let task = recognizer.recognitionTask(with: requestBox.request) { result, error in
            if let result {
                box.update(text: result.bestTranscription.formattedString, isFinal: result.isFinal)
            } else if error != nil {
                box.update(text: box.snapshot.text, isFinal: true)
            }
        }

        let start = Date()
        var lastReported = ""
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
            let state = box.snapshot
            if state.text != lastReported {
                lastReported = state.text
                onPartial?(state.text)
            }
            let heardSomething = !state.text.isEmpty
            if state.isFinal && heardSomething { break }
            if heardSomething, Date().timeIntervalSince(state.changedAt) > silence { break }
            if Date().timeIntervalSince(start) > maxDuration { break }
        }

        engine.stop()
        input.removeTap(onBus: 0)
        requestBox.request.endAudio()
        task.cancel()
        logger.info("Escuta encerrada (\(box.snapshot.text.isEmpty ? "sem fala" : "com fala", privacy: .public))")
        return box.snapshot.text
    }
}
#endif
