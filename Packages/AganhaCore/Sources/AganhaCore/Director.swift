/// Gera os comandos da partida conforme o nível (ritmo, truques, "fica"). Determinístico por semente.
public struct Director: Sendable, Equatable {
    /// Como o nível começa e como a dificuldade sobe a cada comando, até alguém errar
    /// (como o adulto que vai falando mais rápido e enganando mais).
    private struct Profile: Sendable, Equatable {
        var gapStart: Int
        var gapStep: Int
        var gapFloor: Int
        /// Primeiro comando (1 = o primeiro) em que truques são permitidos; nil = nunca.
        var trickFromNumber: Int?
        var trickStart = 0.0
        var trickGrowth = 0.0
        var trickMax = 0.0
        var repeatChance: Double
        /// Primeiro comando em que podem vir comandos "emendados"; nil = nunca.
        var chainFromNumber: Int?
        var chainStart = 0.0
        var chainGrowth = 0.0
        var chainMax = 0.0
        /// Furacão pode ter dois truques seguidos; os outros níveis não.
        var allowsConsecutiveTricks: Bool
        /// A janela encolhe esta fração a cada comando, até `windowFloor` do valor da tolerância.
        var windowShrink: Double
        var windowFloor: Double

        func trickChance(at number: Int) -> Double {
            guard let from = trickFromNumber, number >= from else { return 0 }
            return min(trickMax, trickStart + trickGrowth * Double(number - from))
        }

        func chainChance(at number: Int) -> Double {
            guard let from = chainFromNumber, number >= from else { return 0 }
            return min(chainMax, chainStart + chainGrowth * Double(number - from))
        }
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
            Profile(gapStart: 2200, gapStep: 60, gapFloor: 1200, trickFromNumber: nil,
                    repeatChance: 0.22, chainFromNumber: nil, allowsConsecutiveTricks: false,
                    windowShrink: 0.025, windowFloor: 0.85)
        case .sapeca:
            Profile(gapStart: 1500, gapStep: 80, gapFloor: 500, trickFromNumber: 2,
                    trickStart: 0.25, trickGrowth: 0.02, trickMax: 0.55, repeatChance: 0.25,
                    chainFromNumber: 8, chainStart: 0.10, chainGrowth: 0.02, chainMax: 0.30,
                    allowsConsecutiveTricks: false, windowShrink: 0.03, windowFloor: 0.75)
        case .furacao:
            Profile(gapStart: 1000, gapStep: 50, gapFloor: 250, trickFromNumber: 1,
                    trickStart: 0.50, trickGrowth: 0.02, trickMax: 0.75, repeatChance: 0.30,
                    chainFromNumber: 1, chainStart: 0.30, chainGrowth: 0.01, chainMax: 0.45,
                    allowsConsecutiveTricks: true, windowShrink: 0.04, windowFloor: 0.65)
        }
    }

    /// Próximo comando. O primeiro é sempre "em pé"; depois alterna, salvo o "fica".
    public mutating func next() -> Command {
        let number = (previous?.number ?? 0) + 1

        let repeats = previous != nil && roll(profile.repeatChance)
        let word: Stance = if let previous { repeats ? previous.word : previous.word.opposite } else { .up }

        var trick = false
        if roll(profile.trickChance(at: number)) {
            trick = profile.allowsConsecutiveTricks || previous?.isTrick != true
        }
        let gesture = trick ? word.opposite : word

        let chains = roll(profile.chainChance(at: number)) && previous?.chainsToNext != true
        let gap = chains
            ? Self.chainedGapMs
            : max(profile.gapFloor, profile.gapStart - profile.gapStep * (number - 1))

        let command = Command(number: number, word: word, gesture: gesture, isRepeat: repeats,
                              gapMs: gap, chainsToNext: chains, windowMs: windowMs(for: number), cue: cue(for: number))
        previous = command
        return command
    }

    /// A cada 5 comandos a tia avisa que o ritmo subiu (alternando "mais rápido" e "mais difícil").
    private func cue(for number: Int) -> Cue? {
        guard number >= 5, number % 5 == 0 else { return nil }
        let harderAllowed = profile.trickFromNumber != nil
        return (number / 5).isMultiple(of: 2) && harderAllowed ? .harder : .faster
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
