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

        case let .followUpAudioStarted(time):
            return startFollowUp(&state, audioStart: time)

        case let .postureSamples(samples):
            record(&state, samples)
            return []

        case .windowClosed:
            return closeWindow(&state)

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
        state.director = Director(difficulty: config.difficulty, tolerance: config.tolerance, seed: config.seed,
                                  allowsDoubles: config.doubles)
        state.phase = .countdown
        return [.startCountdown]
    }

    private static func openWindow(_ state: inout GameState, audioStart: Double) -> [GameEffect] {
        guard case let .announcing(command) = state.phase else { return [] }
        let opens = audioStart + windowOpensAfter + (state.config?.displayDelay ?? 0)
        let closes = opens + Double(command.windowMs) / 1000
        state.phase = .window(command, opensAt: opens, closesAt: closes)
        // Duplo: quem fecha a janela é o início da segunda palavra (`followUpAudioStarted`).
        return command.followUp == nil ? [.scheduleWindowClose(at: closes)] : []
    }

    private static func closeWindow(_ state: inout GameState) -> [GameEffect] {
        guard case let .window(command, opens, closes) = state.phase else { return [] }
        // Comando duplo: só julga depois que a segunda palavra começou.
        if command.followUp != nil, state.followStart == nil { return [] }
        if state.config?.mode == .score {
            return judgeScore(&state, command: command, commandStart: opens - windowOpensAfter, windowEnd: closes)
        }
        return judge(&state, command: command, windowEnd: closes)
    }

    private static func startFollowUp(_ state: inout GameState, audioStart: Double) -> [GameEffect] {
        guard case let .window(command, opens, _) = state.phase, command.followUp != nil, state.followStart == nil else { return [] }
        let start = audioStart + (state.config?.displayDelay ?? 0)
        let closes = start + windowOpensAfter + Double(command.windowMs) / 1000
        state.followStart = start
        state.phase = .window(command, opensAt: opens, closesAt: closes)
        return [.scheduleWindowClose(at: closes)]
    }

    /// Julga uma criança num comando (num duplo, as duas palavras): quem falha na primeira erra mesmo que acerte a segunda.
    /// A primeira palavra vale até `graceMs` depois que a segunda começou; "ausente" na primeira não conta contra.
    private static func assess(_ state: GameState, slot: ChildSlot, command: Command, windowEnd: Double) -> (Judge.Assessment, Stance) {
        let samples = state.samples[slot] ?? []
        let rules = state.config?.rules ?? JudgeRules()
        guard let follow = command.followUp, let followStart = state.followStart else {
            return (Judge.assess(expected: command.word, samples: samples, windowEnd: windowEnd, rules: rules), command.word)
        }
        let first = Judge.assess(expected: command.word, samples: samples, windowEnd: followStart + Double(follow.graceMs) / 1000,
                                 rules: rules)
        if first.verdict == .wrong { return (first, command.word) }
        return (Judge.assess(expected: follow.word, samples: samples, windowEnd: windowEnd, rules: rules), follow.word)
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
        state.followStart = nil
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
        var failedWords: [ChildSlot: Stance] = [:]
        let maxErrors = state.config?.maxErrors ?? 1

        for slot in before {
            let (assessment, expectedWord) = assess(state, slot: slot, command: command, windowEnd: windowEnd)
            let verdict = assessment.verdict
            if verdict == .wrong { failedWords[slot] = expectedWord }
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
                                 survivors: survivors, isTie: isTie, finished: finished, failedWords: failedWords)
        state.history.append(result)
        state.phase = .result(result)
        return [.showResult(result)]
    }

    /// Modo pontuação: ninguém sai; cada acerto vira moedas pela rapidez (e pelo combo) e a partida acaba na última rodada.
    private static func judgeScore(_ state: inout GameState, command: Command, commandStart: Double,
                                   windowEnd: Double) -> [GameEffect] {
        guard let config = state.config else { return [] }
        let rules = config.scoreRules
        let rising = state.history.last?.command.finalWord == .down && command.word == .up
        var verdicts: [ChildSlot: Verdict] = [:]
        var details: [ChildSlot: Judge.Assessment] = [:]
        var scores: [ChildSlot: RoundScore] = [:]
        var failedWords: [ChildSlot: Stance] = [:]
        var missed: [ChildSlot] = []

        for slot in state.players.keys.sorted() {
            let samples = state.samples[slot] ?? []
            let (assessment, expectedWord) = assess(state, slot: slot, command: command, windowEnd: windowEnd)
            verdicts[slot] = assessment.verdict
            details[slot] = assessment
            var player = state.players[slot] ?? PlayerState()
            guard assessment.verdict == .ok else {
                if assessment.verdict == .wrong {
                    player.errors += 1
                    failedWords[slot] = expectedWord
                }
                player.combo = 0
                missed.append(slot)
                scores[slot] = RoundScore(tier: .miss, reactionMs: nil, coins: 0, multiplier: 1, combo: 0)
                state.players[slot] = player
                continue
            }
            // Num duplo valem as duas palavras: as moedas somam e o tempo mostrado é o da segunda.
            var steps = [Step(expected: command.word, start: commandStart, end: windowEnd, rising: rising)]
            if let follow = command.followUp, let followStart = state.followStart {
                let firstEnd = followStart + Double(follow.graceMs) / 1000
                let risesSecond = command.word == .down && follow.word == .up
                steps = [Step(expected: command.word, start: commandStart, end: firstEnd, rising: rising),
                         Step(expected: follow.word, start: followStart, end: windowEnd, rising: risesSecond)]
            }
            var base = 0
            var shown = (tier: ScoreTier.good, ms: Int?.none)
            for step in steps {
                let outcome = reaction(step, samples: samples, scoreRules: rules, judgeRules: config.rules)
                base += rules.baseCoins(for: outcome.tier)
                shown = outcome
            }
            player.combo += 1
            player.bestCombo = max(player.bestCombo, player.combo)
            let multiplier = rules.multiplier(forCombo: player.combo)
            let coins = base * multiplier
            player.coins += coins
            player.points += coins
            player.correct += 1
            player.addReaction(shown.ms)
            scores[slot] = RoundScore(tier: shown.tier, reactionMs: shown.ms, coins: coins, multiplier: multiplier,
                                      combo: player.combo, isDouble: command.followUp != nil)
            state.players[slot] = player
        }

        let finished: GameResult? = state.round >= config.scoreRounds ? makeScoreResult(state) : nil
        var result = RoundResult(command: command, verdicts: verdicts, details: details, wrong: missed.sorted(), eliminated: [],
                                 survivors: state.survivors, isTie: false, finished: finished, failedWords: failedWords)
        result.scores = scores
        state.history.append(result)
        state.phase = .result(result)
        return [.showResult(result)]
    }

    /// Uma palavra a cumprir: de `start` até `end`; `rising` = vinha agachado e precisa levantar.
    private struct Step {
        let expected: Stance
        let start: Double
        let end: Double
        let rising: Bool
    }

    /// Faixa e tempo de reação de uma palavra: do começo dela até o jogador ficar na postura certa.
    private static func reaction(_ step: Step, samples: [PostureSample], scoreRules: ScoreRules,
                                 judgeRules: JudgeRules) -> (tier: ScoreTier, ms: Int?) {
        switch Judge.settle(expected: step.expected, samples: samples, windowEnd: step.end, rules: judgeRules) {
        case .held:
            return (.held, nil)
        case let .at(time):
            let ms = max(0, Int(((time - step.start) * 1000).rounded()))
            return (scoreRules.tier(reactionMs: ms, rising: step.rising), ms)
        case .never:
            return (.good, nil)
        }
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
