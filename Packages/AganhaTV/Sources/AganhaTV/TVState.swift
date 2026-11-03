import Foundation

/// O que a TV mostra agora. É só texto e cores (nada de imagem da câmera): a página da TV desenha tudo.
public struct TVState: Codable, Equatable, Sendable {
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

    /// Um jogador como boneco de palito (só linhas e um ponto: nada de imagem).
    public struct Figure: Codable, Equatable, Sendable {
        public var name: String
        public var color: String
        /// Aparece inteiro no quadro (cabeça aos pés).
        public var ready: Bool
        /// Segmentos `[x1, y1, x2, y2]` em 0...1, origem no canto superior esquerdo.
        public var bones: [[Double]]
        /// Posição da cabeça `[x, y]`.
        public var head: [Double]?

        public init(name: String, color: String, ready: Bool, bones: [[Double]], head: [Double]? = nil) {
            self.name = name
            self.color = color
            self.ready = ready
            self.bones = bones
            self.head = head
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
    /// Largura ÷ altura do que a câmera vê (para desenhar os bonecos na proporção certa).
    public var aspect: Double?
    public var figures: [Figure]

    public init(screen: String, word: String? = nil, background: String? = nil, gesture: String? = nil, trick: Bool = false,
                banner: String? = nil, message: String? = nil, players: [Player] = [], aspect: Double? = nil,
                figures: [Figure] = []) {
        self.screen = screen
        self.word = word
        self.background = background
        self.gesture = gesture
        self.trick = trick
        self.banner = banner
        self.message = message
        self.players = players
        self.aspect = aspect
        self.figures = figures
    }

    public func json() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data("{}".utf8)
    }
}
