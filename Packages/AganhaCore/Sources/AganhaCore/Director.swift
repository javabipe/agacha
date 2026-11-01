/// Gera os comandos da partida conforme o nível (ritmo, truques, "fica"). Determinístico por semente.
public struct Director: Sendable, Equatable {
    private struct Profile: Sendable, Equatable {
        var gapStart: Int
        var gapStep: Int
        var gapFloor: Int
        /// Primeiro comando (1 = o primeiro) em que truques são permitidos; nil = nunca.
        var trickFromNumber: Int?
        var trickChance: Double
        var repeatChance: Double
        var chainChance: Double
        /// Furacão pode ter dois truques seguidos; os outros níveis não.
        var allowsConsecutiveTricks: Bool
        /// A janela encolhe esta fração a cada comando, até `windowFloor` do valor da tolerância.
        var windowShrink: Double
        var windowFloor: Double
    }

    /// Intervalo (ms) entre comandos emendados.
    public static let chainedGapMs = 200

    public let difficulty: Difficulty
    public let tolerance: Tolerance
    public let seed: UInt64

    private let profile: Profile
    private var rng: SeededGenerator
    private var previous: Command?

    public init(difficulty: Difficulty, tolerance: Tolerance = .normal, seed: UInt64) {
        self.difficulty = difficulty
        self.tolerance = tolerance
        self.seed = seed
        rng = SeededGenerator(seed: seed)
        profile = Self.profile(for: difficulty)
    }

    private static func profile(for difficulty: Difficulty) -> Profile {
        switch difficulty {
        case .tranquilo:
            Profile(gapStart: 2200, gapStep: 40, gapFloor: 1500, trickFromNumber: nil, trickChance: 0,
                    repeatChance: 0.22, chainChance: 0, allowsConsecutiveTricks: false,
                    windowShrink: 0, windowFloor: 1)
        case .sapeca:
            Profile(gapStart: 1500, gapStep: 70, gapFloor: 700, trickFromNumber: 2, trickChance: 0.35,
                    repeatChance: 0.25, chainChance: 0, allowsConsecutiveTricks: false,
                    windowShrink: 0.02, windowFloor: 0.8)
        case .furacao:
            Profile(gapStart: 1000, gapStep: 40, gapFloor: 400, trickFromNumber: 1, trickChance: 0.5,
                    repeatChance: 0.30, chainChance: 0.30, allowsConsecutiveTricks: true,
                    windowShrink: 0.03, windowFloor: 0.7)
        }
    }

    /// Próximo comando. O primeiro é sempre "em pé"; depois alterna, salvo o "fica".
    public mutating func next() -> Command {
        let number = (previous?.number ?? 0) + 1

        let repeats = previous != nil && roll(profile.repeatChance)
        let word: Stance = if let previous { repeats ? previous.word : previous.word.opposite } else { .up }

        var trick = false
        if let from = profile.trickFromNumber, number >= from, roll(profile.trickChance) {
            trick = profile.allowsConsecutiveTricks || previous?.isTrick != true
        }
        let gesture = trick ? word.opposite : word

        let chains = roll(profile.chainChance) && previous?.chainsToNext != true
        let gap = chains
            ? Self.chainedGapMs
            : max(profile.gapFloor, profile.gapStart - profile.gapStep * (number - 1))

        let command = Command(number: number, word: word, gesture: gesture, isRepeat: repeats,
                              gapMs: gap, chainsToNext: chains, windowMs: windowMs(for: number))
        previous = command
        return command
    }

    /// Janela do comando: a tolerância escolhida, encolhendo um pouco a cada comando nos níveis mais difíceis.
    private func windowMs(for number: Int) -> Int {
        let factor = max(profile.windowFloor, 1 - profile.windowShrink * Double(number - 1))
        return Int((Double(tolerance.windowMs) * factor).rounded())
    }

    private mutating func roll(_ probability: Double) -> Bool {
        guard probability > 0 else { return false }
        return Double.random(in: 0..<1, using: &rng) < probability
    }
}
