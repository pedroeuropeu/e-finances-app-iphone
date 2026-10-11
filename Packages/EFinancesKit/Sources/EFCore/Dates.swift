import Foundation

/*
 Datas de calendário sem fuso (como o LocalDate do Java que o backend usa). Contas simples e previsíveis: o
 vencimento "07/10" é sempre 7 de outubro, em qualquer fuso do iPhone.
 */

/// Dia do calendário (ano, mês, dia).
public struct LocalDate: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Cria a data ajustando o dia ao tamanho do mês (31/02 vira 28 ou 29/02).
    public init(_ year: Int, _ month: Int, _ day: Int) {
        let ym = YearMonth(year, month)
        self.year = ym.year
        self.month = ym.month
        self.day = min(max(day, 1), ym.lengthOfMonth)
    }

    /// Dias desde 01/01/1970 (algoritmo civil de Howard Hinnant).
    public var epochDay: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    public init(epochDay: Int) {
        let z = epochDay + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        self.year = yoe + era * 400 + (m <= 2 ? 1 : 0)
        self.month = m
        self.day = d
    }

    public var yearMonth: YearMonth { YearMonth(year, month) }
    public var lengthOfMonth: Int { yearMonth.lengthOfMonth }

    public func plusDays(_ n: Int) -> LocalDate { LocalDate(epochDay: epochDay + n) }
    public func minusDays(_ n: Int) -> LocalDate { plusDays(-n) }

    /// Soma meses mantendo o dia (31/01 + 1 mês = 28/02).
    public func plusMonths(_ n: Int) -> LocalDate {
        let ym = yearMonth.plusMonths(n)
        return LocalDate(ym.year, ym.month, day)
    }

    public func plusYears(_ n: Int) -> LocalDate { plusMonths(n * 12) }
    public func withDay(_ d: Int) -> LocalDate { LocalDate(year, month, d) }

    /// Dias entre esta data e [other] (positivo se [other] vem depois).
    public func days(until other: LocalDate) -> Int { other.epochDay - epochDay }

    /// 0 = domingo … 6 = sábado.
    public var weekday: Int { ((epochDay % 7) + 7 + 4) % 7 }

    public static func < (a: LocalDate, b: LocalDate) -> Bool { a.epochDay < b.epochDay }

    public var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    // Codable como "yyyy-MM-dd" (usado só em armazenamento local; a API usa dd/MM/yyyy, ver DateFormats).
    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let d = DateFormats.parse(s) else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "data inválida: \(s)")) }
        self = d
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}

/// Mês do calendário (ano, mês).
public struct YearMonth: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int

    /// Normaliza meses fora de 1…12 (mês 13 vira janeiro do ano seguinte).
    public init(_ year: Int, _ month: Int) {
        let total = year * 12 + (month - 1)
        self.year = Int((Double(total) / 12).rounded(.down))
        self.month = total - self.year * 12 + 1
    }

    public var isLeapYear: Bool { (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 }

    public var lengthOfMonth: Int {
        switch month {
        case 2: return isLeapYear ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    public func plusMonths(_ n: Int) -> YearMonth { YearMonth(year, month + n) }
    public func minusMonths(_ n: Int) -> YearMonth { plusMonths(-n) }
    public func atDay(_ d: Int) -> LocalDate { LocalDate(year, month, d) }
    public var firstDay: LocalDate { atDay(1) }
    public var lastDay: LocalDate { atDay(lengthOfMonth) }

    /// Meses entre este e [other] (positivo se [other] vem depois).
    public func months(until other: YearMonth) -> Int { (other.year * 12 + other.month) - (year * 12 + month) }

    public static func < (a: YearMonth, b: YearMonth) -> Bool { (a.year, a.month) < (b.year, b.month) }

    /// "2026-10" (formato que a API usa em ?month=).
    public var description: String { String(format: "%04d-%02d", year, month) }

    public static func parse(_ s: String?) -> YearMonth? {
        guard let s, s.count >= 7 else { return nil }
        let parts = s.prefix(7).split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]), (1...12).contains(m) else { return nil }
        return YearMonth(y, m)
    }
}

/// Data e hora sem fuso (como o LocalDateTime da API).
public struct LocalDateTime: Hashable, Comparable, Sendable {
    public let date: LocalDate
    public let hour: Int
    public let minute: Int
    public let second: Int

    public init(_ date: LocalDate, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) {
        self.date = date
        self.hour = hour
        self.minute = minute
        self.second = second
    }

    var totalSeconds: Int { ((date.epochDay * 24 + hour) * 60 + minute) * 60 + second }

    public func minutes(until other: LocalDateTime) -> Int { (other.totalSeconds - totalSeconds) / 60 }

    public func plusMinutes(_ n: Int) -> LocalDateTime { LocalDateTime(seconds: totalSeconds + n * 60) }
    public func plusHours(_ n: Int) -> LocalDateTime { plusMinutes(n * 60) }
    public func plusDays(_ n: Int) -> LocalDateTime { plusMinutes(n * 1440) }

    init(seconds: Int) {
        let days = Int((Double(seconds) / 86_400).rounded(.down))
        let rest = seconds - days * 86_400
        self.init(LocalDate(epochDay: days), rest / 3600, (rest % 3600) / 60, rest % 60)
    }

    public func withTime(_ hour: Int, _ minute: Int) -> LocalDateTime { LocalDateTime(date, hour, minute, 0) }

    public static func < (a: LocalDateTime, b: LocalDateTime) -> Bool { a.totalSeconds < b.totalSeconds }
}

/// Relógio injetável: hoje, agora e instante em milissegundos (os testes usam um relógio fixo).
public protocol AppClock: Sendable {
    func now() -> Date
}

public extension AppClock {
    /// Data local de hoje no fuso do iPhone.
    func today() -> LocalDate {
        let c = Calendar(identifier: .gregorian).dateComponents(in: .current, from: now())
        return LocalDate(c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    func currentMonth() -> YearMonth { today().yearMonth }

    func localNow() -> LocalDateTime {
        let c = Calendar(identifier: .gregorian).dateComponents(in: .current, from: now())
        return LocalDateTime(LocalDate(c.year ?? 1970, c.month ?? 1, c.day ?? 1), c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }

    func epochMillis() -> Int64 { Int64((now().timeIntervalSince1970 * 1000).rounded()) }
}

public struct SystemClock: AppClock {
    public init() {}
    public func now() -> Date { Date() }
}

/// Relógio parado num instante (testes e modo demonstração com data fixa).
public struct FixedClock: AppClock {
    public let date: Date
    public init(_ date: Date) { self.date = date }

    /// Relógio no dia [day] às [hour]h no fuso atual.
    public init(_ day: LocalDate, hour: Int = 9) {
        var c = DateComponents()
        c.year = day.year; c.month = day.month; c.day = day.day; c.hour = hour
        self.date = Calendar(identifier: .gregorian).date(from: c) ?? Date()
    }

    public func now() -> Date { date }
}
