import SwiftUI
import EFCore
import EFFeatures

// MARK: - contatos

/// Clientes, fornecedores e funcionários, com quanto cada um te deve ou você deve.
struct ContactsView: View {
    var body: some View {
        Screen(ContactsViewModel.init) { vm in ContactsContent(vm: vm) }
    }
}

private struct ContactEdit: Identifiable {
    let id = UUID()
    var details: ContactDetails?
}

private struct ContactsContent: View {
    let vm: ContactsViewModel
    @State private var editing: ContactEdit?
    @State private var showing: ContactDetails?

    var body: some View {
        @Bindable var vm = vm
        List {
            Section {
                if let debts = vm.state.value?.debts {
                    HStack(spacing: 10) {
                        KPITile("Me devem", value: debts.owesMeTotal, color: .efIncome, detail: "em aberto")
                        KPITile("Eu devo", value: debts.iOweTotal, color: .efExpense, detail: "em aberto")
                    }
                }
                Picker("Tipo", selection: $vm.filter) {
                    Text("Todos").tag(ContactCategory?.none)
                    Text("Clientes").tag(Optional(ContactCategory.client))
                    Text("Fornec.").tag(Optional(ContactCategory.supplier))
                    Text("Funcion.").tag(Optional(ContactCategory.worker))
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowSeparator(.hidden)

            switch vm.state {
            case .loading: Section { LoadingView().frame(minHeight: 220) }.listRowBackground(Color.clear)
            case .failed(let e): Section { ErrorView(e) { await vm.load() } }.listRowBackground(Color.clear)
            case .ready(let d):
                Section {
                    if vm.filtered.isEmpty { Text("Nenhum contato encontrado.").foregroundStyle(.secondary) }
                    ForEach(vm.filtered) { c in
                        Button { showing = c } label: { row(c, d.debts) }
                            .swipeActions {
                                Button(role: .destructive) { Task { _ = await vm.delete(c.contact) } } label: { Label("Excluir", systemImage: "trash") }
                                Button { editing = ContactEdit(details: c) } label: { Label("Editar", systemImage: "pencil") }.tint(.efInfo)
                            }
                    }
                }
                .listRowBackground(Color.efSurface)
            }
        }
        .efGroupedList()
        .scrollContentBackground(.hidden)
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle("Contatos")
        .efLargeTitle()
        .searchable(text: $vm.query, prompt: "Buscar contato")
        .refreshable { await vm.load() }
        .toolbar {
            ToolbarItem(placement: .efTrailing) {
                Button { editing = ContactEdit() } label: { Image(systemName: "plus") }.accessibilityLabel("Novo contato")
            }
        }
        .sheet(item: $editing) { e in ContactEditor(vm: vm, details: e.details) }
        .sheet(item: $showing) { c in
            ContactCard(details: c, debts: vm.state.value?.debts, currency: vm.currency,
                        onEdit: { showing = nil; editing = ContactEdit(details: c) },
                        onDelete: { Task { if await vm.delete(c.contact) { showing = nil } } })
        }
        .task { if vm.state.value == nil { await vm.load() } }
    }

    private func row(_ c: ContactDetails, _ debts: ContactDebts?) -> some View {
        let owes = debts?.owesMe(c.id) ?? 0, owe = debts?.iOwe(c.id) ?? 0
        let net = owes - owe
        return HStack(spacing: 12) {
            InitialsBadge(c.contact.name, color: c.contact.category?.color ?? .efInfo, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.contact.name).foregroundStyle(Color.efInk).lineLimit(1)
                Text([c.contact.category?.label, c.contact.phone].compactMap { $0 }.joined(separator: " · ")).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            if net != 0 {
                VStack(alignment: .trailing, spacing: 0) {
                    MoneyText(net.magnitude, currency: vm.currency, font: .subheadline.weight(.medium), color: net > 0 ? .efIncome : .efExpense)
                    Text(net > 0 ? "te deve" : "você deve").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Cartão do contato: ligar, mensagem, WhatsApp e e-mail, dados e quanto deve.
private struct ContactCard: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let details: ContactDetails
    let debts: ContactDebts?
    let currency: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var confirmDelete = false

    var body: some View {
        let c = details.contact
        let phone = (c.phone ?? "").filter(\.isNumber)
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        InitialsBadge(c.name, color: c.category?.color ?? .efInfo, size: 76)
                        Text(c.name).font(.sora(22, .semibold, relativeTo: .title2)).multilineTextAlignment(.center)
                        if let cat = c.category { Text(cat.label).foregroundStyle(.secondary) }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                Section {
                    HStack(spacing: 10) {
                        action("phone.fill", "Ligar", url: phone.isEmpty ? nil : URL(string: "tel:\(phone)"))
                        action("message.fill", "Mensagem", url: phone.isEmpty ? nil : URL(string: "sms:\(phone)"))
                        action("bubble.left.fill", "WhatsApp", url: phone.isEmpty ? nil : URL(string: "https://wa.me/\(phone.count <= 11 ? "55" + phone : phone)"))
                        action("envelope.fill", "E-mail", url: (c.email ?? "").isEmpty ? nil : URL(string: "mailto:\(c.email ?? "")"))
                    }
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                Section {
                    if let p = c.phone, !p.isEmpty { LabeledContent("Telefone", value: p) }
                    if let e = c.email, !e.isEmpty { LabeledContent("E-mail", value: e) }
                    if let t = details.personType { LabeledContent("Pessoa", value: t.label) }
                    if let d = details.document, !d.isEmpty { LabeledContent("Documento", value: d) }
                    if let city = details.city, !city.isEmpty { LabeledContent("Cidade", value: [city, details.state].compactMap { $0 }.joined(separator: " · ")) }
                    if let owes = debts?.owesMe(c.id), owes > 0 {
                        LabeledContent("Te deve") { MoneyText(owes, currency: currency, color: .efIncome) }
                    }
                    if let owe = debts?.iOwe(c.id), owe > 0 {
                        LabeledContent("Você deve") { MoneyText(owe, currency: currency, color: .efExpense) }
                    }
                    if let desc = details.description, !desc.isEmpty { Text(desc).foregroundStyle(.secondary) }
                }
                Section {
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Excluir contato", systemImage: "trash") }
                } footer: { Text("Contato com lançamentos não pode ser excluído.") }
            }
            .efGroupedList()
            .navigationTitle("Contato")
            .efLargeTitle(false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Editar", action: onEdit) }
            }
            .confirmationDialog("Excluir \(c.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Excluir", role: .destructive, action: onDelete)
            } message: { Text("Dá para restaurar logo depois.") }
        }
        .presentationDetents([.medium, .large])
    }

    private func action(_ symbol: String, _ label: String, url: URL?) -> some View {
        Button { if let url { openURL(url) } } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.title3)
                Text(label).font(.caption)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(Color.efSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(url == nil ? Color.secondary : Color.efTint)
        .disabled(url == nil)
    }
}

private struct ContactEditor: View {
    @Environment(\.dismiss) private var dismiss
    let vm: ContactsViewModel
    let details: ContactDetails?
    @State private var input: ContactInput

    init(vm: ContactsViewModel, details: ContactDetails?) {
        self.vm = vm
        self.details = details
        let c = details?.contact
        _input = State(initialValue: ContactInput(id: c?.id, name: c?.name ?? "", category: c?.category ?? .client, personType: details?.personType ?? .personal,
                                                  cellphone: c?.phone ?? "", email: c?.email ?? "", document: details?.document ?? "",
                                                  city: details?.city ?? "", description: details?.description ?? ""))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome ou razão social", text: $input.name).efNameField()
                    Picker("Tipo", selection: $input.category) {
                        ForEach(ContactCategory.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    Picker("Pessoa", selection: $input.personType) {
                        ForEach(PersonType.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                }
                Section {
                    TextField("Celular", text: $input.cellphone).efPhoneField()
                    TextField("E-mail", text: $input.email).efEmailField()
                    TextField(input.personType == .company ? "CNPJ" : "CPF", text: $input.document).efNumberField()
                    TextField("Cidade", text: $input.city)
                    TextField("Observações", text: $input.description, axis: .vertical).lineLimit(1...4)
                }
            }
            .navigationTitle(details == nil ? "Novo contato" : "Editar contato")
            .efLargeTitle(false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.saving { ProgressView() } else {
                        Button("Salvar") { Task { if await vm.save(input) { dismiss() } } }.fontWeight(.semibold)
                    }
                }
            }
        }
    }
}

// MARK: - centros de custo

/// Centros de custo com orçamento mensal e quanto já foi usado.
struct CostCentersView: View {
    var body: some View {
        Screen(CostCentersViewModel.init) { vm in CostCentersContent(vm: vm) }
    }
}

private struct CostCenterEdit: Identifiable {
    let id = UUID()
    var center: CostCenter?
}

private struct CostCentersContent: View {
    let vm: CostCentersViewModel
    @State private var editing: CostCenterEdit?

    var body: some View {
        @Bindable var vm = vm
        List {
            Section {
                HStack {
                    Button { Task { await vm.changeMonth(-1) } } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Mês anterior")
                    Spacer()
                    Text(DateFormats.monthYearTitle(vm.month)).font(.subheadline.weight(.semibold))
                    Spacer()
                    Button { Task { await vm.changeMonth(1) } } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Próximo mês")
                }
                .buttonStyle(.borderless)
                if let d = vm.state.value {
                    let used = d.usage.values.reduce(Decimal(0)) { $0 + $1.expense }
                    let budget = d.centers.compactMap(\.monthlyBudget).reduce(0, +)
                    HStack(spacing: 10) {
                        KPITile("Despesas classificadas", value: used, detail: "\(plural(d.usage.values.reduce(0) { $0 + Int($1.count) }, "lançamento", "lançamentos"))")
                        KPITile("Orçamento do mês", value: budget, detail: budget > 0 ? "\(pct(used, budget))% usado" : "sem orçamento")
                    }
                }
                Toggle("Mostrar os padrão do sistema", isOn: $vm.showDefaults)
                    .padding(.horizontal, 4)
            }
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowSeparator(.hidden)

            switch vm.state {
            case .loading: Section { LoadingView().frame(minHeight: 220) }.listRowBackground(Color.clear)
            case .failed(let e): Section { ErrorView(e) { await vm.load() } }.listRowBackground(Color.clear)
            case .ready(let d):
                let list = d.centers.filter { vm.showDefaults || !$0.systemDefault }
                Section {
                    if list.isEmpty { Text("Nenhum centro de custo ainda.").foregroundStyle(.secondary) }
                    ForEach(list) { c in
                        Button { if !c.systemDefault { editing = CostCenterEdit(center: c) } } label: { row(c, d.usage[c.id]) }
                            .swipeActions {
                                if !c.systemDefault {
                                    Button(role: .destructive) { Task { _ = await vm.delete(c) } } label: { Label("Excluir", systemImage: "trash") }
                                }
                            }
                    }
                } footer: {
                    Label("Separe despesas por área e acompanhe um orçamento mensal para cada uma.", systemImage: "info.circle")
                }
                .listRowBackground(Color.efSurface)
            }
        }
        .efGroupedList()
        .scrollContentBackground(.hidden)
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle("Centros de custo")
        .efLargeTitle()
        .refreshable { await vm.load() }
        .toolbar {
            ToolbarItem(placement: .efTrailing) {
                Button { editing = CostCenterEdit() } label: { Image(systemName: "plus") }.accessibilityLabel("Novo centro de custo")
            }
        }
        .sheet(item: $editing) { e in CostCenterEditor(vm: vm, center: e.center) }
        .task { if vm.state.value == nil { await vm.load() } }
    }

    private func row(_ c: CostCenter, _ u: CostCenterUsage?) -> some View {
        let spent = u?.expense ?? 0
        let color = Color(hexString: c.color) ?? .efInfo
        let p = (c.monthlyBudget ?? 0) > 0 ? pct(spent, c.monthlyBudget ?? 1) : nil
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                IconBadge(symbol: "point.3.connected.trianglepath.dotted", color: color, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(c.name).foregroundStyle(Color.efInk)
                        if c.systemDefault { Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary) }
                    }
                    Text([c.description, plural(Int(u?.count ?? 0), "lançamento", "lançamentos")].compactMap { $0 }.joined(separator: " · "))
                        .font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if let p {
                    Text("\(p)%").font(.subheadline.weight(.bold)).monospacedDigit()
                        .foregroundStyle(p >= 100 ? Color.efExpense : p >= 85 ? Color.efWarn : Color.efIncome)
                }
            }
            if let budget = c.monthlyBudget, budget > 0 {
                ProgressBar(min(Double(p ?? 0) / 100, 1), color: color)
                HStack(spacing: 3) {
                    MoneyText(spent, font: .caption, color: .secondary)
                    Text("de").font(.caption).foregroundStyle(.secondary)
                    MoneyText(budget, font: .caption, color: .secondary)
                }
            } else if spent > 0 {
                MoneyText(spent, font: .caption, color: .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CostCenterEditor: View {
    @Environment(\.dismiss) private var dismiss
    let vm: CostCentersViewModel
    let center: CostCenter?
    @State private var name: String
    @State private var description: String
    @State private var color: String
    @State private var budget: String
    @State private var confirmDelete = false

    init(vm: CostCentersViewModel, center: CostCenter?) {
        self.vm = vm
        self.center = center
        _name = State(initialValue: center?.name ?? "")
        _description = State(initialValue: center?.description ?? "")
        _color = State(initialValue: center?.color ?? CategoryLooks.colors[1])
        _budget = State(initialValue: center?.monthlyBudget.map { Money.format($0).replacingOccurrences(of: "R$", with: "").trimmingCharacters(in: .whitespaces) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome (ex.: Viagens)", text: $name)
                    TextField("Descrição (opcional)", text: $description)
                    HStack {
                        Text("Orçamento por mês")
                        Spacer()
                        Text("R$").foregroundStyle(.secondary)
                        TextField("Opcional", text: $budget).efDecimalField().multilineTextAlignment(.trailing).frame(maxWidth: 130)
                    }
                }
                Section("Cor") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 10) {
                        ForEach(CategoryLooks.colors, id: \.self) { hex in
                            let on = color.uppercased() == hex.uppercased()
                            Button { color = hex } label: {
                                Circle().fill(Color(hexString: hex) ?? .gray).frame(width: 30, height: 30)
                                    .overlay { if on { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white) } }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Cor \(hex)")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }
                if let c = center {
                    Section {
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Excluir centro de custo", systemImage: "trash") }
                    }
                    .confirmationDialog("Excluir “\(c.name)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("Excluir", role: .destructive) { Task { if await vm.delete(c) { dismiss() } } }
                    }
                }
            }
            .navigationTitle(center == nil ? "Novo centro de custo" : "Editar centro de custo")
            .efLargeTitle(false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.saving { ProgressView() } else {
                        Button("Salvar") {
                            let input = CostCenterInput(id: center?.id, name: name, description: description, color: color, monthlyBudget: parseAmount(budget))
                            Task { if await vm.save(input) { dismiss() } }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - empresas e contas

/// Empresas e suas contas (manuais, do banco e congeladas), com moeda, saldo e conta padrão.
struct CompaniesView: View {
    var body: some View {
        Screen(CompaniesViewModel.init) { vm in CompaniesContent(vm: vm) }
    }
}

private enum CompanySheet: Identifiable {
    case newCompany
    case editCompany(Company)
    case account(Company, Account?)
    var id: String {
        switch self {
        case .newCompany: "new"
        case .editCompany(let c): "c\(c.id)"
        case .account(let c, let a): "a\(c.id)-\(a?.id ?? 0)"
        }
    }
}

private struct CompaniesContent: View {
    @Environment(AppModel.self) private var app
    let vm: CompaniesViewModel
    @State private var sheet: CompanySheet?

    var body: some View {
        LoadableContent(vm.state, retry: { await vm.load() }) { ws in
            List {
                ForEach(ws.companies) { co in
                    Section {
                        ForEach(co.accounts) { a in accountRow(co, a) }
                        Button { sheet = .account(co, nil) } label: { Label("Nova conta manual", systemImage: "plus.circle.fill") }
                    } header: {
                        HStack(spacing: 10) {
                            Text(co.name.initials).font(.caption.weight(.bold)).foregroundStyle(.white)
                                .frame(width: 30, height: 30).background(Icons.companyColor(co.id), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(co.name).font(.headline).foregroundStyle(Color.efInk)
                                Text("\(co.typeLabel) · \(plural(co.accounts.count, "conta", "contas"))").font(.caption)
                            }
                            Spacer()
                            Button { sheet = .editCompany(co) } label: { Image(systemName: "pencil.circle").font(.title3) }
                                .accessibilityLabel("Editar \(co.name)")
                        }
                        .textCase(nil)
                        .padding(.bottom, 4)
                    }
                    .listRowBackground(Color.efSurface)
                }
                Section {
                    EmptyView()
                } footer: {
                    Text("As contas do banco entram aqui quando você conecta um banco na aba Contas. Toque numa conta para passar a usá-la.")
                }
            }
            .efGroupedList()
            .scrollContentBackground(.hidden)
            .refreshable { await vm.load() }
        }
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle("Empresas e contas")
        .efLargeTitle()
        .toolbar {
            ToolbarItem(placement: .efTrailing) {
                Button { sheet = .newCompany } label: { Image(systemName: "plus") }.accessibilityLabel("Nova empresa")
            }
        }
        .sheet(item: $sheet) { s in
            switch s {
            case .newCompany: CompanyEditor(vm: vm, company: nil)
            case .editCompany(let c): CompanyEditor(vm: vm, company: c)
            case .account(let c, let a): AccountEditor(vm: vm, company: c, account: a)
            }
        }
        .task { if vm.state.value == nil { await vm.load() } }
    }

    private func accountRow(_ co: Company, _ a: Account) -> some View {
        let on = vm.inUse == a.id
        let modeText: String = a.mode == .connected ? "do banco" : a.mode == .frozen ? "congelada" : "manual"
        return Button { Task { await vm.use(co, a) } } label: {
            HStack(spacing: 12) {
                AccountBadge(a, companyId: co.id)
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.name).foregroundStyle(Color.efInk).lineLimit(1)
                    Text("\(a.currency)\(a.defaultAccount ? " · padrão" : "") · \(modeText)").font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 6)
                MoneyText(a.balance, currency: a.currency, font: .subheadline.weight(.medium))
                Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.efTint).opacity(on ? 1 : 0).frame(width: 18)
            }
        }
        .accessibilityAddTraits(on ? .isSelected : [])
        .swipeActions {
            if a.mode == .manual {
                Button { sheet = .account(co, a) } label: { Label("Editar", systemImage: "pencil") }.tint(.efInfo)
                if !a.defaultAccount {
                    Button { Task { _ = await vm.setDefault(a) } } label: { Label("Padrão", systemImage: "star") }.tint(.efWarn)
                }
            }
        }
        .contextMenu {
            Button { Task { await vm.use(co, a) } } label: { Label("Usar esta conta", systemImage: "checkmark.circle") }
            if a.mode == .manual {
                Button { sheet = .account(co, a) } label: { Label("Editar", systemImage: "pencil") }
                if !a.defaultAccount { Button { Task { _ = await vm.setDefault(a) } } label: { Label("Tornar padrão", systemImage: "star") } }
            }
        }
    }
}

private struct CompanyEditor: View {
    @Environment(\.dismiss) private var dismiss
    let vm: CompaniesViewModel
    let company: Company?
    @State private var name: String
    @State private var type: CompanyType
    @State private var currency = "BRL"
    @State private var confirmDelete = false

    init(vm: CompaniesViewModel, company: Company?) {
        self.vm = vm
        self.company = company
        _name = State(initialValue: company?.name ?? "")
        _type = State(initialValue: company?.type ?? .business)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome (ex.: Minha loja)", text: $name)
                    Picker("Tipo", selection: $type) {
                        ForEach(CompanyType.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                }
                if company == nil {
                    Section {
                        Picker("Moeda da 1ª conta", selection: $currency) {
                            Text("Real (R$)").tag("BRL")
                            Text("Euro (€)").tag("EUR")
                            Text("Dólar (US$)").tag("USD")
                        }
                    } footer: { Text("Já vem com uma conta padrão. Dá para criar outras depois.") }
                }
                if let c = company {
                    Section {
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Excluir empresa", systemImage: "trash") }
                    } footer: { Text("Só dá para excluir empresa sem lançamentos.") }
                    .confirmationDialog("Excluir \(c.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("Excluir", role: .destructive) { Task { if await vm.deleteCompany(c.id) { dismiss() } } }
                    } message: { Text("Não dá para desfazer.") }
                }
            }
            .navigationTitle(company == nil ? "Nova empresa" : "Editar empresa")
            .efLargeTitle(false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.saving { ProgressView() } else {
                        Button(company == nil ? "Criar" : "Salvar") { save() }
                            .fontWeight(.semibold)
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let input = CompanyInput(id: company?.id, name: name.trimmingCharacters(in: .whitespaces), type: type)
        Task {
            let ok: Bool
            if company == nil {
                ok = await vm.createCompany(input, firstAccount: AccountInput(id: nil, companyId: 0, name: "Conta corrente", currency: currency, initialBalance: nil))
            } else {
                ok = await vm.updateCompany(input)
            }
            if ok { dismiss() }
        }
    }
}

private struct AccountEditor: View {
    @Environment(\.dismiss) private var dismiss
    let vm: CompaniesViewModel
    let company: Company
    let account: Account?
    @State private var name: String
    @State private var currency: String
    @State private var initial = ""
    @State private var confirmDelete = false

    init(vm: CompaniesViewModel, company: Company, account: Account?) {
        self.vm = vm
        self.company = company
        self.account = account
        _name = State(initialValue: account?.name ?? "")
        _currency = State(initialValue: account?.currency ?? "BRL")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome (ex.: Conta corrente, Carteira)", text: $name)
                    Picker("Moeda", selection: $currency) {
                        Text("Real (R$)").tag("BRL")
                        Text("Euro (€)").tag("EUR")
                        Text("Dólar (US$)").tag("USD")
                    }
                    .disabled(account != nil)
                    if account == nil {
                        HStack {
                            Text("Saldo inicial")
                            Spacer()
                            TextField("0,00", text: $initial).efDecimalField().multilineTextAlignment(.trailing).frame(maxWidth: 130)
                        }
                    }
                } footer: { Text("Em \(company.name).") }
                if let a = account, !a.defaultAccount {
                    Section {
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Excluir conta", systemImage: "trash") }
                    } footer: { Text("Só dá para excluir conta sem lançamentos.") }
                    .confirmationDialog("Excluir \(a.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("Excluir", role: .destructive) { Task { if await vm.deleteAccount(a.id) { dismiss() } } }
                    } message: { Text("Não dá para desfazer.") }
                }
            }
            .navigationTitle(account == nil ? "Nova conta" : "Editar conta")
            .efLargeTitle(false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.saving { ProgressView() } else {
                        Button("Salvar") {
                            let input = AccountInput(id: account?.id, companyId: company.id, name: name.trimmingCharacters(in: .whitespaces), currency: currency,
                                                     initialBalance: account == nil ? parseAmount(initial) : nil)
                            Task { if await vm.saveAccount(input) { dismiss() } }
                        }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
