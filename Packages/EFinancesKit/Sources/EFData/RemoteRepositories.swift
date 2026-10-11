import Foundation
import EFCore

/* Implementações que falam com a API do e-Finances (esquemas Produção e Local). */

public final class RemoteAuthRepository: AuthRepository {
    private let api: APIClient
    private let storage: TokenStorage
    private let clock: AppClock

    public init(api: APIClient, storage: TokenStorage, clock: AppClock) {
        self.api = api; self.storage = storage; self.clock = clock
    }

    public func restore() async -> SessionState {
        guard let t = storage.load(), t.usable(clock.epochMillis()) else {
            storage.clear()
            return .loggedOut(.none)
        }
        return .loggedIn(email: t.email)
    }

    public func login(email: String, password: String, remember: Bool) async -> Outcome<String> {
        let mail = email.trimmingCharacters(in: .whitespaces).lowercased()
        let r: Outcome<LoginResponse> = await api.call(.post, "public/auth/login", body: LoginRequest(email: mail, password: password, remember: remember), authenticated: false)
        return r.map { resp in
            let now = clock.epochMillis()
            storage.save(SessionTokens(accessToken: resp.accessToken, refreshToken: resp.refreshToken,
                                       accessExpiresAt: now + (resp.expiresIn ?? 0) * 1000,
                                       refreshExpiresAt: (resp.refreshExpiresIn ?? 0) > 0 ? now + (resp.refreshExpiresIn ?? 0) * 1000 : 0, email: mail))
            return mail
        }
    }

    public func logout() async {
        if let rt = storage.load()?.refreshToken {
            _ = await api.send(.post, "public/auth/logout", body: RefreshTokenRequest(refreshToken: rt), authenticated: false)
        }
        storage.clear()
    }

    public func forgotPassword(email: String) async -> Outcome<Void> {
        await api.send(.post, "public/auth/forgot-password", body: EmailRequest(email: email.trimmingCharacters(in: .whitespaces).lowercased()), authenticated: false)
    }

    public func register(_ d: RegisterData) async -> Outcome<Void> {
        await api.send(.post, "public/registerNewUser", body: RegisterRequest(
            email: d.email.trimmingCharacters(in: .whitespaces).lowercased(), firstName: d.firstName.trimmingCharacters(in: .whitespaces),
            lastName: d.lastName.trimmingCharacters(in: .whitespaces), companyName: d.companyName.trimmingCharacters(in: .whitespaces),
            currency: d.currency, countryName: d.countryName, countryKey: d.countryCode, termsAccepted: d.termsAccepted), authenticated: false)
    }
}

public actor RemoteUserRepository: UserRepository {
    private let api: APIClient
    private let storage: TokenStorage
    private var cached: UserProfile?

    public init(api: APIClient, storage: TokenStorage) { self.api = api; self.storage = storage }

    public func profile() async -> Outcome<UserProfile> {
        guard let email = storage.load()?.email else { return .failure(.unauthorized) }
        if let cached, cached.email.lowercased() == email.lowercased() { return .success(cached) }
        let r: Outcome<UserDTO> = await api.call(.get, "api/users/findByEmail", query: [("email", email)])
        let p = r.map { $0.toDomain(fallbackEmail: email) }
        if case .success(let v) = p { cached = v }
        return p
    }
}

public final class RemoteWorkspaceRepository: WorkspaceRepository {
    private let api: APIClient
    public init(api: APIClient) { self.api = api }

    public func refresh() async -> Outcome<Workspace> {
        let r: Outcome<WorkspaceDTO> = await api.call(.get, "api/workspace")
        return r.map { $0.toDomain() }
    }

    public func select(companyId: Int64, accountId: Int64) async -> Outcome<Workspace> {
        let r: Outcome<WorkspaceDTO> = await api.call(.put, "api/workspace", body: WorkspaceSelectRequest(companyId: companyId, accountId: accountId))
        return r.map { $0.toDomain() }
    }
}

public actor RemoteTransactionRepository: TransactionRepository {
    private let api: APIClient
    private let clock: AppClock
    private var cache: [YearMonth: [Transaction]] = [:]
    /// Excluídos com "Desfazer" ainda pendente: ficam fora das listas até o aviso acabar.
    private var hidden: Set<Int64> = []
    private var contactsCache: [Contact]?
    private var costCentersCache: [CostCenter]?

    public init(api: APIClient, clock: AppClock) { self.api = api; self.clock = clock }

    public func month(_ month: YearMonth) async -> Outcome<[Transaction]> {
        let today = clock.today()
        let r: Outcome<PageDTO<TransactionDTO>> = await api.call(.get, "api/transaction/find", query: [
            ("transactionType", "ALL"), ("dtStart", DateFormats.api(month.firstDay)), ("dtEnd", DateFormats.api(month.lastDay)), ("page", "0"), ("size", "500")
        ])
        let list = r.map { ($0.content ?? []).map { $0.toDomain(today: today) } }
        if case .success(let v) = list { cache[month] = v }
        return list.map { $0.filter { !hidden.contains($0.id) } }
    }

    public func hide(_ ids: [Int64]) { hidden.formUnion(ids) }
    public func unhide(_ ids: [Int64]) { hidden.subtract(ids) }

    public func series(_ id: Int64) async -> Outcome<SeriesInfo?> {
        let r: Outcome<SeriesDTO?> = await api.optional("api/transaction/series", query: [("transactionId", "\(id)")])
        return r.map { $0?.toDomain() }
    }

    public func setSeriesEnd(_ id: Int64, end: LocalDate?) async -> Outcome<SeriesInfo?> {
        let r: Outcome<SeriesDTO> = await api.call(.put, "api/transaction/series/end", query: [("transactionId", "\(id)"), ("endDate", end.map(DateFormats.api))])
        if case .success = r { cache.removeAll() }
        return r.map { $0.toDomain() }
    }

    public func recurrenceLimit() async -> Outcome<LocalDate?> {
        let r: Outcome<RecurrenceLimitDTO> = await api.call(.get, "api/transaction/series/limit")
        return r.map { DateFormats.parse($0.until) }
    }

    public func get(_ id: Int64, month: YearMonth?) async -> Outcome<Transaction> {
        if let t = cache.values.lazy.flatMap({ $0 }).first(where: { $0.id == id }) { return .success(t) }
        if let month, case .success(let list) = await self.month(month), let t = list.first(where: { $0.id == id }) { return .success(t) }
        return .failure(.notFound)
    }

    public func setPaid(_ id: Int64, paid: Bool) async -> Outcome<Void> {
        let r = await api.send(.get, "api/transaction/pay-transaction", query: [("transactionId", "\(id)"), ("isPayed", paid ? "true" : "false")])
        if case .success = r {
            for (k, list) in cache { cache[k] = list.map { var t = $0; if t.id == id { t.paid = paid }; return t } }
        }
        return r
    }

    public func save(_ draft: TransactionDraft, scope: SeriesScope?) async -> Outcome<[Transaction]> {
        let today = clock.today()
        let value = draft.value
        let result: Outcome<[Transaction]>
        if let id = draft.id {
            let before = await get(id, month: draft.date.yearMonth).value
            let r: Outcome<TransactionDTO> = await api.call(.post, "api/transaction/update",
                                                            query: [("scope", scope.flatMap { $0 == .this ? nil : $0.rawValue })],
                                                            body: draft.toUpdateDTO(id: id, value: value, date: draft.date))
            if case .success = r, let before, before.paid != draft.paid { _ = await setPaid(id, paid: draft.paid) }
            result = r.map { var t = $0.toDomain(today: today); t.paid = draft.paid; return [t] }
        } else if draft.paymentMode == .installments {
            let plan = installmentPlan(cents: draft.cents, count: draft.installments, valueIsTotal: draft.valueIsTotal, first: draft.date,
                                       recurrence: draft.recurrence, overrides: draft.installmentDates)
            // competência de cada parcela = o mês dela; a sobra dos centavos fica na 1ª
            let body = plan.dates.enumerated().map { i, d in
                var dto = draft.toUpdateDTO(id: nil, value: plan.values[i], date: d, plot: "\(i + 1)/\(plan.count)")
                dto.transactionRef = DateFormats.api(d.withDay(1))
                return dto
            }
            let r = await api.send(.post, "api/transaction/create/in-batch", body: body)
            if case .success = r, draft.paid {
                // o lote não devolve os ids: busca a 1ª parcela para marcar como paga
                if case .success(let list) = await month(draft.date.yearMonth),
                   let first = list.first(where: { $0.description == draft.description.trimmingCharacters(in: .whitespaces) && $0.plot == "1/\(plan.count)" }) {
                    _ = await setPaid(first.id, paid: true)
                }
            }
            result = r.map { [] }
        } else {
            // mesmo fluxo da web: cria, completa os dados, paga e (se recorrente) gera as próximas
            let created: Outcome<TransactionDTO> = await api.call(.post, "api/transaction/create", query: [("transactionType", draft.type.rawValue)],
                                                                  body: TransactionCreateDTO(description: draft.description.trimmingCharacters(in: .whitespaces),
                                                                                             transactionDate: DateFormats.api(draft.date), value: value.doubleValue))
            switch created {
            case .failure(let e): result = .failure(e)
            case .success(let c):
                let full: Outcome<TransactionDTO> = await api.call(.post, "api/transaction/update", body: draft.toUpdateDTO(id: c.id, value: value, date: draft.date))
                switch full {
                case .failure(let e): result = .failure(e)
                case .success(let f):
                    if draft.paid { _ = await api.send(.get, "api/transaction/pay-transaction", query: [("transactionId", "\(c.id)"), ("isPayed", "true")]) }
                    if draft.paymentMode == .recurring {
                        _ = await api.send(.get, "api/transaction/repeat-transaction", query: [("transactionId", "\(c.id)"), ("repeatableMode", draft.recurrence.rawValue)])
                        if let end = draft.seriesEnd {
                            let _: Outcome<SeriesDTO> = await api.call(.put, "api/transaction/series/end", query: [("transactionId", "\(c.id)"), ("endDate", DateFormats.api(end))])
                        }
                    }
                    var t = f.toDomain(today: today)
                    t.paid = draft.paid
                    result = .success([t])
                }
            }
        }
        if case .success = result { cache.removeAll() }
        return result
    }

    public func organize(_ draft: TransactionDraft) async -> Outcome<Void> {
        guard let id = draft.id else { return .failure(.notFound) }
        let original = await get(id, month: draft.date.yearMonth).value
        let r = await api.send(.post, "api/transaction/update", body: draft.toOrganizeDTO(id: id, original: original))
        if case .success = r { cache.removeAll() }
        return r
    }

    public func delete(_ id: Int64, scope: SeriesScope) async -> Outcome<Void> {
        let r = await api.send(.delete, "api/transaction/delete/\(id)/\(scope.deleteMode)")
        if case .success = r {
            if scope == .this { for (k, list) in cache { cache[k] = list.filter { $0.id != id } } } else { cache.removeAll() }
            hidden.remove(id)
        }
        return r
    }

    public func duplicate(_ id: Int64) async -> Outcome<Transaction> {
        let today = clock.today()
        let r: Outcome<TransactionDTO> = await api.call(.get, "api/transaction/duplicate/\(id)")
        if case .success = r { cache.removeAll() }
        return r.map { $0.toDomain(today: today) }
    }

    // sem cache: a tela Categorias muda nome e aparência
    public func categories() async -> Outcome<[TransactionCategory]> {
        let r: Outcome<PageDTO<CategoryDTO>> = await api.call(.get, "api/transaction/category/find", query: [("page", "0"), ("size", "500")])
        return r.map { ($0.content ?? []).compactMap { $0.toDomain() }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending } }
    }

    public func contacts() async -> Outcome<[Contact]> {
        if let contactsCache { return .success(contactsCache) }
        let r: Outcome<PageDTO<ContactDTO>> = await api.call(.get, "api/contact/find", query: [("page", "0"), ("size", "500")])
        let list = r.map { ($0.content ?? []).compactMap { $0.toDomain() }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending } }
        if case .success(let v) = list { contactsCache = v }
        return list
    }

    public func costCenters() async -> Outcome<[CostCenter]> {
        if let costCentersCache { return .success(costCentersCache) }
        let r: Outcome<PageDTO<CostCenterDTO>> = await api.call(.get, "api/cost-center/find", query: [("page", "0"), ("size", "500")])
        let list = r.map { ($0.content ?? []).compactMap { $0.toDomain() } }
        if case .success(let v) = list { costCentersCache = v }
        return list
    }

    public func installments() async -> Outcome<Installments> {
        let r: Outcome<InstallmentsDTO> = await api.call(.get, "api/transaction/installments")
        return r.map { $0.toDomain() }
    }

    public func subscriptions() async -> Outcome<Subscriptions> {
        let r: Outcome<SubscriptionsDTO> = await api.call(.get, "api/transaction/subscriptions")
        return r.map { $0.toDomain() }
    }

    /// Cadastros mudaram em outra tela (contato criado, centro de custo editado).
    public func invalidateLookups() { contactsCache = nil; costCentersCache = nil }
}

public final class RemotePlanningRepository: PlanningRepository {
    private let api: APIClient
    private let clock: AppClock
    public init(api: APIClient, clock: AppClock) { self.api = api; self.clock = clock }

    public func limits(_ month: YearMonth) async -> Outcome<LimitsOverview> {
        let r: Outcome<LimitsDTO> = await api.call(.get, "api/limits", query: [("month", month.description)])
        return r.map { $0.toDomain(fallback: month) }
    }

    public func saveLimit(categoryId: Int64, monthlyLimit: Decimal, alertPercent: Int) async -> Outcome<Void> {
        let r: Outcome<LimitItemDTO> = await api.call(.post, "api/limits", body: LimitSaveRequest(categoryId: categoryId, monthlyLimit: monthlyLimit.doubleValue, alertPercent: alertPercent))
        return r.map { _ in () }
    }

    public func deleteLimit(_ id: Int64) async -> Outcome<Void> { await api.send(.delete, "api/limits/\(id)") }

    public func yearFlow(_ year: Int) async -> Outcome<[MonthFlow]> {
        let today = clock.today()
        let r: Outcome<ReportFullDTO> = await api.call(.get, "api/reports/overview", query: [("start", DateFormats.api(LocalDate(year, 1, 1))), ("end", DateFormats.api(LocalDate(year, 12, 31))), ("status", "ALL")])
        return r.map { dto in
            let flows = monthFlows(dto.months, today: today)
            return (1...12).map { m in
                flows.first { $0.month.month == m && $0.month.year == year }
                    ?? MonthFlow(month: YearMonth(year, m), income: 0, expense: 0, projected: YearMonth(year, m) > today.yearMonth)
            }
        }
    }
}

public final class RemoteOpenFinanceRepository: OpenFinanceRepository {
    private let api: APIClient
    private let clock: AppClock
    public init(api: APIClient, clock: AppClock) { self.api = api; self.clock = clock }

    public func connections() async -> Outcome<[BankConnection]> {
        let r: Outcome<[ConnectionDTO]> = await api.call(.get, "api/open-finance/connections")
        return r.map { $0.map { $0.toDomain() } }
    }

    public func accountSummary(_ id: Int64, start: LocalDate, end: LocalDate) async -> Outcome<BankAccountSummary> {
        let r: Outcome<OfSummaryDTO> = await api.call(.get, "api/open-finance/accounts/\(id)/summary", query: [("start", DateFormats.api(start)), ("end", DateFormats.api(end))])
        return r.map { $0.toDomain() }
    }

    public func accountTransactions(_ id: Int64, start: LocalDate, end: LocalDate) async -> Outcome<[BankTransaction]> {
        let today = clock.today()
        let r: Outcome<PageDTO<OfTransactionDTO>> = await api.call(.get, "api/open-finance/accounts/\(id)/transactions",
                                                                   query: [("start", DateFormats.api(start)), ("end", DateFormats.api(end)), ("page", "0"), ("size", "50")])
        return r.map { ($0.content ?? []).map { $0.toDomain(today: today) } }
    }

    public func sync(_ connectionId: Int64) async -> Outcome<Void> {
        let r: Outcome<ConnectionDTO> = await api.call(.post, "api/open-finance/connections/\(connectionId)/sync", query: [("force", "false")])
        return r.map { _ in () }
    }

    public func installments() async -> Outcome<Installments> {
        let r: Outcome<InstallmentsDTO> = await api.call(.get, "api/open-finance/insights/installments")
        return r.map { $0.toDomain() }
    }

    public func changeCompany(_ connectionId: Int64, companyId: Int64) async -> Outcome<Void> {
        let r: Outcome<ConnectionDTO> = await api.call(.put, "api/open-finance/connections/\(connectionId)/company", body: CompanyRefRequest(companyId: companyId))
        return r.map { _ in () }
    }

    public func disconnect(_ connectionId: Int64, removeAccounts: Bool, accountIds: [Int64]) async -> Outcome<Void> {
        await api.send(.delete, "api/open-finance/connections/\(connectionId)",
                       query: [("removeAccounts", removeAccounts ? "true" : "false"), ("accounts", accountIds.isEmpty ? nil : accountIds.map(String.init).joined(separator: ","))])
    }
}

public final class RemoteStoryRepository: StoryRepository {
    private let api: APIClient
    public init(api: APIClient) { self.api = api }

    public func pending() async -> Outcome<Story?> {
        let r: Outcome<StoryDTO?> = await api.optional("api/story/pending")
        return r.map { $0?.toDomain() }
    }

    public func latest() async -> Outcome<Story> {
        let r: Outcome<StoryDTO> = await api.call(.get, "api/story")
        return r.map { $0.toDomain() }
    }

    public func markSeen(_ periodKey: String) async { _ = await api.send(.post, "api/story/seen", body: StorySeenRequest(periodKey: periodKey)) }
}

public final class RemoteNotificationRepository: NotificationRepository {
    private let api: APIClient
    public init(api: APIClient) { self.api = api }

    public func list(unreadOnly: Bool) async -> Outcome<NotificationsPage> {
        let r: Outcome<NotificationsPageDTO> = await api.call(.get, "api/notifications", query: [("unread", unreadOnly ? "true" : "false"), ("size", "50")])
        return r.map { NotificationsPage(items: ($0.items ?? []).map { $0.toDomain() }, unread: $0.unread ?? 0) }
    }

    public func markRead(_ id: Int64) async -> Outcome<Int64> {
        let r: Outcome<UnreadDTO> = await api.call(.post, "api/notifications/\(id)/read", query: [("read", "true")])
        return r.map { $0.unread ?? 0 }
    }

    public func markAllRead() async -> Outcome<Void> {
        let r: Outcome<UnreadDTO> = await api.call(.post, "api/notifications/read-all")
        return r.map { _ in () }
    }
}
