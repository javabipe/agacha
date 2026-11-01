#if os(iOS)
import AVFoundation
import Foundation
import os
import Speech

/// Retrato do que o reconhecedor já devolveu (lido pelo laço principal).
private struct ListenState {
    let text: String
    let changedAt: Date
    let isFinal: Bool
    let failed: Bool
}

/// Escuta uma criança dizer o nome. Usa o reconhecimento no próprio aparelho quando o idioma está
/// disponível offline; senão o iOS pode processar o áudio nos servidores da Apple. Nada é gravado em disco.
@MainActor
public final class NameListener {
    public enum Unavailable: Error, Equatable {
        case speechPermissionDenied
        case microphonePermissionDenied
        case recognizerUnavailable
    }

    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var _text = ""
        private var _changedAt = Date.distantPast
        private var _isFinal = false
        private var _failed = false

        var snapshot: ListenState {
            lock.withLock { ListenState(text: _text, changedAt: _changedAt, isFinal: _isFinal, failed: _failed) }
        }

        func markFailed() {
            lock.withLock { _failed = true }
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

    // Os blocos abaixo são chamados pelo iOS em filas de fundo. Criados dentro de um método `@MainActor`
    // herdariam o isolamento e abortariam o app; por isso nascem em funções `nonisolated`.

    private nonisolated static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }

    private nonisolated static func makeTap(_ box: RequestBox) -> AVAudioNodeTapBlock {
        { buffer, _ in box.request.append(buffer) }
    }

    private nonisolated static func makeHandler(_ box: Box) -> @Sendable (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            if let result {
                box.update(text: result.bestTranscription.formattedString, isFinal: result.isFinal)
            } else if error != nil {
                box.markFailed()
            }
        }
    }

    /// Dá para reconhecer sem rede neste aparelho?
    public var supportsOnDevice: Bool { recognizer?.supportsOnDeviceRecognition ?? false }

    /// Pede as permissões de reconhecimento de fala e microfone (a primeira vez abre os avisos do iOS).
    /// Devolve o motivo se alguma foi negada.
    public func requestPermissions() async -> Unavailable? {
        let speech = await Self.requestSpeechAuthorization()
        guard speech else { return .speechPermissionDenied }
        guard await AVAudioApplication.requestRecordPermission() else { return .microphonePermissionDenied }
        return nil
    }

    /// Escuta até `maxDuration` s, ou até a pessoa falar e ficar `silence` s quieta. Devolve o que ouviu.
    public func listen(maxDuration: TimeInterval = 7, silence: TimeInterval = 1.1,
                       onPartial: ((String) -> Void)? = nil) async throws -> String {
        if let denied = await requestPermissions() { throw denied }
        guard let recognizer, recognizer.isAvailable else { throw Unavailable.recognizerUnavailable }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        defer { try? session.setCategory(.playback, mode: .default) }

        let engine = AVAudioEngine()
        let requestBox = RequestBox()
        // Prefere o aparelho quando possível; sem o idioma offline, o iOS usa o reconhecimento da Apple (com internet).
        requestBox.request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        requestBox.request.shouldReportPartialResults = true
        let box = Box()

        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0), block: Self.makeTap(requestBox))
        engine.prepare()
        try engine.start()

        let task = recognizer.recognitionTask(with: requestBox.request, resultHandler: Self.makeHandler(box))

        let start = Date()
        var lastReported = ""
        var failure: Unavailable?
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
            let state = box.snapshot
            if state.text != lastReported {
                lastReported = state.text
                onPartial?(state.text)
            }
            let heardSomething = !state.text.isEmpty
            // Erro logo no começo, sem ter ouvido nada: o reconhecimento não está funcionando (não é só silêncio).
            if state.failed, !heardSomething {
                if Date().timeIntervalSince(start) < 2 { failure = .recognizerUnavailable }
                break
            }
            if state.isFinal && heardSomething { break }
            if heardSomething, Date().timeIntervalSince(state.changedAt) > silence { break }
            if Date().timeIntervalSince(start) > maxDuration { break }
        }

        engine.stop()
        input.removeTap(onBus: 0)
        requestBox.request.endAudio()
        task.cancel()
        logger.info("Escuta encerrada (\(box.snapshot.text.isEmpty ? "sem fala" : "com fala", privacy: .public))")
        if let failure { throw failure }
        return box.snapshot.text
    }
}
#endif
