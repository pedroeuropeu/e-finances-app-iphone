import Foundation
import Observation
import EFCore

// MARK: - Contas (bancos conectados + contas do e-Finances)

public struct AccountsData: Sendable {
    public var connections: [BankConnection]
    public var subscriptions: Subscriptions?
    public var workspace: Workspace?
    public var now: LocalDateTime

    private var all: [BankAccount] { connections.flatMap(\.accounts) }
    /// Contas lançadas à mão (todas as empresas), com a empresa de cada uma.
    public var manualAccounts: [(Company, Account)] { (workspace?.companies ?? []).flatMap { c in c.accounts.filter { $0.mode == .manual }.map { (c, $0) } } }
    /// Contas de bancos já desconectados que ficaram para consulta.
    public var frozenAccounts: [(Company, Account)] { (workspace?.companies ?? []).flatMap { c in c.accounts.filter { $0.mode == .frozen }.map { (c, $0) } } }
    public func inUse(_ accountId: Int64?) -> Bool { accountId != nil && workspace?.account?.id == accountId }
    public var bankBalance: Decimal { all.filter { $0.kind == .bank }.reduce(0) { $0 + $1.balance } }
    public var invoices: Decimal { all.filter { $0.kind == .credit }.reduce(0) { $0 + $1.headline } }
    public var creditLimit: Decimal { all.compactMap(\.creditLimit).reduce(0, +) }
    public var creditAvailable: Decimal { all.compactMap(\.availableCredit).reduce(0, +) }
    public var accountCount: Int { all.count }
}

public enum AccountKindFilter: String, CaseIterable, Sendable {
    case all, bank, credit
    public var label: String { switch self { case .all: "Todas"; case .bank: "Contas"; case .credit: "Cartões" } }
}

@MainActor @Observable
public final class AccountsViewModel {
    public private(set) var state: Loadable<AccountsData> = .loading
    public var filter: AccountKindFilter = .all
    public private(set) var syncing: Set<Int64> = []
    public private(set) var busy = false
    private let app: AppModel

    public init(app: AppModel) { self.app = app }

    public func load() async {
        async let conns = app.repos.openFinance.connections()
        async let subs = app.repos.transactions.subscriptions()
        async let ws = app.repos.workspaces.refresh()
        let c = await conns
        let s = await subs.value
        let w = await ws.value ?? app.workspace
        state = state.keeping(c.map { AccountsData(connections: $0, subscriptions: s, workspace: w, now: app.clock.localNow()) })
    }

    public func sync(_ connection: BankConnection) async {
        syncing.insert(connection.id)
        let r = await app.repos.openFinance.sync(connection.id)
        syncing.remove(connection.id)
        switch r {
        case .success:
            app.messenger.show("\(connection.bankName) atualizado", icon: "arrow.triangle.2.circlepath")
            await load()
        case .failure(let e): app.messenger.show(e.message, icon: "exclamationmark.circle")
        }
    }

    public func syncAll() async {
        let conns = state.value?.connections ?? []
        app.messenger.show("Atualizando \(plural(conns.count, "banco", "bancos"))…", icon: "arrow.triangle.2.circlepath")
        await withTaskGroup(of: Void.self) { g in for c in conns { g.addTask { await self.sync(c) } } }
    }

    /// Passa a usar a conta (a do banco ou a manual).
    public func use(accountId: Int64) async -> Bool {
        guard let ws = state.value?.workspace ?? app.workspace, let company = ws.companyOf(accountId: accountId) else {
            app.messenger.show("Conta ainda não aparece no e-Finances. Atualize o banco e tente de novo.", icon: "exclamationmark.circle")
            return false
        }
        let ok = await app.select(companyId: company.id, accountId: accountId)
        if ok { await load() }
        return ok
    }

    public func changeCompany(_ connection: BankConnection, companyId: Int64) async -> Bool {
        busy = true
        defer { busy = false }
        switch await app.repos.openFinance.changeCompany(connection.id, companyId: companyId) {
        case .success:
            let name = state.value?.workspace?.companies.first { $0.id == companyId }?.name ?? "outra empresa"
            app.messenger.show("Contas do \(connection.bankName) agora em \(name)", icon: "building.2")
            await app.refreshWorkspace()
            await load()
            return true
        case .failure(let e):
            app.messenger.show(e.message, icon: "exclamationmark.circle")
            return false
        }
    }

    /// [accountIds] vazio = o banco inteiro.
    public func disconnect(_ connection: BankConnection, removeAccounts: Bool, accountIds: [Int64]) async -> Bool {
        busy = true
        defer { busy = false }
        let all = accountIds.isEmpty || accountIds.count == connection.accounts.count
        switch await app.repos.openFinance.disconnect(connection.id, removeAccounts: removeAccounts, accountIds: all ? [] : accountIds) {
        case .success:
            let n = all ? connection.accounts.count : accountIds.count
            let text: String
            switch (all, removeAccounts) {
            case (true, true): text = "\(connection.bankName) desconectado e contas apagadas"
            case (true, false): text = "\(connection.bankName) desconectado: \(n == 1 ? "a conta ficou" : "as contas ficaram") para consulta"
            case (false, true): text = "\(plural(n, "conta desconectada", "contas desconectadas")) e \(n == 1 ? "apagada" : "apagadas")"
            case (false, false): text = "\(plural(n, "conta desconectada", "contas desconectadas")): \(n == 1 ? "ficou" : "ficaram") para consulta"
            }
            app.messenger.show(text, icon: "link")
            await app.refreshWorkspace()
            app.transactionsChanged()
            await load()
            return true
        case .failure(let e):
            app.messenger.show(e.message, icon: "exclamationmark.circle")
            return false
        }
    }
}

public struct BankAccountData: Sendable {
    public var connection: BankConnection
    public var account: BankAccount
    public var siblings: [(BankConnection, BankAccount)]
    public var summary: BankAccountSummary?
    public var transactions: [BankTransaction]
}

@MainActor @Observable
public final class BankAccountViewModel {
    public private(set) var state: Loadable<BankAccountData> = .loading
    public private(set) var accountId: Int64
    public var days = 30
    private let app: AppModel

    public init(app: AppModel, accountId: Int64) { self.app = app; self.accountId = accountId }

    public func select(_ id: Int64) async { accountId = id; await load() }
    public func setDays(_ d: Int) async { days = d; await load() }

    public func load() async {
        let conns: [BankConnection]
        switch await app.repos.openFinance.connections() {
        case .success(let c): conns = c
        case .failure(let e): state = state.value == nil ? .failed(e) : state; return
        }
        let pairs = conns.flatMap { c in c.accounts.map { (c, $0) } }
        guard let (conn, acc) = pairs.first(where: { $0.1.id == accountId }) ?? pairs.first else { state = .failed(.notFound); return }
        let end = app.clock.today()
        let start = end.minusDays(days)
        async let s = app.repos.openFinance.accountSummary(acc.id, start: start, end: end)
        async let t = app.repos.openFinance.accountTransactions(acc.id, start: start, end: end)
        state = .ready(BankAccountData(connection: conn, account: acc, siblings: pairs, summary: await s.value, transactions: await t.value ?? []))
    }

    /// Abre a conta do e-Finances que espelha esta (em Transações dá para organizar os lançamentos).
    public func openLedger() async -> Bool {
        guard let a = state.value?.account else { return false }
        guard let ledger = a.ledgerAccountId else {
            app.messenger.show("Esta conta ainda não aparece no e-Finances. Atualize o banco e tente de novo.", icon: "exclamationmark.circle")
            return false
        }
        if app.workspace?.companyOf(accountId: ledger) == nil { await app.refreshWorkspace() }
        guard let company = app.workspace?.companyOf(accountId: ledger) else {
            app.messenger.show("Conta não encontrada no e-Finances.", icon: "exclamationmark.circle")
            return false
        }
        return await app.select(companyId: company.id, accountId: ledger)
    }

    public func sync() async {
        guard let c = state.value?.connection else { return }
        app.messenger.show("Atualizando \(c.bankName)…", icon: "arrow.triangle.2.circlepath")
        switch await app.repos.openFinance.sync(c.id) {
        case .success: app.messenger.show("\(c.bankName) atualizado", icon: "checkmark.circle"); await load()
        case .failure(let e): app.messenger.show(e.message, icon: "exclamationmark.circle")
        }
    }
}

// MARK: - Planejar

public struct PlanningData: Sendable {
    public var month: YearMonth
    public var limits: LimitsOverview?
    public var installments: [InstallmentItem]
    public var subscriptions: Subscriptions?
    public var categories: [TransactionCategory]

    public var installmentsRemaining: Decimal { installments.reduce(0) { $0 + $1.remainingAmount } }
    public var installmentsMonthly: Decimal { installments.reduce(0) { $0 + $1.amount } }
    public func category(_ id: Int64) -> TransactionCategory? { categories.first { $0.id == id } }
}

public enum PlanningTab: Int, CaseIterable, Sendable {
    case limits, installments, subscriptions
    public var label: String { switch self { case .limits: "Limites"; case .installments: "Parcelas"; case .subscriptions: "Assinaturas" } }
}

@MainActor @Observable
public final class PlanningViewModel {
    public private(set) var state: Loadable<PlanningData> = .loading
    public var tab: PlanningTab = .limits
    /// Limites excluídos com "Desfazer" pendente: ficam fora da tela até o aviso acabar.
    private var hiddenLimits: Set<Int64> = []
    private let app: AppModel

    public init(app: AppModel) { self.app = app }

    public func load() async {
        let month = app.clock.currentMonth()
        async let l = app.repos.planning.limits(month)
        async let li = app.repos.transactions.installments()
        async let oi = app.repos.openFinance.installments()
        async let s = app.repos.transactions.subscriptions()
        async let c = app.repos.transactions.categories()
        let limits = await l
        if case .failure(let e) = limits, state.value == nil { state = .failed(e); return }
        let data = PlanningData(month: month, limits: limits.value, installments: (await li.value?.items ?? []) + (await oi.value?.items ?? []),
                                subscriptions: await s.value, categories: await c.value ?? [])
        state = .ready(withoutHidden(data))
    }

    public func saveLimit(categoryId: Int64, value: Decimal, alert: Int) async -> Bool {
        switch await app.repos.planning.saveLimit(categoryId: categoryId, monthlyLimit: value, alertPercent: alert) {
        case .success: await load(); return true
        case .failure(let e): app.messenger.show(e.message, icon: "exclamationmark.circle"); return false
        }
    }

    /// Exclusão com "Desfazer" (como a web): some na hora e só vai ao servidor quando o aviso acaba.
    public func deleteLimit(_ id: Int64) {
        guard let item = state.value?.limits?.items.first(where: { $0.id == id }) else { return }
        hiddenLimits.insert(id)
        if let d = state.value { state = .ready(withoutHidden(d)) }
        app.messenger.deferred("Limite de \(item.categoryName) excluído", undo: { [weak self] in
            self?.hiddenLimits.remove(id)
            await self?.load()
        }, commit: { [weak self] in
            let r = await self?.app.repos.planning.deleteLimit(id) ?? .success(())
            if case .success = r { self?.hiddenLimits.remove(id) }
            return r
        })
    }

    private func withoutHidden(_ d: PlanningData) -> PlanningData {
        guard var l = d.limits else { return d }
        let gone = l.items.filter { hiddenLimits.contains($0.id) }
        guard !gone.isEmpty else { return d }
        l.items.removeAll { hiddenLimits.contains($0.id) }
        l.totalLimit -= gone.reduce(0) { $0 + $1.limit }
        l.totalSpent -= gone.reduce(0) { $0 + $1.spent }
        var out = d
        out.limits = l
        return out
    }
}

// MARK: - Relatórios

public enum ReportPeriod: String, CaseIterable, Sendable {
    case thisMonth, lastMonth, last3, last6, last12, thisYear
    public var label: String {
        switch self { case .thisMonth: "Este mês"; case .lastMonth: "Mês passado"; case .last3: "3 meses"; case .last6: "6 meses"; case .last12: "12 meses"; case .thisYear: "Este ano" }
    }

    /// Intervalo do período (meses inteiros, como a web: assim a comparação é com os meses anteriores).
    public func range(_ today: LocalDate) -> (LocalDate, LocalDate) {
        let m = today.yearMonth
        switch self {
        case .thisMonth: return (m.firstDay, m.lastDay)
        case .lastMonth: return (m.minusMonths(1).firstDay, m.minusMonths(1).lastDay)
        case .last3: return (m.minusMonths(2).firstDay, m.lastDay)
        case .last6: return (m.minusMonths(5).firstDay, m.lastDay)
        case .last12: return (m.minusMonths(11).firstDay, m.lastDay)
        case .thisYear: return (LocalDate(today.year, 1, 1), m.lastDay)
        }
    }
}

@MainActor @Observable
public final class ReportsViewModel {
    public private(set) var state: Loadable<ReportOverview> = .loading
    public private(set) var period: ReportPeriod = .last6
    public private(set) var status: ReportStatus = .all
    public var dimension: ReportDimension = .category
    public var contactKind: ContactCategory?
    /// Despesas do dia tocado no calendário de gastos.
    public private(set) var day: Loadable<DayExpenses>?
    private let app: AppModel

    public init(app: AppModel) { self.app = app }

    public var today: LocalDate { app.clock.today() }
    public var accountName: String { app.account?.name ?? "" }

    public func load() async {
        let (p, s) = (period, status)
        let (start, end) = p.range(today)
        let r = await app.repos.reports.overview(start: start, end: end, status: s)
        guard p == period, s == status else { return }
        state = state.keeping(r)
    }

    public func setPeriod(_ p: ReportPeriod) async { period = p; state = .loading; await load() }
    public func setStatus(_ s: ReportStatus) async { status = s; state = .loading; await load() }

    public var composition: [CategoryShare] {
        guard let r = state.value else { return [] }
        return r.expenseComposition(dimension, contactKind: dimension == .contact ? contactKind : nil)
    }

    public func openDay(_ d: LocalDate) async {
        day = .loading
        day = .ready(await app.repos.reports.day(d).value ?? DayExpenses(date: d, total: 0, count: 0, items: []))
    }

    public func closeDay() { day = nil }
}

// MARK: - Notificações e fechamento do mês

@MainActor @Observable
public final class NotificationsViewModel {
    public private(set) var state: Loadable<[AppNotification]> = .loading
    public var unreadOnly = false
    public var category: NotificationCategory?
    private let app: AppModel

    public init(app: AppModel) { self.app = app }

    public var unread: Int64 { app.unread }
    public var now: LocalDateTime { app.clock.localNow() }

    public var filtered: [AppNotification] { (state.value ?? []).filter { category == nil || $0.category == category } }

    public func load() async {
        let r = await app.repos.notifications.list(unreadOnly: unreadOnly)
        if let p = r.value { app.unread = p.unread }
        state = state.keeping(r.map(\.items))
    }

    public func setUnreadOnly(_ v: Bool) async { unreadOnly = v; await load() }

    public func open(_ n: AppNotification) async {
        guard !n.read else { return }
        if let left = await app.repos.notifications.markRead(n.id).value { app.unread = left }
        if let list = state.value { state = .ready(list.map { var x = $0; if x.id == n.id { x.read = true }; return x }) }
    }

    public func readAll() async {
        switch await app.repos.notifications.markAllRead() {
        case .success: app.unread = 0; app.messenger.show("Todas marcadas como lidas", icon: "checkmark.circle"); await load()
        case .failure(let e): app.messenger.show(e.message, icon: "exclamationmark.circle")
        }
    }

    /// Para onde o aviso leva no app (o link vem da web).
    public static func destination(_ n: AppNotification) -> NotificationDestination {
        let link = (n.link ?? "").lowercased()
        if link.contains("limit") { return .limits }
        if link.contains("story") { return .story }
        if link.contains("support") || link.contains("ticket") { return .support }
        if link.contains("billing") || link.contains("invoice") || link.contains("plan") { return .billing }
        if link.contains("open-finance") || link.contains("bank") { return .accounts }
        if link.contains("transaction") { return .transactions }
        if n.category == .security { return .security }
        return .none
    }
}

public enum NotificationDestination: Sendable { case none, limits, story, support, billing, accounts, transactions, security }

@MainActor @Observable
public final class StoryViewModel {
    public private(set) var state: Loadable<Story> = .loading
    private let app: AppModel

    public init(app: AppModel, story: Story? = nil) {
        self.app = app
        if let story { state = .ready(story) }
    }

    public func load() async {
        guard state.value == nil else { return }
        switch await app.repos.stories.pending() {
        case .success(let s?): state = .ready(s)
        case .success(nil): state = state.keeping(await app.repos.stories.latest())
        case .failure(let e): state = .failed(e)
        }
    }

    public func seen() async {
        guard let s = state.value else { return }
        await app.repos.stories.markSeen(s.periodKey)
        app.pendingStory = nil
    }
}
