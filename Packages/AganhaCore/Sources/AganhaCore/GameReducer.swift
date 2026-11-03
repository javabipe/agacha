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
            guard case let .window(command, _, closes) = state.phase else { return [] }
            return judge(&state, command: command, windowEnd: closes)

        case .unfair:
            guard case .result = state.phase else { return [] }
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
        guard slots.count == config.slots.count, (2...GameLimits.maxChildren).contains(slots.count),
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
        let isTie = !before.isEmpty && eliminated.count == before.count
        if isTie { eliminated = [] }
        for slot in eliminated {
            state.players[slot]?.isEliminated = true
            state.players[slot]?.eliminatedAt = command.number
        }

        let survivors = state.survivors
        let finished: GameResult? = if isTie {
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
