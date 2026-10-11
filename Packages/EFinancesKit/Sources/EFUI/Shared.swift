import SwiftUI
import EFCore
import EFFeatures

/// Cria o modelo da tela uma vez só (com o AppModel do ambiente) e entrega para o conteúdo.
struct Screen<VM: AnyObject, Content: View>: View {
    @Environment(AppModel.self) private var app
    @State private var vm: VM?
    let make: (AppModel) -> VM
    @ViewBuilder let content: (VM) -> Content

    init(_ make: @escaping (AppModel) -> VM, @ViewBuilder content: @escaping (VM) -> Content) { self.make = make; self.content = content }

    var body: some View {
        if let vm { content(vm) } else { Color.clear.onAppear { vm = make(app) } }
    }
}

/// Carregando, erro (com "Tentar de novo") ou o conteúdo.
struct LoadableContent<T, Content: View>: View {
    let state: Loadable<T>
    let retry: () async -> Void
    @ViewBuilder let content: (T) -> Content

    init(_ state: Loadable<T>, retry: @escaping () async -> Void, @ViewBuilder content: @escaping (T) -> Content) {
        self.state = state; self.retry = retry; self.content = content
    }

    var body: some View {
        switch state {
        case .loading: LoadingView()
        case .failed(let e): ErrorView(e, retry: retry)
        case .ready(let v): content(v)
        }
    }
}

extension AppModel {
    /// "Bom dia", "Boa tarde" ou "Boa noite".
    var greeting: String {
        let h = clock.localNow().hour
        return h < 5 ? "Boa noite" : h < 12 ? "Bom dia" : h < 18 ? "Boa tarde" : "Boa noite"
    }

    var today: LocalDate { clock.today() }
}

extension Array where Element == BankConnection {
    /// Conta do banco ligada a uma conta do e-Finances.
    func bankAccount(for ledgerId: Int64?) -> (BankConnection, BankAccount)? {
        guard let ledgerId else { return nil }
        for c in self { if let a = c.accounts.first(where: { $0.ledgerAccountId == ledgerId }) { return (c, a) } }
        return nil
    }
}

extension BankConnection {
    var updated: Bool { status == "UPDATED" && !needsUserAction }
    func updatedLabel(now: LocalDateTime) -> String {
        if !updated { return "precisa reconectar" }
        guard let at = lastSyncAt else { return "sem atualização" }
        return "atualizado \(DateFormats.ago(at, now: now))"
    }
}

// MARK: - empresa e conta

/// Botão do topo do Início: empresa e conta em uso.
struct WorkspaceButton: View {
    @Environment(AppModel.self) private var app
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 6) {
                if let a = app.account { AccountBadge(a, companyId: app.company?.id ?? 0, size: 24) }
                VStack(alignment: .leading, spacing: 0) {
                    Text(app.company?.name ?? "e-Finances").font(.subheadline.weight(.semibold)).foregroundStyle(Color.efInk)
                    Text(app.account?.name ?? "").font(.caption2).foregroundStyle(.secondary)
                }
                .lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: 200, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Empresa e conta: \(app.company?.name ?? ""), \(app.account?.name ?? "")")
        .accessibilityHint("Trocar de empresa ou conta")
        .sheet(isPresented: $open) { WorkspaceSheet() }
    }
}

/// Escolher a empresa e a conta (manuais, do banco e congeladas).
struct WorkspaceSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var connections: [BankConnection] = []
    @State private var choosing: Int64?

    var body: some View {
        NavigationStack {
            List {
                ForEach(app.workspace?.companies ?? []) { company in
                    Section("\(company.name) · \(company.typeLabel)") {
                        ForEach(company.accounts) { account in row(company, account) }
                    }
                }
                Section {
                    Button {
                        dismiss()
                        router.tab = .more
                        router.morePath = NavigationPath([Route.companies])
                    } label: { Label("Gerenciar empresas e contas", systemImage: "building.2") }
                } footer: {
                    Text("As contas do banco aparecem junto com as manuais. Nelas o app não lança: só organiza o que veio do banco.")
                }
            }
            .efGroupedList()
            .navigationTitle("Empresa e conta")
            .efLargeTitle(false)
            .toolbar { ToolbarItem(placement: .efTrailing) { Button("OK") { dismiss() }.fontWeight(.semibold) } }
            .task { connections = await app.repos.openFinance.connections().value ?? [] }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ company: Company, _ account: Account) -> some View {
        let on = app.company?.id == company.id && app.account?.id == account.id
        let bank = connections.bankAccount(for: account.id)
        let sub: String
        switch account.mode {
        case .connected: sub = "\(account.bankName ?? bank?.0.bankName ?? "Banco") · \(bank?.0.updatedLabel(now: app.clock.localNow()) ?? "do banco")"
        case .frozen: sub = "Congelada · só consulta"
        case .manual: sub = "\(account.currency) · \(plural(Int(account.transactions), "lançamento", "lançamentos"))\(account.defaultAccount ? " · padrão" : "")"
        }
        let value = bank.map { $0.1.headline } ?? account.balance
        return Button {
            choosing = account.id
            Task {
                let ok = await app.select(companyId: company.id, accountId: account.id)
                choosing = nil
                if ok { dismiss() }
            }
        } label: {
            HStack(spacing: 12) {
                AccountBadge(account, companyId: company.id)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name).foregroundStyle(Color.efInk).lineLimit(1)
                    Text(sub).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 0) {
                    MoneyText(value, currency: account.currency, font: .subheadline.weight(.medium))
                    if bank?.1.kind == .credit { Text("fatura").font(.caption2).foregroundStyle(.secondary) }
                }
                Group {
                    if choosing == account.id { ProgressView() }
                    else if on { Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.efTint) }
                    else { Color.clear }
                }
                .frame(width: 22)
            }
        }
        .disabled(choosing != nil)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - botão de novo lançamento

/// "+" do topo: recebimento, despesa fixa ou variável (só em conta manual).
struct NewTransactionMenu: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    var month: YearMonth?

    var body: some View {
        if app.canLaunch {
            Menu {
                Button { router.newTransaction(.income, month: month) } label: { Label("Recebimento", systemImage: "arrow.down.left") }
                Button { router.newTransaction(.fixed, month: month) } label: { Label("Despesa fixa", systemImage: "repeat") }
                Button { router.newTransaction(.variable, month: month) } label: { Label("Despesa variável", systemImage: "arrow.up.right") }
            } label: {
                Image(systemName: "plus").fontWeight(.semibold)
            } primaryAction: {
                router.newTransaction(.variable, month: month)
            }
            .accessibilityLabel("Novo lançamento")
            .accessibilityHint("Toque para nova despesa; toque e segure para escolher o tipo")
        }
    }
}

/// Faixa de aviso (conta do banco, congelada, sem conexão).
struct NoticeBanner: View {
    let symbol: String
    let title: String
    let text: String
    var color: Color = .efInfo
    var action: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundStyle(color).frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let action, let onAction {
                    Button(action, action: onAction).font(.footnote.weight(.semibold)).buttonStyle(.bordered).buttonBorderShape(.capsule).tint(color).padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - datas nos seletores do sistema

extension LocalDate {
    /// Meio-dia local (evita pular de dia com horário de verão).
    var date: Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 12
        return Calendar(identifier: .gregorian).date(from: c) ?? Date()
    }

    init(_ date: Date) {
        let c = Calendar(identifier: .gregorian).dateComponents(in: .current, from: date)
        self.init(c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }
}

extension Binding where Value == LocalDate {
    /// Para o DatePicker.
    var asDate: Binding<Date> { Binding<Date>(get: { wrappedValue.date }, set: { wrappedValue = LocalDate($0) }) }
}
