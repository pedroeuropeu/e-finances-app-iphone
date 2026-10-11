import Foundation
import EFCore

/* Modo demonstração: mesma interface, dados do DemoStore e uma pequena espera para simular a rede (e mostrar os
   estados de carregamento). As travas são as mesmas do servidor (conta do banco só organiza; congelada só consulta). */

private func latency(_ ms: UInt64 = 250) async { try? await Task.sleep(nanoseconds: ms * 1_000_000) }

public final class DemoAuthRepository: AuthRepository {
    private let storage: TokenStorage
    public init(storage: TokenStorage) { self.storage = storage }

    public func restore() async -> SessionState { storage.load().map { .loggedIn(email: $0.email) } ?? .loggedOut(.none) }

    public func login(email: String, password: String, remember: Bool) async -> Outcome<String> {
        await latency(600)
        if password.isEmpty { return .failure(.invalidCredentials("Digite qualquer senha para entrar no modo demonstração.")) }
        let mail = (email.trimmingCharacters(in: .whitespaces).isEmpty ? "demo@efinances.top" : email).trimmingCharacters(in: .whitespaces).lowercased()
        storage.save(SessionTokens(accessToken: "demo", refreshToken: "demo", accessExpiresAt: .max, refreshExpiresAt: 0, email: mail))
        return .success(mail)
    }

    public func logout() async { storage.clear() }
    public func forgotPassword(email: String) async -> Outcome<Void> { await latency(); return .success(()) }
    public func register(_ data: RegisterData) async -> Outcome<Void> { await latency(700); return .success(()) }
}

public final class DemoUserRepository: UserRepository {
    private let clock: AppClock
    private let storage: TokenStorage
    public init(clock: AppClock, storage: TokenStorage) { self.clock = clock; self.storage = storage }
    public func profile() async -> Outcome<UserProfile> {
        .success(UserProfile(firstName: "Pedro", lastName: "Europeu", email: storage.load()?.email ?? "demo@efinances.top", planName: "Premium", planEndDate: clock.today().plusDays(33)))
    }
}

public final class DemoWorkspaceRepository: WorkspaceRepository {
    private let store: DemoStore
    public init(store: DemoStore) { self.store = store }

    public func refresh() async -> Outcome<Workspace> { await latency(); return .success(await store.workspaceWithBalance()) }

    public func select(companyId: Int64, accountId: Int64) async -> Outcome<Workspace> {
        await latency()
        await store.update { s in s.workspace.companyId = companyId; s.workspace.accountId = accountId }
        return .success(await store.workspaceWithBalance())
    }
}

public final class DemoTransactionRepository: TransactionRepository {
    private let store: DemoStore
    private let clock: AppClock
    public init(store: DemoStore, clock: AppClock) { self.store = store; self.clock = clock }

    /// Mesmas travas do servidor (AccountLocks) para a conta em uso.
    private func lock(organizing: Bool = false) async -> AppError? {
        switch await store.read({ $0.workspace.mode }) {
        case .frozen: return .validation("Esta conta foi desconectada do banco e ficou só para consulta.")
        case .connected: return organizing ? nil : .validation("Lançamento do banco: valor, datas, situação e exclusão seguem o banco.")
        case .manual: return nil
        }
    }

    public func month(_ month: YearMonth) async -> Outcome<[Transaction]> {
        await latency()
        return .success(await store.read { s in s.month(month).filter { !s.hidden.contains($0.id) } })
    }

    public func get(_ id: Int64, month: YearMonth?) async -> Outcome<Transaction> {
        await store.read { s -> Outcome<Transaction> in
            if let month { _ = s.month(month) }
            return s.find(id).map { .success($0) } ?? .failure(.notFound)
        }
    }

    public func hide(_ ids: [Int64]) async { await store.update { $0.hidden.formUnion(ids) } }
    public func unhide(_ ids: [Int64]) async { await store.update { $0.hidden.subtract(ids) } }

    public func series(_ id: Int64) async -> Outcome<SeriesInfo?> {
        await store.read { s -> Outcome<SeriesInfo?> in
            guard let t = s.find(id) else { return .failure(.notFound) }
            guard t.isRecurring else { return .success(nil) }
            return .success(SeriesInfo(frequency: t.recurrence ?? .monthly, endDate: t.rootNumber.flatMap { s.seriesEnd[$0] }, nextDate: t.date.plusMonths(1), active: true))
        }
    }

    public func setSeriesEnd(_ id: Int64, end: LocalDate?) async -> Outcome<SeriesInfo?> {
        await latency()
        let ok: Bool = await store.read { s in
            guard let t = s.find(id), let root = t.rootNumber else { return false }
            if let end {
                s.seriesEnd[root] = end
                // as ocorrências em aberto depois da data saem
                s.removeWhere { $0.rootNumber == root && !$0.paid && $0.date > end }
            } else { s.seriesEnd[root] = nil }
            return true
        }
        return ok ? await series(id) : .success(nil)
    }

    public func recurrenceLimit() async -> Outcome<LocalDate?> { .success(clock.currentMonth().plusMonths(60).lastDay) }

    public func setPaid(_ id: Int64, paid: Bool) async -> Outcome<Void> {
        await latency()
        if let e = await lock() { return .failure(e) }
        return await store.read { s -> Outcome<Void> in
            guard var t = s.find(id) else { return .failure(.notFound) }
            if t.paid != paid {
                if t.date.yearMonth == s.baseMonth { s.balanceAdjust += paid ? t.signedValue : -t.signedValue }
                t.paid = paid
                s.replace(t)
            }
            return .success(())
        }
    }

    public func save(_ draft: TransactionDraft, scope: SeriesScope?) async -> Outcome<[Transaction]> {
        await latency(400)
        let mode = await store.read { $0.workspace.mode }
        if mode == .connected && draft.id == nil { return .failure(.validation("Esta conta é conectada ao banco: os lançamentos chegam pela sincronização.")) }
        if let e = await lock() { return .failure(e) }
        return await store.read { s -> Outcome<[Transaction]> in
            var category = draft.category
            if category == nil, let n = draft.newCategoryName.clean { category = TransactionCategory(id: s.newId(), name: n); s.categories.append(category!) }
            var contact = draft.contact
            if contact == nil, let n = draft.newContactName.clean { contact = Contact(id: s.newId(), name: n); s.contacts.append(contact!) }
            let accountName = s.workspace.account?.name ?? "Conta corrente"
            func build(_ id: Int64, _ value: Decimal, _ date: LocalDate, _ plot: String?, _ paid: Bool) -> Transaction {
                Transaction(id: id, description: draft.description.trimmingCharacters(in: .whitespaces), value: value, type: draft.type, date: date, paid: paid,
                            refDate: draft.refMonth?.firstDay, paymentType: draft.paymentType, paymentMode: draft.paymentMode,
                            recurrence: draft.paymentMode == .oneTime ? nil : draft.recurrence, plot: plot, category: category, contact: contact,
                            costCenter: draft.costCenter, docNumber: draft.docNumber.clean, details: draft.details.clean, accountName: accountName)
            }
            var list: [Transaction] = []
            if let id = draft.id {
                guard let old = s.find(id) else { return .failure(.notFound) }
                var updated = build(id, draft.value, draft.date, old.plot, draft.paid)
                updated.attachments = old.attachments; updated.rootNumber = old.rootNumber; updated.paymentMode = old.paymentMode; updated.recurrence = old.recurrence
                if old.date.yearMonth == s.baseMonth && old.paid { s.balanceAdjust -= old.signedValue }
                s.remove(id)
                s.add(updated)
                // recorrente: "esta e as próximas" / "todas" levam a mudança para as outras já abertas (as pagas só a organização)
                if let root = old.rootNumber, let scope, scope != .this {
                    for o in s.all() where o.rootNumber == root && o.id != old.id && (scope == .all || o.date > old.date) {
                        var c = o
                        c.description = updated.description; c.category = updated.category; c.contact = updated.contact; c.costCenter = updated.costCenter; c.details = updated.details
                        if !o.paid { c.value = updated.value; c.paymentType = updated.paymentType; c.docNumber = updated.docNumber }
                        s.replace(c)
                    }
                }
                list = [updated]
            } else if draft.paymentMode == .installments {
                let plan = installmentPlan(cents: draft.cents, count: draft.installments, valueIsTotal: draft.valueIsTotal, first: draft.date,
                                           recurrence: draft.recurrence, overrides: draft.installmentDates)
                let root = "N\(s.nextId)"
                for (i, d) in plan.dates.enumerated() {
                    var t = build(s.newId(), plan.values[i], d, "\(i + 1)/\(plan.count)", draft.paid && i == 0)
                    t.refDate = d.withDay(1)
                    t.rootNumber = root
                    s.add(t)
                    list.append(t)
                }
            } else {
                var t = build(s.newId(), draft.value, draft.date, nil, draft.paid)
                if draft.paymentMode == .recurring {
                    t.rootNumber = "R\(t.id)"
                    if let e = draft.seriesEnd { s.seriesEnd["R\(t.id)"] = e }
                    // as próximas ocorrências (mensal), como o backend gera
                    for step in 1...11 {
                        let date = draft.recurrence.next(draft.date, steps: step)
                        if let e = draft.seriesEnd, date > e { break }
                        var next = build(s.newId(), draft.value, date, nil, false)
                        next.rootNumber = t.rootNumber
                        s.add(next)
                    }
                }
                s.add(t)
                list = [t]
            }
            for t in list where t.paid && t.date.yearMonth == s.baseMonth { s.balanceAdjust += t.signedValue }
            return .success(list)
        }
    }

    public func organize(_ draft: TransactionDraft) async -> Outcome<Void> {
        await latency(300)
        if let e = await lock(organizing: true) { return .failure(e) }
        return await store.read { s -> Outcome<Void> in
            guard let id = draft.id, var t = s.find(id) else { return .failure(.notFound) }
            var category = draft.category
            if category == nil, let n = draft.newCategoryName.clean { category = TransactionCategory(id: s.newId(), name: n); s.categories.append(category!) }
            var contact = draft.contact
            if contact == nil, let n = draft.newContactName.clean { contact = Contact(id: s.newId(), name: n); s.contacts.append(contact!) }
            t.description = draft.description.trimmingCharacters(in: .whitespaces)
            t.category = category; t.contact = contact; t.costCenter = draft.costCenter
            if draft.paymentTypeChosen { t.paymentType = draft.paymentType }
            t.docNumber = draft.docNumber.clean; t.details = draft.details.clean
            s.replace(t)
            return .success(())
        }
    }

    public func delete(_ id: Int64, scope: SeriesScope) async -> Outcome<Void> {
        await latency()
        if let e = await lock() { return .failure(e) }
        await store.update { s in
            let t = s.find(id)
            let root = t?.rootNumber
            let gone: [Transaction]
            if let t, let root, scope != .this {
                gone = s.all().filter { $0.rootNumber == root && (scope == .all || $0.date >= t.date) }
                s.cutFrom[root] = scope == .all ? LocalDate(1900, 1, 1) : t.date
            } else { gone = t.map { [$0] } ?? [] }
            for g in gone where g.paid && g.date.yearMonth == s.baseMonth { s.balanceAdjust -= g.signedValue }
            for g in gone { s.remove(g.id) }
            s.hidden.remove(id)
        }
        return .success(())
    }

    public func duplicate(_ id: Int64) async -> Outcome<Transaction> {
        await latency()
        if let e = await lock() { return .failure(e) }
        return await store.read { s -> Outcome<Transaction> in
            guard let t = s.find(id) else { return .failure(.notFound) }
            let copy = Transaction(id: s.newId(), description: t.description, value: t.value, type: t.type, date: t.date, paid: false, refDate: t.refDate,
                                   paymentType: t.paymentType, category: t.category, contact: t.contact, costCenter: t.costCenter, docNumber: t.docNumber,
                                   details: t.details, accountName: t.accountName)
            s.add(copy)
            return .success(copy)
        }
    }

    public func categories() async -> Outcome<[TransactionCategory]> { .success(await store.read { $0.categories.sorted { $0.name < $1.name } }) }
    public func contacts() async -> Outcome<[Contact]> { .success(await store.read { $0.contacts.sorted { $0.name < $1.name } }) }
    public func costCenters() async -> Outcome<[CostCenter]> { .success(await store.read { $0.costCenters }) }

    public func installments() async -> Outcome<Installments> {
        await latency()
        let items: [InstallmentItem] = await store.read { s in
            s.month(s.baseMonth).filter { $0.paymentMode == .installments && $0.plot != nil }.compactMap { t in
                guard let (n, total) = t.installment else { return nil }
                let paidCount = t.paid ? n : n - 1
                return InstallmentItem(key: "ledger-\(t.description)", name: t.description, paid: paidCount, total: total, amount: t.value,
                                       remainingAmount: t.value * Decimal(total - paidCount), endDate: t.date.plusMonths(total - n),
                                       source: .ledger, accountName: t.accountName, transactionId: t.id)
            }
        }
        return .success(Installments(items: items, remainingTotal: items.reduce(0) { $0 + $1.remainingAmount }, monthlyTotal: items.reduce(0) { $0 + $1.amount }))
    }

    public func subscriptions() async -> Outcome<Subscriptions> {
        await latency()
        return await store.read { s in
            let subs = s.subscriptions().map { item -> RecurringItem in
                guard let c = s.categories.first(where: { $0.name == item.category }) else { return item }
                var i = item
                i.icon = c.icon; i.color = c.color; i.logo = c.logo; i.brand = item.brand ?? c.brand
                return i
            }
            let monthly = subs.reduce(Decimal(0)) { $0 + $1.monthlyAmount }
            return .success(Subscriptions(subscriptions: subs, bills: s.bills(), monthlyTotal: monthly, yearlyTotal: monthly * 12, connected: !s.connections().isEmpty))
        }
    }
}

public final class DemoPlanningRepository: PlanningRepository {
    private let store: DemoStore
    public init(store: DemoStore) { self.store = store }

    public func limits(_ month: YearMonth) async -> Outcome<LimitsOverview> {
        await latency()
        return .success(await store.read { s in
            let expenses = s.month(month).filter { !$0.type.isIncome }
            let items = s.limits.map { l -> LimitItem in
                let cat = s.categories.first { $0.id == l.categoryId }
                let spent = expenses.filter { $0.category?.id == l.categoryId }.sum
                return LimitItem(id: l.id, categoryId: l.categoryId, categoryName: cat?.name ?? "", limit: l.limit, spent: spent, percent: pct(spent, l.limit),
                                 alertPercent: l.alert, status: limitStatus(spent: spent, limit: l.limit, alertPercent: l.alert))
            }
            let withLimit = Set(s.limits.map(\.categoryId))
            let suggestions: [LimitSuggestion] = s.categories.filter { !withLimit.contains($0.id) && ![11, 12, 13].contains($0.id) }.compactMap { c in
                let avg = ((1...3).map { i in s.month(month.minusMonths(i)).filter { $0.category?.id == c.id && !$0.type.isIncome }.sum }.reduce(0, +) / 3).rounded(2)
                guard avg > 0 else { return nil }
                return LimitSuggestion(categoryId: c.id, categoryName: c.name, average: avg, suggested: (avg / 50).rounded(0, .up) * 50)
            }
            return LimitsOverview(month: month, totalLimit: items.reduce(0) { $0 + $1.limit }, totalSpent: items.reduce(0) { $0 + $1.spent },
                                  items: items, suggestions: Array(suggestions.prefix(3)))
        })
    }

    public func saveLimit(categoryId: Int64, monthlyLimit: Decimal, alertPercent: Int) async -> Outcome<Void> {
        await latency()
        await store.update { s in
            if let i = s.limits.firstIndex(where: { $0.categoryId == categoryId }) { s.limits[i].limit = monthlyLimit; s.limits[i].alert = alertPercent }
            else { s.limits.append(.init(id: (s.limits.map(\.id).max() ?? 0) + 1, categoryId: categoryId, limit: monthlyLimit, alert: alertPercent)) }
        }
        return .success(())
    }

    public func deleteLimit(_ id: Int64) async -> Outcome<Void> { await latency(); await store.update { $0.limits.removeAll { $0.id == id } }; return .success(()) }

    public func yearFlow(_ year: Int) async -> Outcome<[MonthFlow]> {
        .success(await store.read { s in
            (1...12).map { m in
                let ym = YearMonth(year, m)
                let t = s.month(ym).totals()
                return MonthFlow(month: ym, income: t.income, expense: t.expense, projected: ym > s.baseMonth)
            }
        })
    }
}

public final class DemoOpenFinanceRepository: OpenFinanceRepository {
    private let store: DemoStore
    public init(store: DemoStore) { self.store = store }

    public func connections() async -> Outcome<[BankConnection]> { await latency(); return .success(await store.read { $0.connections() }) }

    public func accountSummary(_ id: Int64, start: LocalDate, end: LocalDate) async -> Outcome<BankAccountSummary> {
        await latency()
        let tx = await store.read { $0.bankTransactions() }
        let factor = Decimal(max(1, start.days(until: end) / 30))
        let expense = tx.filter { !$0.isIncome }
        let byCat = Dictionary(grouping: expense) { $0.categoryName ?? "Outros" }
            .map { CategoryTotal(name: $0.key, total: $0.value.reduce(Decimal(0)) { $0 + $1.amount.magnitude } * factor) }
            .sorted { $0.total > $1.total }
        return .success(BankAccountSummary(income: tx.filter(\.isIncome).reduce(Decimal(0)) { $0 + $1.amount } * factor,
                                           expense: expense.reduce(Decimal(0)) { $0 + $1.amount.magnitude } * factor, expenseByCategory: byCat))
    }

    public func accountTransactions(_ id: Int64, start: LocalDate, end: LocalDate) async -> Outcome<[BankTransaction]> {
        await latency(); return .success(await store.read { $0.bankTransactions() })
    }

    public func sync(_ connectionId: Int64) async -> Outcome<Void> {
        await latency(900)
        if connectionId == 2 { await store.update { $0.itauStatus = "UPDATED" } }
        return .success(())
    }

    public func changeCompany(_ connectionId: Int64, companyId: Int64) async -> Outcome<Void> {
        await latency()
        return await store.read { s -> Outcome<Void> in
            guard let conn = s.connections().first(where: { $0.id == connectionId }) else { return .failure(.notFound) }
            let accounts = Set(conn.accounts.compactMap(\.ledgerAccountId))
            s.connectionCompany[connectionId] = companyId
            // as contas do banco mudam de empresa junto com a conexão
            let moving = s.workspace.companies.flatMap(\.accounts).filter { accounts.contains($0.id) }
            s.workspace.companies = s.workspace.companies.map { c in
                var c = c
                let kept = c.accounts.filter { !accounts.contains($0.id) }
                c.accounts = c.id == companyId ? kept + moving : kept
                return c
            }
            return .success(())
        }
    }

    public func disconnect(_ connectionId: Int64, removeAccounts: Bool, accountIds: [Int64]) async -> Outcome<Void> {
        await latency()
        return await store.read { s -> Outcome<Void> in
            guard let conn = s.connections().first(where: { $0.id == connectionId }) else { return .failure(.notFound) }
            let chosen = conn.accounts.filter { accountIds.isEmpty || accountIds.contains($0.id) }
            let ledger = Set(chosen.compactMap(\.ledgerAccountId))
            if chosen.count == conn.accounts.count { s.removedConnections.insert(connectionId) } else { s.disconnected.formUnion(chosen.map(\.id)) }
            s.workspace.companies = s.workspace.companies.map { c in
                var c = c
                c.accounts = removeAccounts ? c.accounts.filter { !ledger.contains($0.id) }
                    : c.accounts.map { a in var a = a; if ledger.contains(a.id) { a.mode = .frozen }; return a }
                return c
            }
            if !s.workspace.companies.contains(where: { c in c.accounts.contains { $0.id == s.workspace.accountId } }) {
                s.workspace.accountId = s.workspace.companies.first { $0.id == s.workspace.companyId }?.accounts.first?.id
            }
            return .success(())
        }
    }

    public func installments() async -> Outcome<Installments> {
        let items = await store.read { $0.openFinanceInstallments() }
        return .success(Installments(items: items, remainingTotal: items.reduce(0) { $0 + $1.remainingAmount }, monthlyTotal: items.reduce(0) { $0 + $1.amount }))
    }
}

public final class DemoStoryRepository: StoryRepository {
    private let store: DemoStore
    public init(store: DemoStore) { self.store = store }

    private func build() async -> Story {
        await store.read { s in
            let month = s.baseMonth.minusMonths(1)
            let list = s.month(account: 11, month)
            let prev = s.month(account: 11, month.minusMonths(1))
            let t = list.totals(), p = prev.totals()
            let expenses = list.filter { !$0.type.isIncome }
            let biggest = expenses.max { $0.value < $1.value }
            let within = s.limits.filter { l in limitStatus(spent: expenses.filter { $0.category?.id == l.categoryId }.sum, limit: l.limit, alertPercent: l.alert) != .over }.count
            let subs = s.subscriptions()
            return Story(periodKey: "M:\(month)", title: "Fechamento do mês", periodLabel: DateFormats.monthYear(month), tag: DateFormats.monthYearTitle(month),
                         accountName: "Casa · Conta corrente", income: t.income, expenses: t.expense, balance: t.balance,
                         savingsRate: t.income > 0 ? pct(t.balance, t.income) : nil, count: Int64(list.count), openExpenses: Int64(expenses.filter { !$0.paid }.count),
                         expensesDeltaPct: p.expense > 0 ? pct(t.expense - p.expense, p.expense) : nil,
                         categories: list.expensesByCategory().prefix(3).map { StoryCategory(name: $0.name, value: $0.value, percent: $0.percent) },
                         biggestExpense: biggest.map { StoryExpense(description: $0.description, value: $0.value, date: $0.date) },
                         limitsWithin: within, limitsTotal: s.limits.count, limitsOver: s.limits.count - within,
                         subscriptionsMonthly: subs.reduce(0) { $0 + $1.monthlyAmount }, subscriptionsCount: subs.count)
        }
    }

    public func pending() async -> Outcome<Story?> {
        await latency()
        let story = await build()
        let seen = await store.read { $0.storiesSeen.contains(story.periodKey) }
        return .success(seen ? nil : story)
    }

    public func latest() async -> Outcome<Story> { await latency(); return .success(await build()) }
    public func markSeen(_ periodKey: String) async { await store.update { $0.storiesSeen.insert(periodKey) } }
}

public final class DemoNotificationRepository: NotificationRepository {
    private let store: DemoStore
    public init(store: DemoStore) { self.store = store }

    public func list(unreadOnly: Bool) async -> Outcome<NotificationsPage> {
        await latency()
        return .success(await store.read { s in
            NotificationsPage(items: s.notifications.filter { !unreadOnly || !$0.read }, unread: Int64(s.notifications.filter { !$0.read }.count))
        })
    }

    public func markRead(_ id: Int64) async -> Outcome<Int64> {
        .success(await store.read { s in
            if let i = s.notifications.firstIndex(where: { $0.id == id }) { s.notifications[i].read = true }
            return Int64(s.notifications.filter { !$0.read }.count)
        })
    }

    public func markAllRead() async -> Outcome<Void> {
        await store.update { s in for i in s.notifications.indices { s.notifications[i].read = true } }
        return .success(())
    }
}
