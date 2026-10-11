import Foundation

/* Regras de negócio dos lançamentos (as mesmas da web e do Android). */

/// Erro de uma operação, já traduzido para a pessoa.
public enum AppError: Error, Hashable, Sendable {
    /// Sem internet ou servidor fora do ar.
    case network
    case unauthorized
    case invalidCredentials(String)
    case blocked(String)
    case tooManyAttempts(retryAfterSeconds: Int?)
    case server(String)
    case validation(String)
    case notFound

    public var message: String {
        switch self {
        case .network: return "Sem conexão. Confira a internet e tente de novo."
        case .unauthorized: return "Sua sessão terminou. Entre de novo."
        case .invalidCredentials(let m), .blocked(let m), .server(let m), .validation(let m): return m
        case .tooManyAttempts(let s):
            if let s { return "Muitas tentativas. Tente de novo em \((s + 59) / 60) min." }
            return "Muitas tentativas. Aguarde um pouco."
        case .notFound: return "Não encontramos esse registro."
        }
    }

    public static let serverDefault = AppError.server("O servidor não respondeu como esperado. Tente de novo.")
}

/// Resultado de uma operação de dados: sucesso ou erro já traduzido.
public typealias Outcome<T> = Result<T, AppError>

public extension Result where Failure == AppError {
    var value: Success? { if case .success(let v) = self { return v } else { return nil } }
    var error: AppError? { if case .failure(let e) = self { return e } else { return nil } }
}

public extension Transaction {
    /// Situação do lançamento: pago, atrasado, vence em até 7 dias ou agendado.
    func dueStatus(today: LocalDate) -> DueStatus {
        if paid { return .paid }
        let days = today.days(until: date)
        if days < 0 { return .late(days: -days) }
        if days <= 7 { return .dueSoon(days: days) }
        return .scheduled(date)
    }
}

public extension DueStatus {
    var group: DueGroup {
        switch self { case .paid: .paid; case .late: .late; case .dueSoon: .soon; case .scheduled: .scheduled }
    }

    var isLate: Bool { if case .late = self { return true } else { return false } }
    var isSoon: Bool { if case .dueSoon = self { return true } else { return false } }

    /// "Atrasada há 2 dias", "Vence amanhã", "Pago".
    func label(income: Bool) -> String {
        switch self {
        case .paid: return income ? "Recebido" : "Pago"
        case .late(let d): return "Atrasada há \(d) \(d == 1 ? "dia" : "dias")"
        case .dueSoon(let d):
            switch d {
            case 0: return income ? "Recebe hoje" : "Vence hoje"
            case 1: return income ? "Recebe amanhã" : "Vence amanhã"
            default: return "\(income ? "Recebe" : "Vence") em \(d) dias"
            }
        case .scheduled(let date): return "\(income ? "Recebe" : "Vence") \(DateFormats.dayMonth(date))"
        }
    }
}

public extension Array where Element == Transaction {
    /// Agrupados por situação, na ordem da tela (atrasadas primeiro, pagas por último e das mais recentes).
    func groupedByDue(today: LocalDate) -> [(DueGroup, [Transaction])] {
        DueGroup.allCases.compactMap { g in
            let items = filter { $0.dueStatus(today: today).group == g }
            let sorted = g == .paid ? items.sorted { $0.date > $1.date } : items.sorted { $0.date < $1.date }
            return sorted.isEmpty ? nil : (g, sorted)
        }
    }

    func totals() -> MonthTotals {
        let inc = filter { $0.type.isIncome }
        let exp = filter { !$0.type.isIncome }
        return MonthTotals(income: inc.sum, incomePaid: inc.filter(\.paid).sum, expense: exp.sum, expensePaid: exp.filter(\.paid).sum)
    }

    var sum: Decimal { reduce(0) { $0 + $1.value } }

    /// Despesas por categoria, da maior para a menor, com o percentual de cada uma.
    func expensesByCategory() -> [CategoryShare] {
        let expenses = filter { !$0.type.isIncome }
        let total = expenses.sum
        let groups = Dictionary(grouping: expenses) { $0.category?.name ?? "Sem categoria" }
        return groups.map { name, list in
            let v = list.sum
            return CategoryShare(name: name, value: v, percent: pct(v, total), category: list.first?.category)
        }
        .sorted { $0.value == $1.value ? $0.name < $1.name : $0.value > $1.value }
    }
}

public struct MonthTotals: Hashable, Sendable {
    public var income: Decimal
    public var incomePaid: Decimal
    public var expense: Decimal
    public var expensePaid: Decimal

    public init(income: Decimal, incomePaid: Decimal, expense: Decimal, expensePaid: Decimal) {
        self.income = income; self.incomePaid = incomePaid; self.expense = expense; self.expensePaid = expensePaid
    }

    public var balance: Decimal { income - expense }
    /// Resultado do mês: o que entrou menos o que saiu de fato (não acumula os meses anteriores).
    public var result: Decimal { incomePaid - expensePaid }
    public var incomeOpen: Decimal { income - incomePaid }
    public var expenseOpen: Decimal { expense - expensePaid }
    public var incomePaidPct: Int { pct(incomePaid, income) }
    public var expensePaidPct: Int { pct(expensePaid, expense) }
}

/// Saldo previsto no fim do mês: saldo de hoje + a receber − a pagar.
public func forecast(balance: Decimal, totals: MonthTotals) -> Decimal { balance + totals.incomeOpen - totals.expenseOpen }

public struct CategoryShare: Hashable, Sendable, Identifiable {
    public var name: String
    public var value: Decimal
    public var percent: Int
    /// Aparência (quando a fatia é de uma categoria conhecida).
    public var category: TransactionCategory?
    public var id: String { name }

    public init(name: String, value: Decimal, percent: Int, category: TransactionCategory? = nil) {
        self.name = name; self.value = value; self.percent = percent; self.category = category
    }
}

/**
 Parcelas como na web: todas iguais e a sobra dos centavos na 1ª (100 em 3 = 33,34 + 33,33 + 33,33), a data de cada
 uma (a calculada ou a escolhida à mão) e a competência de cada parcela é o mês dela.
 */
public struct InstallmentPlan: Hashable, Sendable {
    public var values: [Decimal]
    public var dates: [LocalDate]
    public var custom: Set<Int>

    public var count: Int { values.count }
    public var first: Decimal { values.first ?? 0 }
    public var each: Decimal { values.last ?? 0 }
    public var total: Decimal { values.reduce(0, +) }
    public var last: LocalDate { dates.max() ?? dates[0] }
    public var even: Bool { values.allSatisfy { $0 == values.first } }
}

public func installmentPlan(cents: Int64, count: Int, valueIsTotal: Bool, first: LocalDate, recurrence: Recurrence, overrides: [Int: LocalDate] = [:]) -> InstallmentPlan {
    let n = max(count, 1)
    let totalCents = valueIsTotal ? cents : cents * Int64(n)
    let each = totalCents / Int64(n)
    let rest = totalCents - each * Int64(n)
    let values = (0..<n).map { i in Decimal(i == 0 ? each + rest : each) / 100 }
    // passo a partir da 1ª data, sem encadear; a 1ª é sempre a do lançamento
    let dates = (0..<n).map { i in i > 0 ? (overrides[i] ?? recurrence.next(first, steps: i)) : first }
    return InstallmentPlan(values: values, dates: dates, custom: Set(overrides.keys.filter { $0 >= 1 && $0 < n }))
}

/// Situação de um limite pela regra do backend: passou de 100% = over; chegou no % de alerta = warn.
public func limitStatus(spent: Decimal, limit: Decimal, alertPercent: Int) -> LimitStatus {
    guard limit > 0 else { return .ok }
    let p = pct(spent, limit)
    if p >= 100 { return .over }
    if p >= alertPercent { return .warn }
    return .ok
}

public extension TransactionDraft {
    /// Validação do formulário: erros por campo (vazio = válido).
    func validate() -> [String: String] {
        var e: [String: String] = [:]
        if cents <= 0 { e["value"] = "Informe o valor" }
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { e["description"] = "Informe uma descrição" }
        if description.count > 255 { e["description"] = "Use até 255 caracteres" }
        if paymentMode == .installments && !(2...48).contains(installments) { e["installments"] = "De 2 a 48 parcelas" }
        return e
    }
}

/// Busca em lançamentos: descrição, contato, categoria e documento, sem acentos.
public func matches(_ t: Transaction, query: String) -> Bool {
    let q = query.trimmingCharacters(in: .whitespaces).normalizedForSearch
    guard !q.isEmpty else { return true }
    return [t.description, t.contact?.name, t.category?.name, t.docNumber].compactMap { $0 }.contains { $0.normalizedForSearch.contains(q) }
}
