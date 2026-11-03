@testable import AganhaCore
import Testing

@Suite struct ScoringTests {
    private func sample(_ slot: ChildSlot, _ posture: Posture, _ time: Double, _ index: Double? = nil) -> PostureSample {
        PostureSample(childSlot: slot, posture: posture, timestamp: time, crouchIndex: index)
    }

    // MARK: settle

    @Test func settleIsHeldWhenAlreadyInThePostureFromTheFirstSample() {
        let samples = [sample(0, .crouching, 10.0, 0.6), sample(0, .crouching, 10.5, 0.7)]
        #expect(Judge.settle(expected: .down, samples: samples, windowEnd: 11) == .held)
    }

    @Test func settleFindsTheFirstRightSampleAfterTheLastWrongOne() {
        let samples = [sample(0, .standing, 10.0, 0.0), sample(0, .standing, 10.3, 0.1), sample(0, .crouching, 10.6, 0.5),
                       sample(0, .crouching, 10.9, 0.7)]
        #expect(Judge.settle(expected: .down, samples: samples, windowEnd: 11) == .at(10.6))
    }

    @Test func settleUsesTheCompleteMovementRule() {
        // Postura "agachado", mas o quadril só desceu 0,3 (< 0,45): ainda não valeu.
        let samples = [sample(0, .standing, 10.0, 0.0), sample(0, .crouching, 10.3, 0.3), sample(0, .crouching, 10.6, 0.5)]
        #expect(Judge.settle(expected: .down, samples: samples, windowEnd: 11) == .at(10.6))
    }

    @Test func settleIsNeverWhenTheEndIsWrongOrThereAreNoSamples() {
        let samples = [sample(0, .crouching, 10.0, 0.6), sample(0, .standing, 10.5, 0.0)]
        #expect(Judge.settle(expected: .down, samples: samples, windowEnd: 11) == .never)
        #expect(Judge.settle(expected: .down, samples: [], windowEnd: 11) == .never)
    }

    @Test func aFlickerInTheMiddleResetsTheReactionTime() {
        let samples = [sample(0, .crouching, 10.0, 0.6), sample(0, .standing, 10.3, 0.0), sample(0, .crouching, 10.6, 0.6)]
        #expect(Judge.settle(expected: .down, samples: samples, windowEnd: 11) == .at(10.6))
    }

    // MARK: faixas e combo

    @Test func tiersFollowTheReactionTimeAndRisingGetsExtraTime() {
        let rules = ScoreRules()
        #expect(rules.tier(reactionMs: 700, rising: false) == .perfect)
        #expect(rules.tier(reactionMs: 1000, rising: false) == .great)
        #expect(rules.tier(reactionMs: 1500, rising: false) == .good)
        #expect(rules.tier(reactionMs: 1100, rising: true) == .perfect)
        #expect(rules.tier(reactionMs: 1500, rising: true) == .great)
    }

    @Test func multiplierGrowsEveryThreeHitsAndCaps() {
        let rules = ScoreRules()
        #expect([1, 2, 3, 6, 9, 30].map(rules.multiplier(forCombo:)) == [1, 1, 2, 3, 4, 4])
    }

    // MARK: partida

    private func scoreConfig(slots: [ChildSlot] = [0, 1], rounds: Int = 3, solo: Bool = false) -> GameConfig {
        GameConfig(slots: slots, seed: 1, solo: solo, mode: .score, scoreRounds: rounds)
    }

    /// Joga uma rodada: cada jogador está na postura errada até `moves[slot]` s depois do começo (nil = errado até o fim).
    private func round(_ state: inout GameState, moves: [ChildSlot: Double?], at start: Double = 10) {
        guard case let .announcing(command) = state.phase else { Issue.record("fase \(state.phase)"); return }
        GameReducer.reduce(&state, .commandAudioStarted(at: start))
        guard case let .window(_, opens, closes) = state.phase else { Issue.record("sem janela"); return }
        var samples: [PostureSample] = []
        for (slot, move) in moves {
            var time = opens
            while time < closes {
                let right = move.map { time - start >= $0 } ?? false
                let posture = right ? command.word.posture : command.word.opposite.posture
                samples.append(sample(slot, posture, time))
                time += 0.1
            }
            samples.append(sample(slot, move != nil ? command.word.posture : command.word.opposite.posture, closes - 0.02))
        }
        GameReducer.reduce(&state, .postureSamples(samples))
        GameReducer.reduce(&state, .windowClosed)
    }

    private func started(_ config: GameConfig) -> GameState {
        var state = GameState()
        GameReducer.reduce(&state, .start(config))
        GameReducer.reduce(&state, .countdownFinished)
        return state
    }

    @Test func fasterPlayerGetsMoreCoinsAndNobodyIsEliminated() {
        var state = started(scoreConfig())
        round(&state, moves: [0: 0.6, 1: 1.1])
        guard case let .result(result) = state.phase else { Issue.record("fase"); return }
        #expect(result.scores[0]?.tier == .perfect && result.scores[0]?.coins == 5)
        #expect(result.scores[1]?.tier == .great && result.scores[1]?.coins == 3)
        #expect(abs(Double(result.scores[0]?.reactionMs ?? 0) - 600) <= 150)
        #expect(state.survivors == [0, 1])
        #expect(state.players[0]?.coins == 5)
    }

    @Test func aMissGivesNothingAndResetsTheCombo() {
        var state = started(scoreConfig(rounds: 5))
        round(&state, moves: [0: 0.5, 1: 0.5])
        GameReducer.reduce(&state, .next)
        round(&state, moves: [0: nil, 1: 0.5])
        guard case let .result(result) = state.phase else { Issue.record("fase"); return }
        #expect(result.scores[0]?.tier == .miss && result.scores[0]?.coins == 0 && result.scores[0]?.combo == 0)
        #expect(state.players[0]?.combo == 0 && state.players[1]?.combo == 2)
        #expect(result.wrong == [0])
        #expect(result.eliminated.isEmpty)
    }

    @Test func gameEndsAfterTheConfiguredRoundsAndTheRichestWins() {
        var state = started(scoreConfig(rounds: 2))
        round(&state, moves: [0: 0.5, 1: 1.0])
        GameReducer.reduce(&state, .next)
        round(&state, moves: [0: 0.5, 1: 1.0])
        guard case let .result(result) = state.phase, let finished = result.finished else { Issue.record("sem fim"); return }
        #expect(finished.winners == [0] && finished.ranking == [0, 1])
        GameReducer.reduce(&state, .next)
        #expect(state.phase == .gameOver(finished))
    }

    @Test func equalCoinsIsATieButTheRankingFavoursTheFasterAverage() {
        var state = started(scoreConfig(rounds: 1))
        round(&state, moves: [0: 0.8, 1: 0.5])
        guard case let .result(result) = state.phase, let finished = result.finished else { Issue.record("sem fim"); return }
        #expect(finished.isTie)
        #expect(finished.ranking == [1, 0])
    }

    @Test func soloScoreModeEndsByRoundsWithTheSinglePlayerAsWinner() {
        var state = started(scoreConfig(slots: [0], rounds: 1, solo: true))
        round(&state, moves: [0: nil])
        guard case let .result(result) = state.phase, let finished = result.finished else { Issue.record("sem fim"); return }
        #expect(finished.winners == [0])
        #expect(state.players[0]?.coins == 0)
    }

    @Test func unfairIsIgnoredInScoreMode() {
        var state = started(scoreConfig())
        round(&state, moves: [0: 0.5, 1: 0.5])
        let before = state
        GameReducer.reduce(&state, .unfair)
        #expect(state == before)
    }

    @Test func repeatedCommandHeldPostureGivesTheFixedCoins() {
        var state = started(scoreConfig(rounds: 5))
        round(&state, moves: [0: 0.0, 1: 0.0])   // já certos desde o começo da janela
        guard case let .result(result) = state.phase else { Issue.record("fase"); return }
        #expect(result.scores[0]?.tier == .held && result.scores[0]?.reactionMs == nil && result.scores[0]?.coins == 2)
    }
}
