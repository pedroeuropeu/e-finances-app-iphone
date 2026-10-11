import Foundation
import EFCore

/// Corpo vazio das respostas que não devolvem JSON.
public struct Empty: Codable, Sendable { public init() {} }

/**
 Cliente da API do e-Finances.
 - coloca o Bearer em toda chamada autenticada e renova o access token 30 s antes de vencer;
 - em 401 tenta renovar uma vez (várias chamadas ao mesmo tempo disparam uma única renovação);
 - sessão encerrada pelo servidor (SESSION_ENDED, ACCOUNT_BLOCKED) ou refresh recusado: avisa [onExpired] e o app volta ao login;
 - traduz falhas para mensagens em português (sem internet, muitas tentativas, validação...).
 */
public actor APIClient {
    public enum Method: String, Sendable { case get = "GET", post = "POST", put = "PUT", delete = "DELETE" }

    private let config: AppConfig
    private let session: URLSession
    private let storage: TokenStorage
    private let clock: AppClock
    private let onExpired: @Sendable () -> Void
    private var refreshing: Task<SessionTokens?, Never>?

    static let encoder: JSONEncoder = JSONEncoder()
    static let decoder: JSONDecoder = JSONDecoder()

    public init(config: AppConfig, session: URLSession = .shared, storage: TokenStorage, clock: AppClock = SystemClock(), onExpired: @escaping @Sendable () -> Void = {}) {
        self.config = config
        self.session = session
        self.storage = storage
        self.clock = clock
        self.onExpired = onExpired
    }

    // MARK: - chamadas tipadas

    public func call<T: Decodable & Sendable>(_ method: Method = .get, _ path: String, query: [(String, String?)] = [], authenticated: Bool = true) async -> Outcome<T> {
        await call(method, path, query: query, body: Optional<Empty>.none, authenticated: authenticated)
    }

    public func call<T: Decodable & Sendable, B: Encodable & Sendable>(_ method: Method, _ path: String, query: [(String, String?)] = [], body: B?, authenticated: Bool = true) async -> Outcome<T> {
        switch await raw(method, path, query: query, body: body, authenticated: authenticated) {
        case .failure(let e): return .failure(e)
        case .success(let (data, _)): return decode(data)
        }
    }

    /// Respostas sem corpo (200/204).
    public func send<B: Encodable & Sendable>(_ method: Method, _ path: String, query: [(String, String?)] = [], body: B? = Optional<Empty>.none, authenticated: Bool = true) async -> Outcome<Void> {
        await raw(method, path, query: query, body: body, authenticated: authenticated).map { _ in () }
    }

    public func send(_ method: Method, _ path: String, query: [(String, String?)] = [], authenticated: Bool = true) async -> Outcome<Void> {
        await send(method, path, query: query, body: Optional<Empty>.none, authenticated: authenticated)
    }

    /// 204 = nil (ex.: lançamento que não é recorrente, nenhum fechamento pendente).
    public func optional<T: Decodable & Sendable>(_ path: String, query: [(String, String?)] = []) async -> Outcome<T?> {
        switch await raw(.get, path, query: query, body: Optional<Empty>.none, authenticated: true) {
        case .failure(let e): return .failure(e)
        case .success(let (data, status)):
            if status == 204 || data.isEmpty { return .success(nil) }
            return decode(data).map { Optional($0) }
        }
    }

    private func decode<T: Decodable>(_ data: Data) -> Outcome<T> {
        do { return .success(try Self.decoder.decode(T.self, from: data.isEmpty ? Data("{}".utf8) : data)) } catch {
            #if DEBUG
            print("[API] resposta inesperada: \(error)")
            #endif
            return .failure(.serverDefault)
        }
    }

    // MARK: - transporte

    private func raw<B: Encodable>(_ method: Method, _ path: String, query: [(String, String?)], body: B?, authenticated: Bool) async -> Outcome<(Data, Int)> {
        var bodyData: Data?
        if let body { bodyData = try? Self.encoder.encode(body) }
        guard var request = makeRequest(method, path, query: query, body: bodyData) else { return .failure(.serverDefault) }

        var sentToken: String?
        if authenticated, var tokens = storage.load() {
            if tokens.accessNeedsRefresh(clock.epochMillis()), let renewed = await refresh(stale: tokens.accessToken) { tokens = renewed }
            sentToken = tokens.accessToken
            request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        }

        var result = await perform(request)
        if case .success(let (data, status)) = result, status == 401, authenticated, sentToken != nil {
            let text = String(data: data.prefix(2048), encoding: .utf8) ?? ""
            // sessão encerrada pelo servidor (admin, bloqueio): renovar não adianta
            if text.contains("SESSION_ENDED") || text.contains("ACCOUNT_BLOCKED") { return .failure(expire()) }
            guard let renewed = await refresh(stale: sentToken) else { return .failure(expire()) }
            request.setValue("Bearer \(renewed.accessToken)", forHTTPHeaderField: "Authorization")
            result = await perform(request)
            if case .success(let (_, s)) = result, s == 401 { return .failure(expire()) }
        }

        switch result {
        case .failure(let e): return .failure(e)
        case .success(let (data, status)):
            if (200..<300).contains(status) { return .success((data, status)) }
            return .failure(Self.httpError(status: status, body: data))
        }
    }

    private func makeRequest(_ method: Method, _ path: String, query: [(String, String?)], body: Data?) -> URLRequest? {
        let base = config.apiBaseURL.absoluteString.droppingSuffix("/")
        guard var comps = URLComponents(string: base + "/" + path.droppingPrefix("/")) else { return nil }
        let items = query.compactMap { k, v in v.map { URLQueryItem(name: k, value: $0) } }
        if !items.isEmpty { comps.queryItems = items }
        // "+" na query vira espaço no servidor: codifica
        comps.percentEncodedQuery = comps.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = comps.url else { return nil }
        var r = URLRequest(url: url, timeoutInterval: 30)
        r.httpMethod = method.rawValue
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        r.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        if let body {
            r.httpBody = body
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return r
    }

    private func perform(_ request: URLRequest) async -> Outcome<(Data, Int)> {
        do {
            let (data, response) = try await session.data(for: request)
            return .success((data, (response as? HTTPURLResponse)?.statusCode ?? 0))
        } catch is CancellationError {
            return .failure(.network)
        } catch {
            return .failure(.network)
        }
    }

    private func expire() -> AppError {
        if storage.load() != nil { onExpired() }
        return .unauthorized
    }

    // MARK: - renovação do token (Keycloak, grant_type=refresh_token, client público)

    /// Renova uma vez só, mesmo com várias chamadas pedindo ao mesmo tempo.
    func refresh(stale: String?) async -> SessionTokens? {
        if let task = refreshing { return await task.value }
        guard let current = storage.load() else { return nil }
        let now = clock.epochMillis()
        // outra chamada já renovou enquanto esta esperava
        if let stale, current.accessToken != stale, !current.accessNeedsRefresh(now) { return current }
        guard current.canRefresh(now), let refreshToken = current.refreshToken else { return nil }

        let task = Task { [config, session, storage, clock] () -> SessionTokens? in
            var r = URLRequest(url: config.tokenURL, timeoutInterval: 30)
            r.httpMethod = "POST"
            r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            r.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")
            r.httpBody = Self.form(["grant_type": "refresh_token", "client_id": config.clientId, "refresh_token": refreshToken])
            guard let (data, resp) = try? await session.data(for: r), (resp as? HTTPURLResponse)?.statusCode == 200,
                  let body = try? Self.decoder.decode(KeycloakTokenResponse.self, from: data) else { return nil }
            let at = clock.epochMillis()
            var tokens = current
            tokens.accessToken = body.access_token
            tokens.refreshToken = body.refresh_token ?? current.refreshToken
            tokens.accessExpiresAt = at + (body.expires_in ?? 0) * 1000
            tokens.refreshExpiresAt = (body.refresh_expires_in ?? 0) > 0 ? at + (body.refresh_expires_in ?? 0) * 1000 : 0
            storage.save(tokens)
            return tokens
        }
        refreshing = task
        let result = await task.value
        refreshing = nil
        return result
    }

    static func form(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let s = fields.sorted { $0.key < $1.key }.map { k, v in
            "\(k.addingPercentEncoding(withAllowedCharacters: allowed) ?? k)=\(v.addingPercentEncoding(withAllowedCharacters: allowed) ?? v)"
        }.joined(separator: "&")
        return Data(s.utf8)
    }

    // MARK: - erros

    /// Traduz o status e o corpo do erro (o backend manda { code, message } no login e { message } no resto).
    public static func httpError(status: Int, body: Data?) -> AppError {
        let parsed = body.flatMap { try? decoder.decode(ErrorBody.self, from: $0) }
        let message = parsed?.message?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        switch parsed?.code {
        case "INVALID_CREDENTIALS": return .invalidCredentials(message ?? "E-mail ou senha incorretos.")
        case "ACCOUNT_BLOCKED": return .blocked(message ?? "Sua conta está bloqueada. Fale com o suporte.")
        case "SETUP_REQUIRED": return .blocked(message ?? "Termine o cadastro pelo link enviado ao seu e-mail.")
        case "ACCOUNT_DELETED": return .blocked(message ?? "Esta conta foi excluída. Para reativar, entre pela web em até 30 dias.")
        default: break
        }
        switch status {
        case 429: return .tooManyAttempts(retryAfterSeconds: parsed?.retryAfterSeconds)
        case 401: return .unauthorized
        case 404: return .notFound
        case 400..<500: return .validation(message ?? "Confira os dados e tente de novo.")
        case 503: return .server(message ?? "O serviço está indisponível agora. Tente em instantes.")
        default: return .server(message ?? "O servidor não respondeu como esperado. Tente de novo.")
        }
    }
}

struct ErrorBody: Decodable {
    var code: String?
    var message: String?
    var retryAfterSeconds: Int?
}

struct KeycloakTokenResponse: Decodable {
    var access_token: String
    var refresh_token: String?
    var expires_in: Int64?
    var refresh_expires_in: Int64?
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
