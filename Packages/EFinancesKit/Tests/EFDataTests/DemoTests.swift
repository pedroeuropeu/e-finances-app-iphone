import Testing
import Foundation
@testable import EFCore
@testable import EFData

@Suite("Modo demonstração")
struct DemoTests {
    let clock = FixedClock(LocalDate(2026, 10, 11))
    var month: YearMonth { YearMonth(2026, 10) }

    func repos() -> Repositories { .demo(storage: MemoryTokenStorage(), clock: clock) }

    @Test func loginWithAnyPassword() async {
        let r = repos()
        #expect(await r.auth.login(email: "", password: "", remember: true).error != nil)
        #expect(await r.auth.login(email: "", password: "x", remember: true).value == "demo@efinances.top")
        #expect(await r.auth.restore() == .loggedIn(email: "demo@efinances.top"))
    }

    @Test func monthMatchesThePrototype() async throws {
        let r = repos()
        let list = try #require(await r.transactions.month(month).value)
        let condo = try #require(list.first { $0.description == "Condomínio" })
        #expect(condo.dueStatus(today: clock.today()) == .late(days: 4))
        #expect(list.contains { $0.description == "Salário de outubro" && $0.paid })
        #expect(list.first { $0.description == "Notebook Dell" }?.plot == "3/10")
        let next = try #require(await r.transactions.month(month.plusMonths(1)).value)
        #expect(next.first { $0.description == "Notebook Dell" }?.plot == "4/10")
        #expect(next.allSatisfy { !$0.paid })
    }

    @Test func payingAdjustsTheBalance() async throws {
        let r = repos()
        let before = try #require(await r.workspaces.refresh().value?.account?.balance)
        let condo = try #require(await r.transactions.month(month).value?.first { $0.description == "Condomínio" })
        #expect(await r.transactions.setPaid(condo.id, paid: true).value != nil)
        let after = try #require(await r.workspaces.refresh().value?.account?.balance)
        #expect(after == before - 680)
    }

    @Test func deleteSeriesFromThisOneOn() async throws {
        let r = repos()
        let diarista = try #require(await r.transactions.month(month).value?.first { $0.description == "Diarista" })
        _ = await r.transactions.month(month.plusMonths(1))
        #expect(await r.transactions.delete(diarista.id, scope: .next).value != nil)
        #expect(await r.transactions.month(month).value?.contains { $0.description == "Diarista" } == false)
        #expect(await r.transactions.month(month.plusMonths(2)).value?.contains { $0.description == "Diarista" } == false)
        #expect(await r.transactions.month(month.minusMonths(1)).value?.contains { $0.description == "Diarista" } == true)
    }

    @Test func hiddenWhileUndoIsPending() async throws {
        let r = repos()
        let first = try #require(await r.transactions.month(month).value?.first)
        await r.transactions.hide([first.id])
        #expect(await r.transactions.month(month).value?.contains { $0.id == first.id } == false)
        await r.transactions.unhide([first.id])
        #expect(await r.transactions.month(month).value?.contains { $0.id == first.id } == true)
    }

    @Test func bankAccountOnlyOrganizes() async throws {
        let r = repos()
        _ = await r.workspaces.select(companyId: 1, accountId: 14)
        let list = try #require(await r.transactions.month(month).value)
        #expect(!list.isEmpty && list.allSatisfy(\.paid))
        let t = list[0]
        #expect(await r.transactions.setPaid(t.id, paid: false).error != nil)
        #expect(await r.transactions.delete(t.id, scope: .this).error != nil)
        #expect(await r.transactions.save(TransactionDraft(description: "x", cents: 100, date: clock.today()), scope: nil).error != nil)
        var d = TransactionDraft(id: t.id, description: "Netflix da família", cents: 0, date: t.date, paymentTypeChosen: false)
        d.newCategoryName = "Streaming"
        #expect(await r.transactions.organize(d).value != nil)
        let organized = try #require(await r.transactions.get(t.id, month: month).value)
        #expect(organized.description == "Netflix da família")
        #expect(organized.category?.name == "Streaming")
        #expect(organized.value == t.value)
    }

    @Test func frozenAccountIsReadOnly() async throws {
        let r = repos()
        _ = await r.workspaces.select(companyId: 2, accountId: 24)
        let ws = try #require(await r.workspaces.refresh().value)
        #expect(ws.mode == .frozen)
        let d = TransactionDraft(id: 1, description: "x", cents: 1, date: clock.today())
        #expect(await r.transactions.organize(d).error != nil)
    }

    @Test func installmentsSaveWithLeftoverInTheFirst() async throws {
        let r = repos()
        var d = TransactionDraft(type: .variable, description: "Sofá", cents: 10000, date: LocalDate(2026, 10, 31), paid: true, paymentMode: .installments, installments: 3)
        d.valueIsTotal = true
        let created = try #require(await r.transactions.save(d, scope: nil).value)
        #expect(created.map(\.plot) == ["1/3", "2/3", "3/3"])
        #expect(created.map(\.value) == [Decimal(string: "33.34")!, Decimal(string: "33.33")!, Decimal(string: "33.33")!])
        #expect(created.map(\.date) == [LocalDate(2026, 10, 31), LocalDate(2026, 11, 30), LocalDate(2026, 12, 31)])
        #expect(created.map(\.paid) == [true, false, false])
        #expect(await r.transactions.month(YearMonth(2026, 12)).value?.contains { $0.description == "Sofá" } == true)
    }

    @Test func seriesEndRemovesOpenOccurrencesAfterTheDate() async throws {
        let r = repos()
        let salary = try #require(await r.transactions.month(month).value?.first { $0.description.hasPrefix("Salário") })
        _ = await r.transactions.month(month.plusMonths(3))
        let info = try #require(await r.transactions.setSeriesEnd(salary.id, end: LocalDate(2026, 11, 30)).value ?? nil)
        #expect(info.endDate == LocalDate(2026, 11, 30))
        #expect(await r.transactions.month(month.plusMonths(2)).value?.contains { $0.description.hasPrefix("Salário") } == false)
        #expect(await r.transactions.month(month.plusMonths(1)).value?.contains { $0.description.hasPrefix("Salário") } == true)
    }

    @Test func disconnectFreezesAccounts() async throws {
        let r = repos()
        #expect(await r.openFinance.disconnect(1, removeAccounts: false, accountIds: [102]).value != nil)
        let ws = try #require(await r.workspaces.refresh().value)
        #expect(ws.companies[0].accounts.first { $0.id == 14 }?.mode == .frozen)
        let conns = try #require(await r.openFinance.connections().value)
        #expect(conns.first { $0.id == 1 }?.accounts.map(\.id) == [101])
        #expect(conns.first { $0.id == 1 }?.disconnectedAccounts == 1)
    }

    @Test func changeCompanyMovesBankAccounts() async throws {
        let r = repos()
        #expect(await r.openFinance.changeCompany(1, companyId: 2).value != nil)
        let ws = try #require(await r.workspaces.refresh().value)
        #expect(ws.companies[1].accounts.contains { $0.id == 13 })
        #expect(!ws.companies[0].accounts.contains { $0.id == 13 })
    }

    @Test func categoriesCanBeDeletedAndRestored() async throws {
        let r = repos()
        let created = try #require(await r.registry.saveCategory(CategoryInput(id: nil, name: "Viagens", icon: "pi-send", color: "#0EA5E9")).value)
        #expect(await r.registry.saveCategory(CategoryInput(id: nil, name: "viagens")).error != nil)
        #expect(await r.registry.deleteCategory(created.id).value != nil)
        #expect(await r.registry.restoreCategory(created.id).value != nil)
        #expect(await r.transactions.categories().value?.contains { $0.name == "Viagens" } == true)
        // padrão do sistema não muda
        #expect(await r.registry.deleteCategory(1).error != nil)
    }

    @Test func reportsAndDay() async throws {
        let r = repos()
        let o = try #require(await r.reports.overview(start: month.firstDay, end: month.lastDay, status: .all).value)
        #expect(o.current.income > 0)
        #expect(!o.days.isEmpty)
        #expect(!(o.breakdown[.contactKind] ?? []).isEmpty)
        let day = try #require(await r.reports.day(LocalDate(2026, 10, 7)).value)
        #expect(day.items.contains { $0.description == "Condomínio" })
        #expect(day.total == day.items.reduce(0) { $0 + $1.value })
    }

    @Test func storyAndSupport() async throws {
        let r = repos()
        let story = try #require(await r.stories.pending().value ?? nil)
        #expect(story.periodLabel == "setembro de 2026")
        await r.stories.markSeen(story.periodKey)
        #expect(await r.stories.pending().value ?? nil == nil)
        let t = try #require(await r.support.create(category: .accountDeletion, title: "Excluir minha conta", message: "Não uso mais").value)
        #expect(t.isDeletionRequest)
        #expect(await r.support.close(t.id, solved: false).value != nil)
        #expect(await r.support.tickets(.closed).value?.contains { $0.id == t.id } == true)
    }
}
