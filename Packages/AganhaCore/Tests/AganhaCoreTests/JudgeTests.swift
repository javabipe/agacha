@testable import AganhaCore
import Testing

@Suite struct JudgeTests {
    private func sample(_ posture: Posture, at time: Double, slot: ChildSlot = 0) -> PostureSample {
        PostureSample(childSlot: slot, posture: posture, timestamp: time)
    }

    @Test func okWhenPostureMatchesWord() {
        #expect(Judge.verdict(expected: .up, samples: [sample(.standing, at: 1.0)], windowEnd: 1.05) == .ok)
        #expect(Judge.verdict(expected: .down, samples: [sample(.crouching, at: 1.0)], windowEnd: 1.05) == .ok)
    }

    @Test func wrongWhenPostureIsOpposite() {
        #expect(Judge.verdict(expected: .up, samples: [sample(.crouching, at: 1.0)], windowEnd: 1.0) == .wrong)
        #expect(Judge.verdict(expected: .down, samples: [sample(.standing, at: 1.0)], windowEnd: 1.0) == .wrong)
    }

    @Test func decisionIsTheStateAtTheEndOfTheWindow() {
        // Estava em pé, agachou a tempo: vale o último estado.
        let samples = [sample(.standing, at: 0.9), sample(.crouching, at: 1.0), sample(.crouching, at: 1.1)]
        #expect(Judge.verdict(expected: .down, samples: samples, windowEnd: 1.1) == .ok)
        // Agachou e levantou de novo antes do fim: errou.
        let flipped = [sample(.crouching, at: 0.9), sample(.standing, at: 1.1)]
        #expect(Judge.verdict(expected: .down, samples: flipped, windowEnd: 1.1) == .wrong)
    }

    @Test func samplesAfterWindowEndAreIgnored() {
        let samples = [sample(.standing, at: 1.0), sample(.crouching, at: 1.2)]
        #expect(Judge.verdict(expected: .up, samples: samples, windowEnd: 1.1) == .ok)
    }

    @Test func staysPutOnRepeat() {
        // "Fica": já está na postura e o comando repete a mesma palavra.
        let samples = [sample(.crouching, at: 0.5), sample(.crouching, at: 1.0)]
        #expect(Judge.verdict(expected: .down, samples: samples, windowEnd: 1.0) == .ok)
    }

    @Test func trickIsJudgedByTheWordNotTheGesture() {
        var director = Director(difficulty: .furacao, seed: 5)
        let trick = (0..<200).map { _ in director.next() }.first { $0.isTrick }
        guard let trick else { Issue.record("sem truque"); return }
        let followedGesture = [sample(trick.gesture.posture, at: 1.0)]
        let followedWord = [sample(trick.word.posture, at: 1.0)]
        #expect(Judge.verdict(expected: trick.word, samples: followedGesture, windowEnd: 1.0) == .wrong)
        #expect(Judge.verdict(expected: trick.word, samples: followedWord, windowEnd: 1.0) == .ok)
    }

    @Test func absentWhenNoSamplesUnknownOrStale() {
        #expect(Judge.verdict(expected: .up, samples: [], windowEnd: 1.0) == .absent)
        #expect(Judge.verdict(expected: .up, samples: [sample(.unknown, at: 1.0)], windowEnd: 1.0) == .absent)
        #expect(Judge.verdict(expected: .up, samples: [sample(.standing, at: 0.5)], windowEnd: 1.0) == .absent)
    }

    // MARK: - Meio movimento é erro

    private func measured(_ posture: Posture, index: Double, at time: Double = 1.0) -> PostureSample {
        PostureSample(childSlot: 0, posture: posture, timestamp: time, crouchIndex: index)
    }

    @Test func fullStandingAndFullCrouchAreOk() {
        #expect(Judge.verdict(expected: .up, samples: [measured(.standing, index: 0.05)], windowEnd: 1.0) == .ok)
        #expect(Judge.verdict(expected: .down, samples: [measured(.crouching, index: 0.8)], windowEnd: 1.0) == .ok)
    }

    @Test func halfSquatWhileToldToStandIsWrong() {
        // Ainda classificado "em pé" (histerese), mas o quadril já desceu: meio movimento.
        #expect(Judge.verdict(expected: .up, samples: [measured(.standing, index: 0.38)], windowEnd: 1.0) == .wrong)
    }

    @Test func halfRiseWhileToldToCrouchIsWrong() {
        #expect(Judge.verdict(expected: .down, samples: [measured(.crouching, index: 0.32)], windowEnd: 1.0) == .wrong)
    }

    @Test func halfwayOnTheWayUpIsWrongWhenWindowEnds() {
        // Estava agachado, levantou só até o meio quando a janela fechou.
        #expect(Judge.verdict(expected: .up, samples: [measured(.crouching, index: 0.35)], windowEnd: 1.0) == .wrong)
    }

    @Test func customRulesChangeTheThresholds() {
        let loose = JudgeRules(standMax: 0.5, crouchMin: 0.3)
        #expect(Judge.verdict(expected: .up, samples: [measured(.standing, index: 0.4)], windowEnd: 1.0, rules: loose) == .ok)
        #expect(Judge.verdict(expected: .down, samples: [measured(.crouching, index: 0.35)], windowEnd: 1.0, rules: loose) == .ok)
    }

    // MARK: - Detalhes para o replay

    @Test func assessmentReportsWhatWasMeasured() {
        let result = Judge.assess(expected: .up, samples: [measured(.standing, index: 0.36)], windowEnd: 1.0)
        #expect(result.verdict == .wrong)
        #expect(result.crouchIndex == 0.36)
        #expect(result.posture == .standing)
        #expect(Judge.assess(expected: .up, samples: [], windowEnd: 1.0).verdict == .absent)
    }

    @Test func traceListsTheLastMomentsOldestFirst() {
        let samples = (0...30).map { step in
            measured(.crouching, index: 0.8 - Double(step) * 0.025, at: 10 + Double(step) * 0.05)
        }
        let result = Judge.assess(expected: .up, samples: samples, windowEnd: 11.5)
        #expect(result.trace.count >= 4)
        #expect(result.trace.map(\.secondsBeforeEnd) == result.trace.map(\.secondsBeforeEnd).sorted(by: >))
        #expect(result.trace.last?.secondsBeforeEnd == 0)
        let indexes = result.trace.compactMap(\.crouchIndex)
        #expect(indexes == indexes.sorted(by: >))   // vai levantando
        #expect(Judge.assess(expected: .up, samples: [], windowEnd: 5).trace.isEmpty)
    }
}
