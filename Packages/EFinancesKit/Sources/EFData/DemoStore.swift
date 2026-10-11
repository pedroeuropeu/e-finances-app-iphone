import Foundation
import EFCore

/**
 Dados de exemplo do modo demonstração (os mesmos do protótipo e do app Android), sempre relativos ao mês atual.
 Ficam só na memória: alterações valem até fechar o app.
 */
public actor DemoStore {
    let clock: AppClock

    public init(clock: AppClock = SystemClock()) {
        self.clock = clock
        let now = clock.localNow()
        notifications = [
            AppNotification(id: 1, category: .limit, severity: .danger, title: "Lazer passou do limite", body: "Você gastou R$ 210,00 de R$ 180,00 este mês.", link: "/finances/limits", createdAt: now.plusHours(-1), read: false),
            AppNotification(id: 2, category: .system, severity: .warning, title: "Condomínio está atrasado", body: "R$ 680,00 · Cond. Jardim das Flores", link: "/finances/transactions", createdAt: now.plusHours(-3), read: false),
            AppNotification(id: 3, category: .system, severity: .info, title: "Fechamento do mês pronto", body: "Veja quanto entrou, quanto saiu e o que sobrou.", link: "/story", createdAt: now.plusDays(-1), read: false),
            AppNotification(id: 4, category: .support, severity: .success, title: "Seu chamado foi respondido", body: "#482 · Como exporto as transações para o contador?", link: "/support", createdAt: now.plusDays(-1).plusHours(-4), read: true),
            AppNotification(id: 5, category: .limit, severity: .warning, title: "Saúde chegou a 96% do limite", body: "Ainda dá para gastar R$ 36,55 este mês.", link: "/finances/limits", createdAt: now.plusDays(-3), read: true),
            AppNotification(id: 6, category: .system, severity: .info, title: "Smart Fit ficou mais cara", body: "De R$ 119,90 para R$ 129,90 por mês (+8%).", link: "/open-finance", createdAt: now.plusDays(-4), read: true),
            AppNotification(id: 7, category: .security, severity: .info, title: "Novo acesso à sua conta", body: "iPhone · São Paulo, SP. Não foi você? Encerre a sessão.", link: nil, createdAt: now.plusDays(-5), read: true),
            AppNotification(id: 8, category: .payment, severity: .success, title: "Pagamento aprovado", body: "Plano Premium mensal · R$ 29,90.", link: "/billing", createdAt: now.plusDays(-28), read: true)
        ]
    }

    // MARK: - cadastros

    private static func cat(_ id: Int64, _ name: String, _ icon: String, _ color: String, system: Bool = true) -> TransactionCategory {
        TransactionCategory(id: id, name: name, systemDefault: system, icon: icon, color: color)
    }
    private static func sub(_ id: Int64, _ name: String, _ brand: String) -> TransactionCategory {
        TransactionCategory(id: id, name: name, systemDefault: false, subscription: true, brand: brand)
    }

    var categories: [TransactionCategory] = [
        cat(1, "Moradia", "pi-home", "#6366F1"), cat(2, "Contas de consumo", "pi-bolt", "#F59E0B"), cat(3, "Alimentação", "pi-shopping-cart", "#EA580C"),
        cat(4, "Transporte", "pi-car", "#2563EB"), cat(5, "Saúde", "pi-heart", "#DB2777"), cat(6, "Educação", "pi-book", "#7C3AED"),
        cat(7, "Lazer", "pi-sun", "#F97316"), cat(9, "Compras", "pi-shopping-bag", "#0F766E"), cat(10, "Impostos e taxas", "pi-percentage", "#64748B"),
        cat(11, "Salário", "pi-wallet", "#16A34A"), cat(12, "Serviços prestados", "pi-briefcase", "#15803D", system: false),
        cat(13, "Aluguéis", "pi-building", "#0F766E", system: false), cat(19, "Pets", "pi-heart", "#B45309", system: false),
        sub(14, "Netflix", "netflix"), sub(15, "Spotify", "spotify"), sub(16, "Smart Fit", "smartfit"), sub(17, "YouTube Premium", "youtube"),
        sub(18, "Disney+", "disneyplus"), sub(20, "Amazon Prime", "primevideo")
    ]

    var contacts: [Contact] = [
        Contact(id: 1, name: "Acme Tecnologia", category: .client, phone: "(11) 3000-1200", email: "rh@acme.com.br"),
        Contact(id: 2, name: "Bistrô Central", category: .client, phone: "(11) 98877-1020"),
        Contact(id: 3, name: "Marina Costa", category: .client, phone: "(11) 99123-4455"),
        Contact(id: 4, name: "Imobiliária Lar", category: .supplier), Contact(id: 5, name: "Cond. Jardim das Flores", category: .supplier),
        Contact(id: 6, name: "Colégio Horizonte", category: .supplier), Contact(id: 7, name: "Unimed", category: .supplier),
        Contact(id: 8, name: "Enel", category: .supplier), Contact(id: 9, name: "Vivo", category: .supplier), Contact(id: 10, name: "Magazine Luiza", category: .supplier),
        Contact(id: 11, name: "Joana Lima", category: .worker, phone: "(11) 97654-3210"), Contact(id: 12, name: "Netflix"), Contact(id: 13, name: "Spotify"),
        Contact(id: 14, name: "Smart Fit"), Contact(id: 15, name: "Pão de Açúcar"), Contact(id: 16, name: "Posto Shell"), Contact(id: 17, name: "iFood"),
        Contact(id: 18, name: "Drogasil"), Contact(id: 19, name: "Uber"), Contact(id: 20, name: "Padaria Real"), Contact(id: 21, name: "Dell"),
        Contact(id: 22, name: "Restaurante Mar Azul"), Contact(id: 23, name: "Sefaz-SP"), Contact(id: 24, name: "Pet Shop Amigo")
    ]

    var costCenters: [CostCenter] = [
        CostCenter(id: 1, name: "Casa", description: "Despesas do apartamento", color: "#4338CA", monthlyBudget: 5000),
        CostCenter(id: 5, name: "Geral", description: "Centro padrão do sistema", color: "#64748B", monthlyBudget: nil, systemDefault: true),
        CostCenter(id: 2, name: "Carro", description: "Combustível, IPVA e manutenção", color: "#0284C7", monthlyBudget: 900),
        CostCenter(id: 3, name: "Filhos", description: "Escola, saúde e atividades", color: "#7C3AED", monthlyBudget: 2200),
        CostCenter(id: 4, name: "Trabalho", description: "Ferramentas e equipamentos", color: "#059669", monthlyBudget: 700)
    ]

    // MARK: - lançamentos de exemplo

    private struct Template {
        var id: Int; var desc: String; var type: TransactionType; var value: String; var day: Int; var cat: Int64; var contact: Int64
        var pay: PaymentType; var mode: PaymentMode = .oneTime; var plot: String? = nil; var cc: Int64? = nil
        var lateIfPast = false; var onlyBase = false; var doc: String? = nil; var notes: String? = nil; var files = 0
    }

    private static let templates: [Template] = [
        Template(id: 1, desc: "Salário", type: .income, value: "9800.00", day: 5, cat: 11, contact: 1, pay: .transfer, mode: .recurring, cc: 4),
        Template(id: 2, desc: "Projeto site do bistrô (2ª parte)", type: .income, value: "2400.00", day: 15, cat: 12, contact: 2, pay: .transfer, onlyBase: true, doc: "NF 0193"),
        Template(id: 3, desc: "Aluguel da sala comercial", type: .income, value: "1350.00", day: 20, cat: 13, contact: 3, pay: .transfer, mode: .recurring),
        Template(id: 4, desc: "Aluguel do apartamento", type: .fixed, value: "2300.00", day: 5, cat: 1, contact: 4, pay: .boleto, mode: .recurring, cc: 1, doc: "34191.79001 01043", files: 1),
        Template(id: 5, desc: "Condomínio", type: .fixed, value: "680.00", day: 7, cat: 1, contact: 5, pay: .boleto, mode: .recurring, cc: 1, lateIfPast: true),
        Template(id: 6, desc: "Energia elétrica", type: .fixed, value: "248.37", day: 10, cat: 2, contact: 8, pay: .autoDebit, mode: .recurring, cc: 1, lateIfPast: true),
        Template(id: 7, desc: "Internet fibra", type: .fixed, value: "129.90", day: 12, cat: 2, contact: 9, pay: .autoDebit, mode: .recurring, cc: 1),
        Template(id: 8, desc: "Plano de saúde", type: .fixed, value: "890.00", day: 15, cat: 5, contact: 7, pay: .boleto, mode: .recurring, cc: 3),
        Template(id: 9, desc: "Mensalidade escolar", type: .fixed, value: "1450.00", day: 20, cat: 6, contact: 6, pay: .boleto, mode: .recurring, cc: 3),
        Template(id: 10, desc: "Netflix", type: .fixed, value: "55.90", day: 3, cat: 14, contact: 12, pay: .creditCard, mode: .recurring),
        Template(id: 11, desc: "Spotify Família", type: .fixed, value: "34.90", day: 3, cat: 15, contact: 13, pay: .creditCard, mode: .recurring),
        Template(id: 12, desc: "Smart Fit", type: .fixed, value: "129.90", day: 8, cat: 16, contact: 14, pay: .creditCard, mode: .recurring),
        Template(id: 13, desc: "Supermercado", type: .variable, value: "487.32", day: 2, cat: 3, contact: 15, pay: .debitCard, cc: 1, files: 1),
        Template(id: 14, desc: "Combustível", type: .variable, value: "250.00", day: 4, cat: 4, contact: 16, pay: .creditCard, cc: 2),
        Template(id: 15, desc: "iFood", type: .variable, value: "89.90", day: 6, cat: 3, contact: 17, pay: .creditCard),
        Template(id: 16, desc: "Farmácia", type: .variable, value: "73.45", day: 7, cat: 5, contact: 18, pay: .debitCard, cc: 3),
        Template(id: 17, desc: "Uber", type: .variable, value: "32.80", day: 8, cat: 4, contact: 19, pay: .creditCard),
        Template(id: 18, desc: "Padaria", type: .variable, value: "18.50", day: 9, cat: 3, contact: 20, pay: .cash),
        Template(id: 19, desc: "Notebook Dell", type: .variable, value: "412.90", day: 1, cat: 9, contact: 21, pay: .creditCard, mode: .installments, plot: "3/10", cc: 4),
        Template(id: 20, desc: "Geladeira Brastemp", type: .variable, value: "349.00", day: 10, cat: 9, contact: 10, pay: .boleto, mode: .installments, plot: "5/12", cc: 1),
        Template(id: 21, desc: "Jantar de aniversário", type: .variable, value: "210.00", day: 5, cat: 7, contact: 22, pay: .creditCard, notes: "Aniversário da Ana, 6 pessoas."),
        Template(id: 22, desc: "IPVA", type: .variable, value: "520.00", day: 28, cat: 10, contact: 23, pay: .boleto, mode: .installments, plot: "3/3", cc: 2),
        Template(id: 23, desc: "Diarista", type: .fixed, value: "600.00", day: 30, cat: 1, contact: 11, pay: .transfer, mode: .recurring, cc: 1),
        Template(id: 24, desc: "YouTube Premium", type: .fixed, value: "26.90", day: 17, cat: 17, contact: 0, pay: .creditCard, mode: .recurring),
        Template(id: 25, desc: "Ração e banho", type: .variable, value: "164.00", day: 11, cat: 19, contact: 24, pay: .debitCard)
    ]

    public var baseMonth: YearMonth { clock.currentMonth() }

    /// Lançamentos por conta e mês: as contas manuais usam os modelos acima; as do banco, o espelho do Open Finance.
    private var months: [String: [Transaction]] = [:]
    var nextId: Int64 = 9_000_000_000
    /// Ajuste do saldo da conta corrente conforme lançamentos do mês atual são pagos ou desfeitos.
    var balanceAdjust: Decimal = 0
    /// Séries cortadas: raiz → a partir de quando não existem mais (excluir "esta e as próximas"/"todas").
    var cutFrom: [String: LocalDate] = [:]
    /// "Termina em" dos recorrentes de exemplo: raiz → último vencimento.
    var seriesEnd: [String: LocalDate] = [:]
    var hidden: Set<Int64> = []

    func newId() -> Int64 { nextId += 1; return nextId }

    private func rnd(_ seed: String) -> Double {
        var h: UInt32 = 2_166_136_261
        for u in seed.unicodeScalars { h ^= u.value; h = h &* 16_777_619 }
        return Double(h % 10000) / 10000
    }

    /// Conta em uso (Transações, Início, Relatórios e Centros de custo mostram só ela).
    var accountId: Int64 { workspace.accountId ?? 11 }

    func month(_ ym: YearMonth) -> [Transaction] { month(account: accountId, ym) }

    private func key(_ account: Int64, _ ym: YearMonth) -> String { "\(account)-\(ym)" }

    func month(account: Int64, _ ym: YearMonth) -> [Transaction] {
        let k = key(account, ym)
        if let cached = months[k] { return cached }
        let acc = workspace.companies.flatMap(\.accounts).first { $0.id == account }
        let list = (acc?.fromBank == true) ? bankLedger(acc!, ym) : generate(ym, accountName: acc?.name ?? "Conta corrente", manualAccount: account)
        months[k] = list
        return list
    }

    func all() -> [Transaction] { months.values.flatMap { $0 } }

    func find(_ id: Int64) -> Transaction? { all().first { $0.id == id } }

    func replace(_ t: Transaction) {
        for (k, list) in months { if let i = list.firstIndex(where: { $0.id == t.id }) { months[k]![i] = t } }
    }

    func remove(_ id: Int64) { for k in months.keys { months[k]!.removeAll { $0.id == id } } }

    func removeWhere(_ predicate: (Transaction) -> Bool) { for k in months.keys { months[k]!.removeAll(where: predicate) } }

    func add(_ t: Transaction) {
        let k = key(accountId, t.date.yearMonth)
        _ = month(t.date.yearMonth)
        months[k, default: []].append(t)
    }

    /// Espelho das contas do banco: o que veio na sincronização (lançado = pago, pendente = a pagar).
    private func bankLedger(_ acc: Account, _ ym: YearMonth) -> [Transaction] {
        if ym > baseMonth || acc.mode == .frozen && ym > baseMonth.minusMonths(2) { return [] }
        let today = clock.today()
        let credit = acc.id == 14 || acc.id == 16
        let rows: [(String, Int64, String)] = credit
            ? [("Netflix.com", 14, "55.90"), ("Spotify", 15, "34.90"), ("iFood *Restaurante", 3, "-89.90"), ("Uber *Trip", 4, "-32.80"),
               ("Amazon Marketplace", 9, "-212.40"), ("YouTube Premium", 17, "26.90"), ("Drogasil", 5, "-73.45")]
            : [("Salário · Acme Tecnologia", 11, "9800.00"), ("Pix enviado · Imobiliária Lar", 1, "-2300.00"), ("Pão de Açúcar", 3, "-487.32"),
               ("Posto Shell", 4, "-250.00"), ("Pix recebido · Marina Costa", 13, "1350.00"), ("Enel Distribuição", 2, "-248.37")]
        return rows.enumerated().compactMap { i, row in
            let (desc, cat, v) = row
            let r = rnd("\(acc.id)-\(i)-\(ym)")
            let day = min(ym.lengthOfMonth, 2 + i * 4)
            let date = ym.atDay(day)
            if ym == baseMonth && date > today { return nil }
            let raw = Decimal(string: v) ?? 0
            var value = raw.magnitude
            if ym != baseMonth && !(14...20).contains(cat) && cat != 11 { value = (value * Decimal(0.7 + r * 0.6)).rounded(2) }
            let income = !(raw < 0 || credit)
            return Transaction(
                id: acc.id * 1_000_000 + Int64(ym.year * 12 + ym.month) * 100 + Int64(i), description: desc, value: value,
                type: income ? .income : (14...20).contains(cat) ? .fixed : .variable, date: date, paid: true, refDate: ym.firstDay,
                paymentType: credit ? .creditCard : .transfer, category: categories.first { $0.id == cat }, accountName: acc.name
            )
        }
    }

    private func generate(_ ym: YearMonth, accountName: String, manualAccount: Int64) -> [Transaction] {
        // as outras contas manuais começam vazias (só a conta corrente tem o exemplo completo)
        guard manualAccount == 11 else { return manualAccount == 21 ? businessMonth(ym) : [] }
        let diff = baseMonth.months(until: ym)
        let today = clock.today()
        var out: [Transaction] = []
        for t in Self.templates {
            let root: String? = t.mode == .oneTime ? nil : "T\(t.id)"
            let date = ym.atDay(min(t.day, ym.lengthOfMonth))
            if let root {
                if let cut = cutFrom[root], date >= cut { continue }
                if let end = seriesEnd[root], date > end { continue }
            }
            var plot = t.plot
            var value = Decimal(string: t.value) ?? 0
            var desc = t.desc
            let r = rnd("\(t.id)-\(ym)")
            if t.mode == .installments, let p = t.plot {
                let parts = p.split(separator: "/").compactMap { Int($0) }
                let k = parts[0] + diff
                if k < 1 || k > parts[1] { continue }
                plot = "\(k)/\(parts[1])"
            }
            if t.onlyBase && diff != 0 {
                if r < 0.35 { continue }
                desc = "Projeto freelance"
                value = Decimal(600 + Int(r * 2400))
            }
            if t.id == 1 { desc = "Salário de \(DateFormats.monthName(ym))" }
            if t.id == 21 && diff != 0 && r < 0.5 { continue }
            if t.id == 25 && diff != 0 && r < 0.4 { continue }
            if t.type == .variable && t.mode == .oneTime && diff != 0 { value = (value * Decimal(0.6 + r * 0.8)).rounded(2) }
            if t.cat == 2 && diff != 0 { value = (value * Decimal(0.85 + r * 0.3)).rounded(2) }
            let paid = diff < 0 ? true : diff > 0 ? false : (!t.lateIfPast && date <= today && t.id != 25)
            out.append(Transaction(
                id: Int64(ym.year * 12 + ym.month) * 100 + Int64(t.id), description: desc, value: value, type: t.type, date: date, paid: paid,
                refDate: ym.firstDay, paymentType: t.pay, paymentMode: t.mode, recurrence: t.mode == .oneTime ? nil : .monthly, plot: plot,
                category: categories.first { $0.id == t.cat }, contact: contacts.first { $0.id == t.contact }, costCenter: t.cc.flatMap { id in costCenters.first { $0.id == id } },
                docNumber: t.doc, details: t.notes, accountName: accountName, attachments: diff <= 0 ? t.files : 0, rootNumber: root
            ))
        }
        return out
    }

    /// Conta PJ do Ateliê Aurora (exemplo menor).
    private func businessMonth(_ ym: YearMonth) -> [Transaction] {
        let diff = baseMonth.months(until: ym)
        let today = clock.today()
        let rows: [(String, TransactionType, String, Int, Int64)] = [
            ("Venda de peças · feira", .income, "3480.00", 4, 12), ("Encomenda Bistrô Central", .income, "1900.00", 18, 12),
            ("Aluguel do ateliê", .fixed, "1800.00", 10, 1), ("Argila e esmaltes", .variable, "642.70", 6, 9), ("DAS do Simples", .fixed, "212.40", 20, 10)
        ]
        return rows.enumerated().map { i, row in
            let date = ym.atDay(row.3)
            return Transaction(id: 21_000_000 + Int64(ym.year * 12 + ym.month) * 10 + Int64(i), description: row.0, value: Decimal(string: row.2) ?? 0, type: row.1,
                               date: date, paid: diff < 0 || (diff == 0 && date <= today), refDate: ym.firstDay, paymentType: .transfer,
                               paymentMode: row.1 == .fixed ? .recurring : .oneTime, recurrence: row.1 == .fixed ? .monthly : nil,
                               category: categories.first { $0.id == row.4 }, accountName: "Conta PJ", rootNumber: row.1 == .fixed ? "PJ\(i)" : nil)
        }
    }

    // MARK: - workspace

    private static func bank(_ id: Int64, _ name: String, _ balance: Decimal, _ bank: String, _ color: String, _ tx: Int64, _ mode: AccountMode = .connected) -> Account {
        Account(id: id, name: name, currency: "BRL", balance: balance, defaultAccount: false, transactions: tx, mode: mode, bankName: bank, bankColor: color)
    }

    var workspace = Workspace(companyId: 1, accountId: 11, companies: [
        Company(id: 1, name: "Casa", type: .family, typeLabel: "Familiar", accounts: [
            Account(id: 11, name: "Conta corrente", currency: "BRL", balance: 8432.17, defaultAccount: true, transactions: 23),
            Account(id: 12, name: "Reserva de emergência", currency: "BRL", balance: 21500, transactions: 4),
            bank(13, "Nubank · Conta", 3214.55, "Nubank", "#820AD1", 86), bank(14, "Nubank · Cartão Ultravioleta", -2148.90, "Nubank", "#820AD1", 142),
            bank(15, "Itaú · Conta corrente", 6880.20, "Itaú", "#EC7000", 64), bank(16, "Itaú · Itaú Click Visa", -1312.44, "Itaú", "#EC7000", 57)
        ]),
        Company(id: 2, name: "Ateliê Aurora", type: .business, typeLabel: "Empresa", accounts: [
            Account(id: 21, name: "Conta PJ", currency: "BRL", balance: 12880.35, defaultAccount: true, transactions: 61),
            Account(id: 22, name: "Caixa da loja", currency: "BRL", balance: 4210.90, transactions: 38),
            bank(23, "Inter · Conta digital", 1045, "Inter", "#FF7A00", 31),
            bank(24, "C6 Bank · Conta", 512.30, "C6 Bank", "#242424", 18, .frozen)
        ])
    ])

    /// Conta do Open Finance → conta do e-Finances que a espelha.
    let ledgerOf: [Int64: Int64] = [101: 13, 102: 14, 201: 15, 202: 16, 301: 23]
    /// Empresa de cada conexão (dá para mudar em Contas).
    var connectionCompany: [Int64: Int64] = [1: 1, 2: 1, 3: 2]
    /// Contas do Open Finance desconectadas pela pessoa.
    var disconnected: Set<Int64> = []
    var removedConnections: Set<Int64> = []
    var itauStatus = "LOGIN_ERROR"

    /// Workspace com o saldo da conta corrente ajustado pelos pagamentos feitos no app.
    func workspaceWithBalance() -> Workspace {
        var w = workspace
        w.companies = w.companies.map { c in
            var c = c
            c.accounts = c.accounts.map { a in var a = a; if a.id == 11 { a.balance += balanceAdjust }; return a }
            return c
        }
        return w
    }

    // MARK: - limites

    struct DemoLimit { var id: Int64; var categoryId: Int64; var limit: Decimal; var alert: Int }

    var limits: [DemoLimit] = [
        DemoLimit(id: 1, categoryId: 3, limit: 700, alert: 80), DemoLimit(id: 2, categoryId: 5, limit: 1000, alert: 80),
        DemoLimit(id: 3, categoryId: 7, limit: 180, alert: 80), DemoLimit(id: 4, categoryId: 2, limit: 450, alert: 90),
        DemoLimit(id: 5, categoryId: 9, limit: 1000, alert: 80), DemoLimit(id: 6, categoryId: 4, limit: 500, alert: 80)
    ]

    // MARK: - Open Finance

    func connections() -> [BankConnection] {
        let now = clock.localNow()
        func company(_ conn: Int64) -> Company? { connectionCompany[conn].flatMap { id in workspace.companies.first { $0.id == id } } }
        let base: [BankConnection] = [
            BankConnection(id: 1, bankName: "Nubank", color: "820AD1", imageUrl: nil, status: "UPDATED", needsUserAction: false, syncing: false,
                           lastSyncAt: now.plusHours(-2), nextSyncAt: now.withTime(21, 0), accounts: [
                            BankAccount(id: 101, connectionId: 1, name: "Conta", kind: .bank, balance: 3214.55),
                            BankAccount(id: 102, connectionId: 1, name: "Cartão Ultravioleta", kind: .credit, balance: -2148.90, creditLimit: 8000, availableCredit: 5851.10)
                           ]),
            BankConnection(id: 2, bankName: "Itaú", color: "EC7000", imageUrl: nil, status: itauStatus, needsUserAction: itauStatus != "UPDATED", syncing: false,
                           lastSyncAt: itauStatus == "UPDATED" ? now : now.plusDays(-6), nextSyncAt: nil, accounts: [
                            BankAccount(id: 201, connectionId: 2, name: "Conta corrente", kind: .bank, balance: 6880.20),
                            BankAccount(id: 202, connectionId: 2, name: "Itaú Click Visa", kind: .credit, balance: -1312.44, creditLimit: 6000, availableCredit: 4687.56)
                           ]),
            BankConnection(id: 3, bankName: "Inter", color: "FF7A00", imageUrl: nil, status: "UPDATED", needsUserAction: false, syncing: false,
                           lastSyncAt: now.plusMinutes(-40), nextSyncAt: now.withTime(22, 30), accounts: [
                            BankAccount(id: 301, connectionId: 3, name: "Conta digital", kind: .bank, balance: 1045)
                           ])
        ]
        return base.compactMap { c in
            var c = c
            let kept = c.accounts.filter { !disconnected.contains($0.id) }.map { a in var a = a; a.ledgerAccountId = ledgerOf[a.id]; return a }
            if kept.isEmpty || removedConnections.contains(c.id) { return nil }
            c.disconnectedAccounts = c.accounts.count - kept.count
            c.accounts = kept
            c.companyId = company(c.id)?.id
            c.companyName = company(c.id)?.name
            return c
        }
    }

    func bankTransactions() -> [BankTransaction] {
        let b = baseMonth
        return [
            BankTransaction(id: 1, date: b.atDay(8), description: "Pix recebido · Marina Costa", amount: 1350, categoryName: "Aluguéis"),
            BankTransaction(id: 2, date: b.atDay(6), description: "iFood", amount: -89.90, categoryName: "Alimentação"),
            BankTransaction(id: 3, date: b.atDay(5), description: "Pix enviado · Imobiliária Lar", amount: -2300, categoryName: "Moradia"),
            BankTransaction(id: 4, date: b.atDay(5), description: "Salário · Acme Tecnologia", amount: 9800, categoryName: "Salário"),
            BankTransaction(id: 5, date: b.atDay(4), description: "Posto Shell", amount: -250, categoryName: "Transporte"),
            BankTransaction(id: 6, date: b.atDay(2), description: "Pão de Açúcar", amount: -487.32, categoryName: "Alimentação"),
            BankTransaction(id: 7, date: b.atDay(1), description: "Apple · iPhone 17", amount: -541.58, categoryName: "Compras", installment: "9/12")
        ]
    }

    func subscriptions() -> [RecurringItem] {
        let b = baseMonth.plusMonths(1)
        return [
            RecurringItem(key: "netflix", name: "Netflix", brand: "netflix", frequency: .monthly, amount: 55.90, previousAmount: nil, monthlyAmount: 55.90, nextDate: b.atDay(3), accountName: "Conta corrente", category: "Netflix"),
            RecurringItem(key: "spotify", name: "Spotify Família", brand: "spotify", frequency: .monthly, amount: 34.90, previousAmount: nil, monthlyAmount: 34.90, nextDate: b.atDay(3), accountName: "Conta corrente", category: "Spotify"),
            RecurringItem(key: "smartfit", name: "Smart Fit", brand: "smartfit", frequency: .monthly, amount: 129.90, previousAmount: 119.90, monthlyAmount: 129.90, nextDate: b.atDay(8), accountName: "Conta corrente", category: "Smart Fit"),
            RecurringItem(key: "youtube", name: "YouTube Premium", brand: "youtube", frequency: .monthly, amount: 26.90, previousAmount: nil, monthlyAmount: 26.90, nextDate: b.atDay(17), accountName: "Nubank · Cartão Ultravioleta", category: "YouTube Premium"),
            RecurringItem(key: "prime", name: "Amazon Prime", brand: "primevideo", frequency: .monthly, amount: 19.90, previousAmount: nil, monthlyAmount: 19.90, nextDate: b.atDay(22), accountName: "Nubank · Cartão Ultravioleta", category: "Amazon Prime"),
            RecurringItem(key: "disney", name: "Disney+", brand: "disneyplus", frequency: .yearly, amount: 299.90, previousAmount: nil, monthlyAmount: 24.99, nextDate: baseMonth.plusMonths(5).atDay(14), accountName: "Itaú · Itaú Click Visa", category: "Disney+")
        ]
    }

    func bills() -> [RecurringItem] {
        let b = baseMonth.plusMonths(1)
        return [
            RecurringItem(key: "enel", name: "Enel", brand: nil, frequency: .monthly, amount: 248.37, previousAmount: nil, monthlyAmount: 248.37, nextDate: b.atDay(10), accountName: "Energia · todo dia 10"),
            RecurringItem(key: "vivo", name: "Vivo Fibra", brand: nil, frequency: .monthly, amount: 129.90, previousAmount: nil, monthlyAmount: 129.90, nextDate: b.atDay(12), accountName: "Internet · todo dia 12"),
            RecurringItem(key: "cond", name: "Cond. Jardim das Flores", brand: nil, frequency: .monthly, amount: 680, previousAmount: nil, monthlyAmount: 680, nextDate: b.atDay(7), accountName: "Condomínio · todo dia 7")
        ]
    }

    func openFinanceInstallments() -> [InstallmentItem] {
        [
            InstallmentItem(key: "iphone", name: "iPhone 17", paid: 9, total: 12, amount: 541.58, remainingAmount: 1624.74, endDate: baseMonth.plusMonths(3).atDay(1), source: .openFinance, accountName: "Nubank · cartão", transactionId: nil),
            InstallmentItem(key: "latam", name: "Passagens aéreas", paid: 2, total: 6, amount: 287.30, remainingAmount: 1149.20, endDate: baseMonth.plusMonths(4).atDay(20), source: .openFinance, accountName: "Itaú · cartão", transactionId: nil)
        ]
    }

    // MARK: - notificações, chamados, faturas

    var notifications: [AppNotification]
    var storiesSeen: Set<String> = []
    var trash: [Int64: Any] = [:]
    var contactExtras: [Int64: ContactDetails] = [:]

    var tickets: [Ticket] = []
    var nextTicketId: Int64 = 500
    var testimonial: Testimonial?

    func seedTickets() {
        guard tickets.isEmpty else { return }
        let now = clock.localNow()
        tickets = [
            Ticket(id: 482, protocolNumber: "#000482", title: "Como exporto as transações para o contador?", category: .question, status: .waitingUser,
                   createdAt: now.plusDays(-2), lastMessageAt: now.plusDays(-1), unread: true, lastMessage: "Em Mais › Exportar transações…", lastFromSupport: true, messages: [
                    TicketMessage(id: 1, message: "Preciso mandar todo mês um arquivo para o meu contador. Como faço?", fromSupport: false, authorName: "Você", createdAt: now.plusDays(-2)),
                    TicketMessage(id: 2, message: "Oi! Em Mais › Exportar transações, escolha o período e o formato Excel. O arquivo já sai com o resumo por mês.", fromSupport: true, authorName: "Suporte e-Finances", createdAt: now.plusDays(-1))
                   ]),
            Ticket(id: 455, protocolNumber: "#000455", title: "Erro ao importar extrato do Banco do Brasil", category: .problem, status: .solved,
                   createdAt: now.plusDays(-24), lastMessageAt: now.plusDays(-22), unread: false, lastMessage: "Corrigimos o leitor do modelo do BB.", lastFromSupport: true, messages: [
                    TicketMessage(id: 3, message: "O extrato de agosto não foi reconhecido.", fromSupport: false, authorName: "Você", createdAt: now.plusDays(-24)),
                    TicketMessage(id: 4, message: "Corrigimos o leitor do modelo do BB. Pode importar de novo.", fromSupport: true, authorName: "Suporte e-Finances", createdAt: now.plusDays(-22))
                   ])
        ]
    }

    func invoices() -> [Invoice] {
        let t = clock.today()
        return [
            Invoice(id: 4, status: .paid, description: "Premium · mensal", planName: "Premium", period: .monthly, total: 29.90, totalFormatted: "R$ 29,90", date: t.minusDays(3), paidAt: nil),
            Invoice(id: 3, status: .paid, description: "Premium · mensal", planName: "Premium", period: .monthly, total: 29.90, totalFormatted: "R$ 29,90", date: t.plusMonths(-1).minusDays(3), paidAt: nil),
            Invoice(id: 2, status: .paid, description: "Premium · mensal", planName: "Premium", period: .monthly, total: 29.90, totalFormatted: "R$ 29,90", date: t.plusMonths(-2).minusDays(3), paidAt: nil),
            Invoice(id: 1, status: .freeTrial, description: "Período grátis", planName: "Basic", period: nil, total: 0, totalFormatted: "R$ 0,00", date: t.plusMonths(-3), paidAt: nil)
        ]
    }

    // MARK: - acesso genérico para os repositórios

    func update(_ f: @Sendable (isolated DemoStore) -> Void) { f(self) }
    func read<T: Sendable>(_ f: @Sendable (isolated DemoStore) -> T) -> T { f(self) }
}
