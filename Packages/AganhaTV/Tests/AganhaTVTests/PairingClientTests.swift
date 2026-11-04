@testable import AganhaTV
import Foundation
import Testing

/// Responde no lugar da rede, para testar o cliente sem internet.
private final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var lastBody: Data?

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool { true }
    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var request = self.request
        if request.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            request.httpBody = data
        }
        Self.lastBody = request.httpBody
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized) struct PairingClientTests {
    private func client(_ handler: (@Sendable (URLRequest) -> (Int, Data))?) -> PairingClient {
        StubProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return PairingClient(baseURL: URL(string: "https://example.test")!, session: URLSession(configuration: configuration))
    }

    @Test func pairSendsTheCodeAndTheLocalAddress() async throws {
        let paired = client { request in
            #expect(request.url?.path == "/api/app/pair")
            return (200, Data(#"{"ok":true}"#.utf8))
        }
        try await paired.pair(code: "4821", host: "192.168.13.20", port: 8080, token: "1234")
        let body = try #require(StubProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["code"] as? String == "4821")
        #expect(json["host"] as? String == "192.168.13.20")
        #expect(json["port"] as? Int == 8080)
        #expect(json["token"] as? String == "1234")
    }

    @Test func offerReturnsTheCode() async throws {
        let offering = client { _ in (200, Data(#"{"code":"7777","expiresIn":599}"#.utf8)) }
        let offer = try await offering.offer(host: "10.0.0.5", port: 8080, token: nil)
        #expect(offer == PairingClient.Offer(code: "7777", expiresIn: 599))
        let body = try #require(StubProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["code"] == nil && json["token"] == nil)
    }

    @Test func serverAnswersBecomeFriendlyFailures() async {
        let cases: [(Int, String, PairingClient.Failure)] = [
            (404, #"{"error":"not_found"}"#, .notFound), (429, #"{"error":"slow_down"}"#, .tooManyAttempts),
            (400, #"{"error":"invalid_code"}"#, .notFound), (400, #"{"error":"host precisa ser um IPv4 da rede local"}"#, .invalidAddress),
            (500, "oops", .server)
        ]
        for (status, body, expected) in cases {
            let failing = client { _ in (status, Data(body.utf8)) }
            await #expect(throws: expected) { try await failing.pair(code: "1111", host: "192.168.1.2", port: 8080, token: nil) }
        }
    }

    @Test func noNetworkMeansOffline() async {
        let offline = client(nil)
        await #expect(throws: PairingClient.Failure.offline) {
            try await offline.pair(code: "1111", host: "192.168.1.2", port: 8080, token: nil)
        }
    }
}
