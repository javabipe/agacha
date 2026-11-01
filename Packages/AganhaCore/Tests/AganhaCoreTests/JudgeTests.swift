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
}
