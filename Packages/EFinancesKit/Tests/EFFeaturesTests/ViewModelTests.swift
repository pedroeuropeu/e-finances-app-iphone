import Testing
import Foundation
@testable import EFCore
@testable import EFData
@testable import EFFeatures

/// Estado das telas sobre o modo demonstração (mesmos dados do protótipo), com o relógio parado em 11/10/2026.
@MainActor
struct Env {
    let clock = FixedClock(LocalDate(2026, 10, 11))
    let defaults: UserDefaults
    let app: AppModel

    init() {
        let suite = "ef-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        app = AppModel(repos: .demo(storage: MemoryTokenStorage(), clock: clock), clock: clock, settings: SettingsStore(defaults: defaults),
                       demo: true, envLabel: "Demonstração", webURL: URL(string: "https://efinances.top/")!)
    }

    /// Entra como no app (tela de login).
    func login() async {
        await app.start(deviceLockAvailable: false)
        let vm = LoginViewModel(app: app)
        vm.password = "qualquer"
        await vm.submit()
    }

    var month: YearMonth { YearMonth(2026, 10) }
}

/// Espera algo que acontece numa Task (ex.: a exclusão adiada indo ao servidor).
@MainActor
func eventually(_ timeout: Double = 3, _ condition: @MainActor () async -> Bool) async -> Bool {
    let end = Date().addingTimeInterval(timeout)
    while Date() < end {
        if await condition() { return true }
        try? await Task.sleep(nanoseconds: 50_000_000)
    }
    return await condition()
}

@Suite("Sessão, login e bloqueio")
@MainActor
struct SessionTests {
    @Test func loginValidatesAndLoadsTheWorkspace() async {
        let env = Env()
        await env.app.start(deviceLockAvailable: false)
        #expect(env.app.ready)
        #expect(!env.app.session.isLoggedIn)

        let vm = LoginViewModel(app: env.app)
        #expect(vm.email == "demo@efinances.top")
        await vm.submit()
        #expect(vm.passwordError == "Digite sua senha")

        vm.email = "sem-arroba"
        vm.password = "x"
        await vm.submit()
        #expect(vm.emailError == "Digite um e-mail válido")

        vm.email = "demo@efinances.top"
        await vm.submit()
        #expect(env.app.session == .loggedIn(email: "demo@efinances.top"))
        #expect(env.app.workspace?.company?.name == "Casa")
        #expect(env.app.profile != nil)
        #expect(env.app.settings.onboardingDone)
        #expect(env.app.settings.lastEmail == "demo@efinances.top")
        #expect(vm.password.isEmpty)
    }

    @Test func logoutClearsEverything() async {
        let env = Env()
        await env.login()
        await env.app.logout()
        #expect(env.app.session == .loggedOut(.user))
        #expect(env.app.workspace == nil)
        #expect(env.app.profile == nil)
    }

    @Test func expiredSessionGoesBackToLoginWithANotice() async {
        let env = Env()
        await env.login()
        env.app.sessionExpired()
        #expect(env.app.session == .loggedOut(.expired))
        #expect(env.app.messenger.current?.text == "Sua sessão terminou. Entre de novo.")
    }

    @Test func locksAfterTheChosenTimeInBackground() async {
        let env = Env()
        await env.login()
        env.app.settings.lockEnabled = true

        env.app.settings.lockTimeoutMinutes = 5
        env.app.didEnterBackground()
        env.app.didBecomeActive(deviceLockAvailable: true)
        #expect(!env.app.locked, "o relógio parado não passa dos 5 minutos")

        env.app.settings.lockTimeoutMinutes = 0
        env.app.didEnterBackground()
        env.app.didBecomeActive(deviceLockAvailable: false)
        #expect(!env.app.locked, "sem código no iPhone não bloqueia")

        env.app.didEnterBackground()
        env.app.didBecomeActive(deviceLockAvailable: true)
        #expect(env.app.locked)
        env.app.unlock()
        #expect(!env.app.locked)
    }

    @Test func opensLockedWhenThereIsASavedSession() async {
        let env = Env()
        await env.login()
        env.app.settings.lockEnabled = true
        let again = AppModel(repos: env.app.repos, clock: env.clock, settings: env.app.settings, demo: true, envLabel: "", webURL: env.app.webURL)
        await again.start(deviceLockAvailable: true)
        #expect(again.session.isLoggedIn)
        #expect(again.locked)
    }

    @Test func hideOnOpenHidesValuesAtLaunch() {
        let suite = "ef-hide-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        let s = SettingsStore(defaults: d)
        s.hideOnOpen = true
        s.hideValues = false
        #expect(SettingsStore(defaults: d).hideValues)
        d.removePersistentDomain(forName: suite)
    }
}

@Suite("Avisos com Desfazer")
@MainActor
struct MessengerTests {
    @Test func aNewMessageCommitsThePendingDeletion() async {
        let m = Messenger()
        var committed = false
        var undone = false
        m.deferred("Lançamento excluído", undo: { undone = true }, commit: { committed = true; return .success(()) })
        m.show("Outro aviso")
        #expect(m.current?.text == "Outro aviso")
        #expect(await eventually { committed })
        #expect(!undone)
    }

    @Test func undoRestoresAndNeverCommits() async {
        let m = Messenger()
        var committed = false
        var undone = false
        m.deferred("Lançamento excluído", undo: { undone = true }, commit: { committed = true; return .success(()) })
        m.act()
        #expect(m.current == nil)
        #expect(await eventually { undone })
        #expect(!committed)
    }

    @Test func failedCommitUndoesAndShowsTheError() async {
        let m = Messenger()
        var undone = false
        m.deferred("Lançamento excluído", undo: { undone = true }, commit: { .failure(.validation("Não deu")) })
        m.flush()
        #expect(await eventually { undone && m.current?.text == "Não deu" })
    }
}

@Suite("Início e transações")
@MainActor
struct TransactionsTests {
    @Test func homeShowsTheMonthSummary() async throws {
        let env = Env()
        await env.login()
        let vm = HomeViewModel(app: env.app)
        await vm.load()
        let d = try #require(vm.state.value)
        #expect(d.month == env.month)
        #expect(d.late.contains { $0.description == "Condomínio" })
        #expect(d.balance == env.app.account?.balance)
        #expect(d.forecast == forecast(balance: d.balance, totals: d.totals))
        #expect(!d.categories.isEmpty)
        #expect(d.story != nil)
    }

    @Test func filtersByStatusAndSearch() async {
        let env = Env()
        await env.login()
        let vm = TransactionsViewModel(app: env.app)
        await vm.load()
        #expect(!vm.all.isEmpty)
        vm.toggleStatus(.late)
        #expect(!vm.filtered.isEmpty)
        #expect(vm.filtered.allSatisfy { $0.dueStatus(today: env.clock.today()).isLate })
        vm.clearFilters()
        vm.filters.query = "condominio"
        #expect(vm.filtered.map(\.description) == ["Condomínio"])
    }

    @Test func payWithUndo() async throws {
        let env = Env()
        await env.login()
        let vm = TransactionsViewModel(app: env.app)
        await vm.load()
        let condo = try #require(vm.all.first { $0.description == "Condomínio" })
        await vm.togglePaid(condo)
        #expect(vm.all.first { $0.id == condo.id }?.paid == true)
        #expect(env.app.messenger.current?.text == "Marcado como pago")
        env.app.messenger.act()
        #expect(vm.all.first { $0.id == condo.id }?.paid == false)
        #expect(await eventually { await env.app.repos.transactions.month(env.month).value?.first { $0.id == condo.id }?.paid == false })
    }

    @Test func deleteLeavesTheListAtOnceAndUndoBringsItBack() async throws {
        let env = Env()
        await env.login()
        let vm = TransactionsViewModel(app: env.app)
        await vm.load()
        let t = try #require(vm.all.first { !$0.hasScope })
        await vm.delete([t])
        #expect(!vm.all.contains { $0.id == t.id })
        #expect(env.app.messenger.current?.text == "Lançamento excluído")
        env.app.messenger.act()
        #expect(await eventually { vm.all.contains { $0.id == t.id } })

        await vm.delete([t])
        env.app.messenger.dismiss()
        #expect(await eventually { await env.app.repos.transactions.month(env.month).value?.contains { $0.id == t.id } == false })
    }

    @Test func installmentsPutTheLeftoverCentsInTheFirst() async throws {
        let env = Env()
        await env.login()
        let vm = TransactionFormViewModel(app: env.app, type: .variable)
        await vm.load()
        vm.draft.description = "Cadeira"
        vm.key("1"); vm.key("00"); vm.key("00")
        #expect(vm.draft.cents == 10000)
        vm.draft.paymentMode = .installments
        vm.setInstallments(3)
        let plan = try #require(vm.plan)
        #expect(plan.values == [Decimal(string: "33.34")!, Decimal(string: "33.33")!, Decimal(string: "33.33")!])
        let version = env.app.dataVersion
        await vm.save()
        #expect(vm.saved)
        #expect(env.app.dataVersion > version)
        #expect(env.app.messenger.current?.text == "3 parcelas lançadas")
        let next = await env.app.repos.transactions.month(env.month.plusMonths(1)).value ?? []
        #expect(next.contains { $0.description == "Cadeira" && $0.plot == "2/3" })
    }

    @Test func emptyFormPointsTheFields() async {
        let env = Env()
        await env.login()
        let vm = TransactionFormViewModel(app: env.app)
        await vm.save()
        #expect(vm.errors["value"] != nil)
        #expect(vm.errors["description"] != nil)
        #expect(!vm.saved)
        vm.draft.description = "Feira"
        #expect(vm.errors["description"] == nil, "o erro some enquanto a pessoa corrige")
    }

    @Test func editingARecurringAsksTheScope() async throws {
        let env = Env()
        await env.login()
        let list = await env.app.repos.transactions.month(env.month).value ?? []
        let netflix = try #require(list.first { $0.description == "Netflix" })
        let vm = TransactionFormViewModel(app: env.app, id: netflix.id, month: env.month)
        await vm.load()
        #expect(vm.recurringEdit)
        vm.draft.description = "Netflix Premium"
        await vm.save()
        #expect(vm.askScope)
        #expect(!vm.saved)
        await vm.save(scope: .this)
        #expect(vm.saved)
    }

    @Test func bankAccountOnlyOrganizes() async throws {
        let env = Env()
        await env.login()
        #expect(await env.app.select(companyId: 11, accountId: 13))
        #expect(env.app.mode == .connected)
        #expect(!env.app.canLaunch)
        let list = await env.app.repos.transactions.month(env.month).value ?? []
        let t = try #require(list.first)
        let vm = TransactionFormViewModel(app: env.app, id: t.id, month: env.month)
        #expect(vm.organizeOnly)
    }
}

@Suite("Planejar, relatórios e avisos")
@MainActor
struct PlanningTests {
    @Test func deletingALimitCanBeUndone() async throws {
        let env = Env()
        await env.login()
        let vm = PlanningViewModel(app: env.app)
        await vm.load()
        let item = try #require(vm.state.value?.limits?.items.first)
        vm.deleteLimit(item.id)
        #expect(vm.state.value?.limits?.items.contains { $0.id == item.id } == false)
        env.app.messenger.act()
        #expect(await eventually { vm.state.value?.limits?.items.contains { $0.id == item.id } == true })
    }

    @Test func contactKindComposition() async throws {
        let env = Env()
        await env.login()
        let vm = ReportsViewModel(app: env.app)
        await vm.load()
        vm.dimension = .contactKind
        #expect(!vm.composition.isEmpty)
        #expect(vm.composition.reduce(0) { $0 + $1.percent } >= 98)
    }

    @Test func notificationLinksOpenTheRightScreen() {
        func n(_ link: String?, _ c: NotificationCategory = .system) -> AppNotification {
            AppNotification(id: 1, category: c, severity: .info, title: "", body: "", link: link, createdAt: nil, read: false)
        }
        #expect(NotificationsViewModel.destination(n("/finances/limits")) == .limits)
        #expect(NotificationsViewModel.destination(n("/story")) == .story)
        #expect(NotificationsViewModel.destination(n("/support/ticket/3")) == .support)
        #expect(NotificationsViewModel.destination(n("/finances/transactions")) == .transactions)
        #expect(NotificationsViewModel.destination(n(nil, .security)) == .security)
        #expect(NotificationsViewModel.destination(n(nil)) == .none)
    }

    @Test func readingANotificationLowersTheBadge() async throws {
        let env = Env()
        await env.login()
        let vm = NotificationsViewModel(app: env.app)
        await vm.load()
        let before = env.app.unread
        let unread = try #require(vm.state.value?.first { !$0.read })
        await vm.open(unread)
        #expect(env.app.unread == before - 1)
        #expect(vm.state.value?.first { $0.id == unread.id }?.read == true)
    }
}

@Suite("Conta, suporte e depoimento")
@MainActor
struct AccountTests {
    @Test func accountDeletionBecomesATicketAndCanBeCancelled() async throws {
        let env = Env()
        await env.login()
        let vm = AccountDeletionViewModel(app: env.app)
        await vm.load()
        #expect(vm.pending == nil)
        vm.reasons = ["Preço"]
        #expect(await vm.request())
        let t = try #require(vm.pending)
        #expect(t.category == .accountDeletion)
        #expect(t.messages.first?.message.contains("Motivo: Preço.") == true)
        await vm.cancel()
        #expect(vm.pending == nil)
    }

    @Test func newTicketCarriesTheDevice() async throws {
        let env = Env()
        await env.login()
        let vm = NewTicketViewModel(app: env.app)
        #expect(!vm.canSend)
        vm.title = "Dúvida"
        vm.message = "Como exporto?"
        let t = try #require(await vm.send(deviceInfo: "iPhone17,1 · iOS 26.0 · app 1.0.0 (1)"))
        #expect(t.messages.first?.message.hasSuffix("— iPhone17,1 · iOS 26.0 · app 1.0.0 (1)") == true)
    }

    @Test func testimonialFollowsTheServerRules() async {
        let env = Env()
        await env.login()
        let vm = TestimonialViewModel(app: env.app)
        await vm.load()
        #expect(vm.mine == nil)
        vm.startEditing()
        #expect(vm.form.rating == 5)
        #expect(!vm.form.authorName.isEmpty)
        vm.form.text = "Curto"
        #expect(await vm.save() == false)
        #expect(vm.error == "Conte um pouco mais (pelo menos 20 caracteres).")
        vm.form.text = "Agora vejo tudo num lugar só e sei quanto posso gastar."
        #expect(await vm.save() == false)
        #expect(vm.error == "Para publicar, marque que você autoriza mostrar o depoimento no site.")
        vm.form.consent = true
        #expect(await vm.save())
        #expect(vm.mine?.status == .pending)
        await vm.withdraw()
        #expect(vm.mine == nil)
    }
}
