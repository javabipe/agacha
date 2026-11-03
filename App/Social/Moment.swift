import AganhaCore
import Foundation

/// Um "momento" para compartilhar: o resultado de uma partida (hoje com dados de exemplo; depois, o clipe de verdade).
struct Moment: Identifiable, Sendable {
    struct Player: Identifiable, Sendable {
        var id: String { name }
        let name: String
        let colorHex: String
        let coins: Int
        let isWinner: Bool
    }

    let id: UUID
    let title: String
    let place: String
    let ago: String
    let durationSeconds: Int
    let views: Int
    let likes: Int
    let mode: GameMode
    let rounds: Int
    let fastestMs: Int?
    let players: [Player]
    /// Dados de exemplo (não é uma partida de verdade).
    var isSample = true
    /// Momento salvo: pôster de avatares e fotos reais ("shots") guardados no aparelho.
    var posterURL: URL?
    var shotURLs: [URL] = []

    init(id: UUID = UUID(), title: String, place: String, ago: String, durationSeconds: Int, views: Int, likes: Int,
         mode: GameMode, rounds: Int, fastestMs: Int?, players: [Player]) {
        self.id = id
        self.title = title
        self.place = place
        self.ago = ago
        self.durationSeconds = durationSeconds
        self.views = views
        self.likes = likes
        self.mode = mode
        self.rounds = rounds
        self.fastestMs = fastestMs
        self.players = players
    }

    var durationText: String { String(format: "%d:%02d", durationSeconds / 60, durationSeconds % 60) }
    var winners: [Player] { players.filter(\.isWinner) }
    var headline: String {
        switch winners.count {
        case 0: String(localized: "Vamos de novo?")
        case 1: String(localized: "\(winners[0].name) venceu!")
        default: String(localized: "Empate!")
        }
    }

    static func compact(_ number: Int) -> String {
        number >= 1000 ? (Double(number) / 1000).formatted(.number.precision(.fractionLength(1))) + " mil" : "\(number)"
    }
}

extension Moment {
    /// Exemplos para a tela "Momentos" e para ver como o compartilhar vai ficar.
    static let samples: [Moment] = [
        Moment(title: "Família Silva", place: "Sala da vovó", ago: "há 2 h", durationSeconds: 24, views: 12_400, likes: 3_100,
               mode: .score, rounds: 10, fastestMs: 480, players: [
                Player(name: "Davi", colorHex: "#FFC845", coins: 62, isWinner: true),
                Player(name: "Mãe", colorHex: "#36C9A6", coins: 48, isWinner: false),
                Player(name: "Pai", colorHex: "#FF7AB8", coins: 31, isWinner: false)]),
        Moment(title: "Aniversário da Bia", place: "Festa", ago: "ontem", durationSeconds: 31, views: 48_900, likes: 9_800,
               mode: .score, rounds: 15, fastestMs: 410, players: [
                Player(name: "Bia", colorHex: "#FF7AB8", coins: 90, isWinner: true),
                Player(name: "Léo", colorHex: "#4D9DE0", coins: 74, isWinner: false),
                Player(name: "Malu", colorHex: "#8E7BFF", coins: 70, isWinner: false),
                Player(name: "Tito", colorHex: "#FF9F1C", coins: 52, isWinner: false)]),
        Moment(title: "Treino do Arthur", place: "Quarto", ago: "há 3 dias", durationSeconds: 18, views: 860, likes: 240,
               mode: .score, rounds: 10, fastestMs: 530, players: [
                Player(name: "Arthur", colorHex: "#36C9A6", coins: 41, isWinner: true)]),
        Moment(title: "Primos na chácara", place: "Quintal", ago: "semana passada", durationSeconds: 27, views: 5_300, likes: 1_450,
               mode: .elimination, rounds: 12, fastestMs: nil, players: [
                Player(name: "Gui", colorHex: "#FFC845", coins: 0, isWinner: true),
                Player(name: "Ana", colorHex: "#FF9F1C", coins: 0, isWinner: false),
                Player(name: "Teo", colorHex: "#4D9DE0", coins: 0, isWinner: false)])
    ]
}
