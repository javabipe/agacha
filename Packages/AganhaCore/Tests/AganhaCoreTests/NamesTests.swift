@testable import AganhaCore
import Testing

@Suite struct NamesTests {
    @Test func plainNameIsCapitalized() {
        #expect(NameParser.clean("paulo") == "Paulo")
        #expect(NameParser.clean("ARTHUR") == "Arthur")
    }

    @Test func leadInsAreRemoved() {
        #expect(NameParser.clean("meu nome é Paulo") == "Paulo")
        #expect(NameParser.clean("Eu me chamo Arthur") == "Arthur")
        #expect(NameParser.clean("eu sou a Maria") == "Maria")
        #expect(NameParser.clean("oi meu nome é João") == "João")
    }

    @Test func keepsAtMostTwoWordsAndStripsPunctuation() {
        #expect(NameParser.clean("maria clara da silva") == "Maria Clara")
        #expect(NameParser.clean("Paulo!") == "Paulo")
        #expect(NameParser.clean("ana-julia") == "Ana-julia")
    }

    @Test func emptyOrNoiseGivesNil() {
        #expect(NameParser.clean("") == nil)
        #expect(NameParser.clean("   ") == nil)
        #expect(NameParser.clean("!!!") == nil)
        #expect(NameParser.clean("meu nome é") == nil)
    }

    @Test func recentNamesMovesToFrontWithoutDuplicatesAndCaps() {
        #expect(RecentNames.adding("Paulo", to: []) == ["Paulo"])
        #expect(RecentNames.adding("Arthur", to: ["Paulo"]) == ["Arthur", "Paulo"])
        #expect(RecentNames.adding("paulo", to: ["Arthur", "Paulo"]) == ["paulo", "Arthur"])
        let many = (1...20).map { "N\($0)" }
        #expect(RecentNames.adding("Novo", to: many, limit: 12).count == 12)
    }
}

@Suite struct VoiceIntentTests {
    @Test func againPhrases() {
        for phrase in ["de novo!", "De novo", "vamos jogar", "outra vez", "sim", "mais uma", "bora", "continuar"] {
            #expect(VoiceIntent.parse(phrase) == .playAgain, "\(phrase)")
        }
    }

    @Test func menuPhrasesWinOverAgain() {
        for phrase in ["menu", "sair", "chega", "não", "não quero jogar de novo", "acabou", "para"] {
            #expect(VoiceIntent.parse(phrase) == .menu, "\(phrase)")
        }
    }

    @Test func unrelatedOrEmptyIsNil() {
        for phrase in ["", "o gato subiu no telhado", "assim"] {
            #expect(VoiceIntent.parse(phrase) == nil, "\(phrase)")
        }
    }
}
