import AganhaCore
import AganhaVision
import SwiftUI

/// Posicionar: prévia da câmera com esqueletos e orientação para enquadrar todos da cabeça aos pés.
struct PositioningView: View {
    let loop: GameLoop
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(camera: loop.camera).ignoresSafeArea()
            SkeletonOverlay(analysis: loop.analysis).ignoresSafeArea()
            VStack(spacing: 12) {
                banner
                Spacer()
                people
                actions
            }
            .padding()
            if let error = loop.cameraError {
                Text(error)
                    .padding()
                    .background(.red.opacity(0.85), in: .rect(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
        }
    }

    private var banner: some View {
        HStack(spacing: 12) {
            if let slot = loop.guidance?.slot { Circle().fill(SlotPalette.color(for: slot)).frame(width: 28, height: 28) }
            Text(loop.guidance?.text ?? String(localized: "Procurando vocês…"))
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.black.opacity(0.65), in: .rect(cornerRadius: 16))
        .foregroundStyle(.white)
    }

    private var people: some View {
        HStack {
            ForEach(loop.report.people, id: \.slot) { person in
                SlotChip(slot: person.slot, isOut: !person.isReady, detail: person.isReady ? "✓" : "!")
            }
            if loop.report.extraPeople > 0 {
                Text("+\(loop.report.extraPeople) além de 6").font(.caption).foregroundStyle(.white)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button("Voltar", systemImage: "chevron.left", action: onBack)
                    .buttonStyle(.bordered)
                Button {
                    loop.startGame()
                } label: {
                    Text("Começar").font(.title2.weight(.heavy)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#36C9A6"))
                .disabled(!loop.report.allReady)
            }
            .controlSize(.large)
            if !loop.report.allReady, loop.report.people.count >= 2 {
                Button("Começar mesmo assim") { loop.startGame(anyway: true) }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}
