@testable import AganhaCore
import Testing

@Suite struct DirectorTests {
    private func commands(_ difficulty: Difficulty, seed: UInt64 = 1, count: Int = 200,
                          tolerance: Tolerance = .normal) -> [Command] {
        var director = Director(difficulty: difficulty, tolerance: tolerance, seed: seed)
        return (0..<count).map { _ in director.next() }
    }

    @Test func sameSeedGivesSameSequence() {
        for level in Difficulty.allCases {
            #expect(commands(level, seed: 42) == commands(level, seed: 42))
            #expect(commands(level, seed: 42) != commands(level, seed: 43))
        }
    }

    @Test func firstCommandIsAlwaysUpAndNumbersCount() {
        for level in Difficulty.allCases {
            let list = commands(level, count: 10)
            #expect(list[0].word == .up)
            #expect(list[0].isRepeat == false)
            #expect(list.map(\.number) == Array(1...10))
        }
    }

    @Test func wordAlternatesUnlessRepeating() {
        let list = commands(.sapeca, seed: 7)
        for (previous, current) in zip(list, list.dropFirst()) {
            #expect(current.isRepeat == (current.word == previous.word))
        }
    }

    @Test func tranquiloNeverTricksAndSpeedsUpGently() {
        let list = commands(.tranquilo, count: 500)
        #expect(list.allSatisfy { !$0.isTrick && !$0.chainsToNext })
        #expect(list[0].gapMs == 2200)
        #expect(list[1].gapMs == 2160)
        #expect(list.last?.gapMs == 1500)
        #expect(list.allSatisfy { $0.windowMs == 1800 })
    }

    @Test func sapecaTricksStartAtSecondAndNeverBackToBack() {
        for seed in 1...20 as ClosedRange<UInt64> {
            let list = commands(.sapeca, seed: seed, count: 100)
            #expect(!list[0].isTrick)
            for (a, b) in zip(list, list.dropFirst()) { #expect(!(a.isTrick && b.isTrick)) }
        }
        let tricks = commands(.sapeca, seed: 3, count: 4000).filter(\.isTrick).count
        #expect((800...1400).contains(tricks))   // ~35%, menos os bloqueados por "nunca dois seguidos"
    }

    @Test func sapecaGapShrinksSeventyPerRoundDownToFloor() {
        let list = commands(.sapeca, count: 30)
        #expect(list[0].gapMs == 1500)
        #expect(list[1].gapMs == 1430)
        #expect(list[2].gapMs == 1360)
        #expect(list.last?.gapMs == 700)
        #expect(list.allSatisfy { $0.gapMs >= 700 })
    }

    @Test func furacaoTricksFromFirstRoundCanChainAndHasFloor() {
        let list = commands(.furacao, seed: 5, count: 4000)
        let tricks = list.filter(\.isTrick).count
        #expect((1700...2300).contains(tricks))   // ~50%
        #expect(list.contains { $0.chainsToNext && $0.gapMs == Director.chainedGapMs })
        #expect(zip(list, list.dropFirst()).contains { $0.isTrick && $1.isTrick })
        #expect(list.filter { !$0.chainsToNext }.allSatisfy { $0.gapMs >= 400 })
        #expect(list.last { !$0.chainsToNext }?.gapMs == 400)
        for (a, b) in zip(list, list.dropFirst()) { #expect(!(a.chainsToNext && b.chainsToNext)) }
    }

    @Test func repeatFrequencyMatchesLevel() {
        func rate(_ level: Difficulty) -> Double {
            let list = commands(level, seed: 11, count: 4000)
            return Double(list.filter(\.isRepeat).count) / Double(list.count)
        }
        #expect(abs(rate(.tranquilo) - 0.22) < 0.03)
        #expect(abs(rate(.sapeca) - 0.25) < 0.03)
        #expect(abs(rate(.furacao) - 0.30) < 0.03)
    }

    @Test func windowShrinksOnHarderLevelsDownToAFloor() {
        let sapeca = commands(.sapeca, count: 30)
        #expect(sapeca[0].windowMs == 1800)
        #expect(sapeca[10].windowMs == 1440)      // 0,8 do normal
        #expect(sapeca.last?.windowMs == 1440)
        let furacao = commands(.furacao, count: 30)
        #expect(furacao[0].windowMs == 1800)
        #expect(furacao.last?.windowMs == 1260)   // 0,7 do normal
    }

    @Test func trickMeansGestureIsOppositeOfWord() {
        for command in commands(.furacao) {
            #expect(command.isTrick == (command.gesture == command.word.opposite))
        }
    }

    @Test func windowFollowsTolerance() {
        #expect(commands(.tranquilo, count: 3, tolerance: .pequenos).allSatisfy { $0.windowMs == 2400 })
        #expect(commands(.tranquilo, count: 3, tolerance: .normal).allSatisfy { $0.windowMs == 1800 })
        #expect(commands(.tranquilo, count: 3, tolerance: .rigido).allSatisfy { $0.windowMs == 1200 })
    }
}
