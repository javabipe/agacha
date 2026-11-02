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

    @Test func tranquiloNeverTricksButKeepsSpeedingUp() {
        let list = commands(.tranquilo, count: 500)
        #expect(list.allSatisfy { !$0.isTrick && !$0.chainsToNext })
        #expect(list[0].gapMs == 2200)
        #expect(list[1].gapMs == 2140)
        #expect(list.last?.gapMs == 1200)
        #expect(list[0].windowMs == 1800)
        #expect(list.last?.windowMs == 1350)   // 0,75 do normal
    }

    @Test func sapecaTricksStartAtSecondAndNeverBackToBack() {
        for seed in 1...20 as ClosedRange<UInt64> {
            let list = commands(.sapeca, seed: seed, count: 100)
            #expect(!list[0].isTrick)
            for (a, b) in zip(list, list.dropFirst()) { #expect(!(a.isTrick && b.isTrick)) }
        }
        let tricks = commands(.sapeca, seed: 3, count: 4000).filter(\.isTrick).count
        #expect((1250...1600).contains(tricks))   // sobe de 25% até 55%, menos os bloqueados por "nunca dois seguidos"
    }

    @Test func sapecaGapShrinksEightyPerRoundDownToFloor() {
        let list = commands(.sapeca, count: 40)
        #expect(list[0].gapMs == 1500)
        #expect(list[1].gapMs == 1420)
        #expect(list[2].gapMs == 1340)
        let regular = list.filter { !$0.chainsToNext }
        #expect(regular.last?.gapMs == 500)
        #expect(regular.allSatisfy { $0.gapMs >= 500 })
    }

    @Test func difficultyKeepsRisingTheLongerTheGameLasts() {
        func rate(_ level: Difficulty, _ range: Range<Int>, _ keyPath: KeyPath<Command, Bool>) -> Double {
            var hits = 0.0, total = 0.0
            for seed in 1...200 as ClosedRange<UInt64> {
                let list = commands(level, seed: seed, count: 60)
                for command in list[range] {
                    total += 1
                    if command[keyPath: keyPath] { hits += 1 }
                }
            }
            return hits / total
        }
        // Mais truques no fim do que no começo, e emendados só aparecem depois do 8º comando no Sapeca.
        #expect(rate(.sapeca, 40..<60, \.isTrick) > rate(.sapeca, 1..<10, \.isTrick) + 0.1)
        #expect(rate(.furacao, 40..<60, \.isTrick) > rate(.furacao, 0..<10, \.isTrick) + 0.1)
        #expect(commands(.sapeca, seed: 4, count: 7).allSatisfy { !$0.chainsToNext })
        #expect(rate(.sapeca, 30..<60, \.chainsToNext) > 0.15)
    }

    @Test func furacaoTricksFromFirstRoundCanChainAndHasFloor() {
        let list = commands(.furacao, seed: 5, count: 4000)
        let tricks = list.filter(\.isTrick).count
        #expect((2700...3200).contains(tricks))   // sobe de 50% até 75%
        #expect(list.contains { $0.chainsToNext && $0.gapMs == Director.chainedGapMs })
        #expect(zip(list, list.dropFirst()).contains { $0.isTrick && $1.isTrick })
        #expect(list.filter { !$0.chainsToNext }.allSatisfy { $0.gapMs >= 250 })
        #expect(list.last { !$0.chainsToNext }?.gapMs == 250)
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

    @Test func windowShrinksOnEveryLevelDownToAFloor() {
        #expect(commands(.sapeca, count: 30)[0].windowMs == 1800)
        #expect(commands(.sapeca, count: 30).last?.windowMs == 1170)    // 0,65 do normal
        #expect(commands(.furacao, count: 30)[0].windowMs == 1800)
        #expect(commands(.furacao, count: 30).last?.windowMs == 990)    // 0,55 do normal
    }

    @Test func cuesAnnounceHigherPaceEveryFiveCommands() {
        let sapeca = commands(.sapeca, count: 30)
        let cues = sapeca.compactMap { command in command.cue.map { (command.number, $0) } }
        #expect(cues.map(\.0) == [5, 10, 15, 20, 25, 30])
        #expect(cues.map(\.1) == [.faster, .harder, .faster, .harder, .faster, .harder])
        // Tranquilo não tem truques, então só avisa que ficou mais rápido.
        #expect(commands(.tranquilo, count: 30).compactMap(\.cue).allSatisfy { $0 == .faster })
        #expect(sapeca.filter { $0.cue == nil }.count == 24)
    }

    @Test func trickMeansGestureIsOppositeOfWord() {
        for command in commands(.furacao) {
            #expect(command.isTrick == (command.gesture == command.word.opposite))
        }
    }

    @Test func windowFollowsTolerance() {
        #expect(commands(.tranquilo, count: 1, tolerance: .pequenos).allSatisfy { $0.windowMs == 2400 })
        #expect(commands(.tranquilo, count: 1, tolerance: .normal).allSatisfy { $0.windowMs == 1800 })
        #expect(commands(.tranquilo, count: 1, tolerance: .rigido).allSatisfy { $0.windowMs == 1200 })
    }
}
