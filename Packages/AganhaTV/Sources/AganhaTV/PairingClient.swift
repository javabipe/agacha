import Foundation

/// Fala com o roteador `https://agacha.app`: entrega o endereço do jogo (rede local) à TV que mostra um código,
/// ou pede um código para digitar na TV. O servidor só guarda o endereço por alguns minutos, na memória.
public struct PairingClient: Sendable {
    public enum Failure: Error, Equatable, Sendable {
        /// Sem internet (ou o roteador não respondeu).
        case offline
        /// O código não existe ou já expirou.
        case notFound
        /// O endereço do iPad não é de uma rede local.
        case invalidAddress
        case tooManyAttempts
        case server
    }

    public struct Offer: Sendable, Equatable {
        public let code: String
        /// Segundos até o código expirar.
        public let expiresIn: Int
    }

    public static let defaultBaseURL = URL(string: "https://agacha.app")!

    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = PairingClient.defaultBaseURL, session: URLSession? = nil) {
        self.baseURL = baseURL
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 8
            configuration.waitsForConnectivity = false
            configuration.httpCookieStorage = nil
            self.session = URLSession(configuration: configuration)
        }
    }

    private struct Body: Encodable {
        var code: String?
        let host: String
        let port: Int
        var token: String?
    }

    private struct OfferResponse: Decodable {
        let code: String
        let expiresIn: Int
    }

    /// A TV mostra `code` em agacha.app; o iPad entrega o endereço e a TV é levada ao jogo.
    public func pair(code: String, host: String, port: Int, token: String?) async throws {
        _ = try await send("/api/app/pair", Body(code: code, host: host, port: port, token: token))
    }

    /// O iPad pede um código para digitar na TV (campo "Ou digite aqui" de agacha.app).
    public func offer(host: String, port: Int, token: String?) async throws -> Offer {
        let data = try await send("/api/app/offer", Body(code: nil, host: host, port: port, token: token))
        guard let response = try? JSONDecoder().decode(OfferResponse.self, from: data) else { throw Failure.server }
        return Offer(code: response.code, expiresIn: response.expiresIn)
    }

    private func send(_ path: String, _ body: Body) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Failure.offline
        }
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw Failure.server }
        switch status {
        case 200: return data
        case 404: throw Failure.notFound
        case 429: throw Failure.tooManyAttempts
        case 400:
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? ""
            throw message == "invalid_code" ? Failure.notFound : Failure.invalidAddress
        default: throw Failure.server
        }
    }
}
