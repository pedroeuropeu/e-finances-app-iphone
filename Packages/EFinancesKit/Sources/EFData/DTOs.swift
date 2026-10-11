import Foundation

/* Formatos da API do e-Finances. O backend omite campos nulos (Jackson NON_NULL), então quase tudo é opcional.
   Datas chegam como "dd/MM/yyyy" e "dd/MM/yyyy HH:mm:ss". */

// MARK: - autenticação

struct LoginRequest: Encodable, Sendable { var email: String; var password: String; var remember: Bool }

struct LoginResponse: Decodable, Sendable {
    var accessToken: String
    var refreshToken: String?
    var expiresIn: Int64?
    var refreshExpiresIn: Int64?
}

struct EmailRequest: Encodable, Sendable { var email: String }
struct RefreshTokenRequest: Encodable, Sendable { var refreshToken: String }

struct RegisterRequest: Encodable, Sendable {
    var email: String
    var firstName: String
    var lastName: String
    var companyName: String
    var companyType = "FAMILY"
    var accountName = "Conta corrente"
    var accountDescription = "Conta principal"
    var currency: String
    var accountBalance = 0.0
    var countryName: String
    var countryKey: String
    var termsAccepted: Bool
}

// MARK: - usuário e workspace

struct UserDTO: Decodable, Sendable {
    var id: Int64?
    var email: String?
    var firstName: String?
    var lastName: String?
    var completeName: String?
    var currency: String?
    var userPlan: UserPlanDTO?
}

struct UserPlanDTO: Decodable, Sendable {
    var plan: PlanDTO?
    var startDate: String?
    var endDate: String?
    var freePeriodEndDate: String?
    var subscriptionType: String?
}

struct PlanDTO: Decodable, Sendable { var id: Int64?; var name: String?; var storageLimitMb: Int64? }

struct WorkspaceDTO: Decodable, Sendable {
    var companyId: Int64?
    var accountId: Int64?
    var companies: [WorkspaceCompanyDTO]?
}

struct WorkspaceCompanyDTO: Decodable, Sendable {
    var id: Int64
    var name: String?
    var type: String?
    var typeLabel: String?
    var accounts: [WorkspaceAccountDTO]?
}

struct WorkspaceAccountDTO: Decodable, Sendable {
    var id: Int64
    var name: String?
    var currency: String?
    var balance: Double?
    var defaultAccount: Bool?
    var transactions: Int64?
    /// Conta do banco: connected = recebe do banco; frozen = desconectada, só consulta.
    var connected: Bool?
    var frozen: Bool?
    var bankName: String?
    var bankLogoUrl: String?
    var bankColor: String?
}

struct WorkspaceSelectRequest: Encodable, Sendable { var companyId: Int64; var accountId: Int64? }

struct PageDTO<T: Decodable & Sendable>: Decodable, Sendable {
    var content: [T]?
    var totalElements: Int64?
    var last: Bool?
}

// MARK: - lançamentos

struct TransactionDTO: Decodable, Sendable {
    var id: Int64
    var description: String?
    var details: String?
    var docNumber: String?
    var plotDescription: String?
    var value: Double?
    var paymentType: String?
    var paymentMode: String?
    var paymentModeRecurrence: String?
    var transactionType: String?
    var payed: Bool?
    var contact: ContactDTO?
    var costCenter: CostCenterDTO?
    var category: CategoryDTO?
    var account: AccountRefDTO?
    var transactionRef: String?
    var transactionDate: String?
    var transactionRootNumber: String?
}

struct SeriesDTO: Decodable, Sendable {
    var id: Int64?
    var frequency: String?
    var active: Bool?
    var endDate: String?
    var nextDate: String?
}

struct RecurrenceLimitDTO: Decodable, Sendable { var until: String?; var monthsAhead: Int? }

struct ContactDTO: Decodable, Sendable {
    var id: Int64?
    var name: String?
    var category: String?
    var cellphone: String?
    var phone: String?
    var personalEmail: String?
    var companyEmail: String?
}

struct CostCenterDTO: Codable, Sendable {
    var id: Int64?
    var name: String?
    var description: String?
    var idUserOwner: Int64?
    var color: String?
    var icon: String?
    var monthlyBudget: Double?
}

struct CategoryDTO: Decodable, Sendable {
    var id: Int64?
    var name: String?
    var description: String?
    var systemDefault: Bool?
    var subscription: Bool?
    var brand: String?
    var icon: String?
    var color: String?
    var logo: String?
}

struct CategoryOverviewDTO: Decodable, Sendable {
    var month: String?
    var currency: String?
    var spent: Double?
    var categories: [CategoryViewDTO]?
}

struct CategoryViewDTO: Decodable, Sendable {
    var id: Int64
    var name: String?
    var description: String?
    var systemDefault: Bool?
    var subscription: Bool?
    var brand: String?
    var icon: String?
    var color: String?
    var logo: String?
    var spent: Double?
    var income: Double?
    var count: Int64?
    var usage: Int64?
    var limitId: Int64?
    var limit: Double?
    var limitPercent: Int?
    var limitStatus: String?
    var alertPercent: Int?
}

struct CategorySaveRequest: Encodable, Sendable {
    var id: Int64?
    var name: String
    var description: String?
    var subscription: Bool
    var brand: String?
    var icon: String?
    var color: String?
    var logo: String?
}

struct AccountRefDTO: Decodable, Sendable { var id: Int64?; var name: String?; var currency: String? }

struct TransactionCreateDTO: Encodable, Sendable {
    var description: String
    var transactionDate: String
    var value: Double
    var payed = false
    var paymentMode = "ONE_TIME"
}

/// Referência por id (existente) ou por nome (o backend cria na hora).
struct RefDTO: Encodable, Sendable, Equatable { var id: Int64?; var name: String?; var category: String? }

struct TransactionUpdateDTO: Encodable, Sendable {
    /// nil = criar (no envio em lote das parcelas).
    var id: Int64?
    var description: String
    var value: Double
    var transactionDate: String
    var transactionRef: String?
    var details: String?
    var docNumber: String?
    var payed: Bool?
    var paymentType: String?
    var paymentMode: String?
    var paymentModeRecurrence: String?
    var plotDescription: String?
    var transactionType: String?
    var contact: RefDTO?
    var category: RefDTO?
    var costCenter: RefDTO?
}

/// Lançamento do banco: só os campos de organização (o servidor recusa mudança em valor, datas e situação).
struct TransactionOrganizeDTO: Encodable, Sendable, Equatable {
    var id: Int64
    var description: String
    var details: String?
    var docNumber: String?
    var paymentType: String?
    var contact: RefDTO?
    var category: RefDTO?
    var costCenter: RefDTO?
}

struct InstallmentsDTO: Decodable, Sendable {
    var items: [InstallmentItemDTO]?
    var remainingTotal: Double?
    var monthlyTotal: Double?
}

struct InstallmentItemDTO: Decodable, Sendable {
    var key: String?
    var name: String?
    var paid: Int?
    var total: Int?
    var amount: Double?
    var remainingAmount: Double?
    var endDate: String?
    var accountName: String?
    var source: String?
    var transactionId: Int64?
}

// MARK: - limites e relatórios

struct LimitsDTO: Decodable, Sendable {
    var month: String?
    var totalLimit: Double?
    var totalSpent: Double?
    var items: [LimitItemDTO]?
    var suggestions: [LimitSuggestionDTO]?
}

struct LimitItemDTO: Decodable, Sendable {
    var id: Int64?
    var categoryId: Int64?
    var categoryName: String?
    var limit: Double?
    var spent: Double?
    var percent: Int?
    var alertPercent: Int?
    var status: String?
}

struct LimitSuggestionDTO: Decodable, Sendable { var categoryId: Int64?; var categoryName: String?; var average: Double?; var suggested: Double? }

struct LimitSaveRequest: Encodable, Sendable { var categoryId: Int64; var monthlyLimit: Double; var alertPercent: Int }

struct ReportMonthDTO: Decodable, Sendable { var year: Int; var month: Int; var income: Double?; var expense: Double? }

struct ReportTotalsDTO: Decodable, Sendable {
    var income: Double?
    var expenseFixed: Double?
    var expenseVariable: Double?
    var paidIncome: Double?
    var paidExpense: Double?
    var openIncome: Double?
    var openExpense: Double?
    var count: Int64?
}

struct ReportSliceDTO: Decodable, Sendable {
    var key: String?
    var label: String?
    var type: String?
    var total: Double?
    var count: Int64?
    var group: String?
}

struct ReportTopExpenseDTO: Decodable, Sendable {
    var id: Int64?
    var date: String?
    var description: String?
    var contact: String?
    var category: String?
    var value: Double?
    var paid: Bool?
}

struct ReportDayDTO: Decodable, Sendable { var date: String?; var income: Double?; var expense: Double? }

struct ReportFullDTO: Decodable, Sendable {
    var start: String?
    var end: String?
    var currency: String?
    var accountName: String?
    var current: ReportTotalsDTO?
    var previous: ReportTotalsDTO?
    var months: [ReportMonthDTO]?
    var breakdown: [String: [ReportSliceDTO]]?
    var topExpenses: [ReportTopExpenseDTO]?
    var days: [ReportDayDTO]?
}

struct ReportDayDetailDTO: Decodable, Sendable {
    var date: String?
    var total: Double?
    var count: Int?
    var items: [ReportDayItemDTO]?
}

struct ReportDayItemDTO: Decodable, Sendable {
    var id: Int64?
    var description: String?
    var contact: String?
    var category: String?
    var categoryIcon: String?
    var categoryColor: String?
    var categoryBrand: String?
    var categoryLogo: String?
    var type: String?
    var value: Double?
    var paid: Bool?
}

// MARK: - Open Finance

struct ConnectionDTO: Decodable, Sendable {
    var id: Int64
    var connectorName: String?
    var connectorImageUrl: String?
    var connectorPrimaryColor: String?
    var status: String?
    var lastSyncAt: String?
    var nextAutoSyncAt: String?
    var syncing: Bool?
    var needsUserAction: Bool?
    var accounts: [OfAccountDTO]?
    var companyId: Int64?
    var companyName: String?
    var disconnectedAccounts: Int?
}

struct CompanyRefRequest: Encodable, Sendable { var companyId: Int64 }

struct OfAccountDTO: Decodable, Sendable {
    var id: Int64
    var connectionId: Int64?
    var type: String?
    var name: String?
    var marketingName: String?
    var number: String?
    var balance: Double?
    var currencyCode: String?
    var creditLimit: Double?
    var availableCreditLimit: Double?
    var ledgerAccountId: Int64?
}

struct OfTransactionDTO: Decodable, Sendable {
    var id: Int64?
    var transactionDate: String?
    var description: String?
    var amount: Double?
    var categoryName: String?
    var merchantName: String?
    var installmentNumber: Int?
    var totalInstallments: Int?
}

struct OfSummaryDTO: Decodable, Sendable {
    var income: Double?
    var expense: Double?
    var expenseByCategory: [CategoryTotalDTO]?
}

struct CategoryTotalDTO: Decodable, Sendable { var category: String?; var total: Double? }

struct SubscriptionsDTO: Decodable, Sendable {
    var subscriptions: [RecurringItemDTO]?
    var bills: [RecurringItemDTO]?
    var totals: [SubscriptionTotalsDTO]?
    var connected: Bool?
}

struct RecurringItemDTO: Decodable, Sendable {
    var key: String?
    var name: String?
    var brand: String?
    var frequency: String?
    var amount: Double?
    var previousAmount: Double?
    var monthlyAmount: Double?
    var lastDate: String?
    var nextDate: String?
    var category: String?
    var currency: String?
    var accountName: String?
    var icon: String?
    var color: String?
    var logo: String?
}

struct SubscriptionTotalsDTO: Decodable, Sendable { var currency: String?; var monthly: Double?; var yearly: Double?; var count: Int? }

// MARK: - fechamento (story)

struct StoryDTO: Decodable, Sendable {
    var periodKey: String?
    var title: String?
    var periodLabel: String?
    var tag: String?
    var currency: String?
    var accountName: String?
    var income: Double?
    var expenses: Double?
    var balance: Double?
    var savingsRate: Int?
    var count: Int64?
    var openExpenses: Int64?
    var expensesDeltaPct: Int?
    var categories: [StoryCategoryDTO]?
    var biggestExpense: StoryExpenseDTO?
    var limits: StoryLimitsDTO?
    var subscriptions: StorySubscriptionsDTO?
}

struct StoryCategoryDTO: Decodable, Sendable { var name: String?; var value: Double?; var percent: Int? }
struct StoryExpenseDTO: Decodable, Sendable { var description: String?; var value: Double?; var date: String? }
struct StoryLimitsDTO: Decodable, Sendable { var total: Int?; var within: Int?; var over: Int? }
struct StorySubscriptionsDTO: Decodable, Sendable { var monthly: Double?; var count: Int? }
struct StorySeenRequest: Encodable, Sendable { var periodKey: String }

// MARK: - notificações

struct NotificationsPageDTO: Decodable, Sendable { var items: [NotificationDTO]?; var unread: Int64? }

struct NotificationDTO: Decodable, Sendable {
    var id: Int64
    var category: String?
    var severity: String?
    var title: String?
    var body: String?
    var link: String?
    var createdAt: String?
    var readAt: String?
}

struct UnreadDTO: Decodable, Sendable { var unread: Int64? }

// MARK: - cadastros, empresas, plano e suporte

/// Contato completo: o update do backend copia todos os campos, então o app reenvia o objeto inteiro.
struct ContactFullDTO: Codable, Sendable {
    var id: Int64?
    var name: String?
    var type: String?
    var category: String?
    var identificationNumber: String?
    var typeIdentification: String?
    var birthday: String?
    var companyContact: String?
    var companyEmail: String?
    var personalEmail: String?
    var cellphone: String?
    var phone: String?
    var city: String?
    var state: String?
    var address: String?
    var cep: String?
    var country: String?
    var description: String?
}

struct ContactDebtDTO: Decodable, Sendable { var contactId: Int64?; var contactName: String?; var value: Double? }

struct CostCenterSummaryDTO: Decodable, Sendable { var costCenterId: Int64?; var expense: Double?; var income: Double?; var count: Int64? }

struct CompanySaveDTO: Encodable, Sendable {
    var id: Int64?
    var companyName: String
    var description: String?
    var companyType: String
    var city: String?
}

struct CompanyCreatedDTO: Decodable, Sendable { var id: Int64? }

struct AccountSaveDTO: Encodable, Sendable {
    var id: Int64?
    var name: String
    var description: String?
    var accountBalance: Double?
    var currency: String?
    var userCompanyId: Int64?
}

struct StorageDTO: Decodable, Sendable { var sizeUsedInMB: Double?; var sizeTotalInMB: Int?; var percent: Int? }

struct InvoiceDTO: Decodable, Sendable {
    var id: Int64
    var statusInvoice: String?
    var plan: PlanDTO?
    var description: String?
    var totalValue: Double?
    var totalValueFormatted: String?
    var subscriptionType: String?
    var invoiceDate: String?
    var paidAt: String?
}

struct TicketMessageDTO: Decodable, Sendable { var id: Int64?; var message: String?; var fromSupport: Bool?; var authorName: String?; var createdAt: String? }

struct TicketDTO: Decodable, Sendable {
    var id: Int64
    var `protocol`: String?
    var title: String?
    var category: String?
    var ticketStatus: String?
    var createdAt: String?
    var lastMessageAt: String?
    var unread: Bool?
    var lastMessage: String?
    var lastFromSupport: Bool?
    var messages: [TicketMessageDTO]?
}

struct TicketCreateDTO: Encodable, Sendable { var title: String; var category: String; var message: String; var screen = "App iPhone" }
struct TicketReplyDTO: Encodable, Sendable { var message: String }

// MARK: - depoimento

struct TestimonialDTO: Codable, Sendable {
    var id: Int64?
    var authorName: String?
    var authorRole: String?
    var rating: Int?
    var text: String?
    var consent: Bool?
    var status: String?
    var createdAt: String?
    var initials: String?
}
