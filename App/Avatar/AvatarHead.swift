import SwiftUI
// swiftlint:disable line_length

/// Cabeça do avatar: gira e inclina com olhos e orelhas, cabelo com franja, olhos, sobrancelhas, bochechas, boca
/// (sorriso, alegre ou chorando com lágrimas), coroa de quem ganhou e o visual do apresentador (tia ou tio).
struct AvatarHead {
    let figure: AvatarFigure
    let renderer: AvatarRenderer
    let time: Double

    private var palette: AvatarPalette { AvatarPalette(hex: figure.colorHex) }
    private let ink = AvatarPalette.ink

    private func spread(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(b.x - a.x, b.y - a.y) }

    func draw(in ctx: inout GraphicsContext, unit: CGFloat, edge: CGFloat, box: CGRect) {
        guard let nose = renderer.point("n") else { return }
        let radius = figure.headRadius.map { $0 * box.height } ?? unit * 0.74
        var eyes = [renderer.point("ley"), renderer.point("rey")].compactMap { $0 }.sorted { $0.x < $1.x }
        var ears = [renderer.point("lea"), renderer.point("rea")].compactMap { $0 }.sorted { $0.x < $1.x }
        if eyes.count < 2 { eyes = [] }
        if ears.count < 2 { ears = [] }
        var roll = 0.0, yaw = 0.0
        var center = CGPoint(x: nose.x, y: nose.y - radius * 0.06)
        var reference: CGPoint?, span: CGFloat = 0
        if eyes.count == 2 {
            roll = Double(atan2(eyes[1].y - eyes[0].y, eyes[1].x - eyes[0].x))
            reference = CGPoint(x: (eyes[0].x + eyes[1].x) / 2, y: (eyes[0].y + eyes[1].y) / 2)
            span = spread(eyes[0], eyes[1]) * 0.8
        } else if ears.count == 2 {
            roll = Double(atan2(ears[1].y - ears[0].y, ears[1].x - ears[0].x))
            reference = CGPoint(x: (ears[0].x + ears[1].x) / 2, y: (ears[0].y + ears[1].y) / 2)
            span = spread(ears[0], ears[1]) * 0.35
        }
        roll = min(max(roll, -0.7), 0.7)
        let cs = CGFloat(cos(roll)), sn = CGFloat(sin(roll))
        if let reference {
            center = CGPoint(x: reference.x - sn * radius * 0.1, y: reference.y + cs * radius * 0.1)
            if span > 0 { yaw = Double(min(max(((nose.x - reference.x) * cs + (nose.y - reference.y) * sn) / span, -1), 1)) }
        }
        var c = ctx
        c.translateBy(x: center.x, y: center.y)
        c.rotate(by: .radians(roll))
        drawFace(in: &c, radius: radius, yaw: yaw, edge: edge)
        drawLabel(in: &ctx, center: center, radius: radius, box: box)
    }

    private func drawFace(in c: inout GraphicsContext, radius r: CGFloat, yaw: Double, edge: CGFloat) {
        let faceShift = CGFloat(yaw) * r * 0.42, squeeze = 1 - 0.3 * CGFloat(abs(yaw))
        if figure.host == .tia { drawLongHair(in: &c, r: r) }
        func dot(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ color: Color) {
            c.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
        }
        let leftEar = r * 0.2 * (1 - 0.8 * CGFloat(max(0, -yaw))), rightEar = r * 0.2 * (1 - 0.8 * CGFloat(max(0, yaw)))
        dot(-r * 0.98, r * 0.05, leftEar + edge / 2, AvatarPalette.skinEdge)
        dot(-r * 0.98, r * 0.05, leftEar, AvatarPalette.skin)
        dot(r * 0.98, r * 0.05, rightEar + edge / 2, AvatarPalette.skinEdge)
        dot(r * 0.98, r * 0.05, rightEar, AvatarPalette.skin)
        dot(0, 0, r + edge / 2, AvatarPalette.skinEdge)
        let skin = GraphicsContext.Shading.radialGradient(Gradient(colors: [Color(hex: "#FFEBD6"), AvatarPalette.skin]),
                                                          center: CGPoint(x: -r * 0.3, y: -r * 0.35), startRadius: r * 0.1, endRadius: r * 1.1)
        c.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: skin)
        drawHair(in: &c, r: r, shift: faceShift * 0.3)
        drawFeatures(in: &c, r: r, shift: faceShift, squeeze: squeeze, yaw: yaw)
        if figure.crown { drawCrown(in: &c, r: r, edge: edge) }
    }

    private func drawHair(in c: inout GraphicsContext, r: CGFloat, shift: CGFloat) {
        let hair = figure.host == .tia ? Color(hex: "#6B3F2A") : (figure.host == .tio ? Color(hex: "#3B2A22") : palette.hair)
        var path = Path()
        path.addArc(center: CGPoint(x: shift, y: 0), radius: r * 1.04, startAngle: .radians(3.3), endAngle: .radians(6.12), clockwise: false)
        path.addQuadCurve(to: CGPoint(x: shift + r * 0.1, y: -r * 0.5), control: CGPoint(x: shift + r * 0.55, y: -r * 0.3))
        path.addQuadCurve(to: CGPoint(x: shift - r * 1.0, y: -r * 0.3), control: CGPoint(x: shift - r * 0.35, y: -r * 0.7))
        c.fill(path, with: .color(hair))
        var shine = Path()
        shine.addArc(center: CGPoint(x: shift, y: 0), radius: r * 0.82, startAngle: .radians(3.7), endAngle: .radians(4.7), clockwise: false)
        c.stroke(shine, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: r * 0.09, lineCap: .round))
        if figure.host == .tia {
            // Presilha rosa
            c.fill(Path(ellipseIn: CGRect(x: r * 0.45, y: -r * 1.0, width: r * 0.32, height: r * 0.24)), with: .color(Color(hex: "#FF7AB8")))
        }
    }

    /// Cabelo comprido da tia: aparece atrás da cabeça e dos ombros.
    private func drawLongHair(in c: inout GraphicsContext, r: CGFloat) {
        for side in [CGFloat(-1), 1] {
            let lock = CGRect(x: side * r * 1.0 - r * 0.3, y: r * 0.75 - r * 1.0, width: r * 0.6, height: r * 2.0)
            c.fill(Path(ellipseIn: lock), with: .color(Color(hex: "#6B3F2A")))
        }
    }

    private func drawFeatures(in c: inout GraphicsContext, r: CGFloat, shift fx: CGFloat, squeeze: CGFloat, yaw: Double) {
        let sad = figure.mood == .sad, happy = figure.mood == .win
        let ex = r * 0.38 * squeeze, ey = r * 0.02 - (happy ? r * 0.03 : 0)
        let blink = time.truncatingRemainder(dividingBy: 3.6) < 0.14 && !sad
        func dot(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ color: Color) {
            c.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
        }
        for side in [CGFloat(-1), 1] {
            dot(fx + side * r * 0.64 * squeeze, r * 0.4, r * 0.17, Color(red: 1, green: 0.43, blue: 0.47).opacity(0.38))
            if blink {
                var lid = Path()
                lid.move(to: CGPoint(x: fx + side * ex - r * 0.14, y: ey))
                lid.addLine(to: CGPoint(x: fx + side * ex + r * 0.14, y: ey))
                c.stroke(lid, with: .color(ink), style: StrokeStyle(lineWidth: max(1.5, r * 0.08), lineCap: .round))
            } else {
                let x = fx + side * ex, shiftEye = CGFloat(yaw) * r * 0.05
                dot(x, ey, r * (sad ? 0.22 : 0.19), .white)
                dot(x + shiftEye, ey + r * (sad ? 0.05 : 0.02), r * (sad ? 0.14 : 0.115), ink)
                dot(x + shiftEye - r * 0.04, ey - r * 0.02, r * (sad ? 0.055 : 0.04), .white)
            }
            var brow = Path()
            if sad {
                brow.move(to: CGPoint(x: fx + side * (ex + r * 0.17), y: ey - r * 0.27))
                brow.addLine(to: CGPoint(x: fx + side * (ex - r * 0.16), y: ey - r * 0.4))
            } else {
                let lift = happy ? r * 0.1 : 0
                brow.move(to: CGPoint(x: fx + side * ex - r * 0.15, y: ey - r * 0.3 - lift))
                brow.addQuadCurve(to: CGPoint(x: fx + side * ex + r * 0.15, y: ey - r * 0.3 - lift),
                                  control: CGPoint(x: fx + side * ex, y: ey - r * 0.38 - lift))
            }
            c.stroke(brow, with: .color(ink), style: StrokeStyle(lineWidth: max(1.5, r * 0.07), lineCap: .round))
        }
        drawMouth(in: &c, r: r, fx: fx, ex: ex, ey: ey)
        if figure.host == .tio { drawTioDetails(in: &c, r: r, fx: fx, ex: ex, ey: ey) }
    }

    private func drawMouth(in c: inout GraphicsContext, r: CGFloat, fx: CGFloat, ex: CGFloat, ey: CGFloat) {
        let stroke = StrokeStyle(lineWidth: max(1.5, r * 0.07), lineCap: .round)
        switch figure.mood {
        case .sad:
            let wail = figure.sob
            if wail > 0.25 {
                let ry = r * (0.08 + 0.2 * wail)
                c.fill(Path(ellipseIn: CGRect(x: fx - r * 0.2, y: r * 0.48 - ry, width: r * 0.4, height: ry * 2)), with: .color(ink))
            } else {
                var frown = Path()
                frown.addArc(center: CGPoint(x: fx, y: r * 0.62), radius: r * 0.26, startAngle: .radians(3.6), endAngle: .radians(5.82), clockwise: false)
                c.stroke(frown, with: .color(ink), style: stroke)
            }
            drawTears(in: &c, r: r, fx: fx, ex: ex, ey: ey)
        case .win:
            var open = Path()
            open.addArc(center: CGPoint(x: fx, y: r * 0.3), radius: r * 0.26, startAngle: .radians(0), endAngle: .radians(.pi), clockwise: false)
            open.closeSubpath()
            c.fill(open, with: .color(ink))
            c.fill(Path(ellipseIn: CGRect(x: fx - r * 0.12, y: r * 0.4, width: r * 0.24, height: r * 0.14)), with: .color(Color(hex: "#FF7A8A")))
        case .normal:
            var smile = Path()
            smile.addArc(center: CGPoint(x: fx, y: r * 0.2), radius: r * 0.3, startAngle: .radians(0.4), endAngle: .radians(2.74),
                         clockwise: false)
            c.stroke(smile, with: .color(ink), style: stroke)
        }
    }

    private func drawTears(in c: inout GraphicsContext, r: CGFloat, fx: CGFloat, ex: CGFloat, ey: CGFloat) {
        for side in [CGFloat(-1), 1] {
            var streak = Path()
            streak.move(to: CGPoint(x: fx + side * ex, y: ey + r * 0.16))
            streak.addLine(to: CGPoint(x: fx + side * (ex + r * 0.14), y: ey + r * 0.95))
            c.stroke(streak, with: .color(Color(hex: "#8FD8FF").opacity(0.55)), lineWidth: r * 0.07)
            for drop in 0..<3 {
                let p = (time * 0.9 + Double(drop) / 3 + (side > 0 ? 0.17 : 0)).truncatingRemainder(dividingBy: 1)
                let x = fx + side * (ex + r * 0.14 * CGFloat(p)), y = ey + r * 0.18 + CGFloat(p) * r * 0.85
                let radius = r * 0.075 * (1 - 0.35 * CGFloat(p))
                c.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                       with: .color(Color(hex: "#8FD8FF").opacity(1 - p * p * p)))
            }
        }
    }

    private func drawTioDetails(in c: inout GraphicsContext, r: CGFloat, fx: CGFloat, ex: CGFloat, ey: CGFloat) {
        // Óculos redondos e bigode
        for side in [CGFloat(-1), 1] {
            let rect = CGRect(x: fx + side * ex - r * 0.26, y: ey - r * 0.26, width: r * 0.52, height: r * 0.52)
            c.stroke(Path(ellipseIn: rect), with: .color(Color(hex: "#3B2A22")), lineWidth: max(1.5, r * 0.06))
        }
        var bridge = Path()
        bridge.move(to: CGPoint(x: fx - ex + r * 0.26, y: ey))
        bridge.addLine(to: CGPoint(x: fx + ex - r * 0.26, y: ey))
        c.stroke(bridge, with: .color(Color(hex: "#3B2A22")), lineWidth: max(1.5, r * 0.05))
        var moustache = Path()
        moustache.move(to: CGPoint(x: fx - r * 0.3, y: r * 0.34))
        moustache.addQuadCurve(to: CGPoint(x: fx, y: r * 0.3), control: CGPoint(x: fx - r * 0.15, y: r * 0.22))
        moustache.addQuadCurve(to: CGPoint(x: fx + r * 0.3, y: r * 0.34), control: CGPoint(x: fx + r * 0.15, y: r * 0.22))
        c.stroke(moustache, with: .color(Color(hex: "#3B2A22")), style: StrokeStyle(lineWidth: r * 0.1, lineCap: .round))
    }

    private func drawCrown(in c: inout GraphicsContext, r: CGFloat, edge: CGFloat) {
        let y0 = -r * 0.88
        var crown = Path()
        crown.move(to: CGPoint(x: -r * 0.62, y: y0))
        for point in [(-0.66, -0.5), (-0.3, -0.26), (0, -0.68), (0.3, -0.26), (0.66, -0.5), (0.62, 0)] {
            crown.addLine(to: CGPoint(x: r * point.0, y: y0 + r * point.1))
        }
        crown.closeSubpath()
        c.fill(crown, with: .color(Color(hex: "#FFC83D")))
        c.stroke(crown, with: .color(Color(hex: "#B5791A")), style: StrokeStyle(lineWidth: max(1.5, r * 0.07), lineJoin: .round))
        for (x, color) in [(-0.36, "#4D9DE0"), (0, "#E0523C"), (0.36, "#36C9A6")] {
            let size = r * (x == 0 ? 0.07 : 0.05)
            let jewel = CGRect(x: r * x - size, y: y0 - r * 0.08 - size, width: size * 2, height: size * 2)
            c.fill(Path(ellipseIn: jewel), with: .color(Color(hex: color)))
        }
    }

    private func drawLabel(in ctx: inout GraphicsContext, center: CGPoint, radius: CGFloat, box: CGRect) {
        guard let name = figure.name else { return }
        let suffix = figure.mood == .win ? " ★" : ""
        let height = box.height * 0.085
        let text = Text(name + suffix).font(.system(size: box.height * 0.06, weight: .bold)).foregroundColor(Color(hex: figure.colorHex))
        let resolved = ctx.resolve(text)
        let size = resolved.measure(in: CGSize(width: 400, height: 100))
        let y = max(box.minY + height * 0.1, center.y - radius * 1.15 - height * 1.25)
        let pill = CGRect(x: center.x - size.width / 2 - height * 0.45, y: y, width: size.width + height * 0.9, height: height)
        ctx.fill(Path(roundedRect: pill, cornerRadius: height / 2), with: .color(.black.opacity(0.55)))
        ctx.draw(resolved, at: CGPoint(x: center.x, y: y + height / 2), anchor: .center)
    }
}
// swiftlint:enable line_length
