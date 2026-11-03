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

    public init(screen: String, word: String? = nil, background: String? = nil, gesture: String? = nil, trick: Bool = false,
                banner: String? = nil, message: String? = nil, players: [Player] = []) {
        self.screen = screen
        self.word = word
        self.background = background
        self.gesture = gesture
        self.trick = trick
        self.banner = banner
        self.message = message
        self.players = players
    }

    public func json() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data("{}".utf8)
    }
}
