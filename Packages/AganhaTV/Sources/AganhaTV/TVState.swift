import Foundation

/// O que a TV mostra agora. É só texto e cores (nada de imagem da câmera): a página da TV desenha tudo.
public struct TVState: Codable, Equatable, Sendable {
    public struct Replay: Codable, Equatable, Sendable {
        public var frames: Int
        public var version: Int
        public var fps: Int

        public init(frames: Int, version: Int, fps: Int) {
            self.frames = frames
            self.version = version
            self.fps = fps
        }
    }

    fileprivate nonisolated(unsafe) static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]   // ordem estável das chaves
        return encoder
    }()

    public struct Player: Codable, Equatable, Sendable {
        public var name: String
        /// `#RRGGBB`
        public var color: String
        public var out: Bool
        /// Corações, "✓", "✕"...
        public var detail: String?

        public init(name: String, color: String, out: Bool = false, detail: String? = nil) {
            self.name = name
            self.color = color
            self.out = out
            self.detail = detail
        }
    }

    /// Um jogador como avatar: só as posições das juntas do corpo (nada de imagem).
    public struct Figure: Codable, Equatable, Sendable {
        public var name: String
        public var color: String
        /// Aparece inteiro no quadro (cabeça aos pés).
        public var ready: Bool
        /// Juntas vistas: `n` nariz, `ls`/`rs` ombros, `le`/`re` cotovelos, `lw`/`rw` pulsos, `lh`/`rh` quadris,
        /// `lk`/`rk` joelhos, `la`/`ra` tornozelos. Cada uma `[x, y]` em 0...1 (origem no canto superior esquerdo).
        public var joints: [String: [Double]]

        public init(name: String, color: String, ready: Bool, joints: [String: [Double]]) {
            self.name = name
            self.color = color
            self.ready = ready
            self.joints = joints
        }
    }

    /// `menu`, `positioning`, `play`, `result` ou `gameover`.
    public var screen: String
    public var word: String?
    /// Cor de fundo da palavra (`#RRGGBB`).
    public var background: String?
    /// `up`, `down` ou nil (tia parada).
    public var gesture: String?
    public var trick: Bool
    /// Contagem, avisos, orientações.
    public var banner: String?
    /// Resultado ("Paulo errou!", "Arthur venceu!").
    public var message: String?
    public var players: [Player]
    /// Replay pronto para a TV baixar quadro a quadro (`/replay/N.jpg?v=V`). A página acrescenta o código de acesso.
    public var replay: Replay?
    /// Linha pequena de diagnóstico ("mediu 0,36 · precisava ≤ 0,25").
    public var note: String?

    public init(screen: String, word: String? = nil, background: String? = nil, gesture: String? = nil, trick: Bool = false,
                banner: String? = nil, message: String? = nil, players: [Player] = [],
                replay: Replay? = nil, note: String? = nil) {
        self.screen = screen
        self.word = word
        self.background = background
        self.gesture = gesture
        self.trick = trick
        self.banner = banner
        self.message = message
        self.players = players
        self.replay = replay
        self.note = note
    }

    public func json() -> Data {
        (try? Self.encoder.encode(self)) ?? Data("{}".utf8)
    }
}

/// Posição dos jogadores agora (muda várias vezes por segundo, por isso vai separada do estado do jogo).
public struct TVPose: Codable, Equatable, Sendable {
    /// Largura ÷ altura do que a câmera vê (para desenhar na proporção certa).
    public var aspect: Double?
    public var figures: [TVState.Figure]

    public init(aspect: Double? = nil, figures: [TVState.Figure] = []) {
        self.aspect = aspect
        self.figures = figures
    }

    public func json() -> Data {
        (try? TVState.encoder.encode(self)) ?? Data("{}".utf8)
    }
}
