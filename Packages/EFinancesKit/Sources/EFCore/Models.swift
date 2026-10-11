import Foundation

/* Modelos de domínio do app. Os nomes dos enums seguem a API do e-Finances (TransactionType, PaymentType...). */

public enum TransactionType: String, CaseIterable, Sendable, Hashable {
    case income = "RECEBIMENTO"
    case fixed = "DESPESAS_FIXAS"
    case variable = "DESPESAS_VARIAVEIS"

    public var label: String {
        switch self { case .income: "Recebimento"; case .fixed: "Despesa fixa"; case .variable: "Despesa variável" }
    }

    public var plural: String {
        switch self { case .income: "Recebimentos"; case .fixed: "Despesas fixas"; case .variable: "Despesas variáveis" }
    }

    public var isIncome: Bool { self == .income }
}

public enum PaymentType: String, CaseIterable, Sendable, Hashable {
    case cash = "DINHEIRO"
    case creditCard = "CARTAO_CREDITO"
    case debitCard = "CARTAO_DEBITO"
    case boleto = "BOLETO_BANCARIO"
    case transfer = "TED"
    case autoDebit = "DEBITO_AUTOMATICO"
    case check = "CHECK"
    case promissory = "PROMISSORIA"

    public var label: String {
        switch self {
        case .cash: "Dinheiro"
        case .creditCard: "Cartão de crédito"
        case .debitCard: "Cartão de débito"
        case .boleto: "Boleto bancário"
        case .transfer: "Transferência (TED/Pix)"
        case .autoDebit: "Débito automático"
        case .check: "Cheque"
        case .promissory: "Promissória"
        }
    }
}

public enum PaymentMode: String, CaseIterable, Sendable, Hashable {
    case oneTime = "ONE_TIME"
    case installments = "MANY_TIMES"
    case recurring = "REPEATABLE"

    public var label: String {
        switch self { case .oneTime: "À vista"; case .installments: "Parcelado"; case .recurring: "Recorrente" }
    }
}

public enum Recurrence: String, CaseIterable, Sendable, Hashable {
    case fortnightly = "FORTNIGHTLY"
    case monthly = "MONTHLY"
    case bimonthly = "BIMONTHLY"
    case quarterly = "QUARTERLY"
    case semester = "SEMESTER"
    case yearly = "YEARLY"

    public var label: String {
        switch self {
        case .fortnightly: "Quinzenal"
        case .monthly: "Mensal"
        case .bimonthly: "Bimestral"
        case .quarterly: "Trimestral"
        case .semester: "Semestral"
        case .yearly: "Anual"
        }
    }

    var months: Int {
        switch self { case .fortnightly: 0; case .monthly: 1; case .bimonthly: 2; case .quarterly: 3; case .semester: 6; case .yearly: 12 }
    }

    /// Data da ocorrência [steps] a partir de [date] (sem encadear: mensal no dia 31 dá 28/02 e depois 31/03).
    public func next(_ date: LocalDate, steps: Int) -> LocalDate {
        self == .fortnightly ? date.plusDays(15 * steps) : date.plusMonths(months * steps)
    }
}

public enum ContactCategory: String, CaseIterable, Sendable, Hashable {
    case client = "CLIENT"
    case supplier = "SUPPLIER"
    case worker = "WORKER"

    public var label: String {
        switch self { case .client: "Cliente"; case .supplier: "Fornecedor"; case .worker: "Funcionário" }
    }

    public var pluralLabel: String {
        switch self { case .client: "Clientes"; case .supplier: "Fornecedores"; case .worker: "Funcionários" }
    }
}

public struct TransactionCategory: Identifiable, Hashable, Sendable {
    public let id: Int64
    public var name: String
    public var systemDefault: Bool
    public var description: String?
    /// Lançamento nesta categoria é assinatura.
    public var subscription: Bool
    /// Marca do catálogo (netflix, spotify...), com logo.
    public var brand: String?
    /// Ícone da web (PrimeIcons, ex.: "pi-home").
    public var icon: String?
    /// "#RRGGBB".
    public var color: String?
    /// Logo enviado pela pessoa (data URL PNG/JPEG/WebP).
    public var logo: String?

    public init(id: Int64, name: String, systemDefault: Bool = false, description: String? = nil, subscription: Bool = false,
                brand: String? = nil, icon: String? = nil, color: String? = nil, logo: String? = nil) {
        self.id = id; self.name = name; self.systemDefault = systemDefault; self.description = description; self.subscription = subscription
        self.brand = brand; self.icon = icon; self.color = color; self.logo = logo
    }

    /// Categorias que fazem sentido para recebimentos (as outras ficam para despesas).
    public var isIncomeCategory: Bool {
        let n = name.lowercased()
        return ["salário", "salario", "serviço", "servico", "aluguéis", "alugueis", "receita", "venda", "rendimento", "freela"].contains { n.contains($0) }
    }
}

public struct Contact: Identifiable, Hashable, Sendable {
    public let id: Int64
    public var name: String
    public var category: ContactCategory?
    public var phone: String?
    public var email: String?

    public init(id: Int64, name: String, category: ContactCategory? = nil, phone: String? = nil, email: String? = nil) {
        self.id = id; self.name = name; self.category = category; self.phone = phone; self.email = email
    }
}

public struct CostCenter: Identifiable, Hashable, Sendable {
    public let id: Int64
    public var name: String
    public var description: String?
    public var color: String?
    public var monthlyBudget: Decimal?
    /// Centro padrão do sistema (sem dono): só leitura.
    public var systemDefault: Bool

    public init(id: Int64, name: String, description: String? = nil, color: String? = nil, monthlyBudget: Decimal? = nil, systemDefault: Bool = false) {
        self.id = id; self.name = name; self.description = description; self.color = color; self.monthlyBudget = monthlyBudget; self.systemDefault = systemDefault
    }
}

public struct Transaction: Identifiable, Hashable, Sendable {
    public let id: Int64
    public var description: String
    public var value: Decimal
    public var type: TransactionType
    public var date: LocalDate
    public var paid: Bool
    public var refDate: LocalDate?
    public var paymentType: PaymentType?
    public var paymentMode: PaymentMode
    public var recurrence: Recurrence?
    /// Parcela no formato "3/10".
    public var plot: String?
    public var category: TransactionCategory?
    public var contact: Contact?
    public var costCenter: CostCenter?
    public var docNumber: String?
    public var details: String?
    public var accountName: String?
    public var attachments: Int
    /// Mesmo número em todas as ocorrências de um recorrente ou parcelas de um parcelamento.
    public var rootNumber: String?

    public init(id: Int64, description: String, value: Decimal, type: TransactionType, date: LocalDate, paid: Bool, refDate: LocalDate? = nil,
                paymentType: PaymentType? = nil, paymentMode: PaymentMode = .oneTime, recurrence: Recurrence? = nil, plot: String? = nil,
                category: TransactionCategory? = nil, contact: Contact? = nil, costCenter: CostCenter? = nil, docNumber: String? = nil, details: String? = nil,
                accountName: String? = nil, attachments: Int = 0, rootNumber: String? = nil) {
        self.id = id; self.description = description; self.value = value; self.type = type; self.date = date; self.paid = paid
        self.refDate = refDate; self.paymentType = paymentType; self.paymentMode = paymentMode; self.recurrence = recurrence; self.plot = plot
        self.category = category; self.contact = contact; self.costCenter = costCenter; self.docNumber = docNumber; self.details = details
        self.accountName = accountName; self.attachments = attachments; self.rootNumber = rootNumber
    }

    public var signedValue: Decimal { type.isIncome ? value : -value }
    /// Ocorrência de um recorrente (série): editar e excluir perguntam o escopo.
    public var isRecurring: Bool { paymentMode == .recurring }
    /// "3/10" → (3, 10).
    public var installment: (Int, Int)? {
        guard let parts = plot?.split(separator: "/"), parts.count == 2,
              let a = Int(parts[0].trimmingCharacters(in: .whitespaces)), let b = Int(parts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
        return (a, b)
    }
    /// Parcela de um parcelamento: excluir pergunta o escopo.
    public var isInstallment: Bool { paymentMode == .installments || installment != nil }
    public var hasScope: Bool { isRecurring || isInstallment }
}

/// Onde vale a edição ou a exclusão de um recorrente/parcela (como na web).
public enum SeriesScope: String, Sendable, CaseIterable {
    case this = "THIS", next = "NEXT", all = "ALL"

    public var deleteMode: String {
        switch self { case .this: "onlyThis"; case .next: "thisAndNext"; case .all: "allTransaction" }
    }
}

/// Regra de um recorrente: frequência e "Termina em" (nil = nunca).
public struct SeriesInfo: Hashable, Sendable {
    public var frequency: Recurrence?
    public var endDate: LocalDate?
    public var nextDate: LocalDate?
    public var active: Bool

    public init(frequency: Recurrence?, endDate: LocalDate?, nextDate: LocalDate?, active: Bool) {
        self.frequency = frequency; self.endDate = endDate; self.nextDate = nextDate; self.active = active
    }
}

/// Situação de um lançamento em relação a hoje (mesma regra da tela de Transações da web).
public enum DueStatus: Hashable, Sendable {
    case paid
    case late(days: Int)
    case dueSoon(days: Int)
    case scheduled(LocalDate)
}

public enum DueGroup: Int, CaseIterable, Sendable {
    case late, soon, scheduled, paid

    public var label: String {
        switch self { case .late: "Atrasadas"; case .soon: "Próximos 7 dias"; case .scheduled: "Agendadas"; case .paid: "Pagas e recebidas" }
    }
}

/// O que a conta permite: manual (tudo), conectada ao banco (só organizar) ou congelada (só consulta).
public enum AccountMode: Sendable, Hashable { case manual, connected, frozen }

public struct Account: Identifiable, Hashable, Sendable {
    public let id: Int64
    public var name: String
    public var currency: String
    public var balance: Decimal
    public var defaultAccount: Bool
    public var transactions: Int64
    public var mode: AccountMode
    public var bankName: String?
    public var bankLogoUrl: String?
    public var bankColor: String?

    public init(id: Int64, name: String, currency: String = "BRL", balance: Decimal = 0, defaultAccount: Bool = false, transactions: Int64 = 0,
                mode: AccountMode = .manual, bankName: String? = nil, bankLogoUrl: String? = nil, bankColor: String? = nil) {
        self.id = id; self.name = name; self.currency = currency; self.balance = balance; self.defaultAccount = defaultAccount
        self.transactions = transactions; self.mode = mode; self.bankName = bankName; self.bankLogoUrl = bankLogoUrl; self.bankColor = bankColor
    }

    public var fromBank: Bool { mode != .manual }
}

public enum CompanyType: String, CaseIterable, Sendable {
    case family = "FAMILY", autonomous = "AUTONOMOUS", microentrepreneur = "MICROENTREPRENEUR", business = "BUSINESS"

    public var label: String {
        switch self { case .family: "Familiar"; case .autonomous: "Autônomo"; case .microentrepreneur: "Microempreendedor"; case .business: "Empresa" }
    }
}

public struct Company: Identifiable, Hashable, Sendable {
    public let id: Int64
    public var name: String
    public var type: CompanyType?
    public var typeLabel: String
    public var accounts: [Account]

    public init(id: Int64, name: String, type: CompanyType?, typeLabel: String, accounts: [Account]) {
        self.id = id; self.name = name; self.type = type; self.typeLabel = typeLabel; self.accounts = accounts
    }
}

public struct Workspace: Hashable, Sendable {
    public var companyId: Int64?
    public var accountId: Int64?
    public var companies: [Company]

    public init(companyId: Int64?, accountId: Int64?, companies: [Company]) {
        self.companyId = companyId; self.accountId = accountId; self.companies = companies
    }

    public var company: Company? { companies.first { $0.id == companyId } ?? companies.first }
    public var account: Account? {
        guard let c = company else { return nil }
        return c.accounts.first { $0.id == accountId } ?? c.accounts.first { $0.defaultAccount } ?? c.accounts.first
    }
    /// Modo da conta em uso: decide se dá para lançar, pagar e excluir.
    public var mode: AccountMode { account?.mode ?? .manual }
    public func companyOf(accountId: Int64) -> Company? { companies.first { c in c.accounts.contains { $0.id == accountId } } }
}

// MARK: - Open Finance

public enum BankAccountKind: Sendable, Hashable { case bank, credit }

public struct BankAccount: Identifiable, Hashable, Sendable {
    public let id: Int64
    public var connectionId: Int64
    public var name: String
    public var kind: BankAccountKind
    public var balance: Decimal
    public var creditLimit: Decimal?
    public var availableCredit: Decimal?
    public var currency: String
    public var number: String?
    /// Conta do e-Finances que espelha esta (abre em Transações).
    public var ledgerAccountId: Int64?

    public init(id: Int64, connectionId: Int64, name: String, kind: BankAccountKind, balance: Decimal, creditLimit: Decimal? = nil,
                availableCredit: Decimal? = nil, currency: String = "BRL", number: String? = nil, ledgerAccountId: Int64? = nil) {
        self.id = id; self.connectionId = connectionId; self.name = name; self.kind = kind; self.balance = balance; self.creditLimit = creditLimit
        self.availableCredit = availableCredit; self.currency = currency; self.number = number; self.ledgerAccountId = ledgerAccountId
    }

    /// Cartão: fatura atual (o saldo do cartão; se vier zerado, limite − disponível); conta: saldo.
    public var headline: Decimal {
        guard kind == .credit else { return balance }
        if balance.magnitude > 0 { return balance.magnitude }
        if let l = creditLimit, let a = availableCredit { return max(l - a, 0) }
        return 0
    }
}

public struct BankConnection: Identifiable, Hashable, Sendable {
    public let id: Int64
    public var bankName: String
    public var color: String?
    public var imageUrl: String?
    public var status: String
    public var needsUserAction: Bool
    public var syncing: Bool
    public var lastSyncAt: LocalDateTime?
    public var nextSyncAt: LocalDateTime?
    public var accounts: [BankAccount]
    /// Empresa onde as contas desta conexão aparecem no e-Finances.
    public var companyId: Int64?
    public var companyName: String?
    /// Contas que a pessoa desconectou (o banco segue conectado para as outras).
    public var disconnectedAccounts: Int

    public init(id: Int64, bankName: String, color: String?, imageUrl: String?, status: String, needsUserAction: Bool, syncing: Bool,
                lastSyncAt: LocalDateTime?, nextSyncAt: LocalDateTime?, accounts: [BankAccount], companyId: Int64? = nil,
                companyName: String? = nil, disconnectedAccounts: Int = 0) {
        self.id = id; self.bankName = bankName; self.color = color; self.imageUrl = imageUrl; self.status = status
        self.needsUserAction = needsUserAction; self.syncing = syncing; self.lastSyncAt = lastSyncAt; self.nextSyncAt = nextSyncAt
        self.accounts = accounts; self.companyId = companyId; self.companyName = companyName; self.disconnectedAccounts = disconnectedAccounts
    }
}

public struct BankTransaction: Identifiable, Hashable, Sendable {
    public let id: Int64
    public var date: LocalDate
    public var description: String
    public var amount: Decimal
    public var categoryName: String?
    public var installment: String?

    public init(id: Int64, date: LocalDate, description: String, amount: Decimal, categoryName: String?, installment: String? = nil) {
        self.id = id; self.date = date; self.description = description; self.amount = amount; self.categoryName = categoryName; self.installment = installment
    }

    public var isIncome: Bool { amount > 0 }
}

public struct CategoryTotal: Hashable, Sendable {
    public var name: String
    public var total: Decimal
    public init(name: String, total: Decimal) { self.name = name; self.total = total }
}

public struct BankAccountSummary: Hashable, Sendable {
    public var income: Decimal
    public var expense: Decimal
    public var expenseByCategory: [CategoryTotal]
    public init(income: Decimal, expense: Decimal, expenseByCategory: [CategoryTotal]) {
        self.income = income; self.expense = expense; self.expenseByCategory = expenseByCategory
    }
}

public enum Frequency: String, Sendable, CaseIterable {
    case weekly = "WEEKLY", monthly = "MONTHLY", yearly = "YEARLY"
    public var label: String { switch self { case .weekly: "Semanal"; case .monthly: "Mensal"; case .yearly: "Anual" } }
}

public struct RecurringItem: Identifiable, Hashable, Sendable {
    public var key: String
    public var name: String
    public var brand: String?
    public var frequency: Frequency
    public var amount: Decimal
    public var previousAmount: Decimal?
    public var monthlyAmount: Decimal
    public var nextDate: LocalDate?
    public var accountName: String?
    public var lastDate: LocalDate?
    public var category: String?
    public var currency: String
    /// Aparência da categoria de assinatura (ícone, cor, logo enviado).
    public var icon: String?
    public var color: String?
    public var logo: String?

    public var id: String { key }

    public init(key: String, name: String, brand: String?, frequency: Frequency, amount: Decimal, previousAmount: Decimal?, monthlyAmount: Decimal,
                nextDate: LocalDate?, accountName: String?, lastDate: LocalDate? = nil, category: String? = nil, currency: String = "BRL",
                icon: String? = nil, color: String? = nil, logo: String? = nil) {
        self.key = key; self.name = name; self.brand = brand; self.frequency = frequency; self.amount = amount; self.previousAmount = previousAmount
        self.monthlyAmount = monthlyAmount; self.nextDate = nextDate; self.accountName = accountName; self.lastDate = lastDate; self.category = category
        self.currency = currency; self.icon = icon; self.color = color; self.logo = logo
    }

    /// Para desenhar o selo com a mesma regra das categorias.
    public var look: TransactionCategory { TransactionCategory(id: 0, name: name, subscription: true, brand: brand, icon: icon, color: color, logo: logo) }

    public var priceIncreasePct: Int? {
        guard let p = previousAmount, p > 0, amount > p else { return nil }
        return ((amount - p) * 100 / p).intValue
    }
}

public struct Subscriptions: Hashable, Sendable {
    public var subscriptions: [RecurringItem]
    public var bills: [RecurringItem]
    public var monthlyTotal: Decimal
    public var yearlyTotal: Decimal
    public var currency: String
    /// Há banco conectado (as "outras cobranças recorrentes" vêm dele).
    public var connected: Bool

    public init(subscriptions: [RecurringItem], bills: [RecurringItem], monthlyTotal: Decimal, yearlyTotal: Decimal, currency: String = "BRL", connected: Bool = false) {
        self.subscriptions = subscriptions; self.bills = bills; self.monthlyTotal = monthlyTotal; self.yearlyTotal = yearlyTotal
        self.currency = currency; self.connected = connected
    }
}

// MARK: - Planejamento

public enum InstallmentSource: String, Sendable { case ledger = "LEDGER", openFinance = "OPEN_FINANCE" }

public struct InstallmentItem: Identifiable, Hashable, Sendable {
    public var key: String
    public var name: String
    public var paid: Int
    public var total: Int
    public var amount: Decimal
    public var remainingAmount: Decimal
    public var endDate: LocalDate?
    public var source: InstallmentSource
    public var accountName: String?
    public var transactionId: Int64?
    public var id: String { key }

    public init(key: String, name: String, paid: Int, total: Int, amount: Decimal, remainingAmount: Decimal, endDate: LocalDate?,
                source: InstallmentSource, accountName: String?, transactionId: Int64?) {
        self.key = key; self.name = name; self.paid = paid; self.total = total; self.amount = amount; self.remainingAmount = remainingAmount
        self.endDate = endDate; self.source = source; self.accountName = accountName; self.transactionId = transactionId
    }
}

public struct Installments: Hashable, Sendable {
    public var items: [InstallmentItem]
    public var remainingTotal: Decimal
    public var monthlyTotal: Decimal
    public init(items: [InstallmentItem], remainingTotal: Decimal, monthlyTotal: Decimal) {
        self.items = items; self.remainingTotal = remainingTotal; self.monthlyTotal = monthlyTotal
    }
}

public enum LimitStatus: String, Sendable { case ok, warn, over }

public struct LimitItem: Identifiable, Hashable, Sendable {
    public var id: Int64
    public var categoryId: Int64
    public var categoryName: String
    public var limit: Decimal
    public var spent: Decimal
    public var percent: Int
    public var alertPercent: Int
    public var status: LimitStatus

    public init(id: Int64, categoryId: Int64, categoryName: String, limit: Decimal, spent: Decimal, percent: Int, alertPercent: Int, status: LimitStatus) {
        self.id = id; self.categoryId = categoryId; self.categoryName = categoryName; self.limit = limit; self.spent = spent
        self.percent = percent; self.alertPercent = alertPercent; self.status = status
    }

    public var remaining: Decimal { limit - spent }
}

public struct LimitSuggestion: Hashable, Sendable, Identifiable {
    public var categoryId: Int64
    public var categoryName: String
    public var average: Decimal
    public var suggested: Decimal
    public var id: Int64 { categoryId }
    public init(categoryId: Int64, categoryName: String, average: Decimal, suggested: Decimal) {
        self.categoryId = categoryId; self.categoryName = categoryName; self.average = average; self.suggested = suggested
    }
}

public struct LimitsOverview: Hashable, Sendable {
    public var month: YearMonth
    public var totalLimit: Decimal
    public var totalSpent: Decimal
    public var items: [LimitItem]
    public var suggestions: [LimitSuggestion]

    public init(month: YearMonth, totalLimit: Decimal, totalSpent: Decimal, items: [LimitItem], suggestions: [LimitSuggestion]) {
        self.month = month; self.totalLimit = totalLimit; self.totalSpent = totalSpent; self.items = items; self.suggestions = suggestions
    }

    public var available: Decimal { max(totalLimit - totalSpent, 0) }
    public var attention: Int { items.filter { $0.status != .ok }.count }
}

public struct MonthFlow: Hashable, Sendable, Identifiable {
    public var month: YearMonth
    public var income: Decimal
    public var expense: Decimal
    public var projected: Bool
    public var id: YearMonth { month }
    public init(month: YearMonth, income: Decimal, expense: Decimal, projected: Bool) {
        self.month = month; self.income = income; self.expense = expense; self.projected = projected
    }
}

// MARK: - Fechamento (story)

public struct Story: Hashable, Sendable {
    public var periodKey: String
    public var title: String
    public var periodLabel: String
    public var tag: String
    public var accountName: String
    public var income: Decimal
    public var expenses: Decimal
    public var balance: Decimal
    public var savingsRate: Int?
    public var count: Int64
    public var openExpenses: Int64
    public var expensesDeltaPct: Int?
    public var categories: [StoryCategory]
    public var biggestExpense: StoryExpense?
    public var limitsWithin: Int
    public var limitsTotal: Int
    public var limitsOver: Int
    public var subscriptionsMonthly: Decimal
    public var subscriptionsCount: Int
    public var currency: String

    public init(periodKey: String, title: String, periodLabel: String, tag: String, accountName: String, income: Decimal, expenses: Decimal,
                balance: Decimal, savingsRate: Int?, count: Int64, openExpenses: Int64, expensesDeltaPct: Int?, categories: [StoryCategory],
                biggestExpense: StoryExpense?, limitsWithin: Int, limitsTotal: Int, limitsOver: Int, subscriptionsMonthly: Decimal,
                subscriptionsCount: Int, currency: String = "BRL") {
        self.periodKey = periodKey; self.title = title; self.periodLabel = periodLabel; self.tag = tag; self.accountName = accountName
        self.income = income; self.expenses = expenses; self.balance = balance; self.savingsRate = savingsRate; self.count = count
        self.openExpenses = openExpenses; self.expensesDeltaPct = expensesDeltaPct; self.categories = categories; self.biggestExpense = biggestExpense
        self.limitsWithin = limitsWithin; self.limitsTotal = limitsTotal; self.limitsOver = limitsOver
        self.subscriptionsMonthly = subscriptionsMonthly; self.subscriptionsCount = subscriptionsCount; self.currency = currency
    }
}

public struct StoryCategory: Hashable, Sendable {
    public var name: String
    public var value: Decimal
    public var percent: Int
    public init(name: String, value: Decimal, percent: Int) { self.name = name; self.value = value; self.percent = percent }
}

public struct StoryExpense: Hashable, Sendable {
    public var description: String
    public var value: Decimal
    public var date: LocalDate?
    public init(description: String, value: Decimal, date: LocalDate?) { self.description = description; self.value = value; self.date = date }
}

// MARK: - Notificações

public enum NotificationCategory: String, CaseIterable, Sendable {
    case limit = "LIMIT", payment = "PAYMENT", support = "SUPPORT", security = "SECURITY", system = "SYSTEM", admin = "ADMIN", signup = "SIGNUP", queue = "QUEUE"

    public var label: String {
        switch self {
        case .limit: "Limites"; case .payment: "Pagamentos"; case .support: "Suporte"; case .security: "Segurança"
        case .system: "Sistema"; case .admin: "Avisos"; case .signup: "Cadastros"; case .queue: "Filas"
        }
    }
}

public enum NotificationSeverity: String, CaseIterable, Sendable { case info = "INFO", success = "SUCCESS", warning = "WARNING", danger = "DANGER" }

public struct AppNotification: Identifiable, Hashable, Sendable {
    public let id: Int64
    public var category: NotificationCategory
    public var severity: NotificationSeverity
    public var title: String
    public var body: String
    public var link: String?
    public var createdAt: LocalDateTime?
    public var read: Bool

    public init(id: Int64, category: NotificationCategory, severity: NotificationSeverity, title: String, body: String, link: String?, createdAt: LocalDateTime?, read: Bool) {
        self.id = id; self.category = category; self.severity = severity; self.title = title; self.body = body; self.link = link
        self.createdAt = createdAt; self.read = read
    }
}

public struct NotificationsPage: Hashable, Sendable {
    public var items: [AppNotification]
    public var unread: Int64
    public init(items: [AppNotification], unread: Int64) { self.items = items; self.unread = unread }
}

// MARK: - Usuário

public struct UserProfile: Hashable, Sendable {
    public var firstName: String
    public var lastName: String
    public var email: String
    public var planName: String?
    public var planEndDate: LocalDate?

    public init(firstName: String, lastName: String, email: String, planName: String?, planEndDate: LocalDate?) {
        self.firstName = firstName; self.lastName = lastName; self.email = email; self.planName = planName; self.planEndDate = planEndDate
    }

    public var fullName: String { [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ") }
    public var initials: String {
        let i = [firstName, lastName].compactMap { $0.first.map { String($0).uppercased() } }.joined()
        return i.isEmpty ? String(email.prefix(2)).uppercased() : i
    }
}

// MARK: - Escrita de lançamento

public struct TransactionDraft: Hashable, Sendable {
    public var id: Int64?
    public var type: TransactionType
    public var description: String
    /// Valor em centavos (o teclado numérico digita da direita para a esquerda).
    public var cents: Int64
    public var date: LocalDate
    public var category: TransactionCategory?
    public var newCategoryName: String?
    public var contact: Contact?
    public var newContactName: String?
    public var paid: Bool
    public var paymentType: PaymentType
    /// false = o lançamento não tinha forma de pagamento e a pessoa não escolheu (ao organizar, não manda).
    public var paymentTypeChosen: Bool
    public var paymentMode: PaymentMode
    public var installments: Int
    /// No parcelado: o valor digitado é o total (true) ou o de cada parcela (false).
    public var valueIsTotal: Bool
    public var recurrence: Recurrence
    /// Recorrente: "Termina em" (nil = nunca).
    public var seriesEnd: LocalDate?
    /// Parcelado: datas escolhidas à mão por parcela (índice a partir de 1; a 1ª é a [date]).
    public var installmentDates: [Int: LocalDate]
    public var costCenter: CostCenter?
    public var refMonth: YearMonth?
    public var docNumber: String
    public var details: String

    public init(id: Int64? = nil, type: TransactionType = .variable, description: String = "", cents: Int64 = 0, date: LocalDate,
                category: TransactionCategory? = nil, newCategoryName: String? = nil, contact: Contact? = nil, newContactName: String? = nil,
                paid: Bool = false, paymentType: PaymentType = .creditCard, paymentTypeChosen: Bool = true, paymentMode: PaymentMode = .oneTime,
                installments: Int = 3, valueIsTotal: Bool = true, recurrence: Recurrence = .monthly, seriesEnd: LocalDate? = nil,
                installmentDates: [Int: LocalDate] = [:], costCenter: CostCenter? = nil, refMonth: YearMonth? = nil, docNumber: String = "", details: String = "") {
        self.id = id; self.type = type; self.description = description; self.cents = cents; self.date = date; self.category = category
        self.newCategoryName = newCategoryName; self.contact = contact; self.newContactName = newContactName; self.paid = paid
        self.paymentType = paymentType; self.paymentTypeChosen = paymentTypeChosen; self.paymentMode = paymentMode; self.installments = installments
        self.valueIsTotal = valueIsTotal; self.recurrence = recurrence; self.seriesEnd = seriesEnd; self.installmentDates = installmentDates
        self.costCenter = costCenter; self.refMonth = refMonth; self.docNumber = docNumber; self.details = details
    }

    public var value: Decimal { Decimal(cents) / 100 }
}

public struct RegisterData: Hashable, Sendable {
    public var firstName: String
    public var lastName: String
    public var email: String
    public var companyName: String
    public var countryCode: String
    public var countryName: String
    public var currency: String
    public var termsAccepted: Bool

    public init(firstName: String, lastName: String, email: String, companyName: String, countryCode: String, countryName: String, currency: String, termsAccepted: Bool) {
        self.firstName = firstName; self.lastName = lastName; self.email = email; self.companyName = companyName; self.countryCode = countryCode
        self.countryName = countryName; self.currency = currency; self.termsAccepted = termsAccepted
    }
}
