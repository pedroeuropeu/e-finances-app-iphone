import Testing
import Foundation
@testable import EFCore

@Suite("Datas do calendário")
struct DatesTests {
    @Test func epochDayRoundTrip() {
        for d in [LocalDate(1970, 1, 1), LocalDate(2026, 10, 11), LocalDate(2024, 2, 29), LocalDate(1899, 12, 31), LocalDate(2100, 3, 1)] {
            #expect(LocalDate(epochDay: d.epochDay) == d)
        }
        #expect(LocalDate(1970, 1, 1).epochDay == 0)
    }

    @Test func monthArithmeticKeepsDayWithinMonth() {
        #expect(LocalDate(2026, 1, 31).plusMonths(1) == LocalDate(2026, 2, 28))
        #expect(LocalDate(2024, 1, 31).plusMonths(1) == LocalDate(2024, 2, 29))
        #expect(LocalDate(2026, 12, 15).plusMonths(1) == LocalDate(2027, 1, 15))
        #expect(LocalDate(2026, 3, 10).plusMonths(-3) == LocalDate(2025, 12, 10))
        #expect(YearMonth(2026, 13) == YearMonth(2027, 1))
        #expect(YearMonth(2026, 0) == YearMonth(2025, 12))
    }

    @Test func weekdayAndLongDay() {
        // 11/10/2026 é domingo
        #expect(LocalDate(2026, 10, 11).weekday == 0)
        #expect(DateFormats.longDay(LocalDate(2026, 10, 9)) == "sexta-feira, 9 de outubro")
    }

    @Test func apiFormats() {
        #expect(DateFormats.api(LocalDate(2026, 10, 7)) == "07/10/2026")
        #expect(DateFormats.parse("07/10/2026") == LocalDate(2026, 10, 7))
        #expect(DateFormats.parse("2026-10-07") == LocalDate(2026, 10, 7))
        #expect(DateFormats.parse("31/02/2026") == nil)
        #expect(DateFormats.parse("") == nil)
        let dt = DateFormats.parseDateTime("10/10/2026 14:03:22")
        #expect(dt == LocalDateTime(LocalDate(2026, 10, 10), 14, 3, 22))
        #expect(DateFormats.parseDateTime("2026-10-10T14:03:22.123Z") == LocalDateTime(LocalDate(2026, 10, 10), 14, 3, 22))
        #expect(YearMonth.parse("2026-10") == YearMonth(2026, 10))
        #expect(YearMonth(2026, 10).description == "2026-10")
    }

    @Test func ago() {
        let now = LocalDateTime(LocalDate(2026, 10, 11), 12, 0)
        #expect(DateFormats.ago(now.plusMinutes(-40), now: now) == "há 40 min")
        #expect(DateFormats.ago(now.plusHours(-2), now: now) == "há 2 h")
        #expect(DateFormats.ago(now.plusDays(-1), now: now) == "há 1 dia")
        #expect(DateFormats.ago(now.plusDays(-6), now: now) == "há 6 dias")
        #expect(DateFormats.ago(nil, now: now) == "há algum tempo")
    }
}

@Suite("Dinheiro no padrão brasileiro")
struct MoneyTests {
    @Test func formats() {
        #expect(Money.format(1234.56) == "R$ 1.234,56")
        #expect(Money.format(0) == "R$ 0,00")
        #expect(Money.format(-2148.9) == "-R$ 2.148,90")
        #expect(Money.format(cents: 3334) == "R$ 33,34")
        #expect(Money.signed(10, income: true) == "+ R$ 10,00")
        #expect(Money.signed(-10, income: false) == "− R$ 10,00")
    }

    @Test func compact() {
        #expect(Money.compactNumber(13550) == "13,6 mil")
        #expect(Money.compactNumber(1_250_000) == "1,3 mi")
        #expect(Money.compactNumber(950) == "950")
        #expect(Money.compactNumber(9000) == "9 mil")
        #expect(Money.compact(13550) == "R$ 13,6 mil")
    }

    @Test func split() {
        let (a, b) = Money.split(8432.17)
        #expect(a == "R$ 8.432")
        #expect(b == ",17")
    }

    @Test func apiDoubleBecomesExactDecimal() {
        #expect(Decimal(api: 0.1) == Decimal(string: "0.1"))
        #expect(Decimal(api: 248.37) == Decimal(string: "248.37"))
        #expect(Decimal(api: nil) == 0)
        #expect(Decimal(string: "123.45")!.cents == 12345)
    }

    @Test func percentages() {
        #expect(pct(1, 3) == 33)
        #expect(pct(2, 3) == 67)
        #expect(pct(5, 0) == 0)
        #expect(variation(110, 100) == 10)
        #expect(variation(90, 100) == -10)
        #expect(variation(10, 0) == nil)
    }
}

@Suite("Regras dos lançamentos")
struct TransactionRulesTests {
    let today = LocalDate(2026, 10, 11)

    func tx(_ id: Int64, day: Int, paid: Bool = false, type: TransactionType = .variable, value: Decimal = 10, category: String? = nil) -> Transaction {
        Transaction(id: id, description: "T\(id)", value: value, type: type, date: LocalDate(2026, 10, day), paid: paid,
                    category: category.map { TransactionCategory(id: Int64($0.count), name: $0) })
    }

    @Test func dueStatusAndLabels() {
        #expect(tx(1, day: 7).dueStatus(today: today) == .late(days: 4))
        #expect(tx(1, day: 11).dueStatus(today: today) == .dueSoon(days: 0))
        #expect(tx(1, day: 18).dueStatus(today: today) == .dueSoon(days: 7))
        #expect(tx(1, day: 19).dueStatus(today: today) == .scheduled(LocalDate(2026, 10, 19)))
        #expect(tx(1, day: 1, paid: true).dueStatus(today: today) == .paid)
        #expect(DueStatus.late(days: 1).label(income: false) == "Atrasada há 1 dia")
        #expect(DueStatus.dueSoon(days: 0).label(income: true) == "Recebe hoje")
        #expect(DueStatus.dueSoon(days: 1).label(income: false) == "Vence amanhã")
        #expect(DueStatus.dueSoon(days: 4).label(income: false) == "Vence em 4 dias")
        #expect(DueStatus.scheduled(LocalDate(2026, 10, 20)).label(income: true) == "Recebe 20/10")
    }

    @Test func groupsInScreenOrder() {
        let list = [tx(1, day: 20), tx(2, day: 1, paid: true), tx(3, day: 9), tx(4, day: 5, paid: true), tx(5, day: 12), tx(6, day: 7)]
        let groups = list.groupedByDue(today: today)
        #expect(groups.map(\.0) == [.late, .soon, .scheduled, .paid])
        #expect(groups[0].1.map(\.id) == [6, 3])   // atrasadas: da mais antiga para a mais nova
        #expect(groups[3].1.map(\.id) == [4, 2])   // pagas: das mais recentes
    }

    @Test func totalsResultAndForecast() {
        let list = [tx(1, day: 5, paid: true, type: .income, value: 1000), tx(2, day: 20, type: .income, value: 500),
                    tx(3, day: 2, paid: true, value: 300), tx(4, day: 25, value: 200)]
        let t = list.totals()
        #expect(t.income == 1500)
        #expect(t.expense == 500)
        #expect(t.result == 700)
        #expect(t.incomePaidPct == 67)
        #expect(t.expensePaidPct == 60)
        #expect(forecast(balance: 1000, totals: t) == 1300)
    }

    @Test func expensesByCategory() {
        let list = [tx(1, day: 1, value: 30, category: "Lazer"), tx(2, day: 2, value: 70, category: "Moradia"), tx(3, day: 3, type: .income, value: 999, category: "Salário")]
        let shares = list.expensesByCategory()
        #expect(shares.map(\.name) == ["Moradia", "Lazer"])
        #expect(shares.map(\.percent) == [70, 30])
    }

    @Test func installmentPlanPutsLeftoverCentsInTheFirst() {
        let plan = installmentPlan(cents: 10000, count: 3, valueIsTotal: true, first: LocalDate(2026, 1, 31), recurrence: .monthly)
        #expect(plan.values == [Decimal(string: "33.34")!, Decimal(string: "33.33")!, Decimal(string: "33.33")!])
        #expect(plan.total == 100)
        #expect(!plan.even)
        // mensal no dia 31 sem encadear: 28/02 e depois 31/03
        #expect(plan.dates == [LocalDate(2026, 1, 31), LocalDate(2026, 2, 28), LocalDate(2026, 3, 31)])

        let each = installmentPlan(cents: 2000, count: 4, valueIsTotal: false, first: LocalDate(2026, 10, 1), recurrence: .monthly)
        #expect(each.total == 80)
        #expect(each.even)

        let custom = installmentPlan(cents: 9000, count: 3, valueIsTotal: true, first: LocalDate(2026, 10, 1), recurrence: .monthly, overrides: [2: LocalDate(2027, 1, 15)])
        #expect(custom.dates[2] == LocalDate(2027, 1, 15))
        #expect(custom.custom == [2])

        let fortnight = installmentPlan(cents: 3000, count: 3, valueIsTotal: true, first: LocalDate(2026, 10, 1), recurrence: .fortnightly)
        #expect(fortnight.dates == [LocalDate(2026, 10, 1), LocalDate(2026, 10, 16), LocalDate(2026, 10, 31)])
    }

    @Test func limitStatusRule() {
        #expect(limitStatus(spent: 210, limit: 180, alertPercent: 80) == .over)
        #expect(limitStatus(spent: 180, limit: 180, alertPercent: 80) == .over)
        #expect(limitStatus(spent: 150, limit: 180, alertPercent: 80) == .warn)
        #expect(limitStatus(spent: 100, limit: 180, alertPercent: 80) == .ok)
        #expect(limitStatus(spent: 100, limit: 0, alertPercent: 80) == .ok)
    }

    @Test func draftValidation() {
        var d = TransactionDraft(date: today)
        #expect(d.validate().keys.sorted() == ["description", "value"])
        d.cents = 1000
        d.description = "Luz"
        #expect(d.validate().isEmpty)
        d.paymentMode = .installments
        d.installments = 60
        #expect(d.validate()["installments"] != nil)
    }

    @Test func searchIgnoresAccentsAndCase() {
        var t = tx(1, day: 1, category: "Alimentação")
        t.description = "Condomínio"
        #expect(matches(t, query: "condominio"))
        #expect(matches(t, query: "ALIMENTA"))
        #expect(!matches(t, query: "luz"))
        #expect(matches(t, query: "  "))
    }

    @Test func installmentParsingAndScope() {
        var t = tx(1, day: 1)
        t.plot = "3/10"
        #expect(t.installment! == (3, 10))
        #expect(t.isInstallment)
        #expect(t.hasScope)
        t.plot = nil
        t.paymentMode = .recurring
        #expect(t.isRecurring && t.hasScope)
    }

    @Test func recurrenceSteps() {
        #expect(Recurrence.quarterly.next(LocalDate(2026, 11, 30), steps: 1) == LocalDate(2027, 2, 28))
        #expect(Recurrence.yearly.next(LocalDate(2024, 2, 29), steps: 1) == LocalDate(2025, 2, 28))
    }
}

@Suite("Relatórios e cadastros")
struct ManagementTests {
    @Test func compositionSumsMonthsAndFiltersByContactKind() {
        let r = ReportOverview(start: LocalDate(2026, 9, 1), end: LocalDate(2026, 10, 31), currency: "BRL", accountName: "Conta", current: .zero, previous: .zero, months: [],
                               breakdown: [.contact: [
                                ReportSlice(key: "1", label: "Enel", type: .fixed, total: 100, count: 1, group: .supplier),
                                ReportSlice(key: "1", label: "Enel", type: .fixed, total: 50, count: 1, group: .supplier),
                                ReportSlice(key: "2", label: "Joana", type: .fixed, total: 600, count: 1, group: .worker),
                                ReportSlice(key: "3", label: "Acme", type: .income, total: 9800, count: 1, group: .client)
                               ]], topExpenses: [])
        let all = r.expenseComposition(.contact)
        #expect(all.map(\.name) == ["Joana", "Enel"])
        #expect(all.map(\.value) == [600, 150])
        #expect(all.map(\.percent) == [80, 20])
        #expect(r.expenseComposition(.contact, contactKind: .supplier).map(\.name) == ["Enel"])
    }

    @Test func reportTotals() {
        let t = ReportTotals(income: 1000, expenseFixed: 300, expenseVariable: 200, paidIncome: 0, paidExpense: 0, openIncome: 0, openExpense: 0, count: 3)
        #expect(t.expense == 500)
        #expect(t.net == 500)
        #expect(t.margin == 50)
    }

    @Test func deletionRequestDetection() {
        func ticket(_ c: TicketCategory?, _ title: String) -> Ticket {
            Ticket(id: 1, protocolNumber: "#1", title: title, category: c, status: .open, createdAt: nil, lastMessageAt: nil, unread: false, lastMessage: nil, lastFromSupport: false, messages: [])
        }
        #expect(ticket(.accountDeletion, "Excluir minha conta").isDeletionRequest)
        #expect(ticket(.account, "Quero excluir tudo").isDeletionRequest)
        #expect(!ticket(.account, "Trocar e-mail").isDeletionRequest)
        #expect(!ticket(.question, "Como excluir lançamento").isDeletionRequest)
    }

    @Test func workspaceFallbacks() {
        let ws = Workspace(companyId: 9, accountId: 99, companies: [
            Company(id: 1, name: "Casa", type: .family, typeLabel: "Familiar", accounts: [
                Account(id: 11, name: "Conta corrente", defaultAccount: true), Account(id: 13, name: "Nubank", mode: .connected)
            ])
        ])
        #expect(ws.company?.id == 1)
        #expect(ws.account?.id == 11)
        #expect(ws.mode == .manual)
        #expect(ws.companyOf(accountId: 13)?.name == "Casa")
    }

    @Test func bankAccountHeadline() {
        #expect(BankAccount(id: 1, connectionId: 1, name: "Cartão", kind: .credit, balance: -2148.90, creditLimit: 8000, availableCredit: 5851.10).headline == Decimal(string: "2148.9"))
        #expect(BankAccount(id: 1, connectionId: 1, name: "Cartão", kind: .credit, balance: 0, creditLimit: 8000, availableCredit: 5851.10).headline == Decimal(string: "2148.9"))
        #expect(BankAccount(id: 1, connectionId: 1, name: "Conta", kind: .bank, balance: 3214.55).headline == Decimal(string: "3214.55"))
    }

    @Test func profileInitials() {
        #expect(UserProfile(firstName: "Pedro", lastName: "Europeu", email: "p@x.com", planName: nil, planEndDate: nil).initials == "PE")
        #expect(UserProfile(firstName: "", lastName: "", email: "maria@x.com", planName: nil, planEndDate: nil).initials == "MA")
        #expect("Cond. Jardim das Flores".initials == "CJ")
    }
}
