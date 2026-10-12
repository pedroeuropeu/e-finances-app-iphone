import SwiftUI
import EFCore
import EFFeatures

/// Planejar: limites por categoria, parcelamentos em andamento e assinaturas.
struct PlanningView: View {
    var body: some View {
        Screen(PlanningViewModel.init) { vm in PlanningContent(vm: vm) }
    }
}

/// Limite aberto na folha (novo ou existente).
private struct LimitEdit: Identifiable {
    let id = UUID()
    var category: TransactionCategory?
    var item: LimitItem?
    var suggested: Decimal?
}

private struct PlanningContent: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    let vm: PlanningViewModel
    @State private var editing: LimitEdit?

    var body: some View {
        @Bindable var vm = vm
        List {
            Section {
                Picker("Planejar", selection: $vm.tab) {
                    ForEach(PlanningTab.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            switch vm.state {
            case .loading: Section { LoadingView().frame(minHeight: 260) }.listRowBackground(Color.clear)
            case .failed(let e): Section { ErrorView(e) { await vm.load() }.frame(minHeight: 260) }.listRowBackground(Color.clear)
            case .ready(let d):
                switch vm.tab {
                case .limits: limits(d)
                case .installments: installments(d)
                case .subscriptions: subscriptions(d)
                }
            }
        }
        .efGroupedList()
        .scrollContentBackground(.hidden)
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle("Planejar")
        .efLargeTitle()
        .refreshable { await vm.load() }
        .toolbar {
            ToolbarItemGroup(placement: .efTrailing) {
                NavigationLink(value: Route.reports) { Image(systemName: "chart.bar") }.accessibilityLabel("Relatórios")
                if vm.tab == .limits {
                    Button { editing = LimitEdit() } label: { Image(systemName: "plus") }.accessibilityLabel("Novo limite")
                }
            }
        }
        .sheet(item: $editing) { e in
            LimitSheet(edit: e, vm: vm, categories: availableCategories(vm.state.value, keeping: e.item?.categoryId)).efToasts()
        }
        .task {
            if let t = router.planningTab { vm.tab = t; router.planningTab = nil }
            if vm.state.value == nil { await vm.load() }
        }
        .onChange(of: router.planningTab) { _, t in if let t { vm.tab = t; router.planningTab = nil } }
        .onChange(of: app.dataVersion) { Task { await vm.load() } }
        .animation(.snappy, value: vm.tab)
    }

    /// Categorias de despesa ainda sem limite (ou a do limite que está sendo editado).
    private func availableCategories(_ d: PlanningData?, keeping id: Int64?) -> [TransactionCategory] {
        guard let d else { return [] }
        let used = Set((d.limits?.items ?? []).map(\.categoryId))
        return d.categories.filter { !$0.isIncomeCategory && (!used.contains($0.id) || $0.id == id) }
    }

    // MARK: limites

    @ViewBuilder private func limits(_ d: PlanningData) -> some View {
        let l = d.limits
        Section {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                KPITile("Limites somados", value: l?.totalLimit ?? 0)
                KPITile("Gasto em \(DateFormats.monthName(d.month))", value: l?.totalSpent ?? 0)
                KPITile("Ainda dá para gastar", value: l?.available ?? 0, color: .efIncome)
                KPITile("Pedem atenção", text: "\(l?.attention ?? 0)", color: (l?.attention ?? 0) > 0 ? .efExpense : nil)
            }
        }
        .listRowBackground(Color.clear).listRowInsets(EdgeInsets())

        if let items = l?.items, !items.isEmpty {
            Section {
                ForEach(items.sorted { $0.percent > $1.percent }) { item in
                    Button { editing = LimitEdit(category: d.category(item.categoryId), item: item) } label: {
                        LimitRow(item: item, look: d.category(item.categoryId)).padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) { vm.deleteLimit(item.id) } label: { Label("Excluir", systemImage: "trash") }.tint(.efExpense)
                    }
                }
            }
            .listRowBackground(Color.efSurface)
        } else {
            Section {
                VStack(spacing: 12) {
                    EmptyStateView("flag", "Nenhum limite ainda", message: "Defina quanto quer gastar por categoria e receba um aviso quando chegar perto.")
                    Button("Criar limite") { editing = LimitEdit() }.buttonStyle(.bordered).buttonBorderShape(.capsule).tint(.efTint)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
            }
            .listRowBackground(Color.clear)
        }

        if let s = l?.suggestions, !s.isEmpty {
            Section {
                ForEach(s.prefix(3), id: \.categoryName) { sug in
                    HStack(spacing: 12) {
                        CategoryBadge(d.category(sug.categoryId), size: 36, fallbackName: sug.categoryName)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(sug.categoryName)
                            HStack(spacing: 3) {
                                Text("Média de").font(.footnote).foregroundStyle(Color.secondary)
                                MoneyText(sug.average, font: .footnote, color: .secondary)
                                Text("por mês").font(.footnote).foregroundStyle(Color.secondary)
                            }
                        }
                        Spacer()
                        Button("Criar") { editing = LimitEdit(category: d.category(sug.categoryId), suggested: sug.suggested) }
                            .buttonStyle(.bordered).buttonBorderShape(.capsule).tint(.efTint)
                    }
                }
            } header: { Text("Sugestões") } footer: { Text("Pela média dos últimos 3 meses.") }
            .listRowBackground(Color.efSurface)
        }

        Section {
            EmptyView()
        } footer: {
            Label("Avisamos no iPhone e por e-mail quando uma categoria chega no % de alerta e quando passa do limite.", systemImage: "bell.badge")
        }
    }

    // MARK: parcelas

    @ViewBuilder private func installments(_ d: PlanningData) -> some View {
        Section {
            HeroCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Falta pagar").font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.78))
                    BigMoney(d.installmentsRemaining, size: 34).foregroundStyle(.white)
                    HStack(spacing: 4) {
                        Text("\(plural(d.installments.count, "parcelamento", "parcelamentos")) ·").foregroundStyle(.white.opacity(0.8))
                        MoneyText(d.installmentsMonthly, font: .subheadline.weight(.semibold), color: .white)
                        Text("por mês").foregroundStyle(.white.opacity(0.8))
                    }
                    .font(.subheadline)
                }
            }
        }
        .listRowBackground(Color.clear).listRowInsets(EdgeInsets())

        if d.installments.isEmpty {
            Section {
                EmptyStateView("square.stack.3d.up", "Nenhum parcelamento", message: "Compras parceladas nos lançamentos e nos cartões conectados aparecem aqui.")
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            }
            .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(d.installments) { i in
                    if let id = i.transactionId {
                        NavigationLink(value: Route.transaction(id, nil)) { installmentRow(i) }
                    } else {
                        installmentRow(i)
                    }
                }
            } footer: {
                Label("Parcelas dos seus lançamentos e as que vêm dos cartões conectados.", systemImage: "info.circle")
            }
            .listRowBackground(Color.efSurface)
        }
    }

    private func installmentRow(_ i: InstallmentItem) -> some View {
        HStack(spacing: 12) {
            InstallmentRing(paid: i.paid, total: i.total)
            VStack(alignment: .leading, spacing: 3) {
                Text(i.name).lineLimit(1)
                HStack(spacing: 3) {
                    MoneyText(i.amount, font: .footnote, color: .secondary)
                    Text("/mês\(i.endDate.map { " · termina em \(DateFormats.shortMonthYear($0))" } ?? "")").font(.footnote).foregroundStyle(Color.secondary)
                }
                Tag(i.source == .ledger ? "Lançamentos" : i.accountName ?? "Cartão", symbol: i.source == .ledger ? "list.bullet.rectangle" : "link",
                    color: i.source == .ledger ? .efInfo : .efNavy)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 0) {
                Text("Falta").font(.caption2).foregroundStyle(Color.secondary)
                MoneyText(i.remainingAmount, font: .subheadline.weight(.medium))
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    // MARK: assinaturas

    @ViewBuilder private func subscriptions(_ d: PlanningData) -> some View {
        let s = d.subscriptions
        Section {
            HeroCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Assinaturas").font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.78))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        BigMoney(s?.monthlyTotal ?? 0, size: 34, currency: s?.currency).foregroundStyle(.white)
                        Text("/mês").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    }
                    HStack(spacing: 4) {
                        Text("\(plural(s?.subscriptions.count ?? 0, "assinatura", "assinaturas")) ·").foregroundStyle(.white.opacity(0.8))
                        MoneyText(s?.yearlyTotal ?? 0, currency: s?.currency, font: .subheadline.weight(.semibold), color: .white)
                        Text("por ano").foregroundStyle(.white.opacity(0.8))
                    }
                    .font(.subheadline)
                }
            }
            ForEach((s?.subscriptions ?? []).filter { $0.priceIncreasePct != nil }) { item in
                NoticeBanner(symbol: "chart.line.uptrend.xyaxis", title: "\(item.name) ficou \(item.priceIncreasePct ?? 0)% mais cara",
                             text: "Passou de \(Money.format(item.previousAmount ?? 0, currency: item.currency)) para \(Money.format(item.amount, currency: item.currency)).",
                             color: .efWarn)
            }
        }
        .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowSeparator(.hidden)

        if let items = s?.subscriptions, !items.isEmpty {
            Section {
                ForEach(items) { item in
                    Button { openSubscription(item, d) } label: { recurringRow(item) }
                }
            }
            .listRowBackground(Color.efSurface)
        } else {
            Section {
                EmptyStateView("repeat", "Nenhuma assinatura", message: "Marque categorias como assinatura em Mais › Categorias.")
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            }
            .listRowBackground(Color.clear)
        }

        if let bills = s?.bills, !bills.isEmpty {
            Section {
                ForEach(bills) { recurringRow($0) }
            } header: { Text("Outras cobranças recorrentes") } footer: { Text("Contas fixas encontradas no banco.") }
            .listRowBackground(Color.efSurface)
        }

        Section {
            EmptyView()
        } footer: {
            Label("Assinatura é todo lançamento, manual ou do banco, numa categoria marcada como assinatura. Marque em Mais › Categorias.", systemImage: "info.circle")
        }
    }

    private func recurringRow(_ item: RecurringItem) -> some View {
        HStack(spacing: 12) {
            CategoryBadge(item.look, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).foregroundStyle(Color.efInk).lineLimit(1)
                Text([item.frequency.label, item.nextDate.map { "próxima em \(DateFormats.dayMonth($0))" }, item.accountName].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote).foregroundStyle(Color.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            MoneyText(item.amount, currency: item.currency, font: .subheadline.weight(.medium))
        }
    }

    private func openSubscription(_ item: RecurringItem, _ d: PlanningData) {
        let category = d.categories.first { $0.name == item.category } ?? d.categories.first { $0.name == item.name }
        router.showTransactions(TxFilters(category: category, query: category == nil ? item.name : ""))
    }
}

// MARK: - folha do limite

private struct LimitSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let edit: LimitEdit
    let vm: PlanningViewModel
    let categories: [TransactionCategory]
    @State private var category: TransactionCategory?
    @State private var value = ""
    @State private var alert = 80.0
    @State private var saving = false
    @State private var error: String?

    init(edit: LimitEdit, vm: PlanningViewModel, categories: [TransactionCategory]) {
        self.edit = edit; self.vm = vm; self.categories = categories
        _category = State(initialValue: edit.category)
        let v = edit.item?.limit ?? edit.suggested
        _value = State(initialValue: v.map { Money.format($0).replacingOccurrences(of: "R$", with: "").trimmingCharacters(in: .whitespaces) } ?? "")
        _alert = State(initialValue: Double(edit.item?.alertPercent ?? 80))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        CategoryBadge(category, size: 56, fallbackName: category?.name ?? "Limite")
                        Text(category?.name ?? "Escolha a categoria").font(.sora(20, .semibold, relativeTo: .title3))
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                Section {
                    if edit.item == nil {
                        Picker("Categoria", selection: $category) {
                            Text("Escolher").tag(TransactionCategory?.none)
                            ForEach(categories) { Text($0.name).tag(Optional($0)) }
                        }
                    }
                    HStack {
                        Text("Limite por mês")
                        Spacer()
                        Text("R$").foregroundStyle(Color.secondary)
                        TextField("0,00", text: $value).efDecimalField().multilineTextAlignment(.trailing).frame(maxWidth: 130)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Avisar quando chegar em")
                            Spacer()
                            Text("\(Int(alert))%").fontWeight(.semibold).foregroundStyle(Color.efTint).monospacedDigit()
                        }
                        Slider(value: $alert, in: 50...100, step: 5).tint(.efGreen)
                    }
                } footer: {
                    if let error { Text(error).foregroundStyle(Color.efExpense) }
                    else { Label("Aviso no iPhone e por e-mail, uma vez por nível em cada mês.", systemImage: "bell.badge") }
                }
                if let item = edit.item {
                    Section {
                        Button(role: .destructive) {
                            vm.deleteLimit(item.id)
                            dismiss()
                        } label: { Label("Excluir limite", systemImage: "trash") }
                    }
                }
            }
            .navigationTitle(edit.item == nil ? "Novo limite" : "Editar limite")
            .efLargeTitle(false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else { Button("Salvar") { save() }.fontWeight(.semibold) }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard let c = category else { error = "Escolha a categoria"; return }
        guard let v = parseAmount(value), v > 0 else { error = "Informe um valor maior que zero"; return }
        error = nil
        saving = true
        Task {
            let ok = await vm.saveLimit(categoryId: c.id, value: v, alert: Int(alert))
            saving = false
            if ok {
                app.messenger.show(edit.item == nil ? "Limite criado" : "Limite atualizado", icon: "flag")
                dismiss()
            }
        }
    }
}
