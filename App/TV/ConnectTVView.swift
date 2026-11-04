import AganhaTV
import SwiftUI

/// Conectar a TV sem digitar endereços: a TV abre agacha.app e mostra um código; aqui se digita o código (ou se mostra um
/// código aqui para digitar na TV). O endereço direto continua à mão para quando não há internet.
struct ConnectTVView: View {
    @Bindable var loop: GameLoop
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var status = Status.idle
    @State private var offer: PairingClient.Offer?
    @State private var offerStart = Date()
    @State private var showHelp = false
    @State private var mirroring = MirroringMonitor()
    @FocusState private var focused: Bool
    private let client = PairingClient()

    enum Status: Equatable {
        case idle, working
        case sent
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if loop.tv.connectedScreens > 0 { connectedBanner }
                    typeCodeCard
                    showCodeCard
                    directAddressCard
                    Button("Outras formas de ver na TV (AirPlay)") { showHelp = true }
                        .font(.subheadline)
                        .padding(.top, 4)
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationTitle("Conectar a TV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fechar") { dismiss() } }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { if !loop.tv.isOn { loop.setTVEnabled(true) } }
        .sheet(isPresented: $showHelp) { TVHelpView(monitor: mirroring, tv: loop.tv) }
        .preferredColorScheme(.dark)
    }

    // MARK: - Partes

    private var connectedBanner: some View {
        Label("TV conectada!", systemImage: "checkmark.tv.fill")
            .font(.title3.weight(.heavy))
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(Color(hex: "#1FA98A"), in: .rect(cornerRadius: 16))
    }

    /// Caminho principal: a TV mostra o código, o iPad digita (teclado do iPad, não o controle remoto).
    private var typeCodeCard: some View {
        card(number: "1", title: "Na TV, abra o navegador e digite", highlight: "agacha.app") {
            Text("A TV mostra um código de 4 números. Digite aqui:")
                .font(.callout)
                .foregroundStyle(Color.aganhaCream.opacity(0.9))
            TextField("0000", text: $code)
                .keyboardType(.numberPad)
                .font(.system(size: 48, weight: .heavy, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
                .background(.white.opacity(0.12), in: .rect(cornerRadius: 14))
                .focused($focused)
                .disabled(status == .working || endpoint == nil)
                .onChange(of: code) { _, value in
                    let digits = String(value.filter(\.isNumber).prefix(4))
                    if digits != value { code = digits }
                    if digits.count == 4 { pair(digits) }
                }
            statusLine
        }
    }

    @ViewBuilder private var statusLine: some View {
        switch status {
        case .idle:
            if endpoint == nil { Label("Ligando a conexão com a TV…", systemImage: "wifi").font(.footnote) }
        case .working:
            ProgressView().tint(.white)
        case .sent:
            Label("Pronto! A TV está abrindo o jogo.", systemImage: "checkmark.circle.fill").foregroundStyle(Color(hex: "#7CFFB2"))
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundStyle(Color(hex: "#FFC845"))
        }
    }

    /// Caminho inverso: o iPad mostra o código e se digita na TV.
    private var showCodeCard: some View {
        card(number: "2", title: "Ou prefere digitar na TV?", highlight: nil) {
            if let offer {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(0, offer.expiresIn - Int(context.date.timeIntervalSince(offerStart)))
                    VStack(spacing: 6) {
                        Text(offer.code).font(.system(size: 56, weight: .black, design: .monospaced)).foregroundStyle(Color.aganhaYellow)
                        Text(left > 0 ? validText(left) : String(localized: "O código venceu. Peça outro."))
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }
                }
            } else {
                Text("O iPad mostra um código e você digita na TV, no campo \"Ou digite aqui o código que aparece no iPad\".")
                    .font(.callout)
                    .foregroundStyle(Color.aganhaCream.opacity(0.9))
            }
            Button(offer == nil ? "Mostrar um código aqui" : "Gerar outro código") { makeOffer() }
                .buttonStyle(.bordered)
                .disabled(status == .working || endpoint == nil)
        }
    }

    private func validText(_ seconds: Int) -> String {
        let time = "\(seconds / 60):" + String(format: "%02d", seconds % 60)
        return String(localized: "Em agacha.app, digite no campo \"Ou digite aqui\". Vale por \(time).")
    }

    private var directAddressCard: some View {
        card(number: nil, title: "Sem internet?", highlight: nil) {
            Text("Digite este endereço no navegador da TV (iPad e TV no mesmo Wi-Fi):")
                .font(.callout)
                .foregroundStyle(Color.aganhaCream.opacity(0.9))
            Text(loop.tv.cameraAddress ?? loop.tv.address ?? "…")
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundStyle(Color.aganhaYellow)
                .textSelection(.enabled)
        }
    }

    private func card(number: String?, title: LocalizedStringKey, highlight: String?, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let number {
                    Text(number).font(.headline.weight(.black)).frame(width: 28, height: 28).background(Color.aganhaYellow, in: .circle)
                        .foregroundStyle(Color(hex: "#1B1433"))
                }
                Text(title).font(.headline)
            }
            if let highlight {
                Text(highlight).font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(Color.aganhaYellow)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.black.opacity(0.3), in: .rect(cornerRadius: 18))
    }

    // MARK: - Ações

    /// Endereço do jogo na rede da casa (só existe com o servidor da TV ligado).
    private var endpoint: (host: String, port: Int, token: String?)? {
        guard loop.tv.isOn, let host = loop.tv.host, let port = loop.tv.port else { return nil }
        return (host, port, loop.tv.cameraToken)
    }

    private func pair(_ digits: String) {
        guard let endpoint else { return }
        status = .working
        Task {
            do {
                try await client.pair(code: digits, host: endpoint.host, port: endpoint.port, token: endpoint.token)
                status = .sent
            } catch {
                status = .failed(Self.message(for: error))
                code = ""
                focused = true
            }
        }
    }

    private func makeOffer() {
        guard let endpoint else { return }
        status = .working
        Task {
            do {
                offer = try await client.offer(host: endpoint.host, port: endpoint.port, token: endpoint.token)
                offerStart = Date()
                status = .idle
            } catch {
                status = .failed(Self.message(for: error))
            }
        }
    }

    static func message(for error: Error) -> String {
        switch error as? PairingClient.Failure {
        case .offline: String(localized: "Sem internet agora. Use o endereço direto abaixo.")
        case .notFound: String(localized: "Esse código não existe ou já venceu. Confira o que a TV mostra.")
        case .invalidAddress: String(localized: "O iPad precisa estar num Wi-Fi para ser achado pela TV.")
        case .tooManyAttempts: String(localized: "Muitas tentativas. Espere um minuto.")
        default: String(localized: "Algo deu errado. Tente de novo.")
        }
    }
}
