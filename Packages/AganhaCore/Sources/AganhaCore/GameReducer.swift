/// Máquina de estados da partida: lobby → countdown → command → window → judge → result → (next | gameOver).
/// Pura e sem relógio: quem dá o tempo é o GameLoop, que envia as ações e executa os efeitos.
public enum GameReducer {
    public static let windowOpensAfter = 0.3
    public static let correctPoints = 10
    public static let winnerBonus = 50

    @discardableResult
    public static func reduce(_ state: inout GameState, _ action: GameAction) -> [GameEffect] {
        switch action {
        case let .start(config):
            return start(&state, config)

        case .countdownFinished:
            guard state.phase == .countdown else { return [] }
            return issueCommand(&state)

        case let .commandAudioStarted(time):
            return openWindow(&state, audioStart: time)

        case let .postureSamples(samples):
            record(&state, samples)
            return []

        case .windowClosed:
            guard case let .window(command, opens, closes) = state.phase else { return [] }
            if state.config?.mode == .score {
                return judgeScore(&state, command: command, commandStart: opens - windowOpensAfter, windowEnd: closes)
            }
            return judge(&state, command: command, windowEnd: closes)

        case .unfair:
            guard case .result = state.phase, state.config?.mode != .score else { return [] }
            state.players = state.snapshot
            state.director = state.directorSnapshot
            state.history.removeLast()
            state.round -= 1
            return issueCommand(&state)

        case .next:
            guard case let .result(result) = state.phase else { return [] }
            if let finished = result.finished {
                state.phase = .gameOver(finished)
                return [.finished(finished)]
            }
            return issueCommand(&state)

        case .quit:
            state = GameState()
            return []
        }
    }

    // MARK: - Privado

    private static func start(_ state: inout GameState, _ config: GameConfig) -> [GameEffect] {
        switch state.phase {
        case .lobby, .gameOver: break
        default: return []
        }
        let slots = Set(config.slots)
        let validCount = config.solo ? slots.count == 1 : (2...GameLimits.maxChildren).contains(slots.count)
        guard slots.count == config.slots.count, validCount,
              slots.allSatisfy({ (0..<GameLimits.maxChildren).contains($0) })
        else { return [] }

        state = GameState()
        state.config = config
        state.players = Dictionary(uniqueKeysWithValues: config.slots.map { ($0, PlayerState()) })
        state.director = Director(difficulty: config.difficulty, tolerance: config.tolerance, seed: config.seed)
        state.phase = .countdown
        return [.startCountdown]
    }

    private static func openWindow(_ state: inout GameState, audioStart: Double) -> [GameEffect] {
        guard case let .announcing(command) = state.phase else { return [] }
        let opens = audioStart + windowOpensAfter + (state.config?.displayDelay ?? 0)
        let closes = opens + Double(command.windowMs) / 1000
        state.phase = .window(command, opensAt: opens, closesAt: closes)
        return [.scheduleWindowClose(at: closes)]
    }

    private static func record(_ state: inout GameState, _ samples: [PostureSample]) {
        guard case .window = state.phase else { return }
        for sample in samples where state.players[sample.childSlot] != nil {
            state.samples[sample.childSlot, default: []].append(sample)
        }
    }

    private static func issueCommand(_ state: inout GameState) -> [GameEffect] {
        guard var director = state.director else { return [] }
        state.directorSnapshot = director
        let command = director.next()
        state.director = director
        state.round += 1
        state.samples = [:]
        state.snapshot = state.players
        state.phase = .announcing(command)
        return [.playCommand(command)]
    }

    private static func judge(_ state: inout GameState, command: Command, windowEnd: Double) -> [GameEffect] {
        let maxAbsent = state.config?.maxAbsentStreak ?? 3
        let before = state.survivors
        var verdicts: [ChildSlot: Verdict] = [:]
        var details: [ChildSlot: Judge.Assessment] = [:]
        var eliminated: [ChildSlot] = []
        var wrong: [ChildSlot] = []
        let maxErrors = state.config?.maxErrors ?? 1

        for slot in before {
            let assessment = Judge.assess(expected: command.word, samples: state.samples[slot] ?? [], windowEnd: windowEnd,
                                          rules: state.config?.rules ?? JudgeRules())
            let verdict = assessment.verdict
            verdicts[slot] = verdict
            details[slot] = assessment
            var player = state.players[slot] ?? PlayerState()
            switch verdict {
            case .ok:
                player.correct += 1
                player.points += correctPoints
                player.absentStreak = 0
            case .wrong:
                player.absentStreak = 0
                player.errors += 1
                wrong.append(slot)
                if player.errors >= maxErrors { eliminated.append(slot) }
            case .absent:
                player.absentStreak += 1
                if player.absentStreak >= maxAbsent { eliminated.append(slot) }
            }
            state.players[slot] = player
        }

        // Todos os que restavam saíram juntos: empate, ninguém é eliminado.
        // (No treino solo, perder é só o fim do treino.)
        let solo = state.config?.solo ?? false
        let isTie = !solo && !before.isEmpty && eliminated.count == before.count
        if isTie { eliminated = [] }
        for slot in eliminated {
            state.players[slot]?.isEliminated = true
            state.players[slot]?.eliminatedAt = command.number
        }

        let survivors = state.survivors
        let finished: GameResult? = if solo {
            survivors.isEmpty ? makeResult(state, winners: []) : nil
        } else if isTie {
            makeResult(state, winners: survivors)
        } else if survivors.count == 1 {
            makeResult(state, winners: survivors)
        } else {
            nil
        }
        if let finished, !finished.winners.isEmpty {
            for slot in finished.winners { state.players[slot]?.points += winnerBonus }
        }

        let result = RoundResult(command: command, verdicts: verdicts, details: details, wrong: wrong.sorted(),
                                 eliminated: eliminated.sorted(),
                                 survivors: survivors, isTie: isTie, finished: finished)
        state.history.append(result)
        state.phase = .result(result)
        return [.showResult(result)]
    }

    /// Modo pontuação: ninguém sai; cada acerto vira moedas pela rapidez (e pelo combo) e a partida acaba na última rodada.
    private static func judgeScore(_ state: inout GameState, command: Command, commandStart: Double,
                                   windowEnd: Double) -> [GameEffect] {
        guard let config = state.config else { return [] }
        let rules = config.scoreRules
        let rising = state.history.last?.command.word == .down && command.word == .up
        var verdicts: [ChildSlot: Verdict] = [:]
        var details: [ChildSlot: Judge.Assessment] = [:]
        var scores: [ChildSlot: RoundScore] = [:]
        var missed: [ChildSlot] = []

        for slot in state.players.keys.sorted() {
            let samples = state.samples[slot] ?? []
            let assessment = Judge.assess(expected: command.word, samples: samples, windowEnd: windowEnd, rules: config.rules)
            verdicts[slot] = assessment.verdict
            details[slot] = assessment
            var player = state.players[slot] ?? PlayerState()
            guard assessment.verdict == .ok else {
                if assessment.verdict == .wrong { player.errors += 1 }
                player.combo = 0
                missed.append(slot)
                scores[slot] = RoundScore(tier: .miss, reactionMs: nil, coins: 0, multiplier: 1, combo: 0)
                state.players[slot] = player
                continue
            }
            var tier = ScoreTier.good
            var reactionMs: Int?
            switch Judge.settle(expected: command.word, samples: samples, windowEnd: windowEnd, rules: config.rules) {
            case .held:
                tier = .held
            case let .at(time):
                let ms = max(0, Int(((time - commandStart) * 1000).rounded()))
                reactionMs = ms
                tier = rules.tier(reactionMs: ms, rising: rising)
            case .never:
                break
            }
            player.combo += 1
            player.bestCombo = max(player.bestCombo, player.combo)
            let multiplier = rules.multiplier(forCombo: player.combo)
            let coins = rules.baseCoins(for: tier) * multiplier
            player.coins += coins
            player.points += coins
            player.correct += 1
            if let reactionMs {
                player.reactionTotalMs += reactionMs
                player.reactionCount += 1
                player.bestReactionMs = min(player.bestReactionMs ?? reactionMs, reactionMs)
            }
            scores[slot] = RoundScore(tier: tier, reactionMs: reactionMs, coins: coins, multiplier: multiplier, combo: player.combo)
            state.players[slot] = player
        }

        let finished: GameResult? = state.round >= config.scoreRounds ? makeScoreResult(state) : nil
        var result = RoundResult(command: command, verdicts: verdicts, details: details, wrong: missed.sorted(), eliminated: [],
                                 survivors: state.survivors, isTie: false, finished: finished)
        result.scores = scores
        state.history.append(result)
        state.phase = .result(result)
        return [.showResult(result)]
    }

    /// Mais moedas vence (empate de moedas = empate); na lista, desempata quem teve a média de reação mais rápida.
    private static func makeScoreResult(_ state: GameState) -> GameResult {
        let ranking = state.players.sorted { lhs, rhs in
            if lhs.value.coins != rhs.value.coins { return lhs.value.coins > rhs.value.coins }
            let l = lhs.value.averageReactionMs ?? Int.max
            let r = rhs.value.averageReactionMs ?? Int.max
            return l != r ? l < r : lhs.key < rhs.key
        }.map(\.key)
        let best = state.players.values.map(\.coins).max() ?? 0
        let winners = state.players.filter { $0.value.coins == best }.map(\.key).sorted()
        return GameResult(winners: winners, ranking: ranking)
    }

    private static func makeResult(_ state: GameState, winners: [ChildSlot]) -> GameResult {
        let others = state.players
            .filter { !winners.contains($0.key) }
            .sorted { lhs, rhs in
                let l = lhs.value.eliminatedAt ?? Int.max
                let r = rhs.value.eliminatedAt ?? Int.max
                return l != r ? l > r : lhs.key < rhs.key
            }
            .map(\.key)
        return GameResult(winners: winners.sorted(), ranking: winners.sorted() + others)
    }
}
