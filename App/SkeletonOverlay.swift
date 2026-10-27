import AganhaCore
import AganhaVision
import SwiftUI

enum SlotPalette {
    static let colors: [Color] = [.yellow, .mint, .orange, .purple, .cyan, .pink]

    static func color(for slot: ChildSlot?) -> Color {
        guard let slot else { return .gray }
        return colors[slot % colors.count]
    }
}

/// Desenha esqueletos e rótulos sobre a prévia (que usa aspect-fit).
struct SkeletonOverlay: View {
    let analysis: FrameAnalysis?

    var body: some View {
        GeometryReader { geometry in
            if let analysis, analysis.imageSize.width > 0 {
                let rect = Self.fitRect(image: analysis.imageSize, in: geometry.size)
                ZStack(alignment: .topLeading) {
                    Canvas { context, _ in
                        for person in analysis.people {
                            draw(person, in: rect, context: &context)
                        }
                    }
                    ForEach(analysis.people) { person in
                        if let anchor = labelAnchor(for: person, in: rect) {
                            PersonLabel(person: person)
                                .position(anchor)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    static func fitRect(image: CGSize, in container: CGSize) -> CGRect {
        let scale = min(container.width / image.width, container.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: (container.width - size.width) / 2, y: (container.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    private func point(_ joint: Joint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + joint.x * rect.width, y: rect.minY + joint.y * rect.height)
    }

    private func draw(_ person: TrackedPerson, in rect: CGRect, context: inout GraphicsContext) {
        let color = SlotPalette.color(for: person.slot)
        for (a, b) in Skeleton.bones {
            guard let ja = person.skeleton.joints[a], let jb = person.skeleton.joints[b],
                  ja.confidence > 0.2, jb.confidence > 0.2 else { continue }
            var path = Path()
            path.move(to: point(ja, in: rect))
            path.addLine(to: point(jb, in: rect))
            context.stroke(path, with: .color(color), lineWidth: 4)
        }
        for joint in person.skeleton.joints.values where joint.confidence > 0.2 {
            let p = point(joint, in: rect)
            context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(.white))
        }
    }

    private func labelAnchor(for person: TrackedPerson, in rect: CGRect) -> CGPoint? {
        let top = person.skeleton.joints.values.filter { $0.confidence > 0.2 }.map(\.y).min()
        guard let top, let center = person.skeleton.centroid else { return nil }
        let y = max(rect.minY + 40, rect.minY + top * rect.height - 34)
        return CGPoint(x: rect.minX + center.x * rect.width, y: y)
    }
}

private struct PersonLabel: View {
    let person: TrackedPerson

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.headline)
            if let crouch = person.reading.crouchIndex {
                Text(crouch.formatted(.number.precision(.fractionLength(2))))
                    .font(.caption.monospacedDigit())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(SlotPalette.color(for: person.slot).opacity(0.85), in: .rect(cornerRadius: 8))
        .foregroundStyle(.black)
    }

    private var title: String {
        guard let slot = person.slot else { return String(localized: "extra") }
        let state = switch person.reading.posture {
        case .standing: String(localized: "em pé")
        case .crouching: String(localized: "agachado")
        case .unknown: person.reading.isCalibrated ? "?" : String(localized: "calibrando…")
        }
        return "#\(slot + 1) \(state)"
    }
}
