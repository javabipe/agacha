import SwiftUI

/// Desenha um avatar com o mesmo visual da TV: contorno escuro, camisa com degradê, calça, tênis, mãos com dedos e
/// cabeça que inclina e vira. Usado na tela inicial, no apresentador e nos cartões de compartilhar.
struct AvatarRenderer {
    let figure: AvatarFigure
    let box: CGRect
    let time: Double

    private var palette: AvatarPalette { AvatarPalette(hex: figure.colorHex) }

    /// Medidas do boneco: `unit` = largura dos ombros; `edge` = espessura do contorno.
    struct Metrics {
        let unit: CGFloat
        let edge: CGFloat
    }

    private struct Arm {
        let wrist: CGPoint?
        let elbow: CGPoint?
        let shoulder: CGPoint?
    }

    private struct Leg {
        let ankle: CGPoint?
        let knee: CGPoint?
        let hip: CGPoint?
        let other: CGPoint?
    }

    /// Como desenhar um membro: cor, contorno e se leva um brilho fino por cima.
    struct LimbStyle {
        let width: CGFloat
        let color: Color
        let edge: Color
        let edgeWidth: CGFloat
        var glow = false
    }

    func point(_ key: String) -> CGPoint? {
        figure.joints[key].map { CGPoint(x: box.minX + $0.x * box.width, y: box.minY + $0.y * box.height) }
    }

    private func mid(_ a: CGPoint?, _ b: CGPoint?) -> CGPoint? {
        guard let a, let b else { return a ?? b }
        return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    func draw(in ctx: inout GraphicsContext) {
        let nose = point("n")
        var leftShoulder = point("ls"), rightShoulder = point("rs")
        let leftHip = point("lh"), rightHip = point("rh")
        var unit: CGFloat
        if let figureWidth = figure.shoulderWidth {
            unit = figureWidth * box.height
        } else if let ls = leftShoulder, let rs = rightShoulder {
            unit = min(max(abs(ls.x - rs.x), box.height * 0.045), box.height * 0.22)
        } else if let lh = leftHip, let rh = rightHip {
            unit = min(max(abs(lh.x - rh.x) * 1.2, box.height * 0.045), box.height * 0.22)
        } else {
            unit = box.height * 0.08
        }
        if leftShoulder == nil || rightShoulder == nil, let nose {
            leftShoulder = CGPoint(x: nose.x - unit * 0.5, y: nose.y + unit * 0.9)
            rightShoulder = CGPoint(x: nose.x + unit * 0.5, y: nose.y + unit * 0.9)
        }
        let metrics = Metrics(unit: unit, edge: max(1.5, unit * 0.09))
        drawShadow(in: &ctx, unit: unit)
        drawLegs(in: &ctx, metrics)
        let hips = drawTorso(in: &ctx, shoulders: (leftShoulder, rightShoulder), hips: (leftHip, rightHip), nose: nose, metrics)
        drawArms(in: &ctx, shoulders: (leftShoulder, rightShoulder), body: mid(mid(leftShoulder, rightShoulder), hips), metrics)
        if nose != nil {
            AvatarHead(figure: figure, renderer: self, time: time).draw(in: &ctx, unit: unit, edge: metrics.edge, box: box)
        }
    }

    // MARK: - Partes

    private func drawShadow(in ctx: inout GraphicsContext, unit: CGFloat) {
        var feet = mid(point("la"), point("ra"))
        if let floor = figure.floor {
            feet = CGPoint(x: feet?.x ?? point("n")?.x ?? box.midX, y: box.minY + floor * box.height)
        }
        guard let feet else { return }
        let rect = CGRect(x: feet.x - unit * 1.1, y: feet.y + unit * 0.2 - unit * 0.22, width: unit * 2.2, height: unit * 0.44)
        ctx.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.22)))
    }

    private func drawLegs(in ctx: inout GraphicsContext, _ m: Metrics) {
        let hipMid = mid(point("lh"), point("rh"))
        let legs = [Leg(ankle: point("la"), knee: point("lk"), hip: point("lh"), other: point("ra")),
                    Leg(ankle: point("ra"), knee: point("rk"), hip: point("rh"), other: point("la"))]
        let style = LimbStyle(width: m.unit * 0.52, color: palette.pants, edge: palette.pantsEdge, edgeWidth: m.edge, glow: true)
        for leg in legs { chain([leg.hip, leg.knee, leg.ankle], style, in: &ctx) }
        for (index, leg) in legs.enumerated() {
            guard let ankle = leg.ankle else { continue }
            let side: CGFloat = hipMid.map { ankle.x < $0.x ? -1 : 1 } ?? (index == 0 ? -1 : 1)
            drawShoe(in: &ctx, leg, side: side, m)
        }
    }

    /// Tênis de lado, com a ponta para fora, deduzido do tornozelo: a canela inclina o tênis, o calcanhar sobe ao agachar
    /// e o pé mais alto aparece levantado (ponta para baixo). Solado branco, biqueira/calcanhar/listra na cor do jogador.
    private func drawShoe(in ctx: inout GraphicsContext, _ leg: Leg, side: CGFloat, _ m: Metrics) {
        guard let ankle = leg.ankle else { return }
        let unit = m.unit
        var tilt = 0.0
        var heel = 0.0
        if let knee = leg.knee {
            tilt = Double(atan2(ankle.y - knee.y, ankle.x - knee.x)) - .pi / 2
            if let hip = leg.hip {
                let shin = max(unit * 0.2, ankle.y - knee.y)
                heel = min(max(1 - Double((knee.y - hip.y) / shin), 0), 1)
            }
        }
        let lift = leg.other.map { min(max(Double(($0.y - ankle.y) / unit), 0), 1.2) } ?? 0
        var c = ctx
        c.translateBy(x: ankle.x, y: ankle.y + unit * (0.1 - heel * 0.1))
        c.rotate(by: .radians(tilt * 0.6 + Double(side) * (lift * 0.6 + heel * 0.35)))
        c.scaleBy(x: side * unit, y: unit)
        let line = m.edge / unit
        var body = Path()
        body.move(to: CGPoint(x: -0.30, y: 0.22))
        body.addLine(to: CGPoint(x: 0.52, y: 0.22))
        body.addQuadCurve(to: CGPoint(x: 0.60, y: 0.10), control: CGPoint(x: 0.63, y: 0.22))
        body.addQuadCurve(to: CGPoint(x: 0.46, y: -0.03), control: CGPoint(x: 0.58, y: -0.01))
        body.addQuadCurve(to: CGPoint(x: 0.14, y: -0.14), control: CGPoint(x: 0.28, y: -0.05))
        body.addLine(to: CGPoint(x: 0.10, y: -0.27))
        body.addLine(to: CGPoint(x: -0.20, y: -0.27))
        body.addQuadCurve(to: CGPoint(x: -0.32, y: 0.02), control: CGPoint(x: -0.35, y: -0.22))
        body.closeSubpath()
        c.fill(body, with: .color(Color(hex: "#F6F6FA")))
        var painted = c
        painted.clip(to: body)
        painted.fill(Path(CGRect(x: 0.38, y: -0.1, width: 0.3, height: 0.4)), with: .color(palette.base))
        painted.fill(Path(CGRect(x: -0.4, y: -0.3, width: 0.14, height: 0.6)), with: .color(palette.base))
        var stripe = Path()
        stripe.move(to: CGPoint(x: -0.2, y: 0.06))
        stripe.addQuadCurve(to: CGPoint(x: 0.32, y: 0.08), control: CGPoint(x: 0.1, y: 0))
        painted.stroke(stripe, with: .color(palette.base), lineWidth: 0.05)
        painted.fill(Path(CGRect(x: -0.4, y: 0.12, width: 1.1, height: 0.12)), with: .color(.white))
        c.stroke(body, with: .color(AvatarPalette.ink), style: StrokeStyle(lineWidth: line, lineJoin: .round))
        var sole = Path()
        sole.move(to: CGPoint(x: -0.31, y: 0.12))
        sole.addLine(to: CGPoint(x: 0.58, y: 0.12))
        c.stroke(sole, with: .color(AvatarPalette.ink), lineWidth: line * 0.6)
        for index in 0..<3 {
            var lace = Path()
            lace.move(to: CGPoint(x: 0.1 + Double(index) * 0.11, y: -0.1 + Double(index) * 0.015))
            lace.addLine(to: CGPoint(x: 0.2 + Double(index) * 0.11, y: -0.16 + Double(index) * 0.045))
            c.stroke(lace, with: .color(Color(hex: "#8F8FA8")), style: StrokeStyle(lineWidth: line * 0.7, lineCap: .round))
        }
        var collar = Path()
        collar.move(to: CGPoint(x: -0.2, y: -0.27))
        collar.addQuadCurve(to: CGPoint(x: 0.1, y: -0.27), control: CGPoint(x: -0.05, y: -0.2))
        collar.addQuadCurve(to: CGPoint(x: -0.2, y: -0.27), control: CGPoint(x: -0.05, y: -0.33))
        c.fill(collar, with: .color(Color(hex: "#3A3050")))
    }

    /// Tronco com degradê e cantos arredondados, cinto, estrela no peito. Devolve o meio dos quadris (real ou deduzido).
    private func drawTorso(in ctx: inout GraphicsContext, shoulders: (CGPoint?, CGPoint?), hips: (CGPoint?, CGPoint?),
                           nose: CGPoint?, _ m: Metrics) -> CGPoint? {
        let (unit, edge) = (m.unit, m.edge)
        guard let ls = shoulders.0, let rs = shoulders.1 else { return nil }
        var hipLeft = hips.0, hipRight = hips.1
        if hipLeft == nil || hipRight == nil {
            // O apresentador é só busto: o tronco segue para fora do quadro.
            let length = figure.host == nil ? 1.7 : 3.2
            hipLeft = CGPoint(x: ls.x, y: ls.y + unit * length)
            hipRight = CGPoint(x: rs.x, y: rs.y + unit * length)
        }
        guard let hl = hipLeft, let hr = hipRight, let neckBase = mid(ls, rs) else { return nil }
        if let nose {
            chain([nose, neckBase], LimbStyle(width: unit * 0.42, color: AvatarPalette.skin, edge: AvatarPalette.skinEdge, edgeWidth: edge),
                  in: &ctx)
        }
        var path = Path()
        path.addLines([ls, rs, hr, hl])
        path.closeSubpath()
        let top = min(ls.y, rs.y), bottom = max(hl.y, hr.y)
        let gradient = Gradient(stops: [.init(color: palette.tint(0.28), location: 0), .init(color: palette.base, location: 0.45),
                                        .init(color: palette.shade(0.82), location: 1)])
        let shading = GraphicsContext.Shading.linearGradient(gradient, startPoint: CGPoint(x: 0, y: top),
                                                             endPoint: CGPoint(x: 0, y: bottom))
        let round = unit * 0.38
        ctx.stroke(path, with: .color(palette.shirtEdge), style: StrokeStyle(lineWidth: round + edge * 2, lineJoin: .round))
        ctx.fill(path, with: .color(palette.shirtEdge))
        ctx.stroke(path, with: shading, style: StrokeStyle(lineWidth: round, lineJoin: .round))
        ctx.fill(path, with: shading)
        var belt = Path()
        belt.move(to: CGPoint(x: hl.x, y: hl.y - unit * 0.06))
        belt.addLine(to: CGPoint(x: hr.x, y: hr.y - unit * 0.06))
        ctx.stroke(belt, with: .color(AvatarPalette.ink), lineWidth: unit * 0.13)
        let buckle = mid(hl, hr) ?? neckBase
        ctx.fill(Path(ellipseIn: CGRect(x: buckle.x - unit * 0.1, y: buckle.y - unit * 0.16, width: unit * 0.2, height: unit * 0.2)),
                 with: .color(Color(hex: "#FFC845")))
        drawStar(in: &ctx, center: CGPoint(x: neckBase.x, y: neckBase.y + unit * 0.55), unit: unit)
        ctx.fill(Path(ellipseIn: CGRect(x: neckBase.x - unit * 0.2, y: neckBase.y - unit * 0.2, width: unit * 0.4, height: unit * 0.4)),
                 with: .color(AvatarPalette.skin))
        return mid(hl, hr)
    }

    private func drawStar(in ctx: inout GraphicsContext, center: CGPoint, unit: CGFloat) {
        var star = Path()
        for index in 0..<10 {
            let radius = (index % 2 == 1 ? 0.1 : 0.23) * unit, angle = -Double.pi / 2 + Double(index) * 0.6283
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            if index == 0 { star.move(to: point) } else { star.addLine(to: point) }
        }
        star.closeSubpath()
        ctx.fill(star, with: .color(.white.opacity(0.8)))
    }

    private func drawArms(in ctx: inout GraphicsContext, shoulders: (CGPoint?, CGPoint?), body: CGPoint?, _ m: Metrics) {
        let sleeve = LimbStyle(width: m.unit * 0.46, color: palette.base, edge: palette.shirtEdge, edgeWidth: m.edge, glow: true)
        let forearm = LimbStyle(width: m.unit * 0.36, color: AvatarPalette.skin, edge: AvatarPalette.skinEdge, edgeWidth: m.edge,
                                glow: true)
        chain([shoulders.0, point("le")], sleeve, in: &ctx)
        chain([shoulders.1, point("re")], sleeve, in: &ctx)
        chain([point("le"), point("lw")], forearm, in: &ctx)
        chain([point("re"), point("rw")], forearm, in: &ctx)
        drawHand(in: &ctx, Arm(wrist: point("lw"), elbow: point("le"), shoulder: shoulders.0), toward: body, m)
        drawHand(in: &ctx, Arm(wrist: point("rw"), elbow: point("re"), shoulder: shoulders.1), toward: body, m)
    }

    /// Mão com dedos que se abrem quando o braço está acima do ombro; o polegar fica do lado do corpo.
    private func drawHand(in ctx: inout GraphicsContext, _ arm: Arm, toward: CGPoint?, _ m: Metrics) {
        guard let wrist = arm.wrist else { return }
        let (elbow, shoulder) = (arm.elbow, arm.shoulder)
        let (size, edge) = (m.unit * 0.36, m.edge)
        let angle = elbow.map { Double(atan2(wrist.y - $0.y, wrist.x - $0.x)) } ?? .pi / 2
        let relative = toward.map { CGPoint(x: $0.x - wrist.x, y: $0.y - wrist.y) } ?? .zero
        let side: Double = (-sin(angle) * Double(relative.x) + cos(angle) * Double(relative.y)) > 0 ? 1 : -1
        let spread = (shoulder.map { wrist.y < $0.y } ?? false) ? 1.0 : 0.25
        var c = ctx
        c.translateBy(x: wrist.x, y: wrist.y)
        c.rotate(by: .radians(angle))
        let fan = [-0.42, -0.14, 0.14, 0.42], length = [0.62, 0.78, 0.74, 0.58]
        for pass in 0..<2 {
            let color = pass == 1 ? AvatarPalette.skin : AvatarPalette.skinEdge
            let style = StrokeStyle(lineWidth: size * 0.3 + (pass == 1 ? 0 : edge), lineCap: .round, lineJoin: .round)
            for index in 0..<4 {
                let a = fan[index] * (0.35 + 0.65 * spread), x0 = size * 0.7, y0 = (Double(index) - 1.5) * size * 0.3
                var finger = Path()
                finger.move(to: CGPoint(x: x0, y: y0))
                finger.addLine(to: CGPoint(x: x0 + cos(a) * size * length[index], y: y0 + sin(a) * size * length[index]))
                c.stroke(finger, with: .color(color), style: style)
            }
            let thumbAngle = side * (0.7 + 0.5 * spread)
            var thumb = Path()
            thumb.move(to: CGPoint(x: size * 0.35, y: side * size * 0.38))
            let tip = CGPoint(x: size * 0.35 + cos(thumbAngle) * size * 0.62, y: side * size * 0.38 + sin(thumbAngle) * size * 0.62)
            thumb.addLine(to: tip)
            c.stroke(thumb, with: .color(color), style: style)
            let palm = size * 0.58 + (pass == 1 ? 0 : edge / 2)
            c.fill(Path(ellipseIn: CGRect(x: size * 0.4 - palm, y: -palm, width: palm * 2, height: palm * 2)), with: .color(color))
        }
    }

    // MARK: - Utilidades

    /// Membro de um ou mais segmentos (juntas que faltam são puladas), com contorno por baixo e um brilho fino em cima.
    func chain(_ points: [CGPoint?], _ style: LimbStyle, in ctx: inout GraphicsContext) {
        let list = points.compactMap { $0 }
        guard list.count >= 2 else { return }
        func path(offset: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: list[0].x + offset, y: list[0].y + offset))
            for point in list.dropFirst() { p.addLine(to: CGPoint(x: point.x + offset, y: point.y + offset)) }
            return p
        }
        let round = { (w: CGFloat) in StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round) }
        ctx.stroke(path(offset: 0), with: .color(style.edge), style: round(style.width + style.edgeWidth))
        ctx.stroke(path(offset: 0), with: .color(style.color), style: round(style.width))
        if style.glow {
            ctx.stroke(path(offset: -style.width * 0.16), with: .color(.white.opacity(0.28)), style: round(style.width * 0.26))
        }
    }
}
