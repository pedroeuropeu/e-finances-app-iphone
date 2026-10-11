import Testing
import Foundation
@testable import EFCore
@testable import EFData

/// Relógio fixo em milissegundos (a sessão compara instantes).
struct MillisClock: AppClock {
    let millis: Int64
    func now() -> Date { Date(timeIntervalSince1970: Double(millis) / 1000) }
}

final class ExpiredFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func hit() { lock.lock(); value += 1; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
}

@Suite("Cliente da API")
struct NetworkTests {
    let config = AppConfig.production(appVersion: "1.0.0", system: "iOS 26.0", model: "iPhone17,1")
    let now: Int64 = 1_800_000_000_000

    func tokens(accessValidFor ms: Int64 = 600_000, refresh: String? = "rt-1") -> SessionTokens {
        SessionTokens(accessToken: "at-1", refreshToken: refresh, accessExpiresAt: now + ms, refreshExpiresAt: now + 3_600_000, email: "pedro@exemplo.com")
    }

    @Test func sendsBearerUserAgentAndDecodes() async throws {
        let (session, server) = StubURLProtocol.session()
        server.on("GET", "/api/workspace", .init(status: 200, body: #"{"companyId":1,"accountId":11,"companies":[{"id":1,"name":"Casa","type":"FAMILY","accounts":[{"id":11,"name":"Conta corrente","balance":8432.17,"defaultAccount":true}]}]}"#))
        let storage = MemoryTokenStorage(tokens())
        let api = APIClient(config: config, session: session, storage: storage, clock: MillisClock(millis: now))
        let ws = await RemoteWorkspaceRepository(api: api).refresh().value
        #expect(ws?.account?.name == "Conta corrente")
        #expect(ws?.account?.balance == Decimal(string: "8432.17"))
        let r = try #require(server.requests.first)
        #expect(r.value(forHTTPHeaderField: "Authorization") == "Bearer at-1")
        #expect(r.value(forHTTPHeaderField: "User-Agent") == "e-Finances/1.0.0 (iOS 26.0; iPhone17,1)")
        #expect(r.url?.absoluteString == "https://efinances.top/api/workspace")
    }

    @Test func refreshesBeforeExpiryOnlyOnce() async throws {
        let (session, server) = StubURLProtocol.session()
        server.on("POST", "/auth/realms/finances-realm/protocol/openid-connect/token",
                  .init(status: 200, body: #"{"access_token":"at-2","refresh_token":"rt-2","expires_in":300,"refresh_expires_in":1800}"#))
        server.on("GET", "/api/notifications/unread-count", .init(status: 200, body: #"{"unread":3}"#))
        // vence em 10 s: renova antes (margem de 30 s, como o keycloak-js)
        let storage = MemoryTokenStorage(tokens(accessValidFor: 10_000))
        let api = APIClient(config: config, session: session, storage: storage, clock: MillisClock(millis: now))
        async let a: Outcome<UnreadDTO> = api.call(.get, "api/notifications/unread-count")
        async let b: Outcome<UnreadDTO> = api.call(.get, "api/notifications/unread-count")
        let (ra, rb) = await (a, b)
        #expect(ra.value?.unread == 3 && rb.value?.unread == 3)
        #expect(server.paths.filter { $0.hasPrefix("POST /auth") }.count == 1)
        let refresh = try #require(server.requests.first { $0.url?.path.hasPrefix("/auth") == true })
        let body = String(data: refresh.httpBody ?? Data(), encoding: .utf8) ?? ""
        #expect(body.contains("grant_type=refresh_token"))
        #expect(body.contains("client_id=finances-client"))
        #expect(body.contains("refresh_token=rt-1"))
        #expect(storage.load()?.accessToken == "at-2")
        #expect(storage.load()?.accessExpiresAt == now + 300_000)
        #expect(server.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer at-2")
    }

    @Test func retriesOnceAfter401WithRenewedToken() async {
        let (session, server) = StubURLProtocol.session()
        server.on("GET", "/api/story", .init(status: 401, body: "{}"), .init(status: 200, body: #"{"periodKey":"M:2026-09","income":100}"#))
        server.on("POST", "/auth/realms/finances-realm/protocol/openid-connect/token", .init(status: 200, body: #"{"access_token":"at-2","expires_in":300}"#))
        let storage = MemoryTokenStorage(tokens())
        let api = APIClient(config: config, session: session, storage: storage, clock: MillisClock(millis: now))
        let story = await RemoteStoryRepository(api: api).latest().value
        #expect(story?.periodKey == "M:2026-09")
        #expect(story?.income == 100)
        #expect(storage.load()?.refreshToken == "rt-1") // sem refresh novo, mantém o anterior
    }

    @Test func sessionEndedByServerLogsOut() async {
        let (session, server) = StubURLProtocol.session()
        server.on("GET", "/api/workspace", .init(status: 401, body: #"{"code":"SESSION_ENDED","message":"Sessão encerrada"}"#))
        let storage = MemoryTokenStorage(tokens())
        let flag = ExpiredFlag()
        let api = APIClient(config: config, session: session, storage: storage, clock: MillisClock(millis: now), onExpired: { flag.hit() })
        let r = await RemoteWorkspaceRepository(api: api).refresh()
        #expect(r.error == .unauthorized)
        #expect(flag.count == 1)
        #expect(!server.paths.contains { $0.hasPrefix("POST /auth") })
    }

    @Test func refusedRefreshExpiresSession() async {
        let (session, server) = StubURLProtocol.session()
        server.on("GET", "/api/workspace", .init(status: 401, body: "{}"))
        server.on("POST", "/auth/realms/finances-realm/protocol/openid-connect/token", .init(status: 400, body: #"{"error":"invalid_grant"}"#))
        let flag = ExpiredFlag()
        let api = APIClient(config: config, session: session, storage: MemoryTokenStorage(tokens()), clock: MillisClock(millis: now), onExpired: { flag.hit() })
        #expect(await RemoteWorkspaceRepository(api: api).refresh().error == .unauthorized)
        #expect(flag.count == 1)
    }

    @Test func loginStoresTokensAndTranslatesErrors() async {
        let (session, server) = StubURLProtocol.session()
        server.on("POST", "/public/auth/login",
                  .init(status: 401, body: #"{"code":"INVALID_CREDENTIALS","message":"E-mail ou senha incorretos."}"#),
                  .init(status: 429, body: #"{"code":"TOO_MANY","retryAfterSeconds":120}"#),
                  .init(status: 200, body: #"{"accessToken":"at","refreshToken":"rt","expiresIn":300,"refreshExpiresIn":1800}"#))
        let storage = MemoryTokenStorage()
        let api = APIClient(config: config, session: session, storage: storage, clock: MillisClock(millis: now))
        let auth = RemoteAuthRepository(api: api, storage: storage, clock: MillisClock(millis: now))
        #expect(await auth.login(email: " Pedro@Exemplo.com ", password: "x", remember: true).error == .invalidCredentials("E-mail ou senha incorretos."))
        let many = await auth.login(email: "pedro@exemplo.com", password: "x", remember: true).error
        #expect(many?.message == "Muitas tentativas. Tente de novo em 2 min.")
        #expect(await auth.login(email: " Pedro@Exemplo.com ", password: "x", remember: true).value == "pedro@exemplo.com")
        #expect(storage.load()?.refreshExpiresAt == now + 1_800_000)
        let body = String(data: server.requests.last?.httpBody ?? Data(), encoding: .utf8) ?? ""
        #expect(body.contains(#""email":"pedro@exemplo.com""#))
        #expect(server.requests.last?.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(await auth.restore() == .loggedIn(email: "pedro@exemplo.com"))
    }

    @Test func httpErrorTranslation() {
        func err(_ status: Int, _ body: String) -> AppError { APIClient.httpError(status: status, body: Data(body.utf8)) }
        #expect(err(400, #"{"message":"Valor inválido"}"#) == .validation("Valor inválido"))
        #expect(err(400, "") == .validation("Confira os dados e tente de novo."))
        #expect(err(404, "") == .notFound)
        #expect(err(403, #"{"code":"ACCOUNT_BLOCKED"}"#) == .blocked("Sua conta está bloqueada. Fale com o suporte."))
        #expect(err(503, "") == .server("O serviço está indisponível agora. Tente em instantes."))
        #expect(err(500, "<html>") == .server("O servidor não respondeu como esperado. Tente de novo."))
    }

    @Test func networkFailureIsFriendly() async {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 2
        let api = APIClient(config: AppConfig(apiBaseURL: URL(string: "http://127.0.0.1:9/")!, tokenURL: URL(string: "http://127.0.0.1:9/t")!,
                                              webURL: URL(string: "http://127.0.0.1:9/")!, demo: false, envLabel: "", appVersion: "1", userAgent: "t"),
                            session: URLSession(configuration: cfg), storage: MemoryTokenStorage(), clock: MillisClock(millis: now))
        let r: Outcome<UnreadDTO> = await api.call(.get, "api/x", authenticated: false)
        #expect(r.error == .network)
        #expect(AppError.network.message == "Sem conexão. Confira a internet e tente de novo.")
    }

    @Test func expiredStoredSessionIsDiscarded() async {
        let old = SessionTokens(accessToken: "a", refreshToken: "r", accessExpiresAt: now - 10_000, refreshExpiresAt: now - 1, email: "x@y.com")
        let storage = MemoryTokenStorage(old)
        let (session, _) = StubURLProtocol.session()
        let api = APIClient(config: config, session: session, storage: storage, clock: MillisClock(millis: now))
        let auth = RemoteAuthRepository(api: api, storage: storage, clock: MillisClock(millis: now))
        #expect(await auth.restore() == .loggedOut(.none))
        #expect(storage.load() == nil)
    }

    @Test func webPathsAndQueryEncoding() {
        #expect(config.web("/finances/import").absoluteString == "https://efinances.top/finances/import")
        #expect(String(data: APIClient.form(["a": "1+2", "b": "x y"]), encoding: .utf8) == "a=1%2B2&b=x%20y")
    }
}
