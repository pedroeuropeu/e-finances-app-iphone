import Foundation
import Observation
import EFCore

// MARK: - Contatos

public struct ContactsData: Sendable {
    public var contacts: [ContactDetails]
    public var debts: ContactDebts?
}

@MainActor @Observable
public final class ContactsViewModel {
    public private(set) var state: Loadable<ContactsData> = .loading
    public var filter: ContactCategory?
    public var query = ""
    public private(set) var saving = false
    private let app: AppModel

    public init(app: AppModel) { self.app = app }

    public var currency: String { app.currency }

    public var filtered: [ContactDetails] {
        (state.value?.contacts ?? []).filter { c in
            (filter == nil || c.contact.category == filter) && (query.isEmpty || c.contact.name.normalizedForSearch.contains(query.normalizedForSearch))
        }
    }

    public func load() async {
        async let c = app.repos.registry.contacts(nil)
        async let d = app.repos.registry.contactDebts()
        let contacts = await c
        let debts = await d.value
        state = state.keeping(contacts.map { ContactsData(contacts: $0, debts: debts) })
    }

    /// Sucesso que se vê (a folha fecha e a lista muda) não avisa, como na web; erro aparece.
    public func save(_ input: ContactInput) async -> Bool {
        if input.name.trimmingCharacters(in: .whitespaces).isEmpty { app.messenger.show("Digite o nome do contato.", icon: "exclamationmark.circle"); return false }
        saving = true
        defer { saving = false }
        switch await app.repos.registry.saveContact(input) {
        case .success: await load(); return true
        case .failure(let e): app.messenger.show(e.message, icon: "exclamationmark.circle"); return false
        }
    }

    /// Exclui na hora (o servidor recusa se houver lançamentos) e o "Desfazer" restaura.
    public func delete(_ c: Contact) async -> Bool {
        saving = true
        defer { saving = false }
        switch await app.repos.registry.deleteContact(c.id) {
        case .success:
            app.messenger.undoable("“\(c.name)” excluído", restore: { [app] in await app.repos.registry.restoreContact(c.id) }, onRestored: { [weak self] in Task { await self?.load() } })
            await load()
            return true
        case .failure(let e):
            app.messenger.show(e.message, icon: "exclamationmark.circle")
            return false
        }
    }
}

// MARK: - Categorias

public enum CategoryFilter: String, CaseIterable, Sendable {
    case all, own, defaults, subscriptions, withLimit
    public var label: String {
        switch self { case .all: "Todas"; case .own: "Suas"; case .defaults: "Padrão"; case .subscriptions: "Assinaturas"; case .withLimit: "Com limite" }
    }
}

/// Formulário da categoria: nome, aparência, "é assinatura" e o limite do mês.
public struct CategoryForm: Equatable, Sendable {
    public var id: Int64?
    public var name = ""
    public var description = ""
    public var subscription = false
    public var brand: String?
    public var icon: String? = "pi-tag"
    public var color: String? = "#6366F1"
    public var logo: String?
    /// Texto do limite (vazio = sem limite).
    public var limit = ""
    public var alertPercent = 80

    public init() {}

    public init(_ v: CategoryView) {
        id = v.category.id
        name = v.category.name
        description = v.category.description ?? ""
        subscription = v.category.subscription
        brand = v.category.brand
        icon = v.category.icon
        color = v.category.color
        logo = v.category.logo
        limit = v.limit.map { "\($0)".replacingOccurrences(of: ".", with: ",") } ?? ""
        alertPercent = v.alertPercent
    }

    public var look: TransactionCategory { TransactionCategory(id: id ?? 0, name: name, subscription: subscription, brand: brand, icon: icon, color: color, logo: logo) }
}

/// "1.234,56" ou "1234.56" → 1234.56 (nil se não for número).
public func parseAmount(_ s: String) -> Decimal? {
    let t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "R$", with: "").trimmingCharacters(in: .whitespaces)
    guard !t.isEmpty else { return nil }
    let normalized = t.contains(",") ? t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") : t
    guard normalized.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" }) else { return nil }
    return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
}

@MainActor @Observable
public final class CategoriesViewModel {
    public private(set) var month: YearMonth
    public private(set) var state: Loadable<CategoryOverview> = .loading
    public private(set) var subscriptions: Subscriptions?
    public var filter: CategoryFilter = .all
    public var query = ""
    public private(set) var saving = false
    private let app: AppModel

    public init(app: AppModel, filter: CategoryFilter = .all) {
        self.app = app
        self.filter = filter
        month = app.clock.currentMonth()
    }

    public var currency: String { state.value?.currency ?? app.currency }
    public var accountName: String { app.account?.name ?? "" }

    public var filtered: [CategoryView] {
        (state.value?.categories ?? []).filter { v in
            let ok: Bool
            switch filter {
            case .all: ok = true
            case .own: ok = !v.category.systemDefault
            case .defaults: ok = v.category.systemDefault
            case .subscriptions: ok = v.category.subscription
            case .withLimit: ok = v.limit != nil
            }
            return ok && (query.isEmpty || v.category.name.normalizedForSearch.contains(query.normalizedForSearch))
        }
    }

    public func count(_ f: CategoryFilter) -> Int {
        guard let o = state.value else { return 0 }
        switch f { case .all: return o.categories.count; case .own: return o.own; case .defaults: return o.defaults; case .subscriptions: return o.subscriptions; case .withLimit: return o.withLimit }
    }

    public func load() async {
        let m = month
        async let o = app.repos.registry.categoryOverview(m)
        async let s = app.repos.transactions.subscriptions()
        let r = await o
        guard m == month else { return }
        state = state.keeping(r)
        subscriptions = await s.value ?? subscriptions
    }

    public func changeMonth(_ delta: Int) async { month = month.plusMonths(delta); state = .loading; await load() }

    /// Salva a categoria (se não for padrão) e depois o limite do mês: cria/atualiza, remove (vazio) ou deixa como está.
    public func save(_ form: CategoryForm, editing: CategoryView?) async -> Bool {
        let limit = parseAmount(form.limit)
        let systemDefault = editing?.category.systemDefault == true
        if !systemDefault && form.name.trimmingCharacters(in: .whitespaces).isEmpty { app.messenger.show("Dê um nome à categoria.", icon: "exclamationmark.circle"); return false }
        if !form.limit.trimmingCharacters(in: .whitespaces).isEmpty && (limit == nil || limit! < 0) { app.messenger.show("O limite precisa ser um valor positivo.", icon: "exclamationmark.circle"); return false }
        saving = true
        defer { saving = false }
        var categoryId: Int64? = editing?.category.id
        if !systemDefault {
            switch await app.repos.registry.saveCategory(CategoryInput(id: form.id, name: form.name, description: form.description, subscription: form.subscription,
                                                                       brand: form.brand, icon: form.icon, color: form.color, logo: form.logo)) {
            case .success(let c): categoryId = c.id
            case .failure(let e): app.messenger.show(e.message, icon: "exclamationmark.circle"); return false
            }
        }
        guard let id = categoryId else { return false }
        let current = editing?.limitId
        let limitResult: Outcome<Void>
        if limit == nil || limit == 0 {
            if let current { limitResult = await app.repos.planning.deleteLimit(current) } else { limitResult = .success(()) }
        } else if current != nil && limit == editing?.limit && form.alertPercent == editing?.alertPercent {
            limitResult = .success(())
        } else {
            limitResult = await app.repos.planning.saveLimit(categoryId: id, monthlyLimit: limit!, alertPercent: form.alertPercent)
        }
        if case .failure(let e) = limitResult { app.messenger.show("Categoria salva, mas o limite não: \(e.message)", icon: "exclamationmark.circle") }
        app.transactionsChanged()
        await load()
        return true
    }

    /// Exclui na hora (o servidor recusa se houver lançamentos) e o "Desfazer" restaura.
    public func delete(_ c: TransactionCategory) async -> Bool {
        saving = true
        defer { saving = false }
        switch await app.repos.registry.deleteCategory(c.id) {
        case .success:
            app.messenger.undoable("“\(c.name)” excluída", restore: { [app] in await app.repos.registry.restoreCategory(c.id) }, onRestored: { [weak self] in Task { await self?.load() } })
            await load()
            return true
        case .failure(let e):
            app.messenger.show(e.message, icon: "exclamationmark.circle")
            return false
        }
    }
}

// MARK: - Centros de custo

public struct CostCentersData: Sendable {
    public var centers: [CostCenter]
    public var usage: [Int64: CostCenterUsage]
}

@MainActor @Observable
public final class CostCentersViewModel {
    public private(set) var month: YearMonth
    public private(set) var state: Loadable<CostCentersData> = .loading
    public var showDefaults = false
    public private(set) var saving = false
    private let app: AppModel

    public init(app: AppModel) { self.app = app; month = app.clock.currentMonth() }

    public var currency: String { app.currency }

    public func load() async {
        let m = month
        async let c = app.repos.registry.costCenters()
        async let u = app.repos.registry.costCenterUsage(start: m.firstDay, end: m.lastDay)
        let centers = await c
        let usage = Dictionary((await u.value ?? []).map { ($0.costCenterId, $0) }, uniquingKeysWith: { a, _ in a })
        guard m == month else { return }
        state = state.keeping(centers.map { CostCentersData(centers: $0, usage: usage) })
    }

    public func changeMonth(_ delta: Int) async { month = month.plusMonths(delta); await load() }

    public func save(_ input: CostCenterInput) async -> Bool {
        if input.name.trimmingCharacters(in: .whitespaces).isEmpty { app.messenger.show("Dê um nome ao centro de custo.", icon: "exclamationmark.circle"); return false }
        saving = true
        defer { saving = false }
        switch await app.repos.registry.saveCostCenter(input) {
        case .success: await load(); return true
        case .failure(let e): app.messenger.show(e.message, icon: "exclamationmark.circle"); return false
        }
    }

    public func delete(_ c: CostCenter) async -> Bool {
        saving = true
        defer { saving = false }
        switch await app.repos.registry.deleteCostCenter(c.id) {
        case .success:
            app.messenger.undoable("“\(c.name)” excluído", restore: { [app] in await app.repos.registry.restoreCostCenter(c.id) }, onRestored: { [weak self] in Task { await self?.load() } })
            await load()
            return true
        case .failure(let e):
            app.messenger.show(e.message, icon: "exclamationmark.circle")
            return false
        }
    }
}

// MARK: - Empresas e contas

@MainActor @Observable
public final class CompaniesViewModel {
    public private(set) var state: Loadable<Workspace> = .loading
    public private(set) var saving = false
    private let app: AppModel

    public init(app: AppModel) { self.app = app }

    public var inUse: Int64? { app.account?.id }

    public func load() async { state = state.keeping(await app.repos.companies.overview()) }

    private func run(_ success: String, _ block: () async -> Outcome<Void>) async -> Bool {
        saving = true
        defer { saving = false }
        switch await block() {
        case .success:
            app.messenger.show(success, icon: "checkmark.circle")
            await app.refreshWorkspace()
            await load()
            return true
        case .failure(let e):
            app.messenger.show(e.message, icon: "exclamationmark.circle")
            return false
        }
    }

    public func use(_ company: Company, _ account: Account) async {
        if await app.select(companyId: company.id, accountId: account.id) { await load() }
    }

    public func setDefault(_ a: Account) async -> Bool { await run("\(a.name) agora é a conta padrão") { await app.repos.companies.setDefaultAccount(a.id) } }
    public func createCompany(_ c: CompanyInput, firstAccount: AccountInput) async -> Bool { await run("Empresa criada") { await app.repos.companies.createCompany(c, firstAccount: firstAccount) } }
    public func updateCompany(_ c: CompanyInput) async -> Bool { await run("Empresa atualizada") { await app.repos.companies.updateCompany(c) } }
    public func deleteCompany(_ id: Int64) async -> Bool { await run("Empresa excluída") { await app.repos.companies.deleteCompany(id) } }
    public func saveAccount(_ a: AccountInput) async -> Bool { await run(a.id == nil ? "Conta criada" : "Conta atualizada") { await app.repos.companies.saveAccount(a) } }
    public func deleteAccount(_ id: Int64) async -> Bool { await run("Conta excluída") { await app.repos.companies.deleteAccount(id) } }
}

// MARK: - Plano e faturas (só leitura na 1ª versão)

@MainActor @Observable
public final class BillingViewModel {
    public private(set) var state: Loadable<BillingOverview> = .loading
    private let app: AppModel
    public init(app: AppModel) { self.app = app }
    public func load() async { state = state.keeping(await app.repos.billing.overview()) }
}

// MARK: - Ajuda e suporte

@MainActor @Observable
public final class SupportViewModel {
    public let content = HelpContent.shared
    public private(set) var tickets: Loadable<[Ticket]> = .loading
    public private(set) var counts = TicketCounts(open: 0, closed: 0, unread: 0)
    public private(set) var group: TicketGroup = .open
    public var query = ""
    private let app: AppModel

    public init(app: AppModel) { self.app = app }

    public var results: [HelpArticle] { content.search(query) }

    public func load() async {
        let g = group
        async let t = app.repos.support.tickets(g)
        async let c = app.repos.support.counts()
        let r = await t
        if let cc = await c.value { counts = cc }
        guard g == group else { return }
        tickets = tickets.keeping(r)
    }

    public func setGroup(_ g: TicketGroup) async { group = g; tickets = .loading; await load() }
}

@MainActor @Observable
public final class TicketViewModel {
    public private(set) var state: Loadable<Ticket> = .loading
    public private(set) var sending = false
    public let id: Int64
    private let app: AppModel

    public init(app: AppModel, id: Int64) { self.app = app; self.id = id }

    public func load() async { state = state.keeping(await app.repos.support.ticket(id)) }

    public func reply(_ text: String) async -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        sending = true
        defer { sending = false }
        switch await app.repos.support.reply(id, message: text) {
        case .success(let t): state = .ready(t); return true
        case .failure(let e): app.messenger.show(e.message, icon: "exclamationmark.circle"); return false
        }
    }

    public func close(solved: Bool) async {
        switch await app.repos.support.close(id, solved: solved) {
        case .success: app.messenger.show(solved ? "Chamado encerrado como resolvido" : "Chamado encerrado", icon: "checkmark.circle"); await load()
        case .failure(let e): app.messenger.show(e.message, icon: "exclamationmark.circle")
        }
    }

    public func reopen() async {
        switch await app.repos.support.reopen(id) {
        case .success: app.messenger.show("Chamado reaberto", icon: "arrow.uturn.backward"); await load()
        case .failure(let e): app.messenger.show(e.message, icon: "exclamationmark.circle")
        }
    }
}

@MainActor @Observable
public final class NewTicketViewModel {
    public var category: TicketCategory = .question
    public var title = ""
    public var message = ""
    public private(set) var sending = false
    private let app: AppModel

    public init(app: AppModel, category: TicketCategory = .question, title: String = "", message: String = "") {
        self.app = app; self.category = category; self.title = title; self.message = message
    }

    public var canSend: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !sending }

    /// Abre o chamado. O app manda junto o modelo do iPhone e a versão (no fim da mensagem) para agilizar.
    public func send(deviceInfo: String) async -> Ticket? {
        guard canSend else { return nil }
        sending = true
        defer { sending = false }
        let body = message.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n— \(deviceInfo)"
        switch await app.repos.support.create(category: category, title: title, message: body) {
        case .success(let t):
            app.messenger.show("Chamado \(t.protocolNumber) aberto. Respondemos por aqui e por e-mail.", icon: "checkmark.circle")
            return t
        case .failure(let e):
            app.messenger.show(e.message, icon: "exclamationmark.circle")
            return nil
        }
    }
}

/// Exclusão da conta pedida no app (exigência da App Store): vira o chamado "Exclusão de conta", como na web.
@MainActor @Observable
public final class AccountDeletionViewModel {
    public private(set) var pending: Ticket?
    public private(set) var loading = true
    public private(set) var sending = false
    public var reasons: Set<String> = []
    public var note = ""
    private let app: AppModel

    public static let reasonOptions = ["Não uso mais", "Achei difícil de usar", "Falta algum recurso", "Preço", "Outro"]

    public init(app: AppModel) { self.app = app }

    public var email: String { app.profile?.email ?? app.settings.lastEmail }

    public func load() async {
        loading = true
        defer { loading = false }
        pending = await app.repos.support.tickets(.open).value?.first { $0.isDeletionRequest }
    }

    public func request() async -> Bool {
        sending = true
        defer { sending = false }
        var lines = ["Quero excluir a minha conta do e-Finances (\(email))."]
        if !reasons.isEmpty { lines.append("Motivo: \(reasons.sorted().joined(separator: ", ")).") }
        if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { lines.append(note.trimmingCharacters(in: .whitespacesAndNewlines)) }
        lines.append("Pedido feito pelo app iPhone.")
        switch await app.repos.support.create(category: .accountDeletion, title: "Excluir minha conta", message: lines.joined(separator: "\n")) {
        case .success(let t):
            pending = t
            app.messenger.show("Pedido de exclusão enviado", icon: "checkmark.circle")
            return true
        case .failure(let e):
            app.messenger.show(e.message, icon: "exclamationmark.circle")
            return false
        }
    }

    public func cancel() async {
        guard let t = pending else { return }
        _ = await app.repos.support.reply(t.id, message: "Mudei de ideia: quero manter a minha conta.")
        switch await app.repos.support.close(t.id, solved: false) {
        case .success:
            pending = nil
            app.messenger.show("Pedido cancelado. Sua conta continua ativa.", icon: "arrow.uturn.backward")
        case .failure(let e): app.messenger.show(e.message, icon: "exclamationmark.circle")
        }
    }
}

// MARK: - Depoimento

/// "Está gostando? Deixe um depoimento": nota, texto, como aparece e a autorização. O admin aprova antes de ir ao site.
@MainActor @Observable
public final class TestimonialViewModel {
    public private(set) var mine: Testimonial?
    public private(set) var loaded = false
    public var form = Testimonial()
    public private(set) var saving = false
    public private(set) var error: String?
    private let app: AppModel

    public init(app: AppModel) { self.app = app }

    public func load() async {
        if case .success(let t) = await app.repos.support.myTestimonial() { mine = t }
        loaded = true
    }

    /// Abre o formulário com o depoimento atual ou com o nome da pessoa ("Ana S.").
    public func startEditing() {
        error = nil
        if let mine { form = mine; return }
        let first = app.profile?.firstName ?? ""
        let last = app.profile?.lastName.first.map { " \($0)." } ?? ""
        form = Testimonial(authorName: first + last, rating: 5)
    }

    public func save() async -> Bool {
        if let problem = form.validate() { error = problem; return false }
        error = nil
        saving = true
        defer { saving = false }
        switch await app.repos.support.saveTestimonial(form) {
        case .success(let t):
            mine = t
            app.messenger.show("Obrigado! A equipe vai revisar seu depoimento.", icon: "quote.bubble")
            return true
        case .failure(let e):
            error = e.message
            return false
        }
    }

    public func withdraw() async {
        switch await app.repos.support.withdrawTestimonial() {
        case .success:
            mine = nil
            app.messenger.show("Depoimento retirado", icon: "checkmark.circle")
        case .failure(let e): app.messenger.show(e.message, icon: "exclamationmark.circle")
        }
    }
}

// MARK: - Entrar, criar conta e esqueci a senha

public func isValidEmail(_ s: String) -> Bool {
    let t = s.trimmingCharacters(in: .whitespaces)
    guard let at = t.firstIndex(of: "@"), at != t.startIndex else { return false }
    let domain = t[t.index(after: at)...]
    return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".") && !t.contains(" ")
}

@MainActor @Observable
public final class LoginViewModel {
    public var email: String { didSet { emailError = nil; error = nil } }
    public var password = "" { didSet { passwordError = nil; error = nil } }
    public var remember = true
    public private(set) var loading = false
    public private(set) var emailError: String?
    public private(set) var passwordError: String?
    public private(set) var error: String?
    private let app: AppModel

    public init(app: AppModel) {
        self.app = app
        email = app.settings.lastEmail.isEmpty && app.demo ? "demo@efinances.top" : app.settings.lastEmail
    }

    public var isDemo: Bool { app.demo }
    public var envLabel: String { app.envLabel }

    public func submit() async {
        guard !loading else { return }
        emailError = isValidEmail(email) ? nil : "Digite um e-mail válido"
        passwordError = password.isEmpty ? "Digite sua senha" : nil
        guard emailError == nil, passwordError == nil else { return }
        loading = true
        defer { loading = false }
        switch await app.repos.auth.login(email: email, password: password, remember: remember) {
        case .success(let mail):
            password = ""
            app.settings.onboardingDone = true
            await app.didLogin(email: mail)
        case .failure(let e): error = e.message
        }
    }
}

@MainActor @Observable
public final class ForgotPasswordViewModel {
    public var email: String { didSet { error = nil } }
    public private(set) var loading = false
    public private(set) var sent = false
    public private(set) var error: String?
    private let app: AppModel

    public init(app: AppModel) { self.app = app; email = app.settings.lastEmail }

    public func submit() async {
        guard isValidEmail(email) else { error = "Digite um e-mail válido"; return }
        loading = true
        defer { loading = false }
        switch await app.repos.auth.forgotPassword(email: email) {
        case .success: sent = true
        case .failure(let e): error = e.message
        }
    }
}

public struct Country: Hashable, Sendable, Identifiable {
    public let code: String
    public let name: String
    public let currency: String
    public var id: String { code }
    public static let all = [Country(code: "BR", name: "Brasil", currency: "BRL"), Country(code: "PT", name: "Portugal", currency: "EUR"), Country(code: "US", name: "Estados Unidos", currency: "USD")]
}

@MainActor @Observable
public final class RegisterViewModel {
    public var firstName = ""
    public var lastName = ""
    public var email = ""
    public var companyName = "Casa"
    public var country = Country.all[0]
    public var terms = false
    public private(set) var errors: [String: String] = [:]
    public private(set) var error: String?
    public private(set) var loading = false
    public private(set) var done = false
    private let app: AppModel

    public init(app: AppModel) { self.app = app }

    public func submit() async {
        var e: [String: String] = [:]
        if firstName.trimmingCharacters(in: .whitespaces).isEmpty { e["firstName"] = "Digite seu nome" }
        if lastName.trimmingCharacters(in: .whitespaces).isEmpty { e["lastName"] = "Digite o sobrenome" }
        if !isValidEmail(email) { e["email"] = "Digite um e-mail válido" }
        if companyName.trimmingCharacters(in: .whitespaces).isEmpty { e["company"] = "Dê um nome, como Casa ou o nome da empresa" }
        if !terms { e["terms"] = "Aceite os termos para continuar" }
        errors = e
        error = nil
        guard e.isEmpty else { return }
        loading = true
        defer { loading = false }
        let data = RegisterData(firstName: firstName, lastName: lastName, email: email, companyName: companyName, countryCode: country.code,
                                countryName: country.name, currency: country.currency, termsAccepted: terms)
        switch await app.repos.auth.register(data) {
        case .success:
            app.settings.lastEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
            done = true
        case .failure(let err): error = err.message
        }
    }
}
