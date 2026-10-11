import Testing
import Foundation
@testable import EFCore
@testable import EFData

/// JSON no formato que o backend devolve (campos nulos omitidos, datas dd/MM/yyyy).
@Suite("Conversões da API")
struct MappersTests {
    let today = LocalDate(2026, 10, 11)

    func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T { try JSONDecoder().decode(T.self, from: Data(json.utf8)) }

    @Test func transaction() throws {
        let dto = try decode(TransactionDTO.self, """
        {"id":5,"description":"Condomínio","value":680.0,"paymentType":"BOLETO_BANCARIO","paymentMode":"REPEATABLE","paymentModeRecurrence":"MONTHLY",
         "transactionType":"DESPESAS_FIXAS","payed":false,"transactionDate":"07/10/2026","transactionRef":"01/10/2026","transactionRootNumber":"R-77",
         "category":{"id":1,"name":"Moradia","icon":"pi-home","color":"#6366F1","systemDefault":true},
         "contact":{"id":5,"name":"Cond. Jardim das Flores","category":"SUPPLIER","phone":"(11) 3333-1010"},
         "account":{"id":11,"name":"Conta corrente"},"docNumber":"  "}
        """)
        let t = dto.toDomain(today: today)
        #expect(t.value == 680)
        #expect(t.type == .fixed)
        #expect(t.date == LocalDate(2026, 10, 7))
        #expect(t.paymentMode == .recurring && t.recurrence == .monthly)
        #expect(t.category?.icon == "pi-home" && t.category?.systemDefault == true)
        #expect(t.contact?.category == .supplier && t.contact?.phone == "(11) 3333-1010")
        #expect(t.docNumber == nil)
        #expect(t.rootNumber == "R-77")
        #expect(t.accountName == "Conta corrente")
    }

    @Test func missingFieldsBecomeNeutral() throws {
        let t = try decode(TransactionDTO.self, #"{"id":1}"#).toDomain(today: today)
        #expect(t.description == "" && t.value == 0 && t.type == .variable && t.date == today && !t.paid)
    }

    @Test func workspaceWithBankAccounts() throws {
        let ws = try decode(WorkspaceDTO.self, """
        {"companyId":1,"accountId":14,"companies":[{"id":1,"name":"Casa","type":"FAMILY","accounts":[
          {"id":11,"name":"Conta corrente","balance":8432.17,"defaultAccount":true,"transactions":23},
          {"id":14,"name":"Nubank · Cartão","balance":-2148.9,"connected":true,"bankName":"Nubank","bankColor":"#820AD1","bankLogoUrl":""},
          {"id":24,"name":"C6 · Conta","balance":512.3,"connected":true,"frozen":true}]}]}
        """).toDomain()
        #expect(ws.company?.typeLabel == "Familiar")
        #expect(ws.account?.id == 14)
        #expect(ws.mode == .connected)
        #expect(ws.company?.accounts.map(\.mode) == [.manual, .connected, .frozen])
        #expect(ws.company?.accounts[1].bankLogoUrl == nil)
    }

    @Test func userNameCleanup() throws {
        let u = try decode(UserDTO.self, #"{"email":"p@x.com","completeName":"null Silva ","userPlan":{"plan":{"name":"PREMIUN"},"endDate":"12/11/2026"}}"#).toDomain(fallbackEmail: "p@x.com")
        #expect(u.firstName == "Silva")
        #expect(u.lastName == "")
        #expect(u.planName == "Premium")
        #expect(u.planEndDate == LocalDate(2026, 11, 12))
    }

    @Test func connectionsAndHeadline() throws {
        let c = try decode([ConnectionDTO].self, """
        [{"id":2,"connectorName":"Itaú","status":"LOGIN_ERROR","lastSyncAt":"05/10/2026 08:00:00","companyId":1,"companyName":"Casa",
          "accounts":[{"id":202,"type":"CREDIT","name":"ITAU CLICK","marketingName":"Itaú Click Visa","balance":0,"creditLimit":6000,"availableCreditLimit":4687.56,"ledgerAccountId":16}]}]
        """).map { $0.toDomain() }
        #expect(c[0].needsUserAction)
        #expect(c[0].accounts[0].name == "Itaú Click Visa")
        #expect(c[0].accounts[0].headline == Decimal(string: "1312.44"))
        #expect(c[0].accounts[0].ledgerAccountId == 16)
        #expect(c[0].lastSyncAt == LocalDateTime(LocalDate(2026, 10, 5), 8, 0, 0))
    }

    @Test func subscriptionsPickTheMainCurrency() throws {
        let s = try decode(SubscriptionsDTO.self, """
        {"subscriptions":[{"key":"b","name":"Spotify","amount":34.9,"nextDate":"03/11/2026"},{"key":"a","name":"Netflix","amount":55.9,"previousAmount":49.9,"nextDate":"01/11/2026"}],
         "totals":[{"currency":"EUR","monthly":9.99,"count":1},{"currency":"BRL","monthly":90.8,"yearly":1089.6,"count":2}],"connected":true}
        """).toDomain()
        #expect(s.subscriptions.map(\.name) == ["Netflix", "Spotify"])
        #expect(s.monthlyTotal == Decimal(string: "90.8"))
        #expect(s.currency == "BRL")
        #expect(s.subscriptions[0].priceIncreasePct == 12)
        #expect(s.connected)
    }

    @Test func reportWithDaysAndContactKind() throws {
        let r = try decode(ReportFullDTO.self, """
        {"start":"01/10/2026","end":"31/10/2026","currency":"BRL","accountName":"Conta corrente",
         "current":{"income":1000,"expenseFixed":300,"expenseVariable":200},"previous":{"income":800},
         "months":[{"year":2026,"month":10,"income":1000,"expense":500},{"year":2026,"month":11,"income":0,"expense":100}],
         "breakdown":{"CONTACT":[{"key":"5","label":"Enel","type":"DESPESAS_FIXAS","total":-248.37,"count":1,"group":"SUPPLIER"}],"UNKNOWN":[]},
         "days":[{"date":"07/10/2026","income":0,"expense":680}],
         "topExpenses":[{"id":4,"date":"05/10/2026","description":"Aluguel","value":2300,"paid":true}]}
        """).toDomain(start: LocalDate(2026, 10, 1), end: LocalDate(2026, 10, 31), today: today)
        #expect(r.current.expense == 500)
        #expect(r.months.map(\.projected) == [false, true])
        #expect(r.breakdown[.contact]?.first?.group == .supplier)
        #expect(r.breakdown[.contact]?.first?.total == Decimal(string: "248.37"))
        #expect(r.days.first?.expense == 680)
        #expect(r.topExpenses.first?.paid == true)
    }

    @Test func categoryOverviewAndLimits() throws {
        let o = try decode(CategoryOverviewDTO.self, """
        {"month":"2026-10","spent":-963.45,"categories":[{"id":5,"name":"Saúde","spent":-963.45,"limit":1000,"limitPercent":96,"limitStatus":"WARN","usage":12,"count":2}]}
        """).toDomain(fallback: YearMonth(2026, 1))
        #expect(o.month == YearMonth(2026, 10))
        #expect(o.spent == Decimal(string: "963.45"))
        #expect(o.categories[0].limitStatus == .warn)
        #expect(o.nearLimit == 1)
        let l = try decode(LimitsDTO.self, #"{"items":[{"id":3,"categoryId":7,"categoryName":"Lazer","limit":180,"spent":210,"status":"over"}],"suggestions":[{"categoryId":6,"categoryName":"Educação","average":1450,"suggested":1450}]}"#).toDomain(fallback: YearMonth(2026, 10))
        #expect(l.items[0].status == .over)
        #expect(l.attention == 1)
        #expect(l.suggestions.count == 1)
    }

    @Test func storyNotificationsTickets() throws {
        let s = try decode(StoryDTO.self, #"{"periodKey":"M:2026-09","periodLabel":"setembro de 2026","income":13061,"limits":{"total":6,"within":5,"over":1},"subscriptions":{"monthly":292.49,"count":6}}"#).toDomain()
        #expect(s.tag == "setembro de 2026" && s.limitsOver == 1 && s.subscriptionsCount == 6)
        let n = try decode(NotificationDTO.self, #"{"id":1,"category":"LIMIT","severity":"DANGER","title":"x","createdAt":"11/10/2026 08:12:00","readAt":"11/10/2026 09:00:00"}"#).toDomain()
        #expect(n.category == .limit && n.severity == .danger && n.read)
        let t = try decode(TicketDTO.self, ##"{"id":482,"protocol":"#000482","title":"Excluir minha conta","category":"EXCLUSAO_CONTA","ticketStatus":"WAITING_ANSWER_USER","messages":[{"id":1,"message":"oi","fromSupport":true}]}"##).toDomain()
        #expect(t.status == .waitingUser && t.isDeletionRequest && t.messages[0].fromSupport)
    }

    @Test func draftToApiBodies() throws {
        var d = TransactionDraft(type: .income, description: " Aluguel ", cents: 135000, date: LocalDate(2026, 10, 20), newContactName: "Marina",
                                 paid: true, paymentType: .transfer, paymentMode: .recurring, refMonth: YearMonth(2026, 10))
        d.newCategoryName = "Aluguéis"
        let body = d.toUpdateDTO(id: nil, value: d.value, date: d.date)
        #expect(body.description == "Aluguel")
        #expect(body.value == 1350)
        #expect(body.transactionDate == "20/10/2026")
        #expect(body.transactionRef == "01/10/2026")
        #expect(body.paymentModeRecurrence == "MONTHLY")
        #expect(body.contact == RefDTO(name: "Marina", category: "CLIENT"))
        #expect(body.category == RefDTO(name: "Aluguéis"))
        let json = String(data: try JSONEncoder().encode(body), encoding: .utf8) ?? ""
        #expect(!json.contains("\"id\""))       // nulos não vão
        #expect(!json.contains("costCenter"))

        let original = Transaction(id: 9, description: "PIX", value: 10, type: .variable, date: LocalDate(2026, 10, 1), paid: true, docNumber: "123")
        var org = TransactionDraft(id: 9, description: "Pix da Ana", date: original.date, paymentTypeChosen: false)
        org.docNumber = ""
        let o = org.toOrganizeDTO(id: 9, original: original)
        #expect(o.docNumber == "")        // tinha texto: vai vazio para apagar
        #expect(o.details == nil)         // já era vazio: fica de fora
        #expect(o.paymentType == nil)     // a pessoa não escolheu
    }
}
