import AVFoundation
import Foundation
import os

/// Toca os clipes gravados (ex.: `cmd_vivo`, `flow_count_3`) e, se o clipe não existir,
/// fala o texto de reserva com a voz do sistema. Tudo roda na main thread.
@MainActor
public final class AudioPlayer: NSObject {
    public let voice: String
    public let language: String
    public private(set) var isPlaying = false

    private var library: [String: [URL]] = [:]
    private var lastVariant: [String: Int] = [:]
    private var player: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    private var speechStart: (() -> Void)?
    /// Quem está tocando agora; callbacks atrasados de sons antigos são ignorados.
    private var currentSound: ObjectIdentifier?
    private let logger = Logger(subsystem: "br.com.agacha.audio", category: "player")

    public init(voice: String = "lu", language: String = "pt-BR") {
        self.voice = voice
        self.language = language
        super.init()
        synthesizer.delegate = self
        library = Self.scanLibrary(voice: voice, language: language)
        activateSession()
        logger.info("Clipes carregados: \(self.library.count, privacy: .public) ids")
    }

    /// Há clipe gravado para este id?
    public func hasClip(_ id: String) -> Bool { library[id] != nil }

    /// Toca o clipe `id` (sorteando uma variação) ou fala `fallbackText`. Retorna quando termina.
    /// `onStart` é chamado no instante em que o som começa (usado para abrir a janela de julgamento).
    public func play(_ id: String, fallbackText: String? = nil, onStart: (() -> Void)? = nil) async {
        stop()
        if let url = pickVariant(id), let clip = try? AVAudioPlayer(contentsOf: url) {
            await run(clip, onStart: onStart)
        } else if let fallbackText {
            logger.info("Sem clipe '\(id, privacy: .public)': usando voz do sistema")
            await speak(fallbackText, onStart: onStart)
        } else {
            onStart?()
        }
    }

    /// Fala um texto com a voz do sistema (nomes, frases sem gravação).
    public func speak(_ text: String, onStart: (() -> Void)? = nil) async {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = bestVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.1
        isPlaying = true
        currentSound = ObjectIdentifier(utterance)
        speechStart = onStart
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                self.synthesizer.speak(utterance)
            }
        } onCancel: {
            Task { @MainActor in self.stop() }
        }
    }

    public func stop() {
        player?.stop()
        player = nil
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        speechStart = nil
        finish()
    }

    // MARK: - Privado

    private func run(_ clip: AVAudioPlayer, onStart: (() -> Void)?) async {
        clip.delegate = self
        clip.prepareToPlay()
        player = clip
        currentSound = ObjectIdentifier(clip)
        isPlaying = true
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                onStart?()
                if !clip.play() { self.finish() }
            }
        } onCancel: {
            Task { @MainActor in self.stop() }
        }
    }

    /// Fim de um som específico (vindo de delegate): só vale se ainda for o som atual.
    private func finish(ifCurrent sound: ObjectIdentifier) {
        guard currentSound == sound else { return }
        finish()
    }

    private func finish() {
        currentSound = nil
        isPlaying = false
        let pending = continuation
        continuation = nil
        pending?.resume()
    }

    private func pickVariant(_ id: String) -> URL? {
        guard let urls = library[id], !urls.isEmpty else { return nil }
        var index = Int.random(in: 0..<urls.count)
        if urls.count > 1, index == lastVariant[id] { index = (index + 1) % urls.count }
        lastVariant[id] = index
        return urls[index]
    }

    private func bestVoice() -> AVSpeechSynthesisVoice? {
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
        return candidates.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: language)
    }

    private func activateSession() {
        #if os(iOS) || os(tvOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("AVAudioSession falhou: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    /// `lu_cmd_vivo_v2.caf` → id `cmd_vivo`.
    private static func scanLibrary(voice: String, language: String) -> [String: [URL]] {
        let urls = Bundle.module.urls(forResourcesWithExtension: "caf", subdirectory: "Resources/\(language)/\(voice)") ?? []
        var library: [String: [URL]] = [:]
        for url in urls {
            var name = url.deletingPathExtension().lastPathComponent
            guard name.hasPrefix("\(voice)_"), let range = name.range(of: "_v", options: .backwards) else { continue }
            name = String(name[name.index(name.startIndex, offsetBy: voice.count + 1)..<range.lowerBound])
            library[name, default: []].append(url)
        }
        return library.mapValues { $0.sorted { $0.lastPathComponent < $1.lastPathComponent } }
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let sound = ObjectIdentifier(player)
        Task { @MainActor in self.finish(ifCurrent: sound) }
    }
}

extension AudioPlayer: AVSpeechSynthesizerDelegate {
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let sound = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard self.currentSound == sound else { return }
            let start = self.speechStart
            self.speechStart = nil
            start?()
        }
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let sound = ObjectIdentifier(utterance)
        Task { @MainActor in self.finish(ifCurrent: sound) }
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let sound = ObjectIdentifier(utterance)
        Task { @MainActor in self.finish(ifCurrent: sound) }
    }
}
