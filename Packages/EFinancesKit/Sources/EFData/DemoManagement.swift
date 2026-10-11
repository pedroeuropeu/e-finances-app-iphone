import Foundation
import EFCore

/* Modo demonstração: relatórios, cadastros, empresas e contas, plano e suporte. */

private func wait() async { try? await Task.sleep(nanoseconds: 250_000_000) }

public final class DemoReportRepository: ReportRepository {
    private let store: DemoStore
    private let clock: AppClock
    public init(store: DemoStore, clock: AppClock) { self.store = store; self.clock = clock }

    private static func months(_ start: LocalDate, _ end: LocalDate) -> [YearMonth] {
        var out: [YearMonth] = []
        var m = start.yearMonth
        while m <= end.yearMonth { out.append(m); m = m.plusMonths(1) }
        return out
    }

    private static func txIn(_ s: isolated DemoStore, _ start: LocalDate, _ end: LocalDate, _ status: ReportStatus) -> [Transaction] {
        months(start, end).flatMap { s.month($0) }.filter { $0.date >= start && $0.date <= end }
            .filter { status == .all || (status == .paid) == $0.paid }
    }

    private static func totals(_ list: [Transaction]) -> ReportTotals {
        let inc = list.filter { $0.type.isIncome }, exp = list.filter { !$0.type.isIncome }
        return ReportTotals(income: inc.sum, expenseFixed: list.filter { $0.type == .fixed }.sum, expenseVariable: list.filter { $0.type == .variable }.sum,
                            paidIncome: inc.filter(\.paid).sum, paidExpense: exp.filter(\.paid).sum,
                            openIncome: inc.filter { !$0.paid }.sum, openExpense: exp.filter { !$0.paid }.sum, count: Int64(list.count))
    }

    private static func slices(_ list: [Transaction], key: (Transaction) -> (String, String, ContactCategory?)) -> [ReportSlice] {
        var acc: [String: ReportSlice] = [:]
        var order: [String] = []
        for t in list {
            let (k, label, group) = key(t)
            let id = "\(k)|\(t.type.rawValue)"
            if acc[id] == nil { order.append(id); acc[id] = ReportSlice(key: k, label: label, type: t.type, total: 0, count: 0, group: group) }
            acc[id]!.total += t.value
            acc[id]!.count += 1
        }
        return order.map { acc[$0]! }
    }

    public func overview(start: LocalDate, end: LocalDate, status: ReportStatus) async -> Outcome<ReportOverview> {
        await wait()
        let current = clock.currentMonth()
        return .success(await store.read { s in
            let list = Self.txIn(s, start, end, status)
            let whole = start.day == 1 && end == end.yearMonth.lastDay
            let (ps, pe): (LocalDate, LocalDate)
            if whole {
                let n = start.yearMonth.months(until: end.yearMonth) + 1
                ps = start.yearMonth.minusMonths(n).firstDay; pe = start.yearMonth.minusMonths(1).lastDay
            } else {
                let n = start.days(until: end) + 1
                ps = start.minusDays(n); pe = start.minusDays(1)
            }
            let flows = Self.months(start, end).map { m in
                let t = list.filter { $0.date.yearMonth == m }
                return MonthFlow(month: m, income: t.filter { $0.type.isIncome }.sum, expense: t.filter { !$0.type.isIncome }.sum, projected: m > current)
            }
            var days: [LocalDate: (Decimal, Decimal)] = [:]
            for t in list { var d = days[t.date] ?? (0, 0); if t.type.isIncome { d.0 += t.value } else { d.1 += t.value }; days[t.date] = d }
            return ReportOverview(
                start: start, end: end, currency: "BRL", accountName: s.workspace.account?.name ?? "Conta corrente",
                current: Self.totals(list), previous: Self.totals(Self.txIn(s, ps, pe, status)), months: flows,
                breakdown: [
                    .category: Self.slices(list) { (($0.category?.id).map(String.init) ?? "none", $0.category?.name ?? "Sem categoria", nil) },
                    .contact: Self.slices(list) { (($0.contact?.id).map(String.init) ?? "none", $0.contact?.name ?? "Sem contato", $0.contact?.category) },
                    .contactKind: Self.slices(list) { ($0.contact?.category?.rawValue ?? "none", $0.contact?.category?.label ?? "Sem tipo", $0.contact?.category) },
                    .costCenter: Self.slices(list) { (($0.costCenter?.id).map(String.init) ?? "none", $0.costCenter?.name ?? "Sem centro de custo", nil) },
                    .paymentType: Self.slices(list) { ($0.paymentType?.rawValue ?? "none", $0.paymentType?.label ?? "Não informado", nil) }
                ],
                topExpenses: list.filter { !$0.type.isIncome }.sorted { $0.value > $1.value }.prefix(10).map {
                    ReportExpense(id: $0.id, date: $0.date, description: $0.description, contact: $0.contact?.name, category: $0.category?.name, value: $0.value, paid: $0.paid)
                },
                days: days.keys.sorted().map { ReportDay(date: $0, income: days[$0]!.0, expense: days[$0]!.1) }
            )
        })
    }

    public func day(_ date: LocalDate) async -> Outcome<DayExpenses> {
        await wait()
        return .success(await store.read { s in
            let items = s.month(date.yearMonth).filter { $0.date == date && !$0.type.isIncome }.sorted { $0.value > $1.value }
            return DayExpenses(date: date, total: items.sum, count: items.count, items: items.map {
                ReportDayItem(id: $0.id, description: $0.description, contact: $0.contact?.name, category: $0.category, type: $0.type, value: $0.value, paid: $0.paid)
            })
        })
    }
}

public final class DemoRegistryRepository: RegistryRepository {
    private let store: DemoStore
    public init(store: DemoStore) { self.store = store }

    public func contacts(_ category: ContactCategory?) async -> Outcome<[ContactDetails]> {
        await wait()
        return .success(await store.read { s in
            s.contacts.filter { category == nil || $0.category == category }.sorted { $0.name < $1.name }.map { c in
                if var d = s.contactExtras[c.id] { d.contact = c; return d }
                return ContactDetails(contact: c, personType: c.category == .worker ? .personal : .company, document: nil, city: "São Paulo", state: "SP", description: nil)
            }
        })
    }

    public func contactDebts() async -> Outcome<ContactDebts> {
        await wait()
        return .success(await store.read { s in
            let open = (0...12).flatMap { s.month(s.baseMonth.plusMonths($0)) }.filter { !$0.paid && $0.contact != nil }
            func debts(_ list: [Transaction]) -> [ContactDebt] {
                Dictionary(grouping: list) { $0.contact!.id }.map { id, v in ContactDebt(contactId: id, contactName: v[0].contact!.name, value: v.sum) }.sorted { $0.value > $1.value }
            }
            return ContactDebts(owesMe: debts(open.filter { $0.type.isIncome }), iOwe: debts(open.filter { !$0.type.isIncome }))
        })
    }

    public func saveContact(_ input: ContactInput) async -> Outcome<Void> {
        await wait()
        await store.update { s in
            let c = Contact(id: input.id ?? s.newId(), name: input.name.trimmingCharacters(in: .whitespaces), category: input.category,
                            phone: input.cellphone.clean, email: input.email.clean)
            if let i = s.contacts.firstIndex(where: { $0.id == c.id }) { s.contacts[i] = c } else { s.contacts.append(c) }
            s.contactExtras[c.id] = ContactDetails(contact: c, personType: input.personType, document: input.document.clean, city: input.city.clean, state: nil, description: input.description.clean)
        }
        return .success(())
    }

    public func deleteContact(_ id: Int64) async -> Outcome<Void> {
        await wait()
        return await store.read { s -> Outcome<Void> in
            if s.all().contains(where: { $0.contact?.id == id }) { return .failure(.validation("Este contato tem lançamentos vinculados e não pode ser excluído.")) }
            if let c = s.contacts.first(where: { $0.id == id }) { s.trash[id] = c }
            s.contacts.removeAll { $0.id == id }
            return .success(())
        }
    }

    public func restoreContact(_ id: Int64) async -> Outcome<Void> {
        await wait()
        return await store.read { s -> Outcome<Void> in
            guard let c = s.trash.removeValue(forKey: id) as? Contact else { return .failure(.notFound) }
            s.contacts.append(c)
            return .success(())
        }
    }

    public func categoryOverview(_ month: YearMonth) async -> Outcome<CategoryOverview> {
        await wait()
        let overview: CategoryOverview = await store.read { s in
            let list: [Transaction] = s.month(month)
            let all: [Transaction] = s.all()
            let unsorted: [CategoryView] = s.categories.map { c -> CategoryView in
                let mine = list.filter { $0.category?.id == c.id }
                let spent = mine.filter { !$0.type.isIncome }.sum
                let l = s.limits.first { $0.categoryId == c.id }
                let income: Decimal = mine.filter { $0.type.isIncome }.sum
                let usage = Int64(all.filter { $0.category?.id == c.id }.count)
                var view = CategoryView(category: c, spent: spent, income: income, count: Int64(mine.count), usage: usage)
                if let l {
                    view.limitId = l.id
                    view.limit = l.limit
                    view.limitPercent = pct(spent, l.limit)
                    view.limitStatus = limitStatus(spent: spent, limit: l.limit, alertPercent: l.alert)
                    view.alertPercent = l.alert
                }
                return view
            }
            let views = unsorted.sorted(by: Self.bySpent)
            let total: Decimal = views.reduce(Decimal(0)) { $0 + $1.spent }
            return CategoryOverview(month: month, currency: "BRL", spent: total, categories: views)
        }
        return .success(overview)
    }

    private static func bySpent(_ a: CategoryView, _ b: CategoryView) -> Bool {
        a.spent == b.spent ? a.category.name < b.category.name : a.spent > b.spent
    }

    public func saveCategory(_ input: CategoryInput) async -> Outcome<TransactionCategory> {
        await wait()
        return await store.read { s -> Outcome<TransactionCategory> in
            let name = input.name.trimmingCharacters(in: .whitespaces)
            if name.isEmpty { return .failure(.validation("Dê um nome à categoria.")) }
            if s.categories.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame && $0.id != input.id }) { return .failure(.validation("Já existe uma categoria com esse nome.")) }
            let c = TransactionCategory(id: input.id ?? s.newId(), name: name, description: input.description.clean, subscription: input.subscription,
                                        brand: input.brand, icon: input.icon, color: input.color, logo: input.logo)
            if let id = input.id {
                guard let i = s.categories.firstIndex(where: { $0.id == id }) else { return .failure(.notFound) }
                if s.categories[i].systemDefault { return .failure(.validation("Categorias padrão do sistema não podem ser alteradas nem excluídas.")) }
                s.categories[i] = c
            } else { s.categories.append(c) }
            return .success(c)
        }
    }

    public func deleteCategory(_ id: Int64) async -> Outcome<Void> {
        await wait()
        return await store.read { s -> Outcome<Void> in
            guard let c = s.categories.first(where: { $0.id == id }) else { return .failure(.notFound) }
            if c.systemDefault { return .failure(.validation("Categorias padrão do sistema não podem ser alteradas nem excluídas.")) }
            if s.all().contains(where: { $0.category?.id == id }) { return .failure(.validation("Esta categoria tem lançamentos e não pode ser excluída.")) }
            s.trash[id] = c
            s.categories.removeAll { $0.id == id }
            return .success(())
        }
    }

    public func restoreCategory(_ id: Int64) async -> Outcome<Void> {
        await wait()
        return await store.read { s -> Outcome<Void> in
            guard let c = s.trash.removeValue(forKey: id) as? TransactionCategory else { return .failure(.notFound) }
            s.categories.append(c)
            return .success(())
        }
    }

    public func costCenters() async -> Outcome<[CostCenter]> {
        let list: [CostCenter] = await store.read { $0.costCenters }
        return .success(list.sorted { a, b in a.systemDefault != b.systemDefault ? !a.systemDefault : a.name < b.name })
    }

    public func costCenterUsage(start: LocalDate, end: LocalDate) async -> Outcome<[CostCenterUsage]> {
        await wait()
        return .success(await store.read { s in
            let list = s.month(start.yearMonth).filter { $0.costCenter != nil && $0.date >= start && $0.date <= end }
            return Dictionary(grouping: list) { $0.costCenter!.id }.map { id, v in
                CostCenterUsage(costCenterId: id, expense: v.filter { !$0.type.isIncome }.sum, income: v.filter { $0.type.isIncome }.sum, count: Int64(v.count))
            }
        })
    }

    public func saveCostCenter(_ input: CostCenterInput) async -> Outcome<Void> {
        await wait()
        return await store.read { s -> Outcome<Void> in
            let cc = CostCenter(id: input.id ?? s.newId(), name: input.name.trimmingCharacters(in: .whitespaces), description: input.description.clean,
                                color: input.color, monthlyBudget: input.monthlyBudget)
            if let i = s.costCenters.firstIndex(where: { $0.id == cc.id }) {
                if s.costCenters[i].systemDefault { return .failure(.validation("Centros de custo padrão do sistema não podem ser alterados nem excluídos.")) }
                s.costCenters[i] = cc
            } else { s.costCenters.append(cc) }
            return .success(())
        }
    }

    public func deleteCostCenter(_ id: Int64) async -> Outcome<Void> {
        await wait()
        return await store.read { s -> Outcome<Void> in
            guard let c = s.costCenters.first(where: { $0.id == id }) else { return .failure(.notFound) }
            if c.systemDefault { return .failure(.validation("Centros de custo padrão do sistema não podem ser alterados nem excluídos.")) }
            if s.all().contains(where: { $0.costCenter?.id == id }) { return .failure(.validation("Este centro de custo tem lançamentos e não pode ser excluído.")) }
            s.trash[id] = c
            s.costCenters.removeAll { $0.id == id }
            return .success(())
        }
    }

    public func restoreCostCenter(_ id: Int64) async -> Outcome<Void> {
        await wait()
        return await store.read { s -> Outcome<Void> in
            guard let c = s.trash.removeValue(forKey: id) as? CostCenter else { return .failure(.notFound) }
            s.costCenters.append(c)
            return .success(())
        }
    }
}

public final class DemoCompanyRepository: CompanyRepository {
    private let store: DemoStore
    public init(store: DemoStore) { self.store = store }

    public func overview() async -> Outcome<Workspace> { await wait(); return .success(await store.workspaceWithBalance()) }

    public func createCompany(_ company: CompanyInput, firstAccount: AccountInput) async -> Outcome<Void> {
        await wait()
        return await store.read { s -> Outcome<Void> in
            if s.workspace.companies.count >= 3 { return .failure(.validation("O seu plano permite até 3 empresas. Fale com o suporte para aumentar.")) }
            let acc = Account(id: s.newId(), name: firstAccount.name.trimmingCharacters(in: .whitespaces), currency: firstAccount.currency,
                              balance: firstAccount.initialBalance ?? 0, defaultAccount: true)
            s.workspace.companies.append(Company(id: s.newId(), name: company.name.trimmingCharacters(in: .whitespaces), type: company.type, typeLabel: company.type.label, accounts: [acc]))
            return .success(())
        }
    }

    public func updateCompany(_ company: CompanyInput) async -> Outcome<Void> {
        await wait()
        await store.update { s in
            if let i = s.workspace.companies.firstIndex(where: { $0.id == company.id }) {
                s.workspace.companies[i].name = company.name.trimmingCharacters(in: .whitespaces)
                s.workspace.companies[i].type = company.type
                s.workspace.companies[i].typeLabel = company.type.label
            }
        }
        return .success(())
    }

    public func deleteCompany(_ id: Int64) async -> Outcome<Void> {
        await wait()
        return await store.read { s -> Outcome<Void> in
            if s.workspace.companyId == id { return .failure(.validation("Esta é a empresa em uso. Escolha outra empresa no topo do Início antes de excluí-la.")) }
            if s.workspace.companies.first(where: { $0.id == id })?.accounts.contains(where: { $0.transactions > 0 }) == true {
                return .failure(.validation("Esta empresa tem contas com lançamentos e não pode ser excluída."))
            }
            s.workspace.companies.removeAll { $0.id == id }
            return .success(())
        }
    }

    public func saveAccount(_ account: AccountInput) async -> Outcome<Void> {
        await wait()
        return await store.read { s -> Outcome<Void> in
            if s.workspace.companies.flatMap(\.accounts).contains(where: { $0.id == account.id && $0.mode == .frozen }) {
                return .failure(.validation("Esta conta foi desconectada do banco e ficou só para consulta."))
            }
            guard let ci = s.workspace.companies.firstIndex(where: { $0.id == account.companyId }) else { return .failure(.notFound) }
            if let id = account.id, let ai = s.workspace.companies[ci].accounts.firstIndex(where: { $0.id == id }) {
                s.workspace.companies[ci].accounts[ai].name = account.name.trimmingCharacters(in: .whitespaces)
            } else {
                let first = s.workspace.companies[ci].accounts.isEmpty
                s.workspace.companies[ci].accounts.append(Account(id: s.newId(), name: account.name.trimmingCharacters(in: .whitespaces), currency: account.currency,
                                                                  balance: account.initialBalance ?? 0, defaultAccount: first))
            }
            return .success(())
        }
    }

    public func deleteAccount(_ id: Int64) async -> Outcome<Void> {
        await wait()
        return await store.read { s -> Outcome<Void> in
            guard let ci = s.workspace.companies.firstIndex(where: { c in c.accounts.contains { $0.id == id } }),
                  let acc = s.workspace.companies[ci].accounts.first(where: { $0.id == id }) else { return .failure(.notFound) }
            if acc.mode == .connected { return .failure(.validation("Conta conectada ao banco: para removê-la, desconecte o banco em Contas.")) }
            if acc.transactions > 0 && acc.mode != .frozen { return .failure(.validation("Esta conta tem lançamentos e não pode ser excluída.")) }
            if s.workspace.companies[ci].accounts.count == 1 { return .failure(.validation("A empresa precisa ter pelo menos uma conta.")) }
            s.workspace.companies[ci].accounts.removeAll { $0.id == id }
            if acc.defaultAccount { s.workspace.companies[ci].accounts[0].defaultAccount = true }
            return .success(())
        }
    }

    public func setDefaultAccount(_ id: Int64) async -> Outcome<Void> {
        await wait()
        await store.update { s in
            for ci in s.workspace.companies.indices where s.workspace.companies[ci].accounts.contains(where: { $0.id == id }) {
                for ai in s.workspace.companies[ci].accounts.indices { s.workspace.companies[ci].accounts[ai].defaultAccount = s.workspace.companies[ci].accounts[ai].id == id }
            }
        }
        return .success(())
    }
}

public final class DemoBillingRepository: BillingRepository {
    private let store: DemoStore
    private let clock: AppClock
    public init(store: DemoStore, clock: AppClock) { self.store = store; self.clock = clock }

    public func overview() async -> Outcome<BillingOverview> {
        await wait()
        let invoices = await store.read { $0.invoices() }
        return .success(BillingOverview(plan: CurrentPlan(planId: 2, name: "Premium", period: .monthly, validUntil: clock.today().plusDays(27), status: .active, isOwner: true),
                                        storage: StorageUsage(usedMb: 340, totalMb: 2048, percent: 17), invoices: invoices))
    }
}

public final class DemoSupportRepository: SupportRepository {
    private let store: DemoStore
    private let clock: AppClock
    public init(store: DemoStore, clock: AppClock) { self.store = store; self.clock = clock }

    public func tickets(_ group: TicketGroup) async -> Outcome<[Ticket]> {
        await wait()
        return .success(await store.read { s in
            s.seedTickets()
            return s.tickets.filter { group == .all || (group == .open) == !$0.status.closed }
                .sorted { ($0.lastMessageAt ?? LocalDateTime(LocalDate(1970, 1, 1))) > ($1.lastMessageAt ?? LocalDateTime(LocalDate(1970, 1, 1))) }
        })
    }

    public func counts() async -> Outcome<TicketCounts> {
        .success(await store.read { s in
            s.seedTickets()
            return TicketCounts(open: Int64(s.tickets.filter { !$0.status.closed }.count), closed: Int64(s.tickets.filter { $0.status.closed }.count),
                                unread: Int64(s.tickets.filter(\.unread).count))
        })
    }

    public func ticket(_ id: Int64) async -> Outcome<Ticket> {
        await wait()
        return await store.read { s -> Outcome<Ticket> in
            s.seedTickets()
            guard let i = s.tickets.firstIndex(where: { $0.id == id }) else { return .failure(.notFound) }
            s.tickets[i].unread = false
            return .success(s.tickets[i])
        }
    }

    public func create(category: TicketCategory, title: String, message: String) async -> Outcome<Ticket> {
        await wait()
        let now = clock.localNow()
        return .success(await store.read { s in
            s.seedTickets()
            let id = s.nextTicketId
            s.nextTicketId += 1
            let t = Ticket(id: id, protocolNumber: "#000\(id)", title: title.trimmingCharacters(in: .whitespaces), category: category, status: .open,
                           createdAt: now, lastMessageAt: now, unread: false, lastMessage: message, lastFromSupport: false,
                           messages: [TicketMessage(id: id * 10, message: message.trimmingCharacters(in: .whitespacesAndNewlines), fromSupport: false, authorName: "Você", createdAt: now)])
            s.tickets.insert(t, at: 0)
            return t
        })
    }

    public func reply(_ id: Int64, message: String) async -> Outcome<Ticket> {
        await wait()
        let now = clock.localNow()
        return await store.read { s -> Outcome<Ticket> in
            guard let i = s.tickets.firstIndex(where: { $0.id == id }) else { return .failure(.notFound) }
            let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
            s.tickets[i].status = .waitingSupport
            s.tickets[i].lastMessageAt = now
            s.tickets[i].lastMessage = text
            s.tickets[i].lastFromSupport = false
            s.tickets[i].messages.append(TicketMessage(id: Int64(s.tickets[i].messages.count + 1000), message: text, fromSupport: false, authorName: "Você", createdAt: now))
            return .success(s.tickets[i])
        }
    }

    public func close(_ id: Int64, solved: Bool) async -> Outcome<Void> {
        await wait()
        await store.update { s in if let i = s.tickets.firstIndex(where: { $0.id == id }) { s.tickets[i].status = solved ? .solved : .unsolved } }
        return .success(())
    }

    public func reopen(_ id: Int64) async -> Outcome<Void> {
        await wait()
        await store.update { s in if let i = s.tickets.firstIndex(where: { $0.id == id }) { s.tickets[i].status = .waitingSupport } }
        return .success(())
    }

    public func myTestimonial() async -> Outcome<Testimonial?> {
        await wait()
        return .success(await store.read { $0.testimonial })
    }

    public func saveTestimonial(_ t: Testimonial) async -> Outcome<Testimonial> {
        await wait()
        if let problem = t.validate() { return .failure(.validation(problem)) }
        var saved = t
        saved.text = t.text.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.authorName = t.authorName.trimmingCharacters(in: .whitespaces)
        saved.status = .pending
        await store.update { [saved] s in s.testimonial = saved }
        return .success(saved)
    }

    public func withdrawTestimonial() async -> Outcome<Void> {
        await wait()
        await store.update { s in s.testimonial = nil }
        return .success(())
    }
}

public extension Repositories {
    /// Modo demonstração: tudo no próprio iPhone, sem servidor (qualquer senha entra).
    static func demo(storage: TokenStorage, clock: AppClock = SystemClock()) -> Repositories {
        let store = DemoStore(clock: clock)
        return Repositories(
            auth: DemoAuthRepository(storage: storage),
            users: DemoUserRepository(clock: clock, storage: storage),
            workspaces: DemoWorkspaceRepository(store: store),
            transactions: DemoTransactionRepository(store: store, clock: clock),
            planning: DemoPlanningRepository(store: store),
            openFinance: DemoOpenFinanceRepository(store: store),
            stories: DemoStoryRepository(store: store),
            notifications: DemoNotificationRepository(store: store),
            reports: DemoReportRepository(store: store, clock: clock),
            registry: DemoRegistryRepository(store: store),
            companies: DemoCompanyRepository(store: store),
            billing: DemoBillingRepository(store: store, clock: clock),
            support: DemoSupportRepository(store: store, clock: clock)
        )
    }
}
