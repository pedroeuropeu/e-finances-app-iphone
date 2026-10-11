import Foundation
import Observation
import EFCore

/// Estado de carregamento de uma tela.
public enum Loadable<T> {
    case loading
    case ready(T)
    case failed(AppError)

    public var value: T? { if case .ready(let v) = self { return v } else { return nil } }
    public var error: AppError? { if case .failed(let e) = self { return e } else { return nil } }
    public var isLoading: Bool { if case .loading = self { return true } else { return false } }

    /// Mantém o que já estava na tela quando a recarga falha (o erro vira um aviso).
    public func keeping(_ new: Outcome<T>) -> Loadable<T> {
        switch new {
        case .success(let v): return .ready(v)
        case .failure(let e): return value.map { .ready($0) } ?? .failed(e)
        }
    }
}

// MARK: - avisos

/**
 Avisos do app (um por vez; o novo substitui o anterior), como na web. Sobrevivem à troca de tela: o que roda depois do
 aviso (excluir de verdade, desfazer) não depende da tela que já pode ter sido fechada.
 */
@MainActor @Observable
public final class Messenger {
    public struct Message: Identifiable, Equatable {
        public let id = UUID()
        public let text: String
        public let action: String?
        public let icon: String?
        public static func == (a: Message, b: Message) -> Bool { a.id == b.id }
    }

    public private(set) var current: Message?
    private var onAction: (() -> Void)?
    private var onDismiss: (() -> Void)?
    private var timer: Task<Void, Never>?

    public init() {}

    public func show(_ text: String, icon: String? = nil, action: String? = nil, onAction: (() -> Void)? = nil) {
        present(Message(text: text, action: action, icon: icon), onAction: onAction, onDismiss: nil)
    }

    /// Exclusão adiada (como o Gmail): o item já saiu da tela e o aviso oferece "Desfazer". O servidor só recebe
    /// ([commit]) quando o aviso some sem "Desfazer"; se falhar, [undo] devolve o item e o erro aparece.
    public func deferred(_ text: String, undo: @escaping @MainActor () async -> Void, commit: @escaping @MainActor () async -> Outcome<Void>) {
        present(Message(text: text, action: "Desfazer", icon: "trash"), onAction: { Task { await undo() } }, onDismiss: { [weak self] in
            Task { @MainActor in
                if case .failure(let e) = await commit() {
                    await undo()
                    self?.show(e.message, icon: "exclamationmark.circle")
                }
            }
        })
    }

    /// Já excluiu no servidor; "Desfazer" chama [restore] e, dando certo, [onRestored] (a tela recarrega).
    public func undoable(_ text: String, restore: @escaping @MainActor () async -> Outcome<Void>, onRestored: @escaping @MainActor () -> Void = {}) {
        show(text, icon: "trash", action: "Desfazer") { [weak self] in
            Task { @MainActor in
                switch await restore() {
                case .success: onRestored()
                case .failure(let e): self?.show(e.message, icon: "exclamationmark.circle")
                }
            }
        }
    }

    private func present(_ m: Message, onAction: (() -> Void)?, onDismiss: (() -> Void)?) {
        settle(acted: false)
        current = m
        self.onAction = onAction
        self.onDismiss = onDismiss
        timer?.cancel()
        let id = m.id
        let seconds: UInt64 = m.action != nil ? 5 : 3
        timer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.expire(id)
        }
    }

    private func expire(_ id: UUID) { if current?.id == id { settle(acted: false) } }

    /// A pessoa tocou na ação do aviso.
    public func act() { settle(acted: true) }

    /// O aviso sumiu (tempo, arrastado para fora ou outro por cima).
    public func dismiss() { settle(acted: false) }

    /// Ação ou fim do aviso: o primeiro que chegar vale.
    private func settle(acted: Bool) {
        guard current != nil else { return }
        let a = onAction, d = onDismiss
        current = nil
        onAction = nil
        onDismiss = nil
        timer?.cancel()
        if acted { a?() } else { d?() }
    }

    /// Ao ir para segundo plano: confirma o que está pendente (exclusões adiadas vão ao servidor).
    public func flush() { settle(acted: false) }
}

// MARK: - preferências

public enum ThemeMode: String, CaseIterable, Sendable {
    case system, light, dark
    public var label: String { switch self { case .system: "Automático"; case .light: "Claro"; case .dark: "Escuro" } }
}

/// Preferências locais (UserDefaults). Nada sensível fica aqui: a sessão vai no Keychain.
@MainActor @Observable
public final class SettingsStore {
    private let defaults: UserDefaults

    public var theme: ThemeMode { didSet { defaults.set(theme.rawValue, forKey: "theme") } }
    public var hideValues: Bool { didSet { defaults.set(hideValues, forKey: "hideValues") } }
    public var hideOnOpen: Bool { didSet { defaults.set(hideOnOpen, forKey: "hideOnOpen") } }
    public var lockEnabled: Bool { didSet { defaults.set(lockEnabled, forKey: "lockEnabled") } }
    public var lockTimeoutMinutes: Int { didSet { defaults.set(lockTimeoutMinutes, forKey: "lockTimeout") } }
    /// Cobre os valores no alternador de apps.
    public var coverInSwitcher: Bool { didSet { defaults.set(coverInSwitcher, forKey: "coverInSwitcher") } }
    public var onboardingDone: Bool { didSet { defaults.set(onboardingDone, forKey: "onboardingDone") } }
    public var lastEmail: String { didSet { defaults.set(lastEmail, forKey: "lastEmail") } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = ThemeMode(rawValue: defaults.string(forKey: "theme") ?? "") ?? .system
        hideOnOpen = defaults.bool(forKey: "hideOnOpen")
        hideValues = defaults.object(forKey: "hideValues") as? Bool ?? false
        lockEnabled = defaults.object(forKey: "lockEnabled") as? Bool ?? true
        lockTimeoutMinutes = defaults.object(forKey: "lockTimeout") as? Int ?? 5
        coverInSwitcher = defaults.object(forKey: "coverInSwitcher") as? Bool ?? true
        onboardingDone = defaults.bool(forKey: "onboardingDone")
        lastEmail = defaults.string(forKey: "lastEmail") ?? ""
        // ao abrir o app: volta a esconder os valores se a pessoa pediu isso
        if hideOnOpen { hideValues = true }
    }
}

// MARK: - estado do app

/**
 Estado compartilhado por todas as telas: sessão, empresa e conta em uso, perfil, avisos, bloqueio e as versões que
 avisam as telas para recarregar (lançamento salvo, conta trocada).
 */
@MainActor @Observable
public final class AppModel {
    public let repos: Repositories
    public let clock: AppClock
    public let settings: SettingsStore
    public let messenger: Messenger
    public let demo: Bool
    public let envLabel: String
    public let webURL: URL

    public private(set) var session: SessionState = .unknown
    public private(set) var logoutReason: LogoutReason = .none
    public private(set) var workspace: Workspace?
    public private(set) var profile: UserProfile?
    public var unread: Int64 = 0
    /// Fechamento do mês para mostrar depois do login (stories).
    public var pendingStory: Story?
    /// Mudou um lançamento (salvo, pago, excluído): as listas recarregam.
    public private(set) var dataVersion = 0
    /// Trocou a conta em uso: as telas que dependem dela recarregam.
    public private(set) var workspaceVersion = 0

    // bloqueio (Face ID / código do iPhone)
    public private(set) var locked = false
    public private(set) var ready = false
    private var backgroundedAt: Date?

    public init(repos: Repositories, clock: AppClock = SystemClock(), settings: SettingsStore, messenger: Messenger = Messenger(),
                demo: Bool, envLabel: String, webURL: URL) {
        self.repos = repos; self.clock = clock; self.settings = settings; self.messenger = messenger
        self.demo = demo; self.envLabel = envLabel; self.webURL = webURL
    }

    public var account: Account? { workspace?.account }
    public var company: Company? { workspace?.company }
    public var mode: AccountMode { workspace?.mode ?? .manual }
    public var currency: String { account?.currency ?? "BRL" }
    public var canLaunch: Bool { mode == .manual }

    public func web(_ path: String) -> URL {
        URL(string: webURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) ?? webURL
    }

    /// Abertura: recupera a sessão do Keychain e decide se abre bloqueado.
    public func start(deviceLockAvailable: Bool) async {
        let s = await repos.auth.restore()
        session = s
        locked = s.isLoggedIn && settings.lockEnabled && deviceLockAvailable
        ready = true
        if s.isLoggedIn { await afterLogin(showStory: false) }
    }

    public func didLogin(email: String) async {
        settings.lastEmail = email
        logoutReason = .none
        session = .loggedIn(email: email)
        await afterLogin(showStory: true)
    }

    private func afterLogin(showStory: Bool) async {
        async let ws = repos.workspaces.refresh()
        async let p = repos.users.profile()
        async let n = repos.notifications.list(unreadOnly: true)
        async let st = repos.stories.pending()
        if let w = await ws.value { workspace = w }
        profile = await p.value
        unread = await n.value?.unread ?? unread
        if showStory, let story = await st.value ?? nil { pendingStory = story } else { _ = await st }
    }

    public func logout() async {
        messenger.flush()
        await repos.auth.logout()
        reset(.user)
    }

    /// Refresh recusado ou sessão encerrada pelo servidor: volta ao login avisando.
    public func sessionExpired() {
        guard session.isLoggedIn else { return }
        reset(.expired)
        messenger.show("Sua sessão terminou. Entre de novo.", icon: "lock")
    }

    private func reset(_ reason: LogoutReason) {
        session = .loggedOut(reason)
        logoutReason = reason
        workspace = nil
        profile = nil
        unread = 0
        pendingStory = nil
        locked = false
    }

    public func refreshWorkspace() async {
        if case .success(let w) = await repos.workspaces.refresh() { workspace = w }
    }

    /// Passa a usar outra empresa/conta (vale na web também: a escolha fica no servidor).
    @discardableResult
    public func select(companyId: Int64, accountId: Int64, announce: Bool = true) async -> Bool {
        if workspace?.account?.id == accountId && workspace?.company?.id == companyId { return true }
        switch await repos.workspaces.select(companyId: companyId, accountId: accountId) {
        case .success(let w):
            workspace = w
            workspaceVersion += 1
            dataVersion += 1
            if announce { messenger.show("Agora em \(w.company?.name ?? "") · \(w.account?.name ?? "")", icon: w.mode == .manual ? "wallet.bifold" : "building.columns") }
            return true
        case .failure(let e):
            messenger.show(e.message, icon: "exclamationmark.circle")
            return false
        }
    }

    /// Algum lançamento mudou: listas, Início e Planejar recarregam (e o saldo da conta).
    public func transactionsChanged() {
        dataVersion += 1
        Task { await refreshWorkspace() }
    }

    public func refreshUnread() async {
        if case .success(let page) = await repos.notifications.list(unreadOnly: true) { unread = page.unread }
    }

    public func toggleHide() { settings.hideValues.toggle() }

    // MARK: bloqueio

    public func didEnterBackground() {
        backgroundedAt = clock.now()
        messenger.flush()
    }

    public func didBecomeActive(deviceLockAvailable: Bool) {
        guard let since = backgroundedAt else { return }
        backgroundedAt = nil
        let elapsed = clock.now().timeIntervalSince(since)
        if session.isLoggedIn && settings.lockEnabled && deviceLockAvailable && elapsed >= Double(settings.lockTimeoutMinutes * 60) { locked = true }
    }

    public func unlock() { locked = false }
    public func lockNow() { if session.isLoggedIn { locked = true } }
}
