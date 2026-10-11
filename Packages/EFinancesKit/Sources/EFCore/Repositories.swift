import Foundation

/* Contratos da camada de dados. Há duas implementações: a remota (API do e-Finances) e a de demonstração
   (dados no próprio iPhone). As telas só conhecem estes protocolos. */

public enum LogoutReason: Sendable { case none, user, expired }

public enum SessionState: Equatable, Sendable {
    case unknown
    case loggedOut(LogoutReason)
    case loggedIn(email: String)

    public var isLoggedIn: Bool { if case .loggedIn = self { return true } else { return false } }
}

public protocol AuthRepository: Sendable {
    /// Sessão guardada no Keychain (e ainda renovável) ao abrir o app.
    func restore() async -> SessionState
    func login(email: String, password: String, remember: Bool) async -> Outcome<String>
    func logout() async
    func forgotPassword(email: String) async -> Outcome<Void>
    func register(_ data: RegisterData) async -> Outcome<Void>
}

public protocol UserRepository: Sendable {
    func profile() async -> Outcome<UserProfile>
}

public protocol WorkspaceRepository: Sendable {
    func refresh() async -> Outcome<Workspace>
    func select(companyId: Int64, accountId: Int64) async -> Outcome<Workspace>
}

public protocol TransactionRepository: Sendable {
    func month(_ month: YearMonth) async -> Outcome<[Transaction]>
    func get(_ id: Int64, month: YearMonth?) async -> Outcome<Transaction>
    func setPaid(_ id: Int64, paid: Bool) async -> Outcome<Void>
    /// [scope]: edição de uma ocorrência de recorrente (só esta, esta e as próximas, todas).
    func save(_ draft: TransactionDraft, scope: SeriesScope?) async -> Outcome<[Transaction]>
    /// Lançamento de conta conectada ao banco: grava só a organização.
    func organize(_ draft: TransactionDraft) async -> Outcome<Void>
    /// [scope]: recorrente ou parcela (só esta, esta e as próximas, todas).
    func delete(_ id: Int64, scope: SeriesScope) async -> Outcome<Void>
    /// Exclusão adiada (Desfazer): some das listas na hora, sem ir ao servidor.
    func hide(_ ids: [Int64]) async
    func unhide(_ ids: [Int64]) async
    /// Regra do recorrente (nil = não é recorrente).
    func series(_ id: Int64) async -> Outcome<SeriesInfo?>
    /// "Termina em" (nil = nunca): as ocorrências em aberto depois da data saem.
    func setSeriesEnd(_ id: Int64, end: LocalDate?) async -> Outcome<SeriesInfo?>
    /// Até quando os recorrentes aparecem num mês aberto à frente.
    func recurrenceLimit() async -> Outcome<LocalDate?>
    func duplicate(_ id: Int64) async -> Outcome<Transaction>
    func categories() async -> Outcome<[TransactionCategory]>
    func contacts() async -> Outcome<[Contact]>
    func costCenters() async -> Outcome<[CostCenter]>
    func installments() async -> Outcome<Installments>
    /// Assinaturas pelas categorias de assinatura (lançamentos manuais e do banco) + contas fixas detectadas no banco.
    func subscriptions() async -> Outcome<Subscriptions>
}

public protocol PlanningRepository: Sendable {
    func limits(_ month: YearMonth) async -> Outcome<LimitsOverview>
    func saveLimit(categoryId: Int64, monthlyLimit: Decimal, alertPercent: Int) async -> Outcome<Void>
    func deleteLimit(_ id: Int64) async -> Outcome<Void>
    func yearFlow(_ year: Int) async -> Outcome<[MonthFlow]>
}

public protocol OpenFinanceRepository: Sendable {
    func connections() async -> Outcome<[BankConnection]>
    func accountSummary(_ id: Int64, start: LocalDate, end: LocalDate) async -> Outcome<BankAccountSummary>
    func accountTransactions(_ id: Int64, start: LocalDate, end: LocalDate) async -> Outcome<[BankTransaction]>
    func sync(_ connectionId: Int64) async -> Outcome<Void>
    func installments() async -> Outcome<Installments>
    /// Muda a empresa onde as contas desta conexão aparecem.
    func changeCompany(_ connectionId: Int64, companyId: Int64) async -> Outcome<Void>
    /// Desconecta as contas escolhidas (vazio = o banco inteiro): ficam congeladas ou, com [removeAccounts], são apagadas.
    func disconnect(_ connectionId: Int64, removeAccounts: Bool, accountIds: [Int64]) async -> Outcome<Void>
}

public protocol StoryRepository: Sendable {
    func pending() async -> Outcome<Story?>
    func latest() async -> Outcome<Story>
    func markSeen(_ periodKey: String) async
}

public protocol NotificationRepository: Sendable {
    func list(unreadOnly: Bool) async -> Outcome<NotificationsPage>
    func markRead(_ id: Int64) async -> Outcome<Int64>
    func markAllRead() async -> Outcome<Void>
}

public protocol ReportRepository: Sendable {
    func overview(start: LocalDate, end: LocalDate, status: ReportStatus) async -> Outcome<ReportOverview>
    /// Despesas de um dia (calendário de gastos).
    func day(_ date: LocalDate) async -> Outcome<DayExpenses>
}

public protocol RegistryRepository: Sendable {
    func contacts(_ category: ContactCategory?) async -> Outcome<[ContactDetails]>
    func contactDebts() async -> Outcome<ContactDebts>
    func saveContact(_ input: ContactInput) async -> Outcome<Void>
    func deleteContact(_ id: Int64) async -> Outcome<Void>
    func restoreContact(_ id: Int64) async -> Outcome<Void>

    func categoryOverview(_ month: YearMonth) async -> Outcome<CategoryOverview>
    func saveCategory(_ input: CategoryInput) async -> Outcome<TransactionCategory>
    func deleteCategory(_ id: Int64) async -> Outcome<Void>
    func restoreCategory(_ id: Int64) async -> Outcome<Void>

    func costCenters() async -> Outcome<[CostCenter]>
    func costCenterUsage(start: LocalDate, end: LocalDate) async -> Outcome<[CostCenterUsage]>
    func saveCostCenter(_ input: CostCenterInput) async -> Outcome<Void>
    func deleteCostCenter(_ id: Int64) async -> Outcome<Void>
    func restoreCostCenter(_ id: Int64) async -> Outcome<Void>
}

public protocol CompanyRepository: Sendable {
    func overview() async -> Outcome<Workspace>
    /// Cria a empresa e a primeira conta (a web faz o mesmo em duas chamadas).
    func createCompany(_ company: CompanyInput, firstAccount: AccountInput) async -> Outcome<Void>
    func updateCompany(_ company: CompanyInput) async -> Outcome<Void>
    func deleteCompany(_ id: Int64) async -> Outcome<Void>
    func saveAccount(_ account: AccountInput) async -> Outcome<Void>
    func deleteAccount(_ id: Int64) async -> Outcome<Void>
    func setDefaultAccount(_ id: Int64) async -> Outcome<Void>
}

/// Plano e faturas, só leitura (na 1ª versão a compra não acontece dentro do app).
public protocol BillingRepository: Sendable {
    func overview() async -> Outcome<BillingOverview>
}

public protocol SupportRepository: Sendable {
    func tickets(_ group: TicketGroup) async -> Outcome<[Ticket]>
    func counts() async -> Outcome<TicketCounts>
    func ticket(_ id: Int64) async -> Outcome<Ticket>
    func create(category: TicketCategory, title: String, message: String) async -> Outcome<Ticket>
    func reply(_ id: Int64, message: String) async -> Outcome<Ticket>
    func close(_ id: Int64, solved: Bool) async -> Outcome<Void>
    /// Depoimento de quem está logado (nil = ainda não escreveu).
    func myTestimonial() async -> Outcome<Testimonial?>
    /// Cria ou edita (editar volta para análise).
    func saveTestimonial(_ t: Testimonial) async -> Outcome<Testimonial>
    /// Retira do site na hora.
    func withdrawTestimonial() async -> Outcome<Void>
    func reopen(_ id: Int64) async -> Outcome<Void>
}

/// Todos os repositórios do app (remoto ou demonstração), montados uma vez na abertura.
public struct Repositories: Sendable {
    public let auth: any AuthRepository
    public let users: any UserRepository
    public let workspaces: any WorkspaceRepository
    public let transactions: any TransactionRepository
    public let planning: any PlanningRepository
    public let openFinance: any OpenFinanceRepository
    public let stories: any StoryRepository
    public let notifications: any NotificationRepository
    public let reports: any ReportRepository
    public let registry: any RegistryRepository
    public let companies: any CompanyRepository
    public let billing: any BillingRepository
    public let support: any SupportRepository

    public init(auth: any AuthRepository, users: any UserRepository, workspaces: any WorkspaceRepository, transactions: any TransactionRepository,
                planning: any PlanningRepository, openFinance: any OpenFinanceRepository, stories: any StoryRepository,
                notifications: any NotificationRepository, reports: any ReportRepository, registry: any RegistryRepository,
                companies: any CompanyRepository, billing: any BillingRepository, support: any SupportRepository) {
        self.auth = auth; self.users = users; self.workspaces = workspaces; self.transactions = transactions; self.planning = planning
        self.openFinance = openFinance; self.stories = stories; self.notifications = notifications; self.reports = reports
        self.registry = registry; self.companies = companies; self.billing = billing; self.support = support
    }
}
