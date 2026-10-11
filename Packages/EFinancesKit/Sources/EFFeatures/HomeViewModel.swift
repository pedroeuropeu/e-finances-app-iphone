import Foundation
import Observation
import EFCore

public struct HomeData: Sendable {
    public var workspace: Workspace
    public var today: LocalDate
    public var month: YearMonth
    public var totals: MonthTotals
    public var balance: Decimal
    public var currency: String
    public var forecast: Decimal
    public var late: [Transaction]
    public var soon: [Transaction]
    public var categories: [CategoryShare]
    public var limits: LimitsOverview?
    public var installments: [InstallmentItem]
    public var connections: [BankConnection]
    public var story: Story?
    public var yearFlow: [MonthFlow]
    /// Lançamentos do mês (agenda).
    public var monthTransactions: [Transaction]
    public var subscriptions: Subscriptions?

    public var due: [Transaction] { Array((late + soon).sorted { $0.date < $1.date }.prefix(4)) }
    /// Conta em uso: manual, conectada ao banco ou congelada.
    public var mode: AccountMode { workspace.mode }
    /// Aparência das categorias usadas no mês (cor do gráfico e dos limites).
    public var looks: [Int64: TransactionCategory] { Dictionary(monthTransactions.compactMap(\.category).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }
    public var looksByName: [String: TransactionCategory] { Dictionary(monthTransactions.compactMap(\.category).map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a }) }

    /// Lançamentos de um dia da agenda.
    public func day(_ d: LocalDate) -> [Transaction] { monthTransactions.filter { $0.date == d }.sorted { ($0.type.isIncome ? 0 : 1, $0.description) < ($1.type.isIncome ? 0 : 1, $1.description) } }
}

@MainActor @Observable
public final class HomeViewModel {
    public private(set) var state: Loadable<HomeData> = .loading
    public private(set) var refreshing = false
    public var agendaDay: LocalDate
    private let app: AppModel

    public init(app: AppModel) {
        self.app = app
        agendaDay = app.clock.today()
    }

    /// Carrega o Início. Com dados na tela, recarrega por trás (e um erro vira aviso, sem apagar a tela).
    public func load(silent: Bool = false) async {
        let hadData = state.value != nil
        if !hadData { state = .loading } else if silent { refreshing = true }
        let r = await fetch()
        refreshing = false
        state = state.keeping(r)
        if case .failure(let e) = r, hadData { app.messenger.show(e.message, icon: "wifi.exclamationmark") }
    }

    private func fetch() async -> Outcome<HomeData> {
        let repos = app.repos
        let today = app.clock.today()
        let month = today.yearMonth
        async let ws = repos.workspaces.refresh()
        async let tx = repos.transactions.month(month)
        async let limits = repos.planning.limits(month)
        async let ledgerInst = repos.transactions.installments()
        async let ofInst = repos.openFinance.installments()
        async let conns = repos.openFinance.connections()
        async let story = repos.stories.pending()
        async let flow = repos.planning.yearFlow(month.year)
        async let subs = repos.transactions.subscriptions()

        let w: Workspace
        switch await ws { case .success(let v): w = v; case .failure(let e): return .failure(e) }
        let list: [Transaction]
        switch await tx { case .success(let v): list = v; case .failure(let e): return .failure(e) }
        let totals = list.totals()
        let account = w.account
        let balance = account?.balance ?? 0
        let li = await ledgerInst.value?.items ?? []
        let oi = await ofInst.value?.items ?? []
        return .success(HomeData(
            workspace: w, today: today, month: month, totals: totals, balance: balance, currency: account?.currency ?? "BRL",
            forecast: forecast(balance: balance, totals: totals),
            late: list.filter { $0.dueStatus(today: today).isLate },
            soon: list.filter { $0.dueStatus(today: today).isSoon },
            categories: list.expensesByCategory(),
            limits: await limits.value,
            installments: li + oi,
            connections: await conns.value ?? [],
            story: await story.value ?? nil,
            yearFlow: await flow.value ?? [],
            monthTransactions: list,
            subscriptions: await subs.value
        ))
    }

    /// Marca como pago/pendente com "Desfazer" (a lista muda na hora).
    public func togglePaid(_ t: Transaction) async {
        await TransactionActions.togglePaid(t, app: app) { [weak self] id, paid in self?.patch(id, paid: paid) }
    }

    private func patch(_ id: Int64, paid: Bool) {
        guard var d = state.value else { return }
        d.monthTransactions = d.monthTransactions.map { var t = $0; if t.id == id { t.paid = paid }; return t }
        let today = d.today
        d.late = d.monthTransactions.filter { $0.dueStatus(today: today).isLate }
        d.soon = d.monthTransactions.filter { $0.dueStatus(today: today).isSoon }
        d.totals = d.monthTransactions.totals()
        state = .ready(d)
    }

    public func storySeen() {
        guard var d = state.value else { return }
        d.story = nil
        state = .ready(d)
    }
}

/// Ações de lançamento usadas em várias telas (Início, Transações, detalhe).
@MainActor
public enum TransactionActions {
    /// Paga ou volta para pendente com atualização otimista ([patch]) e "Desfazer".
    public static func togglePaid(_ t: Transaction, app: AppModel, patch: @escaping @MainActor (Int64, Bool) -> Void) async {
        let target = !t.paid
        patch(t.id, target)
        switch await app.repos.transactions.setPaid(t.id, paid: target) {
        case .success:
            app.transactionsChanged()
            let text = target ? (t.type.isIncome ? "Marcado como recebido" : "Marcado como pago") : "Voltou para pendente"
            app.messenger.show(text, icon: target ? "checkmark.circle" : "arrow.uturn.backward", action: "Desfazer") {
                patch(t.id, !target)
                Task { @MainActor in
                    if case .failure(let e) = await app.repos.transactions.setPaid(t.id, paid: !target) {
                        patch(t.id, target)
                        app.messenger.show(e.message, icon: "exclamationmark.circle")
                    } else { app.transactionsChanged() }
                }
            }
        case .failure(let e):
            patch(t.id, t.paid)
            app.messenger.show(e.message, icon: "exclamationmark.circle")
        }
    }

    /**
     Exclusão com "Desfazer" (como a web): some da tela na hora e só vai ao servidor quando o aviso acaba.
     [scope] vale para recorrentes e parcelas; os outros saem só eles.
     */
    public static func delete(_ items: [Transaction], scope: SeriesScope, app: AppModel, removed: @escaping @MainActor ([Int64]) -> Void,
                              restored: @escaping @MainActor () -> Void) async {
        guard !items.isEmpty else { return }
        let ids = items.map(\.id)
        await app.repos.transactions.hide(ids)
        removed(ids)
        let text: String
        if items.count == 1 {
            text = scope == .this || !items[0].hasScope ? "Lançamento excluído" : scope == .next ? "Este e os próximos excluídos" : "Série excluída"
        } else { text = "\(items.count) lançamentos excluídos" }
        app.messenger.deferred(text, undo: {
            await app.repos.transactions.unhide(ids)
            restored()
        }, commit: {
            var failed: [Int64] = []
            for t in items {
                if case .failure = await app.repos.transactions.delete(t.id, scope: t.hasScope ? scope : .this) { failed.append(t.id) }
            }
            app.transactionsChanged()
            if failed.isEmpty { return .success(()) }
            await app.repos.transactions.unhide(failed)
            return .failure(.validation(failed.count == 1 ? "1 lançamento não pôde ser excluído." : "\(failed.count) lançamentos não puderam ser excluídos."))
        })
    }
}
