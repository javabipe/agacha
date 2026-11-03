import AganhaCore
import SwiftUI

/// Vários avatares numa caixa, com tempo para as animações (respirar, dançar, chorar).
struct AvatarStage: View {
    /// Monta os bonecos para o instante `time` (s) numa caixa com a proporção `aspect` (largura/altura).
    let figures: (_ time: Double, _ aspect: Double) -> [AvatarFigure]
    var animated = true
    /// Congela num instante (para gerar uma imagem do momento).
    var frozenAt: Double?

    var body: some View {
        Group {
            if let frozenAt {
                canvas(time: frozenAt)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: !animated)) { timeline in
                    canvas(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func canvas(time: Double) -> some View {
        Canvas { ctx, size in
            let box = CGRect(origin: .zero, size: size)
            for figure in figures(time, Double(size.width / max(1, size.height))) {
                AvatarRenderer(figure: figure, box: box, time: time).draw(in: &ctx)
            }
        }
    }
}

extension AvatarFigure {
    /// Jogador de pé no meio de `x` (0...1), na pose e no humor dados.
    static func player(name: String?, colorHex: String, x: Double, spec: AvatarPoseSpec, mood: AvatarMood = .normal,
                       crown: Bool = false, look: AvatarLook = .boy, aspect: Double, scale: Double = 1.1,
                       floor: Double = 0.94) -> AvatarFigure {
        let joints = AvatarPoses.joints(spec, centerX: x, floor: floor, scale: scale, aspect: aspect)
        return AvatarFigure(joints: joints, colorHex: colorHex, name: name, mood: mood, crown: crown, look: look, floor: floor,
                            sob: spec.sob)
    }
}

/// Tia ou tio da tela dos jogadores: mesmo desenho dos avatares, só o busto. Os braços sobem para "vivo" e descem para "morto".
struct HostView: View, Animatable {
    var host: HostStyle
    /// 0 = braços para baixo, 1 = braços para cima (animável, para o movimento ser suave).
    var raise: Double

    init(gesture: Stance?, host: HostStyle) {
        self.host = host
        raise = gesture == .up ? 1 : 0
    }

    nonisolated var animatableData: Double {
        get { raise }
        set { raise = newValue }
    }

    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            let box = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
            var figure = AvatarFigure(joints: AvatarPoses.hostJoints(raise: raise), colorHex: host.shirtHex, host: host)
            figure.shoulderWidth = 0.40
            figure.headRadius = 0.2
            AvatarRenderer(figure: figure, box: box, time: Date.timeIntervalSinceReferenceDate).draw(in: &ctx)
        }
        .accessibilityHidden(true)
    }
}
