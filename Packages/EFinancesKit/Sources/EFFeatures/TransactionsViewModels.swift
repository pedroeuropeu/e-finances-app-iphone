import Foundation
import Observation
import EFCore

public enum StatusFilter: String, CaseIterable, Sendable {
    case pending, late, paid
    public var label: String { switch self { case .pending: "Pendentes"; case .late: "Atrasadas"; case .paid: "Pagas" } }
}

public struct TxFilters: Equatable, Sendable {
    public var type: TransactionType?
    public var status: StatusFilter?
    public var category: TransactionCategory?
    public var query = ""
    public init(type: TransactionType? = nil, status: StatusFilter? = nil, category: TransactionCategory? = nil, query: String = "") {
        self.type = type; self.status = status; self.category = category; self.query = query
    }
    public var isEmpty: Bool { type == nil && status == nil && category == nil && query.trimmingCharacters(in: .whitespaces).isEmpty }
}

// MARK: - lista

@MainActor @Observable
public final class TransactionsViewModel {
    public private(set) var month: YearMonth
    public private(set) var today: LocalDate
    public private(set) var state: Loadable<[Transaction]> = .loading
    public private(set) var refreshing = false
    public var filters = TxFilters()
    public var selecting = false
    public var selection: Set<Int64> = []
    public private(set) var categories: [TransactionCategory] = []
    public private(set) var installmentsCount = 0
    public private(set) var installmentsMonthly: Decimal = 0
    /// Até quando os recorrentes aparecem num mês aberto à frente.
    public private(set) var recurrenceLimit: LocalDate?
    private let app: AppModel

    public init(app: AppModel) {
        self.app = app
        let t = app.clock.today()
        today = t
        month = t.yearMonth
    }

    public var account: Account? { app.account }
    public var mode: AccountMode { app.mode }
    public var manual: Bool { mode == .manual }
    public var all: [Transaction] { state.value ?? [] }
    public var totals: MonthTotals { all.totals() }
    public var lateCount: Int { all.filter { $0.dueStatus(today: today).isLate }.count }
    public var isCurrentMonth: Bool { month == today.yearMonth }
    public var selected: [Transaction] { all.filter { selection.contains($0.id) } }

    public var filtered: [Transaction] {
        all.filter { t in
            (filters.type == nil || t.type == filters.type)
            && {
                switch filters.status {
                case nil: return true
                case .pending: return !t.paid
                case .late: return t.dueStatus(today: today).isLate
                case .paid: return t.paid
                }
            }()
            && (filters.category == nil || t.category?.id == filters.category?.id)
            && matches(t, query: filters.query)
        }
    }

    public var groups: [(DueGroup, [Transaction])] { filtered.groupedByDue(today: today) }

    /// Mês depois do limite dos recorrentes: a tela avisa até quando eles aparecem.
    public var recurrenceNote: String? {
        guard let l = recurrenceLimit, month.lastDay > l else { return nil }
        return String(format: "Lançamentos recorrentes aparecem até %02d/%d.", l.month, l.year)
    }

    public func load(silent: Bool = false) async {
        let m = month
        today = app.clock.today()
        if state.value == nil || !silent { if !silent { state = .loading } } else { refreshing = true }
        let r = await app.repos.transactions.month(m)
        refreshing = false
        guard m == month else { return }
        state = silent ? state.keeping(r) : (r.value.map { .ready($0) } ?? .failed(r.error ?? .serverDefault))
    }

    public func loadExtras() async {
        async let limit = app.repos.transactions.recurrenceLimit()
        async let cats = app.repos.transactions.categories()
        async let inst = app.repos.transactions.installments()
        if let l = await limit.value { recurrenceLimit = l }
        if let c = await cats.value { categories = c }
        if let i = await inst.value {
            let ledger = i.items.filter { $0.source == .ledger }
            installmentsCount = ledger.count
            installmentsMonthly = ledger.reduce(0) { $0 + $1.amount }
        }
    }

    public func changeMonth(_ delta: Int) async {
        month = month.plusMonths(delta)
        clearSelection()
        await load()
    }

    public func goToCurrentMonth() async {
        guard month != today.yearMonth else { return }
        month = today.yearMonth
        await load()
    }

    public func toggleStatus(_ s: StatusFilter) { filters.status = filters.status == s ? nil : s }
    public func clearFilters() { filters = TxFilters() }
    public func showPending() { filters = TxFilters(status: .pending) }

    public func togglePaid(_ t: Transaction) async {
        await TransactionActions.togglePaid(t, app: app) { [weak self] id, paid in self?.patch(id, paid: paid) }
    }

    private func patch(_ id: Int64, paid: Bool) {
        guard let list = state.value else { return }
        state = .ready(list.map { var t = $0; if t.id == id { t.paid = paid }; return t })
    }

    // seleção de vários
    public func startSelection(_ id: Int64? = nil) { selecting = true; selection = id.map { [$0] } ?? [] }
    public func toggleSelected(_ id: Int64) { if selection.contains(id) { selection.remove(id) } else { selection.insert(id) } }
    public func selectAll() { selection = Set(filtered.map(\.id)) }
    public func clearSelection() { selecting = false; selection = [] }

    public func paySelected() async {
        let items = selected.filter { !$0.paid }
        clearSelection()
        guard !items.isEmpty else { return }
        var failed = 0
        for t in items {
            if case .failure = await app.repos.transactions.setPaid(t.id, paid: true) { failed += 1 } else { patch(t.id, paid: true) }
        }
        app.transactionsChanged()
        if failed == 0 {
            app.messenger.show(items.count == 1 ? "1 marcado como pago" : "\(items.count) marcados como pagos", icon: "checkmark.circle", action: "Desfazer") { [weak self] in
                Task { @MainActor in
                    for t in items { _ = await self?.app.repos.transactions.setPaid(t.id, paid: false); self?.patch(t.id, paid: false) }
                    self?.app.transactionsChanged()
                }
            }
        } else {
            app.messenger.show("\(failed) não puderam ser marcados", icon: "exclamationmark.circle")
        }
    }

    /// Exclui os selecionados (ou um só) com "Desfazer".
    public func delete(_ items: [Transaction], scope: SeriesScope = .this) async {
        clearSelection()
        await TransactionActions.delete(items, scope: scope, app: app, removed: { [weak self] ids in
            guard let self, let list = self.state.value else { return }
            self.state = .ready(list.filter { !ids.contains($0.id) })
        }, restored: { [weak self] in
            Task { await self?.load(silent: true) }
        })
    }

    public func duplicate(_ t: Transaction) async -> Transaction? {
        switch await app.repos.transactions.duplicate(t.id) {
        case .success(let copy):
            app.transactionsChanged()
            app.messenger.show("Lançamento duplicado", icon: "plus.square.on.square")
            await load(silent: true)
            return copy
        case .failure(let e):
            app.messenger.show(e.message, icon: "exclamationmark.circle")
            return nil
        }
    }
}

// MARK: - detalhe

@MainActor @Observable
public final class TransactionDetailViewModel {
    public private(set) var state: Loadable<Transaction> = .loading
    public private(set) var series: SeriesInfo?
    public let id: Int64
    public let month: YearMonth?
    private let app: AppModel

    public init(app: AppModel, id: Int64, month: YearMonth?) { self.app = app; self.id = id; self.month = month }

    public var mode: AccountMode { app.mode }
    public var today: LocalDate { app.clock.today() }
    public var accountName: String { [app.company?.name, app.account?.name].compactMap { $0 }.joined(separator: " · ") }

    public func load() async {
        let r = await app.repos.transactions.get(id, month: month)
        state = state.keeping(r)
        if let t = r.value, t.isRecurring { series = await app.repos.transactions.series(t.id).value ?? nil }
    }

    public func togglePaid() async {
        guard let t = state.value else { return }
        await TransactionActions.togglePaid(t, app: app) { [weak self] id, paid in
            guard let self, var cur = self.state.value, cur.id == id else { return }
            cur.paid = paid
            self.state = .ready(cur)
        }
    }

    public func delete(scope: SeriesScope) async {
        guard let t = state.value else { return }
        // a tela do detalhe fecha; a lista recarrega já sem o item (e volta a mostrá-lo no "Desfazer")
        await TransactionActions.delete([t], scope: scope, app: app, removed: { [app] _ in app.transactionsChanged() }, restored: { [app] in app.transactionsChanged() })
    }

    public func duplicate() async -> Transaction? {
        guard let t = state.value else { return nil }
        switch await app.repos.transactions.duplicate(t.id) {
        case .success(let copy):
            app.transactionsChanged()
            app.messenger.show("Lançamento duplicado", icon: "plus.square.on.square")
            return copy
        case .failure(let e):
            app.messenger.show(e.message, icon: "exclamationmark.circle")
            return nil
        }
    }

    /// Mover entre recebimento, despesa fixa e variável.
    public func move(to type: TransactionType) async {
        guard let t = state.value, t.type != type else { return }
        var d = TransactionFormViewModel.draft(from: t)
        d.type = type
        switch await app.repos.transactions.save(d, scope: nil) {
        case .success:
            app.transactionsChanged()
            app.messenger.show("Agora é \(type.label.lowercased())", icon: "arrow.left.arrow.right")
            await load()
        case .failure(let e): app.messenger.show(e.message, icon: "exclamationmark.circle")
        }
    }
}

// MARK: - formulário (novo, editar, organizar)

@MainActor @Observable
public final class TransactionFormViewModel {
    public var draft: TransactionDraft { didSet { if !errors.isEmpty { errors = draft.validate() } } }
    public let editing: Bool
    public private(set) var loading: Bool
    public private(set) var saving = false
    public private(set) var errors: [String: String] = [:]
    public private(set) var categories: [TransactionCategory] = []
    public private(set) var contacts: [Contact] = []
    public private(set) var costCenters: [CostCenter] = []
    public var showMore = false
    public private(set) var saved = false
    /// Lançamento de conta conectada ao banco: só a organização muda (valor, datas e situação seguem o banco).
    public let organizeOnly: Bool
    public let bankName: String?
    /// Como o lançamento estava ao abrir (recorrente: decide se pergunta o escopo).
    public private(set) var original: Transaction?
    private var initial: TransactionDraft?
    /// Regra do recorrente (frequência e "Termina em").
    public private(set) var series: SeriesInfo?
    /// Salvar um recorrente com mudanças: perguntar só esta / esta e as próximas / todas.
    public var askScope = false
    private let app: AppModel
    private let editId: Int64?
    private let month: YearMonth?

    public init(app: AppModel, id: Int64? = nil, type: TransactionType? = nil, month: YearMonth? = nil, date: LocalDate? = nil) {
        self.app = app
        self.editId = id
        self.month = month
        let today = app.clock.today()
        let first: LocalDate = date ?? { guard let month, month != today.yearMonth else { return today }; return month.firstDay }()
        let t = type ?? .variable
        draft = TransactionDraft(type: t, date: first, paymentType: t.isIncome ? .transfer : .creditCard)
        editing = id != nil
        loading = id != nil
        organizeOnly = id != nil && app.mode == .connected
        bankName = app.account?.bankName
    }

    public var today: LocalDate { app.clock.today() }
    public var accountName: String { app.account?.name ?? "" }

    public var plan: InstallmentPlan? {
        guard draft.paymentMode == .installments, draft.installments >= 2 else { return nil }
        return installmentPlan(cents: draft.cents, count: draft.installments, valueIsTotal: draft.valueIsTotal, first: draft.date,
                               recurrence: draft.recurrence, overrides: draft.installmentDates)
    }

    public var recurringEdit: Bool { editing && original?.isRecurring == true && !organizeOnly }

    /// Mudou algo além de "pago" e do "Termina em" (esses não perguntam o escopo).
    public var contentChanged: Bool {
        guard var a = initial else { return false }
        a.paid = draft.paid
        a.seriesEnd = draft.seriesEnd
        return a != draft
    }

    /// Algo digitado num lançamento novo (fechar pergunta se descarta).
    public var dirty: Bool { !editing && (draft.cents > 0 || !draft.description.trimmingCharacters(in: .whitespaces).isEmpty) }

    public static func draft(from t: Transaction) -> TransactionDraft {
        TransactionDraft(id: t.id, type: t.type, description: t.description, cents: t.value.cents, date: t.date, category: t.category, contact: t.contact,
                         paid: t.paid, paymentType: t.paymentType ?? .cash, paymentTypeChosen: t.paymentType != nil,
                         paymentMode: t.paymentMode == .installments ? .oneTime : t.paymentMode, recurrence: t.recurrence ?? .monthly,
                         costCenter: t.costCenter, refMonth: t.refDate?.yearMonth, docNumber: t.docNumber ?? "", details: t.details ?? "")
    }

    public func load() async {
        async let cats = app.repos.transactions.categories()
        async let contacts = app.repos.transactions.contacts()
        async let centers = app.repos.transactions.costCenters()
        categories = await cats.value ?? []
        self.contacts = await contacts.value ?? []
        costCenters = await centers.value ?? []
        guard let id = editId else { return }
        switch await app.repos.transactions.get(id, month: month) {
        case .success(let t):
            original = t
            showMore = t.costCenter != nil || t.docNumber != nil || t.details != nil
            draft = Self.draft(from: t)
            initial = draft
            loading = false
            if t.isRecurring, let info = await app.repos.transactions.series(t.id).value ?? nil {
                series = info
                draft.seriesEnd = info.endDate
                initial?.seriesEnd = info.endDate
            }
        case .failure(let e):
            loading = false
            app.messenger.show(e.message, icon: "exclamationmark.circle")
        }
    }

    // edição
    public func setType(_ t: TransactionType) {
        let keep = draft.category.map { $0.isIncomeCategory == t.isIncome } ?? true
        draft.type = t
        if !keep { draft.category = nil }
        if t.isIncome && draft.paymentType == .creditCard { draft.paymentType = .transfer }
    }

    /// Teclado numérico: os dígitos entram pela direita (centavos), como nos apps de banco.
    public func key(_ k: String) {
        let c: Int64
        switch k {
        case "del": c = draft.cents / 10
        case "00": c = draft.cents * 100
        default: c = draft.cents * 10 + Int64(Int(k) ?? 0)
        }
        if c <= 99_999_999_999 { draft.cents = c }
    }

    public func setCategory(_ c: TransactionCategory?) { draft.category = c; draft.newCategoryName = nil }
    public func newCategory(_ name: String) { draft.category = nil; draft.newCategoryName = name.trimmingCharacters(in: .whitespaces) }
    public func setContact(_ c: Contact?) { draft.contact = c; draft.newContactName = nil }
    public func newContact(_ name: String) { draft.contact = nil; draft.newContactName = name.trimmingCharacters(in: .whitespaces) }
    public func setPaymentType(_ p: PaymentType) { draft.paymentType = p; draft.paymentTypeChosen = true }
    public func setInstallments(_ n: Int) { draft.installments = min(max(n, 2), 48) }
    /// Data de uma parcela escolhida à mão (a 1ª é o vencimento do lançamento).
    public func setInstallmentDate(_ index: Int, _ d: LocalDate) { if index == 0 { draft.date = d } else { draft.installmentDates[index] = d } }
    public func resetInstallmentDate(_ index: Int) { draft.installmentDates[index] = nil }

    public var categoryLabel: String? { draft.category?.name ?? draft.newCategoryName }
    public var contactLabel: String? { draft.contact?.name ?? draft.newContactName }

    /// Categorias que fazem sentido para o tipo escolhido.
    public var suggestedCategories: [TransactionCategory] {
        let fit = categories.filter { $0.isIncomeCategory == draft.type.isIncome }
        return fit.isEmpty ? categories : fit + categories.filter { $0.isIncomeCategory != draft.type.isIncome }
    }

    /// Salva. Recorrente com mudanças pergunta o escopo antes (como a web).
    public func save(scope: SeriesScope? = nil) async {
        guard !saving else { return }
        if organizeOnly { return await organize() }
        let validation = draft.validate()
        if !validation.isEmpty {
            errors = validation
            app.messenger.show("Confira os campos destacados", icon: "exclamationmark.circle")
            return
        }
        if recurringEdit && contentChanged && scope == nil { askScope = true; return }
        askScope = false
        saving = true
        defer { saving = false }
        let onlyEnd = recurringEdit && !contentChanged && draft.paid == initial?.paid
        let r: Outcome<[Transaction]> = onlyEnd ? .success([]) : await app.repos.transactions.save(draft, scope: scope)
        if case .failure(let e) = r { app.messenger.show(e.message, icon: "exclamationmark.circle"); return }
        // "Termina em" do recorrente mudou: vale para a série
        if recurringEdit, draft.seriesEnd != initial?.seriesEnd, let id = draft.id {
            if case .failure(let e) = await app.repos.transactions.setSeriesEnd(id, end: draft.seriesEnd) {
                app.messenger.show(e.message, icon: "exclamationmark.circle")
                return
            }
        }
        // sucesso que se vê (a folha fecha e a lista muda) não avisa; parcelas caem também em outros meses
        if draft.id == nil && draft.paymentMode == .installments { app.messenger.show("\(draft.installments) parcelas lançadas", icon: "checkmark.circle") }
        app.transactionsChanged()
        saved = true
    }

    private func organize() async {
        if draft.description.trimmingCharacters(in: .whitespaces).isEmpty { errors = ["description": "Informe a descrição"]; return }
        errors = [:]
        saving = true
        defer { saving = false }
        switch await app.repos.transactions.organize(draft) {
        case .success:
            app.transactionsChanged()
            saved = true
        case .failure(let e): app.messenger.show(e.message, icon: "exclamationmark.circle")
        }
    }
}
