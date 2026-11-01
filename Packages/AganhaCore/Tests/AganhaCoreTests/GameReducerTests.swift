@testable import AganhaCore
import Testing

@Suite struct GameReducerTests {
    private func config(slots: [ChildSlot] = [0, 1, 2], difficulty: Difficulty = .sapeca, seed: UInt64 = 1) -> GameConfig {
        GameConfig(slots: slots, difficulty: difficulty, seed: seed)
    }

    /// Joga uma rodada: `errors` são as vagas que ficam na postura errada.
    @discardableResult
    private func playRound(_ state: inout GameState, errors: Set<ChildSlot> = [], absent: Set<ChildSlot> = [],
                           at start: Double = 10) -> [GameEffect] {
        guard case let .announcing(command) = state.phase else { Issue.record("fase \(state.phase)"); return [] }
        GameReducer.reduce(&state, .commandAudioStarted(at: start))
        guard case let .window(_, _, closes) = state.phase else { Issue.record("sem janela"); return [] }
        let samples = state.survivors.filter { !absent.contains($0) }.map { slot in
            let posture = errors.contains(slot) ? command.word.opposite.posture : command.word.posture
            return PostureSample(childSlot: slot, posture: posture, timestamp: closes - 0.05)
        }
        GameReducer.reduce(&state, .postureSamples(samples))
        return GameReducer.reduce(&state, .windowClosed)
    }

    private func started(_ config: GameConfig) -> GameState {
        var state = GameState()
        GameReducer.reduce(&state, .start(config))
        GameReducer.reduce(&state, .countdownFinished)
        return state
    }

    @Test func startMovesToCountdownThenFirstCommand() {
        var state = GameState()
        #expect(GameReducer.reduce(&state, .start(config())) == [.startCountdown])
        #expect(state.phase == .countdown)
        let effects = GameReducer.reduce(&state, .countdownFinished)
        guard case let .announcing(command) = state.phase else { Issue.record("fase"); return }
        #expect(effects == [.playCommand(command)])
        #expect(command.word == .up)
        #expect(state.round == 1)
    }

    @Test func startRejectsInvalidPlayerCounts() {
        for slots in [[], [0], [0, 0], [0, 1, 2, 3, 4, 5, 6], [0, 9]] as [[ChildSlot]] {
            var state = GameState()
            #expect(GameReducer.reduce(&state, .start(config(slots: slots))).isEmpty)
            #expect(state.phase == .lobby)
        }
    }

    @Test func windowOpensThreeHundredMsAfterAudioAndLastsWindowMs() {
        var state = started(config())
        let effects = GameReducer.reduce(&state, .commandAudioStarted(at: 5))
        guard case let .window(command, opens, closes) = state.phase else { Issue.record("fase"); return }
        #expect(abs(opens - 5.3) < 1e-9)
        #expect(abs(closes - (5.3 + Double(command.windowMs) / 1000)) < 1e-9)
        #expect(effects == [.scheduleWindowClose(at: closes)])
    }

    @Test func everyoneCorrectKeepsEveryoneAndScores() {
        var state = started(config())
        playRound(&state)
        guard case let .result(result) = state.phase else { Issue.record("fase"); return }
        #expect(result.eliminated.isEmpty)
        #expect(result.survivors == [0, 1, 2])
        #expect(result.verdicts.values.allSatisfy { $0 == .ok })
        #expect(state.players[0]?.points == GameReducer.correctPoints)
        #expect(result.finished == nil)
    }

    @Test func wrongChildIsEliminatedAndOthersContinue() {
        var state = started(config())
        playRound(&state, errors: [1])
        GameReducer.reduce(&state, .next)
        #expect(state.survivors == [0, 2])
        #expect(state.players[1]?.eliminatedAt == 1)
        guard case .announcing = state.phase else { Issue.record("fase \(state.phase)"); return }
        #expect(state.round == 2)
    }

    @Test func lastSurvivorWinsAndRankingFollowsEliminationOrder() {
        var state = started(config())
        playRound(&state, errors: [2])      // 2 cai primeiro
        GameReducer.reduce(&state, .next)
        playRound(&state, errors: [0])      // 0 cai depois: vence o 1
        guard case let .result(result) = state.phase, let finished = result.finished else { Issue.record("sem fim"); return }
        #expect(finished.winners == [1])
        #expect(finished.ranking == [1, 0, 2])
        #expect(!finished.isTie)
        let effects = GameReducer.reduce(&state, .next)
        #expect(effects == [.finished(finished)])
        #expect(state.phase == .gameOver(finished))
        #expect(state.players[1]?.points == 2 * GameReducer.correctPoints + GameReducer.winnerBonus)
    }

    @Test func everyoneWrongTogetherIsATieWithNoElimination() {
        var state = started(config(slots: [0, 1]))
        playRound(&state, errors: [0, 1])
        guard case let .result(result) = state.phase else { Issue.record("fase"); return }
        #expect(result.isTie)
        #expect(result.eliminated.isEmpty)
        #expect(result.finished?.winners == [0, 1])
        #expect(result.finished?.isTie == true)
    }

    @Test func absentDoesNotEliminateUntilStreakLimit() {
        var state = started(config(slots: [0, 1, 2]))
        for round in 1...3 {
            playRound(&state, absent: [2])
            guard case let .result(result) = state.phase else { Issue.record("fase"); return }
            #expect(result.verdicts[2] == .absent)
            #expect(result.eliminated == (round == 3 ? [2] : []))
            GameReducer.reduce(&state, .next)
        }
        #expect(state.survivors == [0, 1])
    }

    @Test func presenceResetsAbsentStreak() {
        var state = started(config(slots: [0, 1, 2]))
        playRound(&state, absent: [2]); GameReducer.reduce(&state, .next)
        playRound(&state, absent: [2]); GameReducer.reduce(&state, .next)
        playRound(&state); GameReducer.reduce(&state, .next)   // 2 aparece
        playRound(&state, absent: [2])
        #expect(state.survivors == [0, 1, 2])
        #expect(state.players[2]?.absentStreak == 1)
    }

    @Test func unfairUndoesTheRoundAndIssuesANewCommand() {
        var state = started(config())
        playRound(&state, errors: [1])
        #expect(state.survivors == [0, 2])
        let effects = GameReducer.reduce(&state, .unfair)
        #expect(state.survivors == [0, 1, 2])
        #expect(state.players[0]?.points == 0)
        #expect(state.history.isEmpty)
        #expect(state.round == 1)
        guard case let .announcing(command) = state.phase else { Issue.record("fase"); return }
        #expect(effects == [.playCommand(command)])
    }

    @Test func unfairOnFinalRoundReopensTheGame() {
        var state = started(config(slots: [0, 1]))
        playRound(&state, errors: [1])
        #expect(state.survivors == [0])
        GameReducer.reduce(&state, .unfair)
        #expect(state.survivors == [0, 1])
        #expect(state.players[0]?.points == 0)
    }

    @Test func actionsOutOfPhaseAreIgnored() {
        var state = GameState()
        for action in [GameAction.countdownFinished, .commandAudioStarted(at: 1), .windowClosed, .unfair, .next] {
            #expect(GameReducer.reduce(&state, action).isEmpty)
        }
        #expect(state.phase == .lobby)
    }

    @Test func samplesFromUnknownSlotsAreIgnored() {
        var state = started(config())
        GameReducer.reduce(&state, .commandAudioStarted(at: 1))
        GameReducer.reduce(&state, .postureSamples([PostureSample(childSlot: 5, posture: .standing, timestamp: 1.2)]))
        #expect(state.samples[5] == nil)
    }

    @Test func quitReturnsToLobbyAndAllowsRestart() {
        var state = started(config())
        GameReducer.reduce(&state, .quit)
        #expect(state.phase == .lobby)
        #expect(GameReducer.reduce(&state, .start(config())) == [.startCountdown])
    }

    // MARK: - Simulação de partidas inteiras

    /// Crianças-robô: cada vaga erra com a probabilidade dada. Devolve o histórico da partida.
    private func simulate(seed: UInt64, difficulty: Difficulty, slots: [ChildSlot], errorRate: Double) -> GameState {
        var bots = SeededGenerator(seed: seed ^ 0xABCD)
        var state = started(GameConfig(slots: slots, difficulty: difficulty, seed: seed))
        var guardCounter = 0
        while true {
            guardCounter += 1
            if guardCounter > 500 { Issue.record("partida não terminou"); break }
            guard case let .announcing(command) = state.phase else { break }
            GameReducer.reduce(&state, .commandAudioStarted(at: Double(guardCounter)))
            guard case let .window(_, _, closes) = state.phase else { break }
            let samples = state.survivors.map { slot -> PostureSample in
                let wrong = Double.random(in: 0..<1, using: &bots) < errorRate
                let posture = wrong ? command.word.opposite.posture : command.word.posture
                return PostureSample(childSlot: slot, posture: posture, timestamp: closes - 0.02)
            }
            GameReducer.reduce(&state, .postureSamples(samples))
            GameReducer.reduce(&state, .windowClosed)
            GameReducer.reduce(&state, .next)
            if case .gameOver = state.phase { break }
        }
        return state
    }

    @Test func simulatedGamesAlwaysEndWithWinnersAndConsistentHistory() {
        for difficulty in Difficulty.allCases {
            for seed in 1...40 as ClosedRange<UInt64> {
                let slots = Array(0..<Int(2 + seed % 5))
                let state = simulate(seed: seed, difficulty: difficulty, slots: slots, errorRate: 0.15)
                guard case let .gameOver(result) = state.phase else { Issue.record("sem gameOver \(difficulty) \(seed)"); continue }
                #expect(!result.winners.isEmpty)
                #expect(Set(result.ranking) == Set(slots))
                #expect(result.ranking.count == slots.count)
                var alive = slots.count
                for round in state.history {
                    #expect(round.survivors.count <= alive)
                    alive = round.survivors.count
                }
                #expect(state.history.last?.finished == result)
            }
        }
    }

    @Test func simulationIsDeterministicPerSeed() {
        let a = simulate(seed: 99, difficulty: .furacao, slots: [0, 1, 2, 3], errorRate: 0.2)
        let b = simulate(seed: 99, difficulty: .furacao, slots: [0, 1, 2, 3], errorRate: 0.2)
        #expect(a.history == b.history)
        #expect(a.phase == b.phase)
    }
}

@Suite struct LivesTests {
    private func started(maxErrors: Int, slots: [ChildSlot] = [0, 1, 2]) -> GameState {
        var state = GameState()
        GameReducer.reduce(&state, .start(GameConfig(slots: slots, seed: 1, maxErrors: maxErrors)))
        GameReducer.reduce(&state, .countdownFinished)
        return state
    }

    private func round(_ state: inout GameState, wrong: Set<ChildSlot>) {
        guard case let .announcing(command) = state.phase else { Issue.record("fase \(state.phase)"); return }
        GameReducer.reduce(&state, .commandAudioStarted(at: 1))
        guard case let .window(_, _, closes) = state.phase else { return }
        let samples = state.survivors.map { slot in
            PostureSample(childSlot: slot, posture: wrong.contains(slot) ? command.word.opposite.posture : command.word.posture,
                          timestamp: closes - 0.05)
        }
        GameReducer.reduce(&state, .postureSamples(samples))
        GameReducer.reduce(&state, .windowClosed)
    }

    @Test func playerSurvivesUntilReachingTheErrorLimit() {
        var state = started(maxErrors: 3)
        for expected in 1...2 {
            round(&state, wrong: [1])
            guard case let .result(result) = state.phase else { Issue.record("fase"); return }
            #expect(result.wrong == [1])
            #expect(result.eliminated.isEmpty)
            #expect(state.players[1]?.errors == expected)
            GameReducer.reduce(&state, .next)
        }
        round(&state, wrong: [1])
        guard case let .result(result) = state.phase else { Issue.record("fase"); return }
        #expect(result.eliminated == [1])
        #expect(state.survivors == [0, 2])
    }

    @Test func defaultStaysOneError() {
        var state = started(maxErrors: 1)
        round(&state, wrong: [0])
        #expect(state.survivors == [1, 2])
    }

    @Test func everyoneErringWithLivesLeftKeepsPlaying() {
        var state = started(maxErrors: 2, slots: [0, 1])
        round(&state, wrong: [0, 1])
        guard case let .result(result) = state.phase else { Issue.record("fase"); return }
        #expect(!result.isTie)
        #expect(result.finished == nil)
        #expect(state.survivors == [0, 1])
    }

    @Test func everyoneEliminatedAtTheSameTimeIsATie() {
        var state = started(maxErrors: 2, slots: [0, 1])
        round(&state, wrong: [0, 1]); GameReducer.reduce(&state, .next)
        round(&state, wrong: [0, 1])
        guard case let .result(result) = state.phase else { Issue.record("fase"); return }
        #expect(result.isTie)
        #expect(result.finished?.winners == [0, 1])
    }

    @Test func unfairGivesTheErrorBack() {
        var state = started(maxErrors: 3)
        round(&state, wrong: [1])
        #expect(state.players[1]?.errors == 1)
        GameReducer.reduce(&state, .unfair)
        #expect(state.players[1]?.errors == 0)
    }

    @Test func invalidLimitIsClampedToOne() {
        #expect(GameConfig(slots: [0, 1], seed: 1, maxErrors: 0).maxErrors == 1)
    }
}
