import SwiftUI
import EFCore
import EFFeatures

/// Lançamentos do mês: busca, filtros, grupos por vencimento, deslizar para pagar/excluir e seleção de vários.
struct TransactionsView: View {
    var body: some View {
        Screen(TransactionsViewModel.init) { vm in TransactionsContent(vm: vm) }
    }
}

private struct TransactionsContent: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    let vm: TransactionsViewModel
    @State private var scopeFor: Tx?
    @State private var moreFor: Tx?
    @State private var confirmBatchDelete = false

    var body: some View {
        @Bindable var vm = vm
        List {
            if !vm.selecting { headerSection }
            switch vm.state {
            case .loading:
                Section { LoadingView().frame(minHeight: 240) }.listRowBackground(Color.clear)
            case .failed(let e):
                Section { ErrorView(e) { await vm.load() }.frame(minHeight: 240) }.listRowBackground(Color.clear)
            case .ready:
                if vm.groups.isEmpty { emptySection } else { groups }
            }
            if let note = vm.recurrenceNote {
                Section { EmptyView() } footer: { Text(note) }
            }
        }
        .efGroupedList()
        .scrollContentBackground(.hidden)
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle(vm.selecting ? selectionTitle : "Transações")
        .efLargeTitle(!vm.selecting)
        .searchable(text: $vm.filters.query, prompt: "Buscar descrição, contato ou categoria")
        .refreshable { await vm.load(silent: true) }
        .toolbar { toolbar }
        .safeAreaInset(edge: .bottom) { if vm.selecting { selectionBar } }
        #if os(iOS)
        .toolbar(vm.selecting ? .hidden : .automatic, for: .tabBar)
        #endif
        .scopeDialog(item: $scopeFor, question: "O que você quer excluir?") { t, scope in Task { await vm.delete([t], scope: scope) } }
        .confirmationDialog(moreFor?.description ?? "", isPresented: Binding(get: { moreFor != nil }, set: { if !$0 { moreFor = nil } }),
                            titleVisibility: .visible, presenting: moreFor) { t in
            Button("Editar") { router.edit(t) }
            Button("Duplicar") { Task { if let c = await vm.duplicate(t) { router.push(.transaction(c.id, c.date.yearMonth)) } } }
            Button("Emitir recibo (web)") { router.web = app.page("Recibo", "finances/transactions") }
            Button("Cancelar", role: .cancel) {}
        }
        .confirmationDialog("Excluir \(plural(vm.selection.count, "lançamento", "lançamentos"))?", isPresented: $confirmBatchDelete, titleVisibility: .visible) {
            Button("Excluir", role: .destructive) { Task { await vm.delete(vm.selected) } }
        } message: {
            Text(vm.selected.contains(where: \.hasScope) ? "Recorrentes e parcelas saem só no mês escolhido." : "Dá para desfazer logo depois.")
        }
        .task {
            applyPendingFilter()
            if vm.state.value == nil { await vm.load() }
            await vm.loadExtras()
        }
        .onChange(of: router.pendingFilter) { applyPendingFilter() }
        .onChange(of: app.dataVersion) { Task { await vm.load(silent: true) } }
        .onChange(of: app.workspaceVersion) { Task { vm.clearSelection(); await vm.load(); await vm.loadExtras() } }
    }

    private var selectionTitle: String {
        vm.selection.isEmpty ? "Selecionar itens" : "\(vm.selection.count) \(vm.selection.count == 1 ? "selecionado" : "selecionados")"
    }

    private func applyPendingFilter() {
        guard let f = router.pendingFilter else { return }
        router.pendingFilter = nil
        vm.filters = f
        if !vm.isCurrentMonth { Task { await vm.goToCurrentMonth() } }
    }

    // MARK: topo

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if vm.selecting {
            ToolbarItem(placement: .efLeading) { Button("Selecionar tudo") { vm.selectAll() } }
            ToolbarItem(placement: .efTrailing) { Button("OK") { vm.clearSelection() }.fontWeight(.semibold) }
        } else {
            ToolbarItemGroup(placement: .efTrailing) {
                Menu {
                    Picker("Categoria", selection: Binding(get: { vm.filters.category }, set: { vm.filters.category = $0 })) {
                        Text("Todas as categorias").tag(TransactionCategory?.none)
                        ForEach(vm.categories) { c in Text(c.name).tag(Optional(c)) }
                    }
                } label: {
                    Image(systemName: vm.filters.category == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityLabel("Filtrar por categoria")
                Menu {
                    if vm.manual { Button { vm.startSelection() } label: { Label("Selecionar", systemImage: "checklist") } }
                    Button { router.web = app.page("Exportar transações", "finances/transactions") } label: { Label("Exportar (web)", systemImage: "square.and.arrow.up") }
                    if vm.manual {
                        Button { router.web = app.page("Importar extrato", "finances/transactions") } label: { Label("Importar extrato (web)", systemImage: "doc.badge.plus") }
                    }
                    Button { router.showPlanning(.installments) } label: { Label("Parcelamentos", systemImage: "square.stack.3d.up") }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Mais opções")
                NewTransactionMenu(month: vm.month)
            }
        }
    }

    private var headerSection: some View {
        Section {
            VStack(spacing: 14) {
                Text("\(app.company?.name ?? "") · \(app.account?.name ?? "")").font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                monthSelector
                summary
                chips
                notice
                installmentsRow
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
        }
        .listSectionSeparator(.hidden)
    }

    private var monthSelector: some View {
        HStack {
            Button { Task { await vm.changeMonth(-1) } } label: { Image(systemName: "chevron.left").frame(width: 40, height: 40) }
                .accessibilityLabel("Mês anterior")
            Spacer()
            Button { Task { await vm.goToCurrentMonth() } } label: {
                HStack(spacing: 6) {
                    Text(DateFormats.monthYearTitle(vm.month)).font(.headline).foregroundStyle(Color.efInk)
                    if !vm.isCurrentMonth { Tag("Hoje", symbol: "arrow.uturn.backward", color: .efInfo) }
                }
            }
            .accessibilityHint(vm.isCurrentMonth ? "" : "Voltar para o mês atual")
            Spacer()
            Button { Task { await vm.changeMonth(1) } } label: { Image(systemName: "chevron.right").frame(width: 40, height: 40) }
                .accessibilityLabel("Próximo mês")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.efTint)
        .fontWeight(.semibold)
        .padding(.horizontal, 4)
        .background(Color.efSurface, in: Capsule())
    }

    private var summary: some View {
        let t = vm.totals
        return HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Resultado do mês").font(.caption).foregroundStyle(.secondary)
                MoneyText(t.result, font: .headline, color: t.result >= 0 ? .efIncome : .efExpense)
                Text("recebido − pago").font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider().frame(height: 44)
            pctTile("Recebido", t.incomePaidPct, of: t.income)
            Divider().frame(height: 44)
            pctTile("Pago", t.expensePaidPct, of: t.expense)
        }
        .padding(14)
        .background(Color.efSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func pctTile(_ label: String, _ pct: Int, of total: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text("\(pct)%").font(.headline).monospacedDigit()
            Text("de \(app.settings.hideValues ? "••••" : Money.compact(total, currency: app.currency))").font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 12)
    }

    private var chips: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip("Todas", selected: vm.filters.type == nil) { vm.filters.type = nil }
                    ForEach(TransactionType.allCases, id: \.self) { type in
                        FilterChip(type.plural, selected: vm.filters.type == type) { vm.filters.type = vm.filters.type == type ? nil : type }
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StatusFilter.allCases, id: \.self) { s in
                        FilterChip(s.label, selected: vm.filters.status == s, badge: s == .late && vm.lateCount > 0 ? vm.lateCount : nil) { vm.toggleStatus(s) }
                    }
                    if let c = vm.filters.category {
                        FilterChip("\(c.name) ✕", selected: true) { vm.filters.category = nil }
                    }
                }
            }
        }
    }

    @ViewBuilder private var notice: some View {
        switch vm.mode {
        case .connected:
            NoticeBanner(symbol: "link", title: "Conta do \(vm.account?.bankName ?? "banco")",
                         text: "Os lançamentos vêm do banco. Dá para organizar descrição, categoria, contato, centro de custo e observações.")
        case .frozen:
            NoticeBanner(symbol: "snowflake", title: "Conta congelada",
                         text: "O \(vm.account?.bankName ?? "banco") foi desconectado. Os lançamentos ficam só para consulta.", color: .secondary)
        case .manual: EmptyView()
        }
    }

    @ViewBuilder private var installmentsRow: some View {
        if vm.installmentsCount > 0 && vm.isCurrentMonth && vm.filters.query.isEmpty && vm.manual {
            Button { router.showPlanning(.installments) } label: {
                HStack(spacing: 12) {
                    SettingsIcon("square.stack.3d.up.fill", .efNavy)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(plural(vm.installmentsCount, "parcelamento", "parcelamentos")) em andamento").font(.subheadline.weight(.semibold)).foregroundStyle(Color.efInk)
                        HStack(spacing: 3) {
                            MoneyText(vm.installmentsMonthly, font: .footnote, color: .secondary)
                            Text("por mês nos lançamentos").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(Color.efSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: lista

    private var groups: some View {
        ForEach(vm.groups, id: \.0) { group, items in
            Section {
                ForEach(items) { t in row(t) }
            } header: {
                let total = items.reduce(Decimal(0)) { $0 + $1.signedValue }
                HStack {
                    Text(group == .paid && !vm.manual ? "Lançamentos do banco" : group.label)
                        .foregroundStyle(group == .late ? Color.efExpense : group == .soon ? Color.efWarn : Color.secondary)
                    Spacer()
                    Text("\(items.count) · \(app.settings.hideValues ? "••••" : Money.format(total.magnitude, currency: app.currency))").monospacedDigit()
                }
                .font(.footnote.weight(.semibold))
                .textCase(nil)
            }
        }
    }

    @ViewBuilder private func row(_ t: Tx) -> some View {
        let selected = vm.selection.contains(t.id)
        Group {
            if vm.selecting {
                Button { vm.toggleSelected(t.id) } label: {
                    TransactionRow(t, today: vm.today, selecting: true, selected: selected)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            } else {
                NavigationLink(value: Route.transaction(t.id, t.date.yearMonth)) {
                    TransactionRow(t, today: vm.today) { Task { await vm.togglePaid(t) } }
                }
            }
        }
        .listRowBackground(Color.efSurface)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if vm.manual && !vm.selecting {
                Button { Task { await vm.togglePaid(t) } } label: {
                    Label(t.paid ? "Pendente" : t.type.isIncome ? "Recebido" : "Pago", systemImage: t.paid ? "arrow.uturn.backward" : "checkmark")
                }
                .tint(t.paid ? .gray : .efIncome)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: vm.manual) {
            if !vm.selecting {
                switch vm.mode {
                case .manual:
                    Button(role: .destructive) { delete(t) } label: { Label("Excluir", systemImage: "trash") }
                    Button { moreFor = t } label: { Label("Mais", systemImage: "ellipsis.circle") }.tint(.gray)
                case .connected:
                    Button { router.edit(t) } label: { Label("Organizar", systemImage: "tag") }.tint(.efInfo)
                case .frozen: EmptyView()
                }
            }
        }
        .contextMenu { if !vm.selecting { menu(t) } }
    }

    @ViewBuilder private func menu(_ t: Tx) -> some View {
        switch vm.mode {
        case .frozen:
            NavigationLink(value: Route.transaction(t.id, t.date.yearMonth)) { Label("Ver detalhe", systemImage: "doc.text") }
        case .connected:
            Button { router.edit(t) } label: { Label("Organizar", systemImage: "tag") }
            NavigationLink(value: Route.transaction(t.id, t.date.yearMonth)) { Label("Ver detalhe", systemImage: "doc.text") }
        case .manual:
            Button { Task { await vm.togglePaid(t) } } label: {
                Label(t.paid ? "Voltar para pendente" : t.type.isIncome ? "Marcar como recebido" : "Marcar como pago",
                      systemImage: t.paid ? "arrow.uturn.backward" : "checkmark.circle")
            }
            Button { router.edit(t) } label: { Label("Editar", systemImage: "pencil") }
            Button { Task { if let c = await vm.duplicate(t) { router.push(.transaction(c.id, c.date.yearMonth)) } } } label: {
                Label("Duplicar", systemImage: "plus.square.on.square")
            }
            Button { vm.startSelection(t.id) } label: { Label("Selecionar", systemImage: "checkmark.circle") }
            Divider()
            Button(role: .destructive) { delete(t) } label: { Label("Excluir", systemImage: "trash") }
        }
    }

    private func delete(_ t: Tx) {
        if t.hasScope { scopeFor = t } else { Task { await vm.delete([t]) } }
    }

    private var emptySection: some View {
        Section {
            VStack(spacing: 12) {
                EmptyStateView("magnifyingglass", "Nada por aqui",
                               message: vm.all.isEmpty ? "Nenhum lançamento em \(DateFormats.monthName(vm.month))." : "Mude os filtros ou a busca.")
                if !vm.all.isEmpty {
                    Button("Limpar filtros") { vm.clearFilters() }.buttonStyle(.bordered).buttonBorderShape(.capsule).tint(.efTint)
                } else if vm.manual {
                    Button("Lançar agora") { router.newTransaction(.variable, month: vm.month) }.buttonStyle(.bordered).buttonBorderShape(.capsule).tint(.efTint)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        }
        .listRowBackground(Color.clear)
    }

    private var selectionBar: some View {
        HStack {
            Button { Task { await vm.paySelected() } } label: { Label("Pagar", systemImage: "checkmark.circle") }
                .disabled(vm.selected.allSatisfy(\.paid))
            Spacer()
            Button(role: .destructive) { confirmBatchDelete = true } label: { Label("Excluir", systemImage: "trash") }
                .tint(.efExpense)
        }
        .font(.headline)
        .labelStyle(.titleAndIcon)
        .disabled(vm.selection.isEmpty)
        .padding(.horizontal, 24).padding(.vertical, 14)
        .efGlass(cornerRadius: 28)
        .padding(.horizontal, 16).padding(.bottom, 6)
    }
}

// MARK: - escopo de recorrentes e parcelas

extension View {
    /// Pergunta "só este / este e os próximos / todos" (recorrente) ou "só esta parcela / … / todas as parcelas".
    func scopeDialog(item: Binding<Tx?>, question: String, destructive: Bool = true, action: @escaping (Tx, SeriesScope) -> Void) -> some View {
        let t = item.wrappedValue
        return confirmationDialog(t.map { $0.isRecurring ? "Este lançamento se repete" : "Parcela \($0.plot ?? "")" } ?? "",
                                  isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } }),
                                  titleVisibility: .visible, presenting: t) { t in
            let role: ButtonRole? = destructive ? .destructive : nil
            Button(t.isRecurring ? "Só este" : "Só esta parcela", role: role) { action(t, .this) }
            Button(t.isRecurring ? "Este e os próximos" : "Esta e as próximas", role: role) { action(t, .next) }
            Button(t.isRecurring ? "Todos da série" : "Todas as parcelas", role: role) { action(t, .all) }
            Button("Cancelar", role: .cancel) {}
        } message: { _ in Text(question) }
    }
}
