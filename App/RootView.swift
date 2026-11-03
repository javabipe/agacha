import AganhaCore
import SwiftUI

struct RootView: View {
    private enum Route { case menu, game, diagnostic }

    @State private var loop = GameLoop()
    @State private var route = Route.menu
    @State private var sharedMoment: Moment?

    var body: some View {
        content
            .onChange(of: loop.wantsMenu) { _, wants in
                if wants { leave() }
            }
    }

    @ViewBuilder private var content: some View {
        switch route {
        case .menu:
            HomeView(loop: loop, onPlay: { solo in
                loop.settings.solo = solo
                route = .game
                loop.startPositioning()
            }, onDiagnostic: { route = .diagnostic })
        case .game:
            gameFlow
        case .diagnostic:
            SpikeView()
                .overlay(alignment: .topTrailing) {
                    Button("Fechar", systemImage: "xmark.circle.fill") { route = .menu }
                        .labelStyle(.iconOnly)
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding()
                }
        }
    }

    @ViewBuilder private var gameFlow: some View {
        switch (loop.stage, loop.state.phase) {
        case (.playing, .gameOver(let result)):
            GameOverView(result: result, name: loop.name(for:), isListening: loop.isListening, heard: loop.heardText,
                         solo: loop.state.config?.solo == true ? loop.soloSummary : nil,
                         scoreLines: loop.isScoreMode ? loop.scoreLines(for: result) : nil,
                         onShare: { sharedMoment = momentForShare(result) },
                         onPlayAgain: { loop.startPositioning(keepSlots: true) }, onMenu: leave)
                .sheet(item: $sharedMoment) { moment in ShareClipView(moment: moment, onClose: { sharedMoment = nil }) }
        case (.playing, _):
            PlayView(loop: loop, onQuit: leave)
        default:
            PositioningView(loop: loop, onBack: leave)
        }
    }

    /// O resultado desta partida como um "momento" (por enquanto sem vídeo de verdade: prévia só com os avatares).
    private func momentForShare(_ result: GameResult) -> Moment {
        let config = loop.state.config
        let scoring = config?.mode == .score
        let players = result.ranking.compactMap { slot -> Moment.Player? in
            guard let player = loop.state.players[slot] else { return nil }
            let wins = result.winners.contains(slot) && (scoring ? player.coins > 0 : true)
            return Moment.Player(name: loop.name(for: slot), colorHex: SlotColors.hex(slot),
                                 coins: scoring ? player.coins : player.correct, isWinner: wins)
        }
        let fastest = loop.state.players.values.compactMap(\.bestReactionMs).min()
        var moment = Moment(title: config?.solo == true ? String(localized: "Treino solo") : String(localized: "Partida de hoje"),
                            place: String(localized: "Em casa"), ago: String(localized: "agora"), durationSeconds: 24, views: 0, likes: 0,
                            mode: config?.mode ?? .score, rounds: loop.state.history.count, fastestMs: fastest, players: players)
        moment.isSample = true
        return moment
    }

    private func leave() {
        loop.leave()
        route = .menu
    }
}
