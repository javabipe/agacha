import SwiftUI

struct RootView: View {
    private enum Route { case menu, game, diagnostic }

    @State private var loop = GameLoop()
    @State private var route = Route.menu

    var body: some View {
        switch route {
        case .menu:
            MenuView(loop: loop, onPlay: {
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
            GameOverView(result: result, name: loop.name(for:), onPlayAgain: { loop.startPositioning(keepSlots: true) }, onMenu: leave)
        case (.playing, _):
            PlayView(loop: loop, onQuit: leave)
        default:
            PositioningView(loop: loop, onBack: leave)
        }
    }

    private func leave() {
        loop.leave()
        route = .menu
    }
}
