import SwiftUI
import EFCore
import EFFeatures

/// Bancos conectados pelo Open Finance (saldo, faturas, limite, situação) e as contas do e-Finances.
struct AccountsView: View {
    var body: some View {
        Screen(AccountsViewModel.init) { vm in AccountsContent(vm: vm) }
    }
}

private struct AccountsContent: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    let vm: AccountsViewModel
    @State private var connecting = false
    @State private var companyFor: BankConnection?
    @State private var disconnectFor: BankConnection?

    var body: some View {
        @Bindable var vm = vm
        LoadableContent(vm.state, retry: { await vm.load() }) { data in
            List {
                Section {
                    hero(data)
                    ForEach(data.connections.filter { !$0.updated }) { c in
                        NoticeBanner(symbol: "arrow.triangle.2.circlepath", title: "\(c.bankName) precisa de você",
                                     text: "A autorização expirou. Reconecte para voltar a sincronizar.", color: .efWarn,
                                     action: "Reconectar") { reconnect(c) }
                    }
                    if !data.connections.isEmpty {
                        Picker("Mostrar", selection: $vm.filter) {
                            ForEach(AccountKindFilter.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)

                ForEach(data.connections) { c in bankSection(c, data) }

                if data.connections.isEmpty {
                    Section {
                        Button { connecting = true } label: {
                            HStack(spacing: 12) {
                                IconBadge(symbol: "link", color: Color(hex: 0x059669), size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Conectar um banco").foregroundStyle(Color.efInk).font(.body.weight(.semibold))
                                    Text("Saldo e lançamentos entram sozinhos, só leitura.").font(.footnote).foregroundStyle(Color.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    ForEach(data.manualAccounts, id: \.1.id) { company, account in manualRow(company, account, data) }
                } header: {
                    HStack {
                        Text("Contas no e-Finances")
                        Spacer()
                        Button("Gerenciar") { router.push(.companies) }.font(.footnote.weight(.semibold)).textCase(nil)
                    }
                } footer: { Text("Manuais: aqui você lança.") }

                if !data.frozenAccounts.isEmpty {
                    Section {
                        ForEach(data.frozenAccounts, id: \.1.id) { company, account in manualRow(company, account, data) }
                    } header: { Text("Congeladas") } footer: { Text("Banco desconectado · só consulta.") }
                }

                if let s = data.subscriptions, !s.subscriptions.isEmpty {
                    Section {
                        Button { router.showPlanning(.subscriptions) } label: {
                            HStack(spacing: 12) {
                                SettingsIcon("repeat", Color(hex: 0xC026D3))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(plural(s.subscriptions.count, "assinatura", "assinaturas")).foregroundStyle(Color.efInk)
                                    HStack(spacing: 3) {
                                        MoneyText(s.monthlyTotal, currency: s.currency, font: .footnote, color: .secondary)
                                        Text("por mês, nos cartões e nos lançamentos").font(.footnote).foregroundStyle(Color.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.efTertiary)
                            }
                        }
                    }
                }

                Section {
                    EmptyView()
                } footer: {
                    Label("Somente leitura, pelo Open Finance. O e-Finances não movimenta seu dinheiro.", systemImage: "lock")
                        .frame(maxWidth: .infinity)
                }
            }
            .efGroupedList()
            .scrollContentBackground(.hidden)
            .refreshable { await vm.load() }
        }
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle("Contas")
        .efLargeTitle()
        .toolbar {
            ToolbarItemGroup(placement: .efTrailing) {
                if !(vm.state.value?.connections.isEmpty ?? true) {
                    Button { Task { await vm.syncAll() } } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                        .accessibilityLabel("Atualizar todos")
                }
                Button { app.toggleHide() } label: { Image(systemName: app.settings.hideValues ? "eye.slash" : "eye") }
                    .accessibilityLabel(app.settings.hideValues ? "Mostrar valores" : "Esconder valores")
                Button { connecting = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Conectar banco")
            }
        }
        .sheet(isPresented: $connecting) { ConnectBankSheet() }
        .sheet(item: $disconnectFor) { c in DisconnectSheet(connection: c, vm: vm).efToasts() }
        .confirmationDialog("Levar o \(companyFor?.bankName ?? "banco") para qual empresa?", isPresented: Binding(get: { companyFor != nil }, set: { if !$0 { companyFor = nil } }),
                            titleVisibility: .visible, presenting: companyFor) { c in
            ForEach(vm.state.value?.workspace?.companies ?? []) { co in
                Button(co.id == c.companyId ? "\(co.name) ✓" : co.name) { Task { _ = await vm.changeCompany(c, companyId: co.id) } }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { _ in Text("As contas do banco e os lançamentos vão junto.") }
        .task { if vm.state.value == nil { await vm.load() } }
        .onChange(of: app.workspaceVersion) { Task { await vm.load() } }
    }

    // MARK: topo

    private func hero(_ d: AccountsData) -> some View {
        let used = d.creditLimit - d.creditAvailable
        return HeroCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Saldo nos bancos conectados").font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.78))
                BigMoney(d.bankBalance).foregroundStyle(.white)
                Text("\(plural(d.connections.count, "banco", "bancos")) · \(plural(d.accountCount, "conta ou cartão", "contas e cartões"))")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                if d.creditLimit > 0 {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Faturas abertas", systemImage: "creditcard").font(.caption).foregroundStyle(.white.opacity(0.75))
                            MoneyText(d.invoices, font: .callout.weight(.semibold), color: .white)
                            ProgressBar((used / d.creditLimit).doubleValue, color: Color(hex: 0xFCA5A5), track: .white.opacity(0.2), height: 4)
                            Text("\(pct(used, d.creditLimit))% do limite usado").font(.caption2).foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Limite disponível", systemImage: "banknote").font(.caption).foregroundStyle(.white.opacity(0.75))
                            MoneyText(d.creditAvailable, font: .callout.weight(.semibold), color: .white)
                            ProgressBar((d.creditAvailable / d.creditLimit).doubleValue, color: .efGreen, track: .white.opacity(0.2), height: 4)
                            HStack(spacing: 3) {
                                Text("de").font(.caption2).foregroundStyle(.white.opacity(0.7))
                                MoneyText(d.creditLimit, font: .caption2, color: .white.opacity(0.7))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 10)
                }
            }
        }
    }

    // MARK: bancos

    @ViewBuilder private func bankSection(_ c: BankConnection, _ d: AccountsData) -> some View {
        let accounts = c.accounts.filter { vm.filter == .all || (vm.filter == .bank ? $0.kind == .bank : $0.kind == .credit) }
        if !accounts.isEmpty {
            Section {
                ForEach(accounts) { a in
                    NavigationLink(value: Route.bankAccount(a.id)) { bankRow(c, a, inUse: d.inUse(a.ledgerAccountId)) }
                }
            } header: {
                HStack(spacing: 10) {
                    BankBadge(name: c.bankName, logoUrl: c.imageUrl, color: c.color, size: 28)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(c.bankName).font(.headline).foregroundStyle(Color.efInk)
                        Text("em \(c.companyName ?? "—") · \(c.updatedLabel(now: d.now))").font(.caption)
                            .foregroundStyle(c.updated ? Color.secondary : Color.efWarn)
                    }
                    Spacer()
                    if vm.syncing.contains(c.id) { ProgressView() }
                    Menu {
                        if c.updated {
                            if let next = c.nextSyncAt { Text("Próxima atualização \(DateFormats.dayMonth(next.date)), \(DateFormats.time(next))") }
                            Button { Task { await vm.sync(c) } } label: { Label("Atualizar agora", systemImage: "arrow.triangle.2.circlepath") }
                        } else {
                            Text("A autorização expirou")
                            Button { reconnect(c) } label: { Label("Reconectar", systemImage: "arrow.triangle.2.circlepath") }
                        }
                        Button { companyFor = c } label: { Label("Mudar empresa", systemImage: "building.2") }
                        Divider()
                        Button(role: .destructive) { disconnectFor = c } label: { Label("Desconectar…", systemImage: "link.badge.plus") }
                    } label: {
                        Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(Color.efTint)
                    }
                    .accessibilityLabel("Opções do \(c.bankName)")
                }
                .textCase(nil)
                .padding(.bottom, 4)
            }
            .listRowBackground(Color.efSurface)
        }
    }

    private func bankRow(_ c: BankConnection, _ a: BankAccount, inUse: Bool) -> some View {
        HStack(spacing: 12) {
            IconBadge(symbol: a.kind == .credit ? "creditcard.fill" : "building.columns.fill", color: Color(hexString: c.color) ?? .efNavy, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(a.name).foregroundStyle(Color.efInk).lineLimit(1)
                    if inUse { Tag("Em uso", color: .efTint) }
                }
                if a.kind == .credit, let available = a.availableCredit {
                    Text("Disponível \(app.settings.hideValues ? Money.hidden : Money.format(available, currency: a.currency))")
                        .font(.footnote).foregroundStyle(Color.secondary).lineLimit(1).minimumScaleFactor(0.85)
                } else {
                    Text("Conta bancária").font(.footnote).foregroundStyle(Color.secondary)
                }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 0) {
                MoneyText(a.headline, currency: a.currency, font: .subheadline.weight(.medium))
                Text(a.kind == .credit ? "fatura" : "saldo").font(.caption2).foregroundStyle(Color.secondary)
            }
        }
    }

    private func manualRow(_ company: Company, _ account: Account, _ d: AccountsData) -> some View {
        Button {
            Task { if await vm.use(accountId: account.id) { router.open(.home) } }
        } label: {
            HStack(spacing: 12) {
                AccountBadge(account, companyId: company.id)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(account.name).foregroundStyle(Color.efInk).lineLimit(1)
                        if d.inUse(account.id) { Tag("Em uso", color: .efTint) }
                    }
                    Text("\(company.name) · \(plural(Int(account.transactions), "lançamento", "lançamentos"))").font(.footnote).foregroundStyle(Color.secondary)
                }
                Spacer(minLength: 6)
                MoneyText(account.balance, currency: account.currency, font: .subheadline.weight(.medium))
            }
        }
        .listRowBackground(Color.efSurface)
        .accessibilityHint(d.inUse(account.id) ? "" : "Passar a usar esta conta")
    }

    private func reconnect(_ c: BankConnection) {
        if app.demo {
            app.messenger.show("No modo demonstração não há banco de verdade para reconectar.", icon: "info.circle")
        } else {
            router.web = app.page("Reconectar \(c.bankName)", "open-finance")
        }
    }
}

// MARK: - conectar banco

/// Explica a conexão e abre a autorização (feita na web, pelo Open Finance).
struct ConnectBankSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        IconBadge(symbol: "link", color: Color(hex: 0x059669), size: 64)
                        Text("Traga seus bancos para o e-Finances").font(.sora(22, .semibold, relativeTo: .title2)).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                Section {
                    point("eye", "Somente leitura", "O e-Finances vê saldos e lançamentos. Nunca movimenta dinheiro.")
                    point("checkmark.shield", "Regulado pelo Banco Central", "Conexão pelo Open Finance.")
                    point("faceid", "Você autoriza no app do banco", "Escolha o banco e confirme lá, com a segurança do banco.")
                    point("link.badge.plus", "Cancele quando quiser", "Aqui no app ou no próprio banco.")
                }
                Section {
                    Button("Escolher banco") {
                        if app.demo {
                            app.messenger.show("No modo demonstração os bancos já vêm conectados.", icon: "info.circle")
                            dismiss()
                        } else {
                            dismiss()
                            router.web = app.page("Conectar banco", "open-finance")
                        }
                    }
                    .buttonStyle(.efGreen)
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                } footer: {
                    Text("A autorização abre a página segura do e-Finances. Ao terminar, volte para o app e puxe a tela para atualizar.")
                }
            }
            .efGroupedList()
            .navigationTitle("Conectar banco")
            .efLargeTitle(false)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private func point(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            SettingsIcon(symbol, Color(hex: 0x059669))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(Color.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - desconectar

/// Escolher as contas que saem e o que fazer com os lançamentos (congelar ou apagar).
struct DisconnectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let connection: BankConnection
    let vm: AccountsViewModel
    @State private var picked: Set<Int64>
    @State private var remove = false
    @State private var confirmRemove = false

    init(connection: BankConnection, vm: AccountsViewModel) {
        self.connection = connection
        self.vm = vm
        _picked = State(initialValue: Set(connection.accounts.map(\.id)))
    }

    var body: some View {
        let all = picked.count == connection.accounts.count
        NavigationStack {
            List {
                Section {
                    ForEach(connection.accounts) { a in
                        Button {
                            if picked.contains(a.id) { picked.remove(a.id) } else { picked.insert(a.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: picked.contains(a.id) ? "checkmark.circle.fill" : "circle").font(.title3)
                                    .foregroundStyle(picked.contains(a.id) ? Color.efTint : Color.secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(a.name).foregroundStyle(Color.efInk)
                                    HStack(spacing: 3) {
                                        Text(a.kind == .credit ? "Cartão ·" : "Conta ·").font(.footnote).foregroundStyle(Color.secondary)
                                        MoneyText(a.headline, currency: a.currency, font: .footnote, color: .secondary)
                                    }
                                }
                            }
                        }
                        .accessibilityAddTraits(picked.contains(a.id) ? .isSelected : [])
                    }
                } header: { Text("Escolha as contas que saem do e-Finances").textCase(nil) }

                Section {
                    option(false, "Manter como conta congelada", "Fica só para consulta, com tudo o que já veio.")
                    option(true, "Apagar as contas e os lançamentos", "Some do e-Finances. Não dá para desfazer.")
                } header: { Text("O que fazer com os lançamentos").textCase(nil) } footer: {
                    Text(all ? "Saindo todas as contas, o acesso ao \(connection.bankName) é revogado." : "As contas que ficarem continuam sincronizando.")
                }

                Section {
                    Button {
                        if remove { confirmRemove = true } else { run() }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.busy { ProgressView().tint(.white) }
                            Text("Desconectar \(plural(picked.count, "conta", "contas"))")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .efExpense, foreground: .white))
                    .disabled(picked.isEmpty || vm.busy)
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
            }
            .efGroupedList()
            .navigationTitle("Desconectar \(connection.bankName)")
            .efLargeTitle(false)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } } }
            .confirmationDialog("Apagar \(plural(picked.count, "conta", "contas")) e os lançamentos?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Apagar de vez", role: .destructive) { run() }
            } message: { Text("Não dá para desfazer.") }
        }
    }

    private func option(_ value: Bool, _ title: String, _ text: String) -> some View {
        Button { remove = value } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(value ? Color.efExpense : Color.efInk)
                    Text(text).font(.footnote).foregroundStyle(Color.secondary)
                }
                Spacer()
                if remove == value { Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.efTint) }
            }
        }
        .accessibilityAddTraits(remove == value ? .isSelected : [])
    }

    private func run() {
        Task {
            if await vm.disconnect(connection, removeAccounts: remove, accountIds: Array(picked)) { dismiss() }
        }
    }
}

// MARK: - conta do banco

/// Conta ou cartão conectado: saldo ou fatura, entradas e saídas, gastos por categoria e lançamentos do banco.
struct BankAccountView: View {
    let accountId: Int64

    var body: some View {
        Screen({ BankAccountViewModel(app: $0, accountId: accountId) }) { vm in BankAccountContent(vm: vm) }
    }
}

private struct BankAccountContent: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    let vm: BankAccountViewModel

    var body: some View {
        LoadableContent(vm.state, retry: { await vm.load() }) { d in
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(d.siblings, id: \.1.id) { c, a in
                                FilterChip("\(c.bankName) · \(a.name)", selected: a.id == d.account.id) { Task { await vm.select(a.id) } }
                            }
                        }
                    }
                    hero(d)
                    if !d.connection.updated {
                        Button { reconnect(d.connection) } label: { Label("Reconectar \(d.connection.bankName)", systemImage: "arrow.triangle.2.circlepath") }
                            .buttonStyle(.efPrimary)
                    }
                    Picker("Período", selection: Binding(get: { vm.days }, set: { v in Task { await vm.setDays(v) } })) {
                        Text("Últimos 30 dias").tag(30)
                        Text("Últimos 90 dias").tag(90)
                    }
                    .pickerStyle(.segmented)
                    if let s = d.summary {
                        HStack(spacing: 10) {
                            KPITile("Entradas", value: s.income, color: .efIncome)
                            KPITile("Saídas", value: s.expense, color: .efExpense)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)

                if let s = d.summary, !s.expenseByCategory.isEmpty {
                    let top = s.expenseByCategory.prefix(5)
                    let max = top.map(\.total).max() ?? 1
                    Section("Saídas por categoria") {
                        ForEach(Array(top), id: \.name) { c in
                            let look = Icons.visual(forName: c.name)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    IconBadge(symbol: look.0, color: look.1, size: 26)
                                    Text(c.name).lineLimit(1)
                                    Spacer()
                                    MoneyText(c.total, currency: d.account.currency, font: .subheadline.weight(.semibold))
                                }
                                ProgressBar(max > 0 ? (c.total / max).doubleValue : 0, color: look.1)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .listRowBackground(Color.efSurface)
                }

                Section {
                    if d.transactions.isEmpty {
                        Text("Nada nos últimos \(vm.days) dias.").foregroundStyle(Color.secondary)
                    }
                    ForEach(d.transactions) { t in
                        HStack(spacing: 12) {
                            let look = Icons.visual(forName: t.categoryName ?? t.description)
                            IconBadge(symbol: look.0, color: look.1, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.description).lineLimit(1)
                                Text([DateFormats.dayMonth(t.date), t.categoryName, t.installment.map { "parcela \($0)" }].compactMap { $0 }.joined(separator: " · "))
                                    .font(.footnote).foregroundStyle(Color.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 6)
                            MoneyText(t.amount.magnitude, currency: d.account.currency, signedIncome: t.isIncome, font: .callout.weight(.medium),
                                      color: t.isIncome ? .efIncome : .efInk)
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: { Text("Lançamentos recentes") } footer: { Text("Vindos do banco. Para organizar categoria e contato, abra em Transações.") }
                .listRowBackground(Color.efSurface)

                Section {
                    Button {
                        Task { if await vm.openLedger() { router.showTransactions() } }
                    } label: { Label("Ver e organizar em Transações", systemImage: "list.bullet.rectangle.portrait") }
                        .buttonStyle(.efSoft)
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            .efGroupedList()
            .scrollContentBackground(.hidden)
            .refreshable { await vm.load() }
            .navigationTitle(d.connection.bankName)
        }
        .background(Color.efBackground.ignoresSafeArea())
        .efLargeTitle(false)
        .toolbar {
            ToolbarItem(placement: .efTrailing) {
                Button { Task { await vm.sync() } } label: { Image(systemName: "arrow.triangle.2.circlepath") }.accessibilityLabel("Atualizar")
            }
        }
        .task { if vm.state.value == nil { await vm.load() } }
    }

    private func hero(_ d: BankAccountData) -> some View {
        let credit = d.account.kind == .credit
        let colors: [Color] = Color(hexString: d.connection.color).map { [$0, Color(hexString: d.connection.color, darkenedBy: 0.4) ?? $0] } ?? [.efHeroTop, .efHeroBottom]
        return HeroCard(colors: colors) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(d.account.name) · \(credit ? "fatura atual" : "saldo")").font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.78))
                BigMoney(d.account.headline, currency: d.account.currency).foregroundStyle(.white)
                if credit, let limit = d.account.creditLimit, let available = d.account.availableCredit, limit > 0 {
                    HStack(spacing: 4) {
                        Text("Disponível").foregroundStyle(.white.opacity(0.78))
                        MoneyText(available, currency: d.account.currency, font: .subheadline.weight(.semibold), color: .white)
                        Text("de").foregroundStyle(.white.opacity(0.78))
                        MoneyText(limit, currency: d.account.currency, font: .subheadline, color: .white.opacity(0.78))
                    }
                    .font(.subheadline)
                    ProgressBar(((limit - available) / limit).doubleValue, color: .white, track: .white.opacity(0.25)).padding(.top, 4)
                } else {
                    Text("\(d.connection.updatedLabel(now: app.clock.localNow()).capitalizedFirst) · em \(d.connection.companyName ?? "—")")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }

    private func reconnect(_ c: BankConnection) {
        if app.demo { app.messenger.show("No modo demonstração não há banco de verdade para reconectar.", icon: "info.circle") }
        else { router.web = app.page("Reconectar \(c.bankName)", "open-finance") }
    }
}
