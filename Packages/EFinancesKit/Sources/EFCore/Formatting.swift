import Foundation

/* Dinheiro e datas no padrão brasileiro, iguais aos da web e do app Android. */

public enum Money {
    public static let hidden = "R$ ••••"

    private static let lock = NSLock()
    nonisolated(unsafe) private static var formatters: [String: NumberFormatter] = [:]

    private static func formatter(_ currency: String) -> NumberFormatter {
        lock.lock(); defer { lock.unlock() }
        if let f = formatters[currency] { return f }
        let f = NumberFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.numberStyle = .currency
        f.currencyCode = currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        switch currency {
        case "BRL": f.currencySymbol = "R$"
        case "EUR": f.currencySymbol = "€"
        case "USD": f.currencySymbol = "US$"
        default: break
        }
        formatters[currency] = f
        return f
    }

    /// "R$ 1.234,56" (espaço normal, sem o espaço inquebrável do Foundation).
    public static func format(_ value: Decimal, currency: String = "BRL") -> String {
        let s = formatter(currency).string(from: NSDecimalNumber(decimal: value.rounded(2))) ?? "\(value)"
        return s.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
    }

    public static func format(cents: Int64, currency: String = "BRL") -> String { format(Decimal(cents) / 100, currency: currency) }

    /// "+ R$ 10,00" para receitas e "− R$ 10,00" para despesas.
    public static func signed(_ value: Decimal, income: Bool, currency: String = "BRL") -> String {
        (income ? "+ " : "− ") + format(value.magnitude, currency: currency)
    }

    /// "R$ 13,6 mil".
    public static func compact(_ value: Decimal, currency: String = "BRL") -> String {
        let symbol = currency == "EUR" ? "€" : currency == "USD" ? "US$" : "R$"
        return "\(symbol) \(compactNumber(value))"
    }

    /// 13550 → "13,6 mil"; 1250000 → "1,3 mi"; 950 → "950".
    public static func compactNumber(_ value: Decimal) -> String {
        let abs = value.magnitude
        let sign = value < 0 ? "-" : ""
        func one(_ d: Decimal) -> String {
            let r = d.rounded(1)
            var s = "\(r)".replacingOccurrences(of: ".", with: ",")
            if s.hasSuffix(",0") { s.removeLast(2) }
            return s
        }
        if abs >= 1_000_000 { return sign + one(abs / 1_000_000) + " mi" }
        if abs >= 1_000 { return sign + one(abs / 1_000) + " mil" }
        return sign + "\(abs.rounded(0))"
    }

    /// Separa os centavos para o valor grande: ("R$ 8.432", ",17").
    public static func split(_ value: Decimal, currency: String = "BRL") -> (String, String) {
        let s = format(value, currency: currency)
        guard let i = s.lastIndex(of: ",") else { return (s, "") }
        return (String(s[..<i]), String(s[i...]))
    }
}

public extension Decimal {
    /// Arredonda (meio para cima) em [scale] casas.
    func rounded(_ scale: Int, _ mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, mode)
        return result
    }

    /// Valor que veio da API como Double (sem os resíduos binários: 0.1 continua 0.1).
    init(api value: Double?) {
        let v = value ?? 0
        self = (Decimal(string: "\(v)", locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(v)).rounded(2)
    }

    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }

    /// Centavos inteiros (123,45 → 12345).
    var cents: Int64 { Int64(truncating: NSDecimalNumber(decimal: (self * 100).rounded(0))) }

    var intValue: Int { Int(truncating: NSDecimalNumber(decimal: self.rounded(0, .down))) }
}

/// Percentual inteiro (meio para cima); 0 quando não há total.
public func pct(_ part: Decimal, _ total: Decimal) -> Int {
    guard total != 0 else { return 0 }
    return Int(truncating: NSDecimalNumber(decimal: (part * 100 / total).rounded(0)))
}

/// Variação percentual entre dois valores (nil quando não há base).
public func variation(_ current: Decimal, _ previous: Decimal) -> Int? {
    guard previous != 0 else { return nil }
    return Int(truncating: NSDecimalNumber(decimal: ((current - previous) * 100 / previous.magnitude).rounded(0)))
}

/// Datas no formato da API (dd/MM/yyyy) e textos em português.
public enum DateFormats {
    public static let monthNames = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
    public static let shortMonths = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
    public static let weekdays = ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"]
    public static let weekdayInitials = ["D", "S", "T", "Q", "Q", "S", "S"]

    /// "dd/MM/yyyy" ou "yyyy-MM-dd" (aceita sufixo de hora).
    public static func parse(_ s: String?) -> LocalDate? {
        guard let raw = s?.trimmingCharacters(in: .whitespaces), raw.count >= 10 else { return nil }
        let v = String(raw.prefix(10))
        let chars = Array(v)
        if chars[2] == "/" {
            let p = v.split(separator: "/")
            guard p.count == 3, let d = Int(p[0]), let m = Int(p[1]), let y = Int(p[2]) else { return nil }
            return valid(y, m, d)
        }
        let p = v.split(separator: "-")
        guard p.count == 3, let y = Int(p[0]), let m = Int(p[1]), let d = Int(p[2]) else { return nil }
        return valid(y, m, d)
    }

    private static func valid(_ y: Int, _ m: Int, _ d: Int) -> LocalDate? {
        guard (1...12).contains(m), d >= 1, d <= YearMonth(y, m).lengthOfMonth else { return nil }
        return LocalDate(y, m, d)
    }

    /// Aceita "dd/MM/yyyy HH:mm:ss", "dd/MM/yyyy HH:mm" e ISO ("2026-10-10T14:03:22.123", com ou sem fuso).
    public static func parseDateTime(_ s: String?) -> LocalDateTime? {
        guard let s = s?.trimmingCharacters(in: .whitespaces), s.count >= 10, let date = parse(s) else { return nil }
        let rest = s.dropFirst(10).drop(while: { $0 == " " || $0 == "T" })
        let time = rest.prefix(8).split(separator: ":").compactMap { Int($0.prefix(2)) }
        return LocalDateTime(date, time.count > 0 ? time[0] : 0, time.count > 1 ? time[1] : 0, time.count > 2 ? time[2] : 0)
    }

    /// "07/10/2026" (formato da API).
    public static func api(_ d: LocalDate) -> String { String(format: "%02d/%02d/%04d", d.day, d.month, d.year) }

    /// "07/10".
    public static func dayMonth(_ d: LocalDate) -> String { String(format: "%02d/%02d", d.day, d.month) }

    /// "07/10/2026".
    public static func full(_ d: LocalDate) -> String { api(d) }

    /// "outubro de 2026".
    public static func monthYear(_ m: YearMonth) -> String { "\(monthNames[m.month - 1]) de \(m.year)" }

    /// "Outubro de 2026".
    public static func monthYearTitle(_ m: YearMonth) -> String { monthYear(m).capitalizedFirst }

    /// "out/2026".
    public static func shortMonthYear(_ d: LocalDate) -> String { "\(shortMonths[d.month - 1])/\(d.year)" }

    public static func monthName(_ m: YearMonth) -> String { monthNames[m.month - 1] }

    /// "O" (inicial do mês, eixo dos gráficos).
    public static func monthInitial(_ m: YearMonth) -> String { String(monthNames[m.month - 1].prefix(1)).uppercased() }

    /// "domingo, 11 de outubro".
    public static func longDay(_ d: LocalDate) -> String { "\(weekdays[d.weekday]), \(d.day) de \(monthNames[d.month - 1])" }

    /// "há 2 h", "há 40 min", "há 6 dias".
    public static func ago(_ at: LocalDateTime?, now: LocalDateTime) -> String {
        guard let at else { return "há algum tempo" }
        let minutes = max(0, at.minutes(until: now))
        if minutes < 1 { return "agora" }
        if minutes < 60 { return "há \(minutes) min" }
        if minutes < 1440 { return "há \(minutes / 60) h" }
        let d = minutes / 1440
        return "há \(d) \(d == 1 ? "dia" : "dias")"
    }

    /// "14:05".
    public static func time(_ t: LocalDateTime) -> String { String(format: "%02d:%02d", t.hour, t.minute) }
}

public extension String {
    /// Primeira letra maiúscula ("outubro" → "Outubro").
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }

    /// Sem acentos e em minúsculas (busca).
    var normalizedForSearch: String { folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR")).lowercased() }

    /// Iniciais (até 2 letras) de um nome.
    var initials: String {
        let words = split(whereSeparator: { $0 == " " }).filter { !$0.isEmpty }
        if words.count > 1, let a = words[0].first, let b = words[1].first { return "\(a)\(b)".uppercased() }
        return String((words.first ?? Substring(self)).prefix(2)).uppercased()
    }
}

/// "1 banco", "3 bancos".
public func plural(_ n: Int, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }
