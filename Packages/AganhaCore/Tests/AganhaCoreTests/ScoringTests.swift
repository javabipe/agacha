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

// MARK: - Comandos duplos

@Suite struct DoubleCommandTests {
    private func commands(_ level: Difficulty, seed: UInt64 = 3, count: Int = 120, doubles: Bool = true) -> [Command] {
        var director = Director(difficulty: level, seed: seed, allowsDoubles: doubles)
        return (0..<count).map { _ in director.next() }
    }

    @Test func tranquiloNeverDoublesAndDisabledMeansNoDoublesAnywhere() {
        #expect(commands(.tranquilo).allSatisfy { $0.followUp == nil })
        for level in Difficulty.allCases {
            #expect(commands(level, doubles: false).allSatisfy { $0.followUp == nil })
        }
    }

    @Test func disablingDoublesKeepsTheSameSequenceAsBefore() {
        let off = commands(.sapeca, seed: 5, doubles: false)
        var plain = Director(difficulty: .sapeca, seed: 5)
        #expect(off == (0..<120).map { _ in plain.next() })
    }

    @Test func doublesStartLaterOnSapecaThanOnFuracaoAndNeverBackToBackOrWithTricks() {
        for level in [Difficulty.sapeca, .furacao] {
            let list = commands(level)
            let from = level == .sapeca ? 6 : 4
            #expect(list.filter { $0.followUp != nil }.count > 3)
            #expect(list.allSatisfy { $0.followUp == nil || ($0.number >= from && !$0.isTrick) })
            for (previous, command) in zip(list, list.dropFirst()) {
                #expect(previous.followUp == nil || command.followUp == nil)
            }
        }
    }

    @Test func nextWordFollowsTheEndOfADouble() {
        let list = commands(.furacao, seed: 11, count: 200)
        for (previous, command) in zip(list, list.dropFirst()) {
            #expect(command.isRepeat ? command.word == previous.finalWord : command.word == previous.finalWord.opposite)
        }
    }

    @Test func risingBetweenTheTwoWordsGetsExtraTimeOnTheSecondWindow() {
        let tolerance = Tolerance.normal
        for command in commands(.furacao, seed: 2, count: 200) {
            guard let follow = command.followUp, command.word == .down, follow.word == .up else { continue }
            #expect(command.windowMs >= tolerance.riseExtraMs)
        }
    }

    // MARK: partida

    private func doubleCommand(first: Stance, second: Stance) -> Command {
        Command(number: 1, word: first, gesture: first, isRepeat: false, gapMs: 1000, chainsToNext: false, windowMs: 2000,
                followUp: FollowUp(word: second, gapMs: 200, graceMs: 250))
    }

    /// Joga um duplo com a postura de cada jogador em dois momentos: até a segunda palavra e depois dela.
    private func play(first: Stance, second: Stance, mode: GameMode = .elimination,
                      players: [ChildSlot: (Stance, Stance)]) -> (GameState, RoundResult)? {
        var state = GameState()
        let config = GameConfig(slots: Array(players.keys).sorted(), seed: 1, mode: mode, scoreRounds: 3, doubles: true)
        GameReducer.reduce(&state, .start(config))
        GameReducer.reduce(&state, .countdownFinished)
        // Troca o comando sorteado por um duplo conhecido.
        let command = doubleCommand(first: first, second: second)
        state.phase = .announcing(command)
        GameReducer.reduce(&state, .commandAudioStarted(at: 10))
        guard case let .window(_, opens, _) = state.phase else { return nil }
        #expect(GameReducer.reduce(&state, .windowClosed).isEmpty)   // ainda sem a segunda palavra
        let followAt = 10.8
        let effects = GameReducer.reduce(&state, .followUpAudioStarted(at: followAt))
        guard case let .window(_, _, closes) = state.phase else { return nil }
        #expect(effects == [.scheduleWindowClose(at: closes)])
        #expect(abs(closes - (followAt + 0.3 + 2.0)) < 1e-9)
        var samples: [PostureSample] = []
        for (slot, postures) in players {
            var time = opens
            while time < closes {
                let posture = (time < followAt + 0.4 ? postures.0 : postures.1).posture
                samples.append(PostureSample(childSlot: slot, posture: posture, timestamp: time))
                time += 0.05
            }
            samples.append(PostureSample(childSlot: slot, posture: postures.1.posture, timestamp: closes - 0.02))
        }
        GameReducer.reduce(&state, .postureSamples(samples))
        GameReducer.reduce(&state, .windowClosed)
        guard case let .result(result) = state.phase else { return nil }
        return (state, result)
    }

    @Test func bothWordsRightKeepsEveryoneAndASecondStartIsOnlyAcceptedOnce() throws {
        let (state, result) = try #require(play(first: .up, second: .down, players: [0: (.up, .down), 1: (.up, .down)]))
        #expect(result.wrong.isEmpty && state.survivors == [0, 1])
    }

    @Test func missingTheFirstWordIsAnErrorEvenIfTheSecondIsRight() throws {
        let (_, result) = try #require(play(first: .up, second: .down, players: [0: (.down, .down), 1: (.up, .down)]))
        #expect(result.wrong == [0] && result.failedWords[0] == .up)
    }

    @Test func missingTheSecondWordIsAnError() throws {
        let (_, result) = try #require(play(first: .up, second: .down, players: [0: (.up, .up), 1: (.up, .down)]))
        #expect(result.wrong == [0] && result.failedWords[0] == .down)
    }

    @Test func scoreModeAddsTheCoinsOfBothWords() throws {
        let (state, result) = try #require(play(first: .up, second: .down, mode: .score,
                                                players: [0: (.up, .down), 1: (.down, .down)]))
        let first = try #require(result.scores[0])
        #expect(first.isDouble && first.coins >= 2 && first.tier != .miss)
        #expect(result.scores[1]?.tier == .miss)
        #expect(state.players[0]?.coins == first.coins)
    }
}
