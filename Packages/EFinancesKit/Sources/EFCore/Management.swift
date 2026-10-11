import Foundation

/* Modelos das telas de gestão: relatórios, cadastros, empresas e contas, plano e suporte. */

// MARK: - Relatórios

public enum ReportStatus: String, CaseIterable, Sendable {
    case all = "ALL", paid = "PAID", open = "OPEN"
    public var label: String { switch self { case .all: "Tudo"; case .paid: "Realizado"; case .open: "Em aberto" } }
}

public enum ReportDimension: String, CaseIterable, Sendable {
    case category = "CATEGORY", contact = "CONTACT", contactKind = "CONTACT_KIND", costCenter = "COST_CENTER", paymentType = "PAYMENT_TYPE"
    public var label: String {
        switch self {
        case .category: "Categoria"; case .contact: "Contato"; case .contactKind: "Tipo de contato"
        case .costCenter: "Centro de custo"; case .paymentType: "Forma de pagamento"
        }
    }
}

public struct ReportTotals: Hashable, Sendable {
    public var income: Decimal
    public var expenseFixed: Decimal
    public var expenseVariable: Decimal
    public var paidIncome: Decimal
    public var paidExpense: Decimal
    public var openIncome: Decimal
    public var openExpense: Decimal
    public var count: Int64

    public init(income: Decimal, expenseFixed: Decimal, expenseVariable: Decimal, paidIncome: Decimal, paidExpense: Decimal,
                openIncome: Decimal, openExpense: Decimal, count: Int64) {
        self.income = income; self.expenseFixed = expenseFixed; self.expenseVariable = expenseVariable; self.paidIncome = paidIncome
        self.paidExpense = paidExpense; self.openIncome = openIncome; self.openExpense = openExpense; self.count = count
    }

    public static let zero = ReportTotals(income: 0, expenseFixed: 0, expenseVariable: 0, paidIncome: 0, paidExpense: 0, openIncome: 0, openExpense: 0, count: 0)

    public var expense: Decimal { expenseFixed + expenseVariable }
    public var net: Decimal { income - expense }
    /// Margem: quanto do que entrou sobrou (%).
    public var margin: Int { pct(net, income) }
}

/// Uma linha do detalhamento: item (categoria, contato…) × tipo × mês.
public struct ReportSlice: Hashable, Sendable {
    public var key: String
    public var label: String
    public var type: TransactionType?
    public var total: Decimal
    public var count: Int64
    /// Contato: o tipo dele (cliente, fornecedor, funcionário; nil = sem tipo).
    public var group: ContactCategory?
    public init(key: String, label: String, type: TransactionType?, total: Decimal, count: Int64, group: ContactCategory? = nil) {
        self.key = key; self.label = label; self.type = type; self.total = total; self.count = count; self.group = group
    }
}

/// Receitas e despesas de um dia (calendário de gastos).
public struct ReportDay: Hashable, Sendable {
    public var date: LocalDate
    public var income: Decimal
    public var expense: Decimal
    public init(date: LocalDate, income: Decimal, expense: Decimal) { self.date = date; self.income = income; self.expense = expense }
}

public struct ReportExpense: Hashable, Sendable, Identifiable {
    public var id: Int64
    public var date: LocalDate?
    public var description: String
    public var contact: String?
    public var category: String?
    public var value: Decimal
    public var paid: Bool
    public init(id: Int64, date: LocalDate?, description: String, contact: String?, category: String?, value: Decimal, paid: Bool) {
        self.id = id; self.date = date; self.description = description; self.contact = contact; self.category = category; self.value = value; self.paid = paid
    }
}

public struct ReportOverview: Hashable, Sendable {
    public var start: LocalDate
    public var end: LocalDate
    public var currency: String
    public var accountName: String
    public var current: ReportTotals
    public var previous: ReportTotals
    public var months: [MonthFlow]
    public var breakdown: [ReportDimension: [ReportSlice]]
    public var topExpenses: [ReportExpense]
    public var days: [ReportDay]

    public init(start: LocalDate, end: LocalDate, currency: String, accountName: String, current: ReportTotals, previous: ReportTotals,
                months: [MonthFlow], breakdown: [ReportDimension: [ReportSlice]], topExpenses: [ReportExpense], days: [ReportDay] = []) {
        self.start = start; self.end = end; self.currency = currency; self.accountName = accountName; self.current = current
        self.previous = previous; self.months = months; self.breakdown = breakdown; self.topExpenses = topExpenses; self.days = days
    }

    /// Despesas somadas por item da dimensão (todas as linhas de mês e tipo juntas), da maior para a menor.
    /// [contactKind] filtra os contatos por tipo (cliente, fornecedor, funcionário).
    public func expenseComposition(_ dimension: ReportDimension, contactKind: ContactCategory? = nil) -> [CategoryShare] {
        let rows = (breakdown[dimension] ?? []).filter { $0.type != .income && (contactKind == nil || $0.group == contactKind) }
        let total = rows.reduce(Decimal(0)) { $0 + $1.total }
        var sums: [String: (String, Decimal)] = [:]
        var order: [String] = []
        for r in rows {
            if sums[r.key] == nil { order.append(r.key); sums[r.key] = (r.label, 0) }
            sums[r.key]!.1 += r.total
        }
        return order.map { k in CategoryShare(name: sums[k]!.0, value: sums[k]!.1, percent: pct(sums[k]!.1, total)) }
            .sorted { $0.value > $1.value }
    }

    public var monthsCount: Int { max(months.count, 1) }
}

/// Um lançamento do dia no calendário de gastos.
public struct ReportDayItem: Hashable, Sendable, Identifiable {
    public var id: Int64
    public var description: String
    public var contact: String?
    /// Nome e aparência da categoria.
    public var category: TransactionCategory?
    public var type: TransactionType
    public var value: Decimal
    public var paid: Bool
    public init(id: Int64, description: String, contact: String?, category: TransactionCategory?, type: TransactionType, value: Decimal, paid: Bool) {
        self.id = id; self.description = description; self.contact = contact; self.category = category; self.type = type; self.value = value; self.paid = paid
    }
}

/// Despesas de um dia (toque num dia do calendário de gastos).
public struct DayExpenses: Hashable, Sendable {
    public var date: LocalDate
    public var total: Decimal
    /// Quantos lançamentos o dia tem (a lista vem limitada).
    public var count: Int
    public var items: [ReportDayItem]
    public init(date: LocalDate, total: Decimal, count: Int, items: [ReportDayItem]) { self.date = date; self.total = total; self.count = count; self.items = items }
    public var open: Decimal { items.filter { !$0.paid }.reduce(0) { $0 + $1.value } }
}

// MARK: - Cadastros

public enum PersonType: String, CaseIterable, Sendable {
    case personal = "PERSONAL", company = "COMPANY"
    public var label: String { switch self { case .personal: "Pessoa física"; case .company: "Empresa" } }
}

public struct ContactInput: Hashable, Sendable {
    public var id: Int64?
    public var name: String
    public var category: ContactCategory
    public var personType: PersonType
    public var cellphone: String
    public var email: String
    public var document: String
    public var city: String
    public var description: String

    public init(id: Int64?, name: String, category: ContactCategory, personType: PersonType, cellphone: String = "", email: String = "",
                document: String = "", city: String = "", description: String = "") {
        self.id = id; self.name = name; self.category = category; self.personType = personType; self.cellphone = cellphone
        self.email = email; self.document = document; self.city = city; self.description = description
    }
}

public struct ContactDetails: Hashable, Sendable, Identifiable {
    public var contact: Contact
    public var personType: PersonType?
    public var document: String?
    public var city: String?
    public var state: String?
    public var description: String?
    public var id: Int64 { contact.id }

    public init(contact: Contact, personType: PersonType?, document: String?, city: String?, state: String?, description: String?) {
        self.contact = contact; self.personType = personType; self.document = document; self.city = city; self.state = state; self.description = description
    }
}

/// Quanto cada contato te deve (recebimentos em aberto) ou você deve a ele (despesas em aberto).
public struct ContactDebt: Hashable, Sendable {
    public var contactId: Int64
    public var contactName: String
    public var value: Decimal
    public init(contactId: Int64, contactName: String, value: Decimal) { self.contactId = contactId; self.contactName = contactName; self.value = value }
}

public struct ContactDebts: Hashable, Sendable {
    public var owesMe: [ContactDebt]
    public var iOwe: [ContactDebt]
    public init(owesMe: [ContactDebt], iOwe: [ContactDebt]) { self.owesMe = owesMe; self.iOwe = iOwe }
    public var owesMeTotal: Decimal { owesMe.reduce(0) { $0 + $1.value } }
    public var iOweTotal: Decimal { iOwe.reduce(0) { $0 + $1.value } }
    public func owesMe(_ id: Int64) -> Decimal? { owesMe.first { $0.contactId == id }?.value }
    public func iOwe(_ id: Int64) -> Decimal? { iOwe.first { $0.contactId == id }?.value }
}

/// Linha da tela Categorias: aparência, gasto do mês (conta em uso) e limite.
public struct CategoryView: Hashable, Sendable, Identifiable {
    public var category: TransactionCategory
    public var spent: Decimal
    public var income: Decimal
    public var count: Int64
    /// Lançamentos (todas as contas) que usam a categoria: com uso, não dá para excluir.
    public var usage: Int64
    public var limitId: Int64?
    public var limit: Decimal?
    public var limitPercent: Int?
    public var limitStatus: LimitStatus?
    public var alertPercent: Int
    public var id: Int64 { category.id }

    public init(category: TransactionCategory, spent: Decimal, income: Decimal, count: Int64, usage: Int64, limitId: Int64? = nil, limit: Decimal? = nil,
                limitPercent: Int? = nil, limitStatus: LimitStatus? = nil, alertPercent: Int = 80) {
        self.category = category; self.spent = spent; self.income = income; self.count = count; self.usage = usage; self.limitId = limitId
        self.limit = limit; self.limitPercent = limitPercent; self.limitStatus = limitStatus; self.alertPercent = alertPercent
    }
}

public struct CategoryOverview: Hashable, Sendable {
    public var month: YearMonth
    public var currency: String
    public var spent: Decimal
    public var categories: [CategoryView]

    public init(month: YearMonth, currency: String, spent: Decimal, categories: [CategoryView]) {
        self.month = month; self.currency = currency; self.spent = spent; self.categories = categories
    }

    public var own: Int { categories.filter { !$0.category.systemDefault }.count }
    public var defaults: Int { categories.filter { $0.category.systemDefault }.count }
    public var subscriptions: Int { categories.filter { $0.category.subscription }.count }
    public var withLimit: Int { categories.filter { $0.limit != nil }.count }
    public var overLimit: Int { categories.filter { $0.limitStatus == .over }.count }
    public var nearLimit: Int { categories.filter { $0.limitStatus == .warn }.count }
}

/// Criar (sem id) ou editar categoria com aparência: ícone + cor, marca do catálogo ou logo próprio.
public struct CategoryInput: Hashable, Sendable {
    public var id: Int64?
    public var name: String
    public var description: String
    public var subscription: Bool
    public var brand: String?
    public var icon: String?
    public var color: String?
    public var logo: String?

    public init(id: Int64?, name: String, description: String = "", subscription: Bool = false, brand: String? = nil, icon: String? = nil, color: String? = nil, logo: String? = nil) {
        self.id = id; self.name = name; self.description = description; self.subscription = subscription; self.brand = brand
        self.icon = icon; self.color = color; self.logo = logo
    }
}

public struct CostCenterUsage: Hashable, Sendable {
    public var costCenterId: Int64
    public var expense: Decimal
    public var income: Decimal
    public var count: Int64
    public init(costCenterId: Int64, expense: Decimal, income: Decimal, count: Int64) {
        self.costCenterId = costCenterId; self.expense = expense; self.income = income; self.count = count
    }
}

public struct CostCenterInput: Hashable, Sendable {
    public var id: Int64?
    public var name: String
    public var description: String
    public var color: String
    public var monthlyBudget: Decimal?
    public init(id: Int64?, name: String, description: String, color: String, monthlyBudget: Decimal?) {
        self.id = id; self.name = name; self.description = description; self.color = color; self.monthlyBudget = monthlyBudget
    }
}

// MARK: - Empresas e contas

public struct CompanyInput: Hashable, Sendable {
    public var id: Int64?
    public var name: String
    public var type: CompanyType
    public var description: String
    public var city: String
    public init(id: Int64?, name: String, type: CompanyType, description: String = "", city: String = "") {
        self.id = id; self.name = name; self.type = type; self.description = description; self.city = city
    }
}

public struct AccountInput: Hashable, Sendable {
    public var id: Int64?
    public var companyId: Int64
    public var name: String
    public var currency: String
    public var initialBalance: Decimal?
    public var description: String
    public init(id: Int64?, companyId: Int64, name: String, currency: String, initialBalance: Decimal?, description: String = "") {
        self.id = id; self.companyId = companyId; self.name = name; self.currency = currency; self.initialBalance = initialBalance; self.description = description
    }
}

// MARK: - Plano e faturas

public enum SubscriptionPeriod: String, CaseIterable, Sendable {
    case monthly = "MONTHLY", quarterly = "QUARTERLY", semesterly = "SEMESTERLY", yearly = "YEARLY"
    public var label: String { switch self { case .monthly: "Mensal"; case .quarterly: "Trimestral"; case .semesterly: "Semestral"; case .yearly: "Anual" } }
    public var months: Int { switch self { case .monthly: 1; case .quarterly: 3; case .semesterly: 6; case .yearly: 12 } }
}

public enum PlanStatus: Sendable {
    case active, free, expired
    public var label: String { switch self { case .active: "Ativo"; case .free: "Período grátis"; case .expired: "Vencido" } }
}

public struct CurrentPlan: Hashable, Sendable {
    public var planId: Int64?
    public var name: String
    public var period: SubscriptionPeriod?
    public var validUntil: LocalDate?
    public var status: PlanStatus
    public var isOwner: Bool
    public init(planId: Int64?, name: String, period: SubscriptionPeriod?, validUntil: LocalDate?, status: PlanStatus, isOwner: Bool) {
        self.planId = planId; self.name = name; self.period = period; self.validUntil = validUntil; self.status = status; self.isOwner = isOwner
    }
}

public struct StorageUsage: Hashable, Sendable {
    public var usedMb: Double
    public var totalMb: Int
    public var percent: Int
    public init(usedMb: Double, totalMb: Int, percent: Int) { self.usedMb = usedMb; self.totalMb = totalMb; self.percent = percent }
}

public enum InvoiceStatus: String, Sendable {
    case paid = "PAYED", waiting = "WAITING_PAYMENT", cancelled = "CANCELLED", expired = "EXPIRED_PAYMENT", freeTrial = "FREE_TRIAL"
    public var label: String {
        switch self { case .paid: "Paga"; case .waiting: "Aguardando pagamento"; case .cancelled: "Cancelada"; case .expired: "Não concluída"; case .freeTrial: "Período grátis" }
    }
}

public struct Invoice: Hashable, Sendable, Identifiable {
    public var id: Int64
    public var status: InvoiceStatus
    public var description: String
    public var planName: String?
    public var period: SubscriptionPeriod?
    public var total: Decimal
    public var totalFormatted: String
    public var date: LocalDate?
    public var paidAt: String?
    public init(id: Int64, status: InvoiceStatus, description: String, planName: String?, period: SubscriptionPeriod?, total: Decimal, totalFormatted: String, date: LocalDate?, paidAt: String?) {
        self.id = id; self.status = status; self.description = description; self.planName = planName; self.period = period; self.total = total
        self.totalFormatted = totalFormatted; self.date = date; self.paidAt = paidAt
    }
}

public struct BillingOverview: Hashable, Sendable {
    public var plan: CurrentPlan
    public var storage: StorageUsage?
    public var invoices: [Invoice]
    public init(plan: CurrentPlan, storage: StorageUsage?, invoices: [Invoice]) { self.plan = plan; self.storage = storage; self.invoices = invoices }
}

// MARK: - Ajuda e suporte

public enum TicketCategory: String, CaseIterable, Sendable {
    case question = "DUVIDA", problem = "PROBLEMA", billing = "FINANCEIRO", account = "CONTA", accountDeletion = "EXCLUSAO_CONTA", suggestion = "SUGESTAO"

    public var label: String {
        switch self {
        case .question: "Dúvida"; case .problem: "Problema ou erro"; case .billing: "Plano e cobrança"; case .account: "Minha conta e acesso"
        case .accountDeletion: "Exclusão de conta"; case .suggestion: "Sugestão"
        }
    }

    public var hint: String {
        switch self {
        case .question: "Como fazer algo no app"; case .problem: "Algo não funcionou como deveria"; case .billing: "Plano, pagamento, faturas"
        case .account: "Login, usuários, dados da conta"; case .accountDeletion: "Excluir a conta e todos os dados"; case .suggestion: "Uma ideia para melhorar o e-Finances"
        }
    }

    /// Categorias que a pessoa escolhe no "Novo chamado" (a exclusão tem tela própria).
    public static let pickable: [TicketCategory] = [.question, .problem, .billing, .account, .suggestion]
}

public enum TicketStatus: String, Sendable {
    case open = "OPEN", waitingSupport = "WAITING_ANSWER_COMPANY", waitingUser = "WAITING_ANSWER_USER", solved = "CLOSED_SOLVED", unsolved = "CLOSED_UNSOLVED"
    public var label: String {
        switch self { case .open: "Aberto"; case .waitingSupport: "Aguardando suporte"; case .waitingUser: "Aguardando você"; case .solved: "Resolvido"; case .unsolved: "Encerrado sem solução" }
    }
    public var closed: Bool { self == .solved || self == .unsolved }
}

public enum TicketGroup: String, CaseIterable, Sendable {
    case open = "OPEN", closed = "CLOSED", all = "ALL"
    public var label: String { switch self { case .open: "Abertos"; case .closed: "Encerrados"; case .all: "Todos" } }
}

public struct TicketMessage: Hashable, Sendable, Identifiable {
    public var id: Int64
    public var message: String
    public var fromSupport: Bool
    public var authorName: String?
    public var createdAt: LocalDateTime?
    public init(id: Int64, message: String, fromSupport: Bool, authorName: String?, createdAt: LocalDateTime?) {
        self.id = id; self.message = message; self.fromSupport = fromSupport; self.authorName = authorName; self.createdAt = createdAt
    }
}

public struct Ticket: Hashable, Sendable, Identifiable {
    public var id: Int64
    public var protocolNumber: String
    public var title: String
    public var category: TicketCategory?
    public var status: TicketStatus
    public var createdAt: LocalDateTime?
    public var lastMessageAt: LocalDateTime?
    public var unread: Bool
    public var lastMessage: String?
    public var lastFromSupport: Bool
    public var messages: [TicketMessage]

    public init(id: Int64, protocolNumber: String, title: String, category: TicketCategory?, status: TicketStatus, createdAt: LocalDateTime?,
                lastMessageAt: LocalDateTime?, unread: Bool, lastMessage: String?, lastFromSupport: Bool, messages: [TicketMessage]) {
        self.id = id; self.protocolNumber = protocolNumber; self.title = title; self.category = category; self.status = status
        self.createdAt = createdAt; self.lastMessageAt = lastMessageAt; self.unread = unread; self.lastMessage = lastMessage
        self.lastFromSupport = lastFromSupport; self.messages = messages
    }

    /// Pedido de exclusão de conta (a categoria própria ou um chamado de conta que fala em excluir, como na web).
    public var isDeletionRequest: Bool {
        if category == .accountDeletion { return true }
        guard category == .account else { return false }
        let t = title.lowercased()
        return t.contains("exclu") || t.contains("apagar") || t.contains("encerrar")
    }
}

public struct TicketCounts: Hashable, Sendable {
    public var open: Int64
    public var closed: Int64
    public var unread: Int64
    public init(open: Int64, closed: Int64, unread: Int64) { self.open = open; self.closed = closed; self.unread = unread }
}

// MARK: - depoimento

public enum TestimonialStatus: String, Sendable {
    case pending = "PENDING", approved = "APPROVED", hidden = "HIDDEN"
    public var label: String { switch self { case .pending: "Em análise"; case .approved: "Publicado na página inicial"; case .hidden: "Não publicado" } }
    public var hint: String {
        switch self {
        case .pending: "Assim que for aprovado, aparece na página inicial do e-Finances."
        case .approved: "Obrigado! Ele ajuda outras pessoas a conhecerem o e-Finances."
        case .hidden: "Fica guardado, mas não aparece no site. Você pode editar e enviar de novo."
        }
    }
}

/// Depoimento de quem usa (só vai para o site com a autorização da pessoa e a aprovação do admin).
public struct Testimonial: Hashable, Sendable {
    public var authorName: String
    public var authorRole: String
    public var rating: Int
    public var text: String
    public var consent: Bool
    public var status: TestimonialStatus?

    public static let minText = 20
    public static let maxText = 600
    public static let maxName = 80

    public init(authorName: String = "", authorRole: String = "", rating: Int = 0, text: String = "", consent: Bool = false, status: TestimonialStatus? = nil) {
        self.authorName = authorName; self.authorRole = authorRole; self.rating = rating; self.text = text; self.consent = consent; self.status = status
    }

    /// As mesmas regras do servidor (mensagem do primeiro problema; nil = pode enviar).
    public func validate() -> String? {
        let text = self.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = authorName.trimmingCharacters(in: .whitespaces)
        if !(1...5).contains(rating) { return "Dê uma nota de 1 a 5." }
        if text.count < Self.minText { return "Conte um pouco mais (pelo menos \(Self.minText) caracteres)." }
        if text.count > Self.maxText { return "O depoimento pode ter até \(Self.maxText) caracteres." }
        if name.isEmpty || name.count > Self.maxName { return "Diga como o seu nome deve aparecer (até \(Self.maxName) caracteres)." }
        if authorRole.trimmingCharacters(in: .whitespaces).count > Self.maxName { return "A descrição pode ter até \(Self.maxName) caracteres." }
        if !consent { return "Para publicar, marque que você autoriza mostrar o depoimento no site." }
        return nil
    }
}
