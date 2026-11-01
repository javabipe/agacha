import AganhaCore
import AganhaVision
import SwiftUI

extension Color {
    /// `#RRGGBB`.
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }

    static let aganhaCream = Color(hex: "#FFF6E5")
    static let aganhaPurple = Color(hex: "#8E7BFF")
    static let aganhaYellow = Color(hex: "#FFC845")
}

enum Theme {
    static let background = LinearGradient(colors: [Color(hex: "#1B1433"), Color(hex: "#3A2A6B")],
                                           startPoint: .top, endPoint: .bottom)
}

/// Bolinha com a cor e o nome da vaga.
struct SlotChip: View {
    let slot: ChildSlot
    var isOut = false
    var detail: String?

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(SlotPalette.color(for: slot)).frame(width: 18, height: 18)
            Text(SlotColors.displayName(slot)).font(.headline)
            if let detail { Text(detail).font(.headline) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.35), in: .capsule)
        .foregroundStyle(.white)
        .opacity(isOut ? 0.4 : 1)
        .overlay { if isOut { Capsule().stroke(.white.opacity(0.4), lineWidth: 1) } }
    }
}

/// Desenho de um esqueleto (replay da eliminação), ajustado ao próprio tamanho.
struct SkeletonThumbnail: View {
    let skeleton: Skeleton
    let color: Color

    var body: some View {
        Canvas { context, size in
            let joints = skeleton.joints.values.filter { $0.confidence > 0.2 }
            guard let minX = joints.map(\.x).min(), let maxX = joints.map(\.x).max(),
                  let minY = joints.map(\.y).min(), let maxY = joints.map(\.y).max() else { return }
            let width = max(maxX - minX, 0.05), height = max(maxY - minY, 0.05)
            let scale = min((size.width - 24) / width, (size.height - 24) / height)
            let originX = (size.width - width * scale) / 2, originY = (size.height - height * scale) / 2
            func point(_ joint: Joint) -> CGPoint {
                CGPoint(x: originX + (joint.x - minX) * scale, y: originY + (joint.y - minY) * scale)
            }
            for (a, b) in Skeleton.bones {
                guard let ja = skeleton.joints[a], let jb = skeleton.joints[b], ja.confidence > 0.2, jb.confidence > 0.2 else { continue }
                var path = Path()
                path.move(to: point(ja))
                path.addLine(to: point(jb))
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
            if let nose = skeleton.joints[.nose], nose.confidence > 0.2 {
                let p = point(nose)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(color))
            }
        }
    }
}

/// Personagem provisório da Tia (SwiftUI) com os estados da Fase 2: braços para cima, para baixo ou parados.
struct TiaView: View {
    /// nil = parada (braços relaxados).
    let gesture: Stance?

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let armLength = size * 0.36
            let armAngle: Double = gesture == .up ? 150 : 18
            ZStack {
                arm(length: armLength, width: size * 0.1, angle: -armAngle, shoulderX: size * 0.2, size: size)
                arm(length: armLength, width: size * 0.1, angle: armAngle, shoulderX: -size * 0.2, size: size)
                RoundedRectangle(cornerRadius: size * 0.14)
                    .fill(Color.aganhaPurple)
                    .frame(width: size * 0.42, height: size * 0.5)
                    .offset(y: size * 0.2)
                Circle()
                    .fill(Color(hex: "#FFD9B8"))
                    .frame(width: size * 0.36, height: size * 0.36)
                    .offset(y: -size * 0.2)
                face(size: size).offset(y: -size * 0.2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: gesture)
        }
        .accessibilityHidden(true)
    }

    private func arm(length: Double, width: Double, angle: Double, shoulderX: Double, size: Double) -> some View {
        Capsule()
            .fill(Color(hex: "#FFD9B8"))
            .frame(width: width, height: length)
            .rotationEffect(.degrees(angle), anchor: .top)
            .offset(x: shoulderX, y: size * 0.02 + length / 2)
    }

    private func face(size: Double) -> some View {
        ZStack {
            HStack(spacing: size * 0.1) {
                Circle().fill(.black).frame(width: size * 0.04)
                Circle().fill(.black).frame(width: size * 0.04)
            }
            .offset(y: -size * 0.02)
            Path { path in
                path.addArc(center: CGPoint(x: 0, y: 0), radius: size * 0.07, startAngle: .degrees(20), endAngle: .degrees(160),
                            clockwise: false)
            }
            .stroke(.black, style: StrokeStyle(lineWidth: size * 0.015, lineCap: .round))
            .frame(width: 1, height: 1)
            .offset(y: size * 0.03)
        }
    }
}
