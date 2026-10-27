import AganhaVision
import SwiftUI

struct SpikeView: View {
    @State private var model = SpikeModel()
    @State private var showDebug = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(camera: model.camera)
                .ignoresSafeArea()
            SkeletonOverlay(analysis: model.analysis)
                .ignoresSafeArea()
            VStack {
                HUD(model: model)
                Spacer()
                controls
            }
            .padding()
            if let message = model.errorMessage {
                Text(message)
                    .padding()
                    .background(.red.opacity(0.85), in: .rect(cornerRadius: 12))
            }
        }
        .sheet(isPresented: $showDebug) {
            DebugPanel(model: model)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .task { await model.start() }
        .onDisappear { model.stop() }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button("Recalibrar", systemImage: "arrow.counterclockwise") { model.recalibrate() }
            Button("Ajustes", systemImage: "slider.horizontal.3") { showDebug = true }
            Button(model.isRecording ? "Parar (\(model.recordedFrameCount))" : "Gravar fixture",
                   systemImage: model.isRecording ? "stop.circle.fill" : "record.circle") {
                model.toggleRecording()
            }
            .tint(model.isRecording ? .red : nil)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

private struct HUD: View {
    let model: SpikeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let analysis = model.analysis {
                Text("FPS \(analysis.fps.formatted(.number.precision(.fractionLength(0))))"
                     + " · Vision \(model.avgDetectionMs.formatted(.number.precision(.fractionLength(1)))) ms"
                     + " · quadro \(analysis.latencyMs.formatted(.number.precision(.fractionLength(1)))) ms")
                Text("\(analysis.people.count) pessoa(s) · \(Int(analysis.imageSize.width))×\(Int(analysis.imageSize.height))")
            } else {
                Text("Aguardando câmera…")
            }
            if let info = model.cameraInfo {
                Text("\(info.deviceName) · Center Stage: \(centerStage(info))")
            }
            if let file = model.lastSavedFile {
                Text("Salvo em Documents/\(file)")
            }
        }
        .font(.caption.monospacedDigit())
        .padding(8)
        .background(.black.opacity(0.6), in: .rect(cornerRadius: 8))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func centerStage(_ info: CameraInfo) -> String {
        guard info.centerStageSupported else { return "indisponível" }
        return info.centerStageEnabled ? "ligado" : "desligado"
    }
}

private struct DebugPanel: View {
    @Bindable var model: SpikeModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Limiares") {
                    slider("Agacha acima de", value: $model.tuning.crouchEnter, range: 0.2...1.0)
                    slider("Em pé abaixo de", value: $model.tuning.standEnter, range: 0.05...0.6)
                    slider("Debounce (s)", value: $model.tuning.debounce, range: 0...0.5)
                    slider("Confiança mínima", value: $model.tuning.minConfidence, range: 0.05...0.8)
                    slider("Sumiu após (s)", value: $model.tuning.lostTimeout, range: 0.1...1.0)
                }
                Section("Fixture") {
                    TextField("Notas (ex.: 3 pessoas, luz fraca, paisagem, 2,5 m)", text: $model.notes, axis: .vertical)
                }
                Section {
                    Button("Voltar ao Normal") { model.resetTuning() }
                    Button("Recalibrar", action: model.recalibrate)
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            Text("\(title): \(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))")
                .font(.footnote.monospacedDigit())
            Slider(value: value, in: range)
        }
    }
}
