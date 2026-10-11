import Foundation
import EFCore

/* Relatórios, cadastros, empresas e contas, plano e suporte pela API do e-Finances. */

public final class RemoteReportRepository: ReportRepository {
    private let api: APIClient
    private let clock: AppClock
    public init(api: APIClient, clock: AppClock) { self.api = api; self.clock = clock }

    public func overview(start: LocalDate, end: LocalDate, status: ReportStatus) async -> Outcome<ReportOverview> {
        let today = clock.today()
        let r: Outcome<ReportFullDTO> = await api.call(.get, "api/reports/overview", query: [("start", DateFormats.api(start)), ("end", DateFormats.api(end)), ("status", status.rawValue)])
        return r.map { $0.toDomain(start: start, end: end, today: today) }
    }

    public func day(_ date: LocalDate) async -> Outcome<DayExpenses> {
        let r: Outcome<ReportDayDetailDTO> = await api.call(.get, "api/reports/day", query: [("date", DateFormats.api(date)), ("status", "ALL")])
        return r.map { $0.toDomain(fallback: date) }
    }
}

public actor RemoteRegistryRepository: RegistryRepository {
    private let api: APIClient
    private let clock: AppClock
    /// Contatos como vieram da API: o update reenvia o objeto inteiro para não apagar campos que o app não edita.
    private var raw: [Int64: ContactFullDTO] = [:]

    public init(api: APIClient, clock: AppClock) { self.api = api; self.clock = clock }

    public func contacts(_ category: ContactCategory?) async -> Outcome<[ContactDetails]> {
        let r: Outcome<PageDTO<ContactFullDTO>> = await api.call(.get, "api/contact/find", query: [("category", category?.rawValue), ("page", "0"), ("size", "500")])
        return r.map { page in
            let list = page.content ?? []
            for c in list { if let id = c.id { raw[id] = c } }
            return list.compactMap { $0.toDetails() }
        }
    }

    public func contactDebts() async -> Outcome<ContactDebts> {
        let start = "01/01/1990", end = DateFormats.api(clock.today().plusYears(10))
        async let owes: Outcome<[ContactDebtDTO]> = api.call(.get, "api/transaction/find-analise-dividas-contatos", query: [("transactionType", "RECEBIMENTO"), ("dtStart", start), ("dtEnd", end), ("onlyOpen", "true")])
        async let iOwe: Outcome<[ContactDebtDTO]> = api.call(.get, "api/transaction/find-analise-dividas-contatos", query: [("transactionType", "DESPESAS"), ("dtStart", start), ("dtEnd", end), ("onlyOpen", "true")])
        func map(_ l: [ContactDebtDTO]) -> [ContactDebt] {
            l.compactMap { d in d.contactId.map { ContactDebt(contactId: $0, contactName: d.contactName ?? "", value: money(d.value).magnitude) } }
                .filter { $0.value > 0 }.sorted { $0.value > $1.value }
        }
        let (a, b) = await (owes, iOwe)
        switch (a, b) {
        case (.success(let x), .success(let y)): return .success(ContactDebts(owesMe: map(x), iOwe: map(y)))
        case (.failure(let e), _), (_, .failure(let e)): return .failure(e)
        }
    }

    public func saveContact(_ input: ContactInput) async -> Outcome<Void> {
        var body = input.id.flatMap { raw[$0] } ?? ContactFullDTO(country: "BR")
        body.id = input.id
        body.name = input.name.trimmingCharacters(in: .whitespaces)
        body.category = input.category.rawValue
        body.type = input.personType.rawValue
        body.cellphone = input.cellphone.clean
        if input.personType == .personal { body.personalEmail = input.email.clean } else { body.companyEmail = input.email.clean }
        body.identificationNumber = input.document.clean
        if let doc = input.document.clean {
            body.typeIdentification = body.typeIdentification ?? (doc.filter(\.isNumber).count > 11 ? "CNPJ" : "CPF")
        } else { body.typeIdentification = nil }
        body.city = input.city.clean
        body.description = input.description.clean
        if input.personType == .company { body.birthday = nil }
        return await api.send(.post, input.id == nil ? "api/contact/create" : "api/contact/update", body: body)
    }

    public func deleteContact(_ id: Int64) async -> Outcome<Void> { await api.send(.delete, "api/contact/delete/\(id)") }
    public func restoreContact(_ id: Int64) async -> Outcome<Void> { await api.send(.post, "api/contact/restore/\(id)") }

    public func categoryOverview(_ month: YearMonth) async -> Outcome<CategoryOverview> {
        let r: Outcome<CategoryOverviewDTO> = await api.call(.get, "api/transaction/category/overview", query: [("month", month.description)])
        return r.map { $0.toDomain(fallback: month) }
    }

    public func saveCategory(_ input: CategoryInput) async -> Outcome<TransactionCategory> {
        let r: Outcome<CategoryDTO> = await api.call(.post, "api/transaction/category/save", body: CategorySaveRequest(
            id: input.id, name: input.name.trimmingCharacters(in: .whitespaces), description: input.description.clean, subscription: input.subscription,
            brand: input.brand, icon: input.icon, color: input.color, logo: input.logo))
        return r.flatMap { dto -> Outcome<TransactionCategory> in dto.toDomain().map { .success($0) } ?? .failure(.serverDefault) }
    }

    public func deleteCategory(_ id: Int64) async -> Outcome<Void> { await api.send(.delete, "api/transaction/category/delete/\(id)") }
    public func restoreCategory(_ id: Int64) async -> Outcome<Void> { await api.send(.post, "api/transaction/category/restore/\(id)") }

    public func costCenters() async -> Outcome<[CostCenter]> {
        let r: Outcome<PageDTO<CostCenterDTO>> = await api.call(.get, "api/cost-center/find", query: [("page", "0"), ("size", "500")])
        return r.map { ($0.content ?? []).compactMap { $0.toManaged() } }
    }

    public func costCenterUsage(start: LocalDate, end: LocalDate) async -> Outcome<[CostCenterUsage]> {
        let r: Outcome<[CostCenterSummaryDTO]> = await api.call(.get, "api/cost-center/summary", query: [("start", DateFormats.api(start)), ("end", DateFormats.api(end))])
        return r.map { $0.compactMap { s in s.costCenterId.map { CostCenterUsage(costCenterId: $0, expense: money(s.expense).magnitude, income: money(s.income).magnitude, count: s.count ?? 0) } } }
    }

    public func saveCostCenter(_ input: CostCenterInput) async -> Outcome<Void> {
        let body = CostCenterDTO(id: input.id, name: input.name.trimmingCharacters(in: .whitespaces), description: input.description.clean, idUserOwner: nil,
                                 color: input.color, icon: "pi-sitemap", monthlyBudget: input.monthlyBudget?.doubleValue)
        return await api.send(.post, input.id == nil ? "api/cost-center/create" : "api/cost-center/update", body: body)
    }

    public func deleteCostCenter(_ id: Int64) async -> Outcome<Void> { await api.send(.delete, "api/cost-center/delete/\(id)") }
    public func restoreCostCenter(_ id: Int64) async -> Outcome<Void> { await api.send(.post, "api/cost-center/restore/\(id)") }
}

public final class RemoteCompanyRepository: CompanyRepository {
    private let api: APIClient
    public init(api: APIClient) { self.api = api }

    public func overview() async -> Outcome<Workspace> {
        let r: Outcome<WorkspaceDTO> = await api.call(.get, "api/workspace/overview")
        return r.map { $0.toDomain() }
    }

    public func createCompany(_ company: CompanyInput, firstAccount: AccountInput) async -> Outcome<Void> {
        let r: Outcome<CompanyCreatedDTO> = await api.call(.post, "api/company/create", body: CompanySaveDTO(
            id: nil, companyName: company.name.trimmingCharacters(in: .whitespaces), description: company.description.clean, companyType: company.type.rawValue, city: company.city.clean))
        switch r {
        case .failure(let e): return .failure(e)
        case .success(let c):
            guard let id = c.id else { return .failure(.serverDefault) }
            var acc = firstAccount
            acc.companyId = id
            return await saveAccount(acc)
        }
    }

    public func updateCompany(_ company: CompanyInput) async -> Outcome<Void> {
        await api.send(.post, "api/company/update", body: CompanySaveDTO(id: company.id, companyName: company.name.trimmingCharacters(in: .whitespaces),
                                                                         description: company.description.clean, companyType: company.type.rawValue, city: company.city.clean))
    }

    public func deleteCompany(_ id: Int64) async -> Outcome<Void> { await api.send(.delete, "api/company/delete/\(id)") }

    public func saveAccount(_ a: AccountInput) async -> Outcome<Void> {
        // moeda vazia = não alterar (conta com lançamentos não pode mudar de moeda)
        let body = AccountSaveDTO(id: a.id, name: a.name.trimmingCharacters(in: .whitespaces), description: a.description.clean,
                                  accountBalance: a.initialBalance?.doubleValue, currency: a.currency.clean, userCompanyId: a.companyId)
        return await api.send(.post, a.id == nil ? "api/transaction/account/create" : "api/transaction/account/update", body: body)
    }

    public func deleteAccount(_ id: Int64) async -> Outcome<Void> { await api.send(.delete, "api/transaction/account/delete/\(id)") }

    public func setDefaultAccount(_ id: Int64) async -> Outcome<Void> {
        await api.send(.get, "api/transaction/account/handleDefaultAccount", query: [("accountId", "\(id)"), ("defaultAccount", "true")])
    }
}

public final class RemoteBillingRepository: BillingRepository {
    private let api: APIClient
    private let storage: TokenStorage
    private let clock: AppClock
    public init(api: APIClient, storage: TokenStorage, clock: AppClock) { self.api = api; self.storage = storage; self.clock = clock }

    public func overview() async -> Outcome<BillingOverview> {
        guard let email = storage.load()?.email else { return .failure(.unauthorized) }
        async let user: Outcome<UserDTO> = api.call(.get, "api/users/findByEmail", query: [("email", email)])
        async let storage: Outcome<StorageDTO> = api.call(.get, "api/plan/receipt/size-used")
        async let invoices: Outcome<PageDTO<InvoiceDTO>> = api.call(.get, "api/invoice/find", query: [("page", "0"), ("size", "50"), ("sort", "id,desc")])
        let (u, s, i) = await (user, storage, invoices)
        guard case .success(let dto) = u else { return .failure(u.error ?? .serverDefault) }
        let up = dto.userPlan
        let free = up?.subscriptionType == nil || up?.subscriptionType == "FREE_PERIOD"
        let until = free ? (DateFormats.parseDateTime(up?.freePeriodEndDate)?.date ?? DateFormats.parse(up?.endDate)) : DateFormats.parse(up?.endDate)
        let status: PlanStatus = until.map { $0 < clock.today() } == true ? .expired : free ? .free : .active
        let plan = CurrentPlan(planId: up?.plan?.id, name: up?.plan?.name.map(planLabel) ?? "Sem plano definido", period: enumValue(up?.subscriptionType),
                               validUntil: until, status: status, isOwner: dto.email == nil || dto.email?.lowercased() == email.lowercased())
        let st = s.value.map { StorageUsage(usedMb: $0.sizeUsedInMB ?? 0, totalMb: $0.sizeTotalInMB ?? 1024, percent: $0.percent ?? 0) }
        return .success(BillingOverview(plan: plan, storage: st, invoices: (i.value?.content ?? []).map { $0.toDomain() }))
    }
}

public final class RemoteSupportRepository: SupportRepository {
    private let api: APIClient
    public init(api: APIClient) { self.api = api }

    public func tickets(_ group: TicketGroup) async -> Outcome<[Ticket]> {
        let r: Outcome<PageDTO<TicketDTO>> = await api.call(.get, "api/ticket/mine", query: [("group", group.rawValue), ("page", "0"), ("size", "50")])
        return r.map { ($0.content ?? []).map { $0.toDomain() } }
    }

    public func counts() async -> Outcome<TicketCounts> {
        let r: Outcome<[String: Int64]> = await api.call(.get, "api/ticket/counts")
        return r.map { TicketCounts(open: $0["open"] ?? 0, closed: $0["closed"] ?? 0, unread: $0["unread"] ?? 0) }
    }

    public func ticket(_ id: Int64) async -> Outcome<Ticket> {
        let r: Outcome<TicketDTO> = await api.call(.get, "api/ticket/\(id)")
        return r.map { $0.toDomain() }
    }

    public func create(category: TicketCategory, title: String, message: String) async -> Outcome<Ticket> {
        let r: Outcome<TicketDTO> = await api.call(.post, "api/ticket", body: TicketCreateDTO(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                                                                              category: category.rawValue, message: message.trimmingCharacters(in: .whitespacesAndNewlines)))
        return r.map { $0.toDomain() }
    }

    public func reply(_ id: Int64, message: String) async -> Outcome<Ticket> {
        let r: Outcome<TicketDTO> = await api.call(.post, "api/ticket/\(id)/reply", body: TicketReplyDTO(message: message.trimmingCharacters(in: .whitespacesAndNewlines)))
        return r.map { $0.toDomain() }
    }

    public func close(_ id: Int64, solved: Bool) async -> Outcome<Void> { await api.send(.post, "api/ticket/\(id)/close", query: [("solved", solved ? "true" : "false")]) }
    public func reopen(_ id: Int64) async -> Outcome<Void> { await api.send(.post, "api/ticket/\(id)/reopen") }

    public func myTestimonial() async -> Outcome<Testimonial?> {
        let r: Outcome<TestimonialDTO?> = await api.optional("api/testimonials/mine")
        return r.map { $0?.toDomain() }
    }

    public func saveTestimonial(_ t: Testimonial) async -> Outcome<Testimonial> {
        let r: Outcome<TestimonialDTO> = await api.call(.put, "api/testimonials/mine", body: TestimonialDTO(t))
        return r.map { $0.toDomain() }
    }

    public func withdrawTestimonial() async -> Outcome<Void> { await api.send(.delete, "api/testimonials/mine") }
}

// MARK: - montagem

public extension Repositories {
    /// Repositórios da API (Produção ou Local).
    static func remote(config: AppConfig, storage: TokenStorage, clock: AppClock = SystemClock(), session: URLSession = .shared,
                       onExpired: @escaping @Sendable () -> Void) -> Repositories {
        let api = APIClient(config: config, session: session, storage: storage, clock: clock, onExpired: onExpired)
        return Repositories(
            auth: RemoteAuthRepository(api: api, storage: storage, clock: clock),
            users: RemoteUserRepository(api: api, storage: storage),
            workspaces: RemoteWorkspaceRepository(api: api),
            transactions: RemoteTransactionRepository(api: api, clock: clock),
            planning: RemotePlanningRepository(api: api, clock: clock),
            openFinance: RemoteOpenFinanceRepository(api: api, clock: clock),
            stories: RemoteStoryRepository(api: api),
            notifications: RemoteNotificationRepository(api: api),
            reports: RemoteReportRepository(api: api, clock: clock),
            registry: RemoteRegistryRepository(api: api, clock: clock),
            companies: RemoteCompanyRepository(api: api),
            billing: RemoteBillingRepository(api: api, storage: storage, clock: clock),
            support: RemoteSupportRepository(api: api)
        )
    }
}
