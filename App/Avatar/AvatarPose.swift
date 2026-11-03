import SwiftUI

/// Humor do avatar: o rosto e a boca mudam (alegre, normal, chorando).
enum AvatarMood {
    case normal, win, sad
}

/// Quem apresenta o jogo (a tia ou o tio), no mesmo estilo dos avatares dos jogadores.
enum HostStyle: String, Codable, CaseIterable {
    case tia, tio

    var shirtHex: String { self == .tia ? "#8E7BFF" : "#4D9DE0" }
    var title: String { self == .tia ? String(localized: "Tia") : String(localized: "Tio") }
}

/// Um boneco para desenhar: as juntas ficam em coordenadas de 0 a 1 dentro da caixa de desenho
/// (os mesmos nomes que a TV recebe: `n`, `ls`, `rs`, `le`, `re`, `lw`, `rw`, `lh`, `rh`, `lk`, `rk`, `la`, `ra`, olhos e orelhas).
struct AvatarFigure {
    var joints: [String: CGPoint]
    var colorHex: String
    var name: String?
    var mood: AvatarMood = .normal
    var crown = false
    var host: HostStyle?
    /// Largura dos ombros e raio da cabeça, em fração da altura da caixa (sem isso saem dos próprios ombros).
    var shoulderWidth: CGFloat?
    var headRadius: CGFloat?
    /// Chão (fração da altura) para a sombra ficar parada enquanto o boneco pula.
    var floor: CGFloat?
    /// Intensidade do soluço de 0 a 1.
    var sob = 0.0
}

/// Esqueleto-modelo em "unidades de altura" (como na TV): pés no chão (y = 0), cabeça em -0,68.
struct AvatarPoseSpec {
    var headX = 0.0
    var headY = -0.68
    var tilt = 0.0
    var shoulderY = -0.58
    var shoulderW = 0.071
    var shoulderX = 0.0
    var hipX = 0.0
    var hipY = -0.32
    var kneeW = 0.036
    var kneeY = -0.16
    var footW = 0.036
    var footY = 0.0
    /// Ângulo do braço de cima e do antebraço (0 = para baixo, π/2 = para o lado, π = para cima), por lado.
    var armLeft: (upper: Double, fore: Double) = (0.2, 0.05)
    var armRight: (upper: Double, fore: Double) = (0.2, 0.05)
    var sob = 0.0
}

enum AvatarPoses {
    private static let danceMoves: [(left: (Double, Double), right: (Double, Double))] = [
        ((2.6, 2.9), (2.6, 2.9)),   // braços em V
        ((2.9, 3.1), (0.9, 0.7)),   // dedo para o alto (disco)
        ((1.2, 2.9), (1.2, 2.9)),   // punhos fechados
        ((0.9, 0.7), (2.9, 3.1))
    ]

    private static func smooth(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    private static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    /// Dancinha da vitória: 4 tempos de 0,55 s (V, disco, punhos, disco), com pulinho e agachada antes de cada pulo.
    static func dance(_ t: Double) -> AvatarPoseSpec {
        let beat = t / 0.55
        let index = Int(floor(beat))
        let phase = beat - floor(beat)
        let ease = smooth(phase)
        let from = danceMoves[((index % 4) + 4) % 4], to = danceMoves[(((index + 1) % 4) + 4) % 4]
        let hop = max(0, sin(.pi * phase)), squat = (1 - hop) * 0.014, lift = hop * 0.04
        let sway = sin(beat * .pi) * 0.022, y = squat - lift
        var spec = AvatarPoseSpec()
        spec.headX = sway * 0.25
        spec.headY = -0.68 + y
        spec.tilt = sway * 0.5
        spec.shoulderY = -0.58 + y
        spec.shoulderX = -sway * 0.3
        spec.hipX = sway * 0.5
        spec.hipY = -0.32 + squat * 0.5 - lift
        spec.kneeW = 0.036 + (1 - hop) * 0.02
        spec.kneeY = -0.16 - lift * 0.5 + squat * 0.5
        spec.footW = 0.036 + (1 - hop) * 0.012
        spec.footY = -lift * 0.9
        spec.armLeft = (mix(from.left.0, to.left.0, ease), mix(from.left.1, to.left.1, ease))
        spec.armRight = (mix(from.right.0, to.right.0, ease), mix(from.right.1, to.right.1, ease))
        return spec
    }

    /// Triste: ombros caídos, cabeça baixa, soluço e a mão enxugando os olhos, uma de cada vez.
    static func sad(_ t: Double) -> AvatarPoseSpec {
        let sobWave = max(0, sin(2 * .pi * t / 1.3)), sob = sobWave * sobWave
        let shake = sin(2 * .pi * 9 * t) * 0.004 * sob, sway = sin(2 * .pi * t / 2.6)
        func wipe(_ offset: Double) -> Double {
            let p = ((t + offset).truncatingRemainder(dividingBy: 2.6) + 2.6).truncatingRemainder(dividingBy: 2.6) / 1.1
            return p < 1 ? sin(.pi * p) : 0
        }
        let left = wipe(0), right = wipe(1.3)
        var spec = AvatarPoseSpec()
        spec.sob = sob
        spec.headX = sway * 0.006
        spec.headY = -0.68 + 0.03 + 0.05 + sob * 0.008
        spec.tilt = sway * 0.012
        spec.shoulderY = -0.58 + 0.03 + shake
        spec.shoulderW = 0.06
        spec.hipY = -0.31
        spec.kneeW = 0.028
        spec.kneeY = -0.155
        spec.footW = 0.045
        spec.armLeft = (mix(0.12, 0.5, left), mix(0.05, -2.55, left) + sin(t * 18) * 0.1 * left)
        spec.armRight = (mix(0.12, 0.5, right), mix(0.05, -2.55, right) + sin(t * 18) * 0.1 * right)
        return spec
    }

    /// Mascote respirando de leve (tela inicial, cartões).
    static func idle(_ t: Double) -> AvatarPoseSpec {
        var spec = AvatarPoseSpec()
        let breathe = sin(t * 2.2) * 0.004
        spec.headY += breathe
        spec.shoulderY += breathe
        spec.tilt = sin(t * 1.1) * 0.008
        return spec
    }

    /// Esqueleto de uma pose, com os pés em (`centerX`, `floor`) e tamanho `scale` (1 = altura-padrão de 0,68 da caixa).
    static func joints(_ spec: AvatarPoseSpec, centerX: Double, floor: Double, scale: Double, aspect: Double) -> [String: CGPoint] {
        var out: [String: CGPoint] = [:]
        func put(_ name: String, _ dx: Double, _ dy: Double) {
            out[name] = CGPoint(x: centerX + dx * scale / aspect, y: floor + dy * scale)
        }
        func arm(_ side: Double, _ prefix: String, shoulder: (Double, Double), angles: (upper: Double, fore: Double)) {
            let ex = shoulder.0 + side * sin(angles.upper) * 0.11, ey = shoulder.1 + cos(angles.upper) * 0.11
            put(prefix + "e", ex, ey)
            put(prefix + "w", ex + side * sin(angles.fore) * 0.11, ey + cos(angles.fore) * 0.11)
        }
        put("n", spec.headX, spec.headY)
        put("ley", spec.headX - 0.027, spec.headY - 0.015 - spec.tilt)
        put("rey", spec.headX + 0.027, spec.headY - 0.015 + spec.tilt)
        put("lea", spec.headX - 0.057, spec.headY - 0.008 - spec.tilt)
        put("rea", spec.headX + 0.057, spec.headY - 0.008 + spec.tilt)
        put("ls", spec.shoulderX - spec.shoulderW, spec.shoulderY)
        put("rs", spec.shoulderX + spec.shoulderW, spec.shoulderY)
        arm(-1, "l", shoulder: (spec.shoulderX - spec.shoulderW, spec.shoulderY), angles: spec.armLeft)
        arm(1, "r", shoulder: (spec.shoulderX + spec.shoulderW, spec.shoulderY), angles: spec.armRight)
        put("lh", spec.hipX - 0.036, spec.hipY)
        put("rh", spec.hipX + 0.036, spec.hipY)
        put("lk", spec.hipX - spec.kneeW, spec.kneeY)
        put("rk", spec.hipX + spec.kneeW, spec.kneeY)
        put("la", -spec.footW, spec.footY)
        put("ra", spec.footW, spec.footY)
        return out
    }

    /// Busto do apresentador numa caixa quadrada: cabeça, ombros e braços (levantados = V, senão para baixo).
    static func hostJoints(raise: Double, bounce: Double = 0) -> [String: CGPoint] {
        func lerp(_ a: Double, _ b: Double) -> Double { mix(a, b, raise) }
        let sy = 0.72 - bounce, upper = lerp(0.3, 2.45), fore = lerp(0.12, 2.9)
        var out: [String: CGPoint] = [
            "n": CGPoint(x: 0.5, y: 0.42 - bounce), "ley": CGPoint(x: 0.44, y: 0.395 - bounce), "rey": CGPoint(x: 0.56, y: 0.395 - bounce),
            "lea": CGPoint(x: 0.385, y: 0.405 - bounce), "rea": CGPoint(x: 0.615, y: 0.405 - bounce),
            "ls": CGPoint(x: 0.30, y: sy), "rs": CGPoint(x: 0.70, y: sy)
        ]
        for (side, prefix, sx) in [(-1.0, "l", 0.30), (1.0, "r", 0.70)] {
            let ex = sx + side * sin(upper) * 0.23, ey = sy + cos(upper) * 0.23
            out[prefix + "e"] = CGPoint(x: ex, y: ey)
            out[prefix + "w"] = CGPoint(x: ex + side * sin(fore) * 0.2, y: ey + cos(fore) * 0.2)
        }
        return out
    }
}
