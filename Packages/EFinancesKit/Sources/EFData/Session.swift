import Foundation
import Security
import EFCore

/// Ambiente do app (vem do Info.plist, preenchido pelos .xcconfig de cada esquema: Demo, Local e Produção).
public struct AppConfig: Sendable {
    public var apiBaseURL: URL
    public var tokenURL: URL
    public var webURL: URL
    public var clientId: String
    /// Modo demonstração: dados de exemplo no próprio iPhone, sem servidor.
    public var demo: Bool
    /// "Local", "Demo" ou vazio (produção): aparece discreto no app para não confundir os ambientes.
    public var envLabel: String
    public var appVersion: String
    public var userAgent: String

    public init(apiBaseURL: URL, tokenURL: URL, webURL: URL, clientId: String = "finances-client", demo: Bool, envLabel: String, appVersion: String, userAgent: String) {
        self.apiBaseURL = apiBaseURL; self.tokenURL = tokenURL; self.webURL = webURL; self.clientId = clientId
        self.demo = demo; self.envLabel = envLabel; self.appVersion = appVersion; self.userAgent = userAgent
    }

    /// Produção: API, Keycloak (/auth) e web no mesmo domínio.
    public static func production(appVersion: String = "1.0.0", system: String = "iOS", model: String = "iPhone") -> AppConfig {
        let base = URL(string: "https://efinances.top/")!
        return AppConfig(apiBaseURL: base, tokenURL: URL(string: "https://efinances.top/auth/realms/finances-realm/protocol/openid-connect/token")!,
                         webURL: base, demo: false, envLabel: "", appVersion: appVersion, userAgent: userAgent(appVersion, system: system, model: model))
    }

    /// Lê as chaves EFApiBaseURL, EFTokenURL, EFWebURL, EFDemo e EFEnvLabel do Info.plist.
    public static func fromBundle(_ bundle: Bundle = .main, system: String, model: String) -> AppConfig {
        let info = bundle.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "1.0.0"
        func url(_ key: String) -> URL? { (info[key] as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) } }
        let prod = production(appVersion: version, system: system, model: model)
        return AppConfig(
            apiBaseURL: url("EFApiBaseURL") ?? prod.apiBaseURL,
            tokenURL: url("EFTokenURL") ?? prod.tokenURL,
            webURL: url("EFWebURL") ?? prod.webURL,
            demo: (info["EFDemo"] as? String) == "YES" || (info["EFDemo"] as? Bool) == true,
            envLabel: info["EFEnvLabel"] as? String ?? "",
            appVersion: version,
            userAgent: userAgent(version, system: system, model: model)
        )
    }

    /// "e-Finances/1.0.0 (iOS 26.1; iPhone)": o backend usa no aviso de novo acesso e na auditoria.
    public static func userAgent(_ version: String, system: String, model: String) -> String {
        let clean = model.unicodeScalars.filter { $0.value >= 0x20 && $0.value <= 0x7e }.map(String.init).joined().trimmingCharacters(in: .whitespaces)
        return "e-Finances/\(version) (\(system); \(clean.isEmpty ? "iPhone" : clean))"
    }

    /// Endereço de uma página da web (importar, exportar, recibos, termos).
    public func web(_ path: String) -> URL {
        URL(string: webURL.absoluteString.droppingSuffix("/") + "/" + path.droppingPrefix("/")) ?? webURL
    }
}

extension String {
    func droppingSuffix(_ s: String) -> String { hasSuffix(s) ? String(dropLast(s.count)) : self }
    func droppingPrefix(_ s: String) -> String { hasPrefix(s) ? String(dropFirst(s.count)) : self }
}

/// Tokens da sessão. Os instantes de expiração são em milissegundos desde 1970 (0 = sem prazo).
public struct SessionTokens: Codable, Equatable, Sendable {
    public var accessToken: String
    public var refreshToken: String?
    public var accessExpiresAt: Int64
    public var refreshExpiresAt: Int64
    public var email: String

    public init(accessToken: String, refreshToken: String?, accessExpiresAt: Int64, refreshExpiresAt: Int64, email: String) {
        self.accessToken = accessToken; self.refreshToken = refreshToken; self.accessExpiresAt = accessExpiresAt
        self.refreshExpiresAt = refreshExpiresAt; self.email = email
    }

    /// Renova 30 s antes de vencer, como o keycloak-js da web (updateToken(30)).
    public func accessNeedsRefresh(_ nowMillis: Int64) -> Bool { nowMillis >= accessExpiresAt - 30_000 }

    public func canRefresh(_ nowMillis: Int64) -> Bool { refreshToken != nil && (refreshExpiresAt == 0 || nowMillis < refreshExpiresAt) }

    /// Sessão que ainda serve: o access vale ou dá para renovar.
    public func usable(_ nowMillis: Int64) -> Bool { !accessNeedsRefresh(nowMillis) || canRefresh(nowMillis) }
}

/// Onde a sessão fica guardada.
public protocol TokenStorage: Sendable {
    func load() -> SessionTokens?
    func save(_ tokens: SessionTokens)
    func clear()
}

/// Sessão no Keychain do iPhone: cifrada pelo sistema, só neste aparelho e só com ele desbloqueado
/// (não vai para backups nem para outro iPhone).
public final class KeychainTokenStorage: TokenStorage, @unchecked Sendable {
    private let service: String
    private let account = "session"
    private let lock = NSLock()
    private var cached: SessionTokens?
    private var loaded = false

    public init(service: String) { self.service = service }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    public func load() -> SessionTokens? {
        lock.lock(); defer { lock.unlock() }
        if loaded { return cached }
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        if SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data {
            cached = try? JSONDecoder().decode(SessionTokens.self, from: data)
        }
        loaded = true
        return cached
    }

    public func save(_ tokens: SessionTokens) {
        lock.lock(); defer { lock.unlock() }
        cached = tokens
        loaded = true
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        cached = nil
        loaded = true
        SecItemDelete(query as CFDictionary)
    }
}

/// Sessão só na memória (testes).
public final class MemoryTokenStorage: TokenStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: SessionTokens?
    public init(_ tokens: SessionTokens? = nil) { self.tokens = tokens }
    public func load() -> SessionTokens? { lock.lock(); defer { lock.unlock() }; return tokens }
    public func save(_ t: SessionTokens) { lock.lock(); tokens = t; lock.unlock() }
    public func clear() { lock.lock(); tokens = nil; lock.unlock() }
}
