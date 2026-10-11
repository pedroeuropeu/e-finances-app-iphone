import Foundation
@testable import EFData

/// Servidor falso para os testes de rede: cada teste registra as respostas por caminho e lê as requisições recebidas.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Reply: Sendable { var status: Int; var body: String }

    final class Server: @unchecked Sendable {
        private let lock = NSLock()
        private var routes: [String: [Reply]] = [:]
        private(set) var requests: [URLRequest] = []

        /// Respostas em fila para "MÉTODO caminho" (a última se repete).
        func on(_ method: String, _ path: String, _ replies: Reply...) {
            lock.lock(); routes["\(method) \(path)"] = replies; lock.unlock()
        }

        func reply(for r: URLRequest) -> Reply {
            lock.lock(); defer { lock.unlock() }
            requests.append(r)
            let key = "\(r.httpMethod ?? "GET") \(r.url?.path ?? "")"
            guard var list = routes[key], !list.isEmpty else { return Reply(status: 404, body: "{\"message\":\"sem rota \(key)\"}") }
            let first = list.removeFirst()
            routes[key] = list.isEmpty ? [first] : list
            return first
        }

        var paths: [String] { lock.lock(); defer { lock.unlock() }; return requests.map { "\($0.httpMethod ?? "GET") \($0.url?.path ?? "")" } }
    }

    nonisolated(unsafe) static var servers: [String: Server] = [:]
    static let lock = NSLock()

    /// Sessão que fala com um servidor falso próprio (identificado por um cabeçalho, para os testes rodarem em paralelo).
    static func session() -> (URLSession, Server) {
        let id = UUID().uuidString
        let server = Server()
        lock.lock(); servers[id] = server; lock.unlock()
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubURLProtocol.self]
        cfg.httpAdditionalHeaders = ["X-Stub": id]
        return (URLSession(configuration: cfg), server)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let id = request.value(forHTTPHeaderField: "X-Stub") ?? ""
        Self.lock.lock(); let server = Self.servers[id]; Self.lock.unlock()
        var req = request
        // URLSession entrega o corpo como stream ao protocolo: lê para o teste conferir
        if req.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buf = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buf, maxLength: buf.count); if n <= 0 { break }; data.append(buf, count: n) }
            stream.close()
            req.httpBody = data
        }
        let reply = server?.reply(for: req) ?? Reply(status: 500, body: "")
        let resp = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
