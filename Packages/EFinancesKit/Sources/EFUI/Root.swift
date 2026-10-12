import SwiftUI
import LocalAuthentication
import EFCore
import EFData
import EFFeatures
#if canImport(SafariServices)
import SafariServices
#endif

// MARK: - navegação

public enum AppTab: Hashable { case home, transactions, accounts, planning, more }

/// Telas empilhadas dentro de cada aba.
public enum Route: Hashable {
    case transaction(Int64, YearMonth?)
    case bankAccount(Int64)
    case reports, contacts, costCenters, companies, billing, profile, deleteAccount, help, appearance, security, about, notifications
    case categories(CategoryFilter)
    case ticket(Int64)
}

/// Página da web aberta dentro do app (importar, exportar, recibos, termos, conectar banco).
public struct WebPage: Identifiable, Hashable {
    public let title: String
    public let url: URL
    public var id: String { url.absoluteString }
}

/// Abas, pilhas de navegação e pedidos entre telas (ex.: "Ver contas" no Início abre Transações filtrada).
@MainActor @Observable
public final class Router {
    public var tab: AppTab = .home
    public var homePath = NavigationPath()
    public var transactionsPath = NavigationPath()
    public var accountsPath = NavigationPath()
    public var planningPath = NavigationPath()
    public var morePath = NavigationPath()
    /// Filtro pedido por outra tela para Transações.
    public var pendingFilter: TxFilters?
    public var planningTab: PlanningTab?
    /// Folha do lançamento (novo, editar ou organizar), aberta de qualquer tela.
    public var form: FormRequest?
    public var web: WebPage?
    public var showStory = false

    public init() {}

    public func open(_ tab: AppTab) { self.tab = tab }

    public func showTransactions(_ filters: TxFilters? = nil) {
        pendingFilter = filters
        transactionsPath = NavigationPath()
        tab = .transactions
    }

    public func showPlanning(_ t: PlanningTab) {
        planningTab = t
        planningPath = NavigationPath()
        tab = .planning
    }

    public func push(_ r: Route) {
        switch tab {
        case .home: homePath.append(r)
        case .transactions: transactionsPath.append(r)
        case .accounts: accountsPath.append(r)
        case .planning: planningPath.append(r)
        case .more: morePath.append(r)
        }
    }

    public func newTransaction(_ type: TransactionType = .variable, month: YearMonth? = nil, date: LocalDate? = nil) {
        form = FormRequest(id: nil, type: type, month: month, date: date)
    }

    public func edit(_ t: Tx) { form = FormRequest(id: t.id, type: t.type, month: t.date.yearMonth, date: nil) }
}

public struct FormRequest: Identifiable, Hashable {
    public let uuid = UUID()
    public var id: UUID { uuid }
    public let txId: Int64?
    public let type: TransactionType
    public let month: YearMonth?
    public let date: LocalDate?
    init(id: Int64?, type: TransactionType, month: YearMonth?, date: LocalDate?) { txId = id; self.type = type; self.month = month; self.date = date }
}

// MARK: - montagem do app

@MainActor
public enum AppFactory {
    /// Monta o estado do app para o ambiente do Info.plist (Demo, Local ou Produção).
    public static func make(bundle: Bundle = .main) -> AppModel {
        EFFonts.register()
        let config = AppConfig.fromBundle(bundle, system: DeviceInfo.system, model: DeviceInfo.model)
        let suffix = config.demo ? ".demo" : config.envLabel.isEmpty ? "" : ".\(config.envLabel.lowercased())"
        let storage = KeychainTokenStorage(service: "top.efinances.app.session\(suffix)")
        let settings = SettingsStore()
        let holder = ExpiryHolder()
        let repos: Repositories = config.demo
            ? .demo(storage: storage)
            : .remote(config: config, storage: storage, onExpired: { Task { @MainActor in holder.app?.sessionExpired() } })
        let app = AppModel(repos: repos, settings: settings, demo: config.demo, envLabel: config.demo ? "Demonstração" : config.envLabel, webURL: config.webURL)
        holder.app = app
        return app
    }

    /// Estado com os dados de exemplo (pré-visualizações e testes de tela).
    public static func preview() -> AppModel {
        AppModel(repos: .demo(storage: MemoryTokenStorage()), settings: SettingsStore(defaults: UserDefaults(suiteName: "preview") ?? .standard),
                 demo: true, envLabel: "Demonstração", webURL: URL(string: "https://efinances.top/")!)
    }
}

/// O cliente da API avisa "sessão encerrada" de fora da MainActor; isto leva o aviso até o AppModel.
@MainActor final class ExpiryHolder { weak var app: AppModel? }

/// Face ID / Touch ID / código do iPhone.
public enum DeviceAuth {
    public static var available: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) }

    public static var biometryName: String {
        let c = LAContext()
        _ = c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch c.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "código do iPhone"
        }
    }

    public static var symbol: String {
        let c = LAContext()
        _ = c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch c.biometryType { case .touchID: return "touchid"; case .opticID: return "opticid"; default: return "faceid" }
    }

    public static func authenticate(_ reason: String = "Desbloquear o e-Finances") async -> Bool {
        await withCheckedContinuation { cont in
            LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in cont.resume(returning: ok) }
        }
    }
}

// MARK: - raiz

public struct RootView: View {
    @State private var app: AppModel
    @State private var router = Router()
    @Environment(\.scenePhase) private var scenePhase
    @State private var covered = false

    public init(app: AppModel) { _app = State(initialValue: app) }

    /// O que cobre o app agora: a tela de bloqueio, a capa do alternador de apps ou nada.
    private var shield: ShieldState {
        if app.locked { return .lock }
        if covered && app.settings.coverInSwitcher && app.session.isLoggedIn { return .cover }
        return .none
    }

    public var body: some View {
        ZStack {
            Color.efBackground.ignoresSafeArea()
            if !app.ready {
                SplashView()
            } else if !app.session.isLoggedIn {
                AuthFlow()
            } else {
                MainTabs()
            }
            #if !os(iOS)
            if app.locked { LockView().transition(.opacity).zIndex(2) }
            if covered && app.settings.coverInSwitcher && app.session.isLoggedIn { PrivacyCover().zIndex(3) }
            #endif
            ToastOverlay().zIndex(4)
        }
        .environment(app)
        .environment(router)
        .tint(.efTint)
        .formStyle(.grouped)
        .preferredColorScheme(app.settings.theme == .light ? .light : app.settings.theme == .dark ? .dark : nil)
        .animation(.easeInOut(duration: 0.25), value: app.session)
        .animation(.easeInOut(duration: 0.2), value: app.locked)
        .task { await app.start(deviceLockAvailable: DeviceAuth.available) }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                covered = true
                app.didEnterBackground()
            case .inactive:
                covered = true
            case .active:
                covered = false
                app.didBecomeActive(deviceLockAvailable: DeviceAuth.available)
            @unknown default: break
            }
        }
        #if os(iOS)
        // bloqueio e capa numa janela própria, acima das barras, das folhas e dos alertas do app
        .onChange(of: shield) { _, s in Shield.shared.update(s, app: app, router: router) }
        #endif
        .onChange(of: app.session) { _, s in if !s.isLoggedIn { router = Router() } }
        .onChange(of: app.pendingStory) { _, s in if s != nil && !app.locked { router.showStory = true } }
        .efFullScreen(isPresented: $router.showStory) { StoryView(story: app.pendingStory).environment(app).environment(router) }
        .sheet(item: $router.form) { req in
            TransactionFormView(request: req).efToasts().environment(app).environment(router)
        }
        .sheet(item: $router.web) { page in WebSheet(page: page) }
        // por fora das folhas, para elas herdarem (o que está dentro da ZStack não chega nelas)
        .tint(.efTint)
        .formStyle(.grouped)
    }
}

enum ShieldState: Equatable { case none, lock, cover }

#if os(iOS)
/**
 Janela por cima de tudo para o bloqueio e a capa do alternador de apps. Na mesma janela do app, a barra de navegação,
 a barra de abas e as folhas abertas ficariam por cima da tela de bloqueio.
 */
@MainActor
final class Shield {
    static let shared = Shield()
    private var window: UIWindow?
    private var state: ShieldState = .none

    func update(_ new: ShieldState, app: AppModel, router: Router) {
        guard new != state else { return }
        state = new
        switch new {
        case .none:
            window?.isHidden = true
            window = nil
        case .lock, .cover:
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
            let w = window ?? UIWindow(windowScene: scene)
            w.windowLevel = .alert + 1
            let content = Group {
                if new == .lock { LockView() } else { PrivacyCover() }
            }
            .environment(app)
            .environment(router)
            .tint(.efTint)
            .preferredColorScheme(app.settings.theme == .light ? .light : app.settings.theme == .dark ? .dark : nil)
            let host = UIHostingController(rootView: AnyView(content))
            host.view.backgroundColor = .clear
            w.rootViewController = host
            w.isHidden = false
            window = w
        }
    }
}
#endif

/// Abertura: marca enquanto o app confere a sessão guardada.
struct SplashView: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [.efNavy2, .efNavy], center: .init(x: 0.5, y: 0.38), startRadius: 0, endRadius: 420).ignoresSafeArea()
            VStack(spacing: 16) {
                EFLogo(size: 96, onDark: true)
                (Text("e") + Text("·").foregroundColor(.efGreen) + Text("finances")).font(.sora(30, .semibold)).foregroundStyle(.white)
            }
        }
        .accessibilityLabel("e-Finances")
    }
}

/// Cobre os valores no alternador de apps.
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            // fundo sólido: o desfoque ainda deixava os valores grandes legíveis
            Color.efBackground.ignoresSafeArea()
            EFLogo(size: 72)
        }
    }
}

/// Desbloqueio com Face ID (ou o código do iPhone).
struct LockView: View {
    @Environment(AppModel.self) private var app
    @State private var failed = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            EFLogo(size: 64)
            VStack(spacing: 6) {
                Text("Olá, \(app.profile?.firstName ?? "")").font(.sora(28, .bold))
                Text("O e-Finances está bloqueado").foregroundStyle(Color.secondary)
            }
            Spacer()
            Button {
                Task { await unlock() }
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: DeviceAuth.symbol).font(.system(size: 54, weight: .light))
                    Text("Usar \(DeviceAuth.biometryName)").font(.headline)
                }
            }
            .tint(.efTint)
            if failed { Text("Não deu para confirmar. Tente de novo.").font(.footnote).foregroundStyle(Color.efExpense) }
            Button("Não é você? Sair", role: .destructive) { Task { await app.logout() } }.font(.subheadline).padding(.bottom, 24)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.efBackground.ignoresSafeArea())
        .task { await unlock() }
    }

    private func unlock() async {
        if await DeviceAuth.authenticate() { failed = false; app.unlock() } else { failed = true }
    }
}

// MARK: - abas

struct MainTabs: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            NavigationStack(path: $router.homePath) { HomeView().routes() }
                .tabItem { Label("Início", systemImage: "house") }.tag(AppTab.home)
            NavigationStack(path: $router.transactionsPath) { TransactionsView().routes() }
                .tabItem { Label("Transações", systemImage: "list.bullet.rectangle.portrait") }.tag(AppTab.transactions)
            NavigationStack(path: $router.accountsPath) { AccountsView().routes() }
                .tabItem { Label("Contas", systemImage: "building.columns") }.tag(AppTab.accounts)
            NavigationStack(path: $router.planningPath) { PlanningView().routes() }
                .tabItem { Label("Planejar", systemImage: "chart.pie") }.tag(AppTab.planning)
            NavigationStack(path: $router.morePath) { MoreView().routes() }
                .tabItem { Label("Mais", systemImage: "ellipsis") }.tag(AppTab.more)
                .badge(Int(app.unread))
        }
        .efMinimizingTabBar()
    }
}

extension View {
    /// Destinos das telas empilhadas (iguais em todas as abas).
    func routes() -> some View {
        navigationDestination(for: Route.self) { r in
            switch r {
            case .transaction(let id, let month): TransactionDetailView(id: id, month: month)
            case .bankAccount(let id): BankAccountView(accountId: id)
            case .reports: ReportsView()
            case .contacts: ContactsView()
            case .costCenters: CostCentersView()
            case .companies: CompaniesView()
            case .billing: BillingView()
            case .profile: ProfileView()
            case .deleteAccount: AccountDeletionView()
            case .help: HelpView()
            case .appearance: AppearanceView()
            case .security: SecurityView()
            case .about: AboutView()
            case .notifications: NotificationsView()
            case .categories(let f): CategoriesView(filter: f)
            case .ticket(let id): TicketView(id: id)
            }
        }
    }
}

// MARK: - páginas da web

/// Abre a página da web dentro do app (Safari), já que importar, exportar e recibos ficam na web.
struct WebSheet: View {
    let page: WebPage
    var body: some View {
        #if os(iOS)
        SafariView(url: page.url).ignoresSafeArea()
        #else
        VStack(spacing: 16) {
            Text(page.title).font(.headline)
            Link("Abrir \(page.url.host ?? "")", destination: page.url)
        }
        .padding(40)
        #endif
    }
}

#if os(iOS)
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let c = SFSafariViewController(url: url)
        c.preferredControlTintColor = UIColor(hex: 0x047857)
        c.dismissButtonStyle = .close
        return c
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
#endif

extension AppModel {
    func page(_ title: String, _ path: String) -> WebPage { WebPage(title: title, url: web(path)) }
}
