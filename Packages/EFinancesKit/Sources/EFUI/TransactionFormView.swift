import SwiftUI
import EFCore
import EFFeatures

/// Lançar, editar ou organizar (lançamento do banco) numa folha.
struct TransactionFormView: View {
    let request: FormRequest

    var body: some View {
        Screen({ TransactionFormViewModel(app: $0, id: request.txId, type: request.type, month: request.month, date: request.date) }) { vm in
            FormContent(vm: vm)
        }
    }
}

private struct FormContent: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let vm: TransactionFormViewModel
    @State private var confirmDiscard = false
    @State private var showAllInstallments = false
    @FocusState private var focus: Field?

    enum Field: Hashable { case amount, description, doc, notes }

    private var d: TransactionDraft { vm.draft }
    private var income: Bool { d.type.isIncome }
    private var title: String { vm.organizeOnly ? "Organizar" : vm.editing ? "Editar lançamento" : "Novo lançamento" }

    var body: some View {
        NavigationStack {
            Group {
                if vm.loading { LoadingView() } else { form }
            }
            .navigationTitle(title)
            .efLargeTitle(false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { close() } label: { Image(systemName: "xmark") }.accessibilityLabel("Cancelar")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.saving { ProgressView() } else {
                        Button { Task { await vm.save() } } label: { Image(systemName: "checkmark") }
                            .fontWeight(.semibold)
                            .accessibilityLabel("Salvar")
                    }
                }
            }
            .confirmationDialog("Descartar este lançamento?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Descartar alterações", role: .destructive) { dismiss() }
                Button("Continuar editando", role: .cancel) {}
            }
            .confirmationDialog("Este lançamento se repete", isPresented: Binding(get: { vm.askScope }, set: { vm.askScope = $0 }), titleVisibility: .visible) {
                Button("Só este") { Task { await vm.save(scope: .this) } }
                Button("Este e os próximos") { Task { await vm.save(scope: .next) } }
                Button("Todos da série") { Task { await vm.save(scope: .all) } }
                Button("Cancelar", role: .cancel) {}
            } message: { Text("Salvar as alterações em quais lançamentos?") }
        }
        .interactiveDismissDisabled(vm.dirty || (vm.editing && vm.contentChanged))
        .task { await vm.load(); if !vm.editing { focus = .amount } }
        .onChange(of: vm.saved) { _, saved in if saved { Haptics.success(); dismiss() } }
    }

    private func close() {
        if vm.dirty || (vm.editing && vm.contentChanged) { confirmDiscard = true } else { dismiss() }
    }

    // MARK: formulário

    private var form: some View {
        @Bindable var vm = vm
        return Form {
            if vm.organizeOnly {
                Section {
                    NoticeBanner(symbol: "lock", title: "Veio do \(vm.bankName ?? "banco")",
                                 text: "Valor, data e situação não mudam. Organize a descrição, a categoria, o contato, o centro de custo e as observações.")
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            } else {
                Section {
                    Picker("Tipo", selection: Binding(get: { vm.draft.type }, set: { vm.setType($0) })) {
                        Text("Recebimento").tag(TransactionType.income)
                        Text("Fixa").tag(TransactionType.fixed)
                        Text("Variável").tag(TransactionType.variable)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Tipo de lançamento")
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }

            Section { amount }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())

            Section {
                VStack(alignment: .leading, spacing: 2) {
                    TextField(income ? "Descrição (ex.: Aluguel recebido)" : "Descrição (ex.: Conta de luz)", text: $vm.draft.description)
                        .focused($focus, equals: .description)
                        .submitLabel(.done)
                    if let e = vm.errors["description"] { Text(e).font(.caption).foregroundStyle(Color.efExpense) }
                }
                if !vm.organizeOnly { dateRow }
                NavigationLink {
                    CategoryPicker(vm: vm)
                } label: {
                    LabeledContent("Categoria") {
                        HStack(spacing: 6) {
                            if let c = d.category { CategoryBadge(c, size: 22) }
                            Text(vm.categoryLabel ?? "Escolher").foregroundStyle(vm.categoryLabel == nil ? .tertiary : .secondary)
                        }
                    }
                }
                NavigationLink {
                    ContactPicker(vm: vm)
                } label: {
                    LabeledContent(income ? "Recebido de" : "Pago a") {
                        Text(vm.contactLabel ?? "Opcional").foregroundStyle(vm.contactLabel == nil ? .tertiary : .secondary)
                    }
                }
                if !vm.organizeOnly {
                    LabeledContent("Conta", value: vm.accountName)
                    Toggle(income ? "Já foi recebido" : "Já foi pago", isOn: $vm.draft.paid)
                    Picker("Pagamento", selection: Binding(get: { vm.draft.paymentType }, set: { vm.setPaymentType($0) })) {
                        ForEach(PaymentType.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                }
            } footer: {
                if !vm.organizeOnly && d.paid { Text("Entra no saldo da conta agora.") }
            }

            if !vm.organizeOnly { repetition }

            Section {
                DisclosureGroup("Mais detalhes", isExpanded: $vm.showMore) {
                    Picker("Centro de custo", selection: $vm.draft.costCenter) {
                        Text("Nenhum").tag(CostCenter?.none)
                        ForEach(vm.costCenters) { Text($0.name).tag(Optional($0)) }
                    }
                    if !vm.organizeOnly {
                        competence
                        TextField("Nº do documento (nota fiscal, boleto…)", text: $vm.draft.docNumber)
                            .focused($focus, equals: .doc)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Observações").font(.footnote).foregroundStyle(Color.secondary)
                        TextField("Opcional", text: $vm.draft.details, axis: .vertical)
                            .lineLimit(2...6)
                            .focused($focus, equals: .notes)
                    }
                }
            }

            Section {
                Button {
                    focus = nil
                    Task { await vm.save() }
                } label: {
                    HStack(spacing: 8) {
                        if vm.saving { ProgressView().tint(Color.efOnPrimary) } else { Image(systemName: "checkmark") }
                        Text(vm.organizeOnly ? "Salvar organização" : "Salvar lançamento")
                    }
                }
                .buttonStyle(.efPrimary)
                .disabled(vm.saving)
            }
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            #if os(iOS)
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { focus = nil }.fontWeight(.semibold)
            }
            #endif
        }
    }

    // MARK: valor

    private var amount: some View {
        VStack(spacing: 4) {
            Text(vm.organizeOnly ? "Valor" : income ? "Valor a receber" : "Valor a pagar").font(.subheadline).foregroundStyle(Color.secondary)
            ZStack {
                Text(Money.format(cents: d.cents, currency: app.currency))
                    .font(.sora(44, .semibold, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .foregroundStyle(d.cents == 0 ? Color.secondary.opacity(0.6) : income ? Color.efIncome : Color.efInk)
                    .contentTransition(.numericText())
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .animation(.snappy, value: d.cents)
                if !vm.organizeOnly {
                    TextField("", text: Binding(get: { d.cents == 0 ? "" : String(d.cents) }, set: { new in
                        let digits = new.filter(\.isNumber).prefix(11)
                        vm.draft.cents = Int64(String(digits)) ?? 0
                    }))
                    .efNumberField()
                    .focused($focus, equals: .amount)
                    .foregroundStyle(.clear)
                    .tint(.clear)
                    .opacity(0.02)
                    .accessibilityLabel(income ? "Valor a receber" : "Valor a pagar")
                    .accessibilityValue(Money.format(cents: d.cents, currency: app.currency))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if !vm.organizeOnly { focus = .amount } }
            Group {
                if vm.organizeOnly {
                    Label("\(DateFormats.api(d.date)) · \(d.paid ? "pago" : "pendente")", systemImage: "lock")
                } else if let e = vm.errors["value"] {
                    Text(e).foregroundStyle(Color.efExpense)
                } else {
                    Text(focus == .amount ? "Os centavos entram pela direita" : "Toque para digitar")
                }
            }
            .font(.footnote).foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    // MARK: data

    private var dateRow: some View {
        @Bindable var vm = vm
        let today = vm.today
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(income ? "Recebimento" : "Vencimento")
                Spacer(minLength: 4)
                DatePicker(income ? "Recebimento" : "Vencimento", selection: $vm.draft.date.asDate, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "pt_BR"))
            }
            HStack(spacing: 8) {
                dateChip("Hoje", on: d.date == today) { vm.draft.date = today }
                dateChip("Amanhã", on: d.date == today.plusDays(1)) { vm.draft.date = today.plusDays(1) }
                dateChip("Fim do mês", on: d.date == today.yearMonth.lastDay) { vm.draft.date = today.yearMonth.lastDay }
            }
        }
    }

    private func dateChip(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(.subheadline.weight(.medium))
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(on ? .efTint : .secondary)
            .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: repetição

    @ViewBuilder private var repetition: some View {
        @Bindable var vm = vm
        if vm.editing {
            if vm.recurringEdit {
                Section {
                    LabeledContent("Frequência", value: (vm.series?.frequency ?? d.recurrence).label)
                    seriesEnd
                } header: { Text("Repetição") } footer: {
                    Text("Mudar o “Termina em” vale para a série toda.")
                }
            } else if let o = vm.original, let inst = o.installment {
                Section {
                    LabeledContent("Parcela", value: "\(inst.0) de \(inst.1)")
                } header: { Text("Repetição") } footer: { Text("A alteração vale só para esta parcela.") }
            }
        } else {
            Section {
                Picker("Repetição", selection: $vm.draft.paymentMode) {
                    ForEach(PaymentMode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            } header: { Text("Repetição") }

            switch d.paymentMode {
            case .installments: installments
            case .recurring:
                Section {
                    Picker("Frequência", selection: $vm.draft.recurrence) {
                        ForEach(Recurrence.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    seriesEnd
                } footer: {
                    Text("Lançamos o próximo automaticamente, \(d.recurrence.label.lowercased())\(d.seriesEnd.map { ", até \(DateFormats.shortMonthYear($0))" } ?? ", até você parar").")
                }
            case .oneTime: EmptyView()
            }
        }
    }

    private var seriesEnd: some View {
        @Bindable var vm = vm
        return Group {
            Toggle("Termina em uma data", isOn: Binding(get: { vm.draft.seriesEnd != nil }, set: { on in
                vm.draft.seriesEnd = on ? (vm.series?.endDate ?? vm.draft.date.plusMonths(11)) : nil
            }))
            if let end = d.seriesEnd {
                DatePicker("Último lançamento", selection: Binding(get: { end.date }, set: { vm.draft.seriesEnd = LocalDate($0) }),
                           in: d.date.date..., displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "pt_BR"))
            }
        }
    }

    @ViewBuilder private var installments: some View {
        @Bindable var vm = vm
        Section {
            Stepper(value: Binding(get: { vm.draft.installments }, set: { vm.setInstallments($0) }), in: 2...48) {
                LabeledContent("Parcelas", value: "\(d.installments)×")
            }
            Picker("Valor", selection: $vm.draft.valueIsTotal) {
                Text("Valor é o total").tag(true)
                Text("Valor é a parcela").tag(false)
            }
            .pickerStyle(.segmented)
            Picker("Frequência", selection: $vm.draft.recurrence) {
                ForEach(Recurrence.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            if let plan = vm.plan {
                let shown = showAllInstallments ? plan.count : min(plan.count, 3)
                ForEach(0..<shown, id: \.self) { i in installmentRow(plan, i) }
                if plan.count > 3 {
                    Button(showAllInstallments ? "Mostrar menos" : "Ver as \(plan.count) parcelas") { withAnimation { showAllInstallments.toggle() } }
                }
            }
        } footer: {
            if let plan = vm.plan {
                Text("\(plan.count)× · total \(Money.format(plan.total, currency: app.currency))\(plan.even ? "" : ". A 1ª parcela leva os centavos que sobram.") Toque numa data para mudar só aquela parcela.")
            }
            if let e = vm.errors["installments"] { Text(e).foregroundStyle(Color.efExpense) }
        }
    }

    private func installmentRow(_ plan: InstallmentPlan, _ i: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(i + 1)ª").foregroundStyle(Color.secondary).frame(width: 30, alignment: .leading)
            MoneyText(plan.values[i], font: .body)
            Spacer(minLength: 4)
            if plan.custom.contains(i) {
                Button { vm.resetInstallmentDate(i) } label: { Image(systemName: "arrow.uturn.backward.circle") }
                    .buttonStyle(.plain).foregroundStyle(Color.efTint)
                    .accessibilityLabel("Voltar à data automática")
            }
            DatePicker("Data da \(i + 1)ª parcela", selection: Binding(get: { plan.dates[i].date }, set: { vm.setInstallmentDate(i, LocalDate($0)) }),
                       displayedComponents: .date)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "pt_BR"))
        }
    }

    // MARK: competência

    private var competence: some View {
        let ref = d.refMonth ?? d.date.yearMonth
        return HStack {
            Text("Competência")
            Spacer()
            Button { vm.draft.refMonth = ref.minusMonths(1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless).accessibilityLabel("Mês anterior")
            Text(DateFormats.monthYear(ref).capitalizedFirst).foregroundStyle(d.refMonth == nil ? .secondary : .primary).monospacedDigit()
            Button { vm.draft.refMonth = ref.plusMonths(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless).accessibilityLabel("Próximo mês")
        }
    }
}

// MARK: - escolher categoria

private struct CategoryPicker: View {
    @Environment(\.dismiss) private var dismiss
    let vm: TransactionFormViewModel
    @State private var query = ""

    var body: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        let list = vm.suggestedCategories.filter { q.isEmpty || $0.name.normalizedForSearch.contains(q.normalizedForSearch) }
        let exact = vm.categories.contains { $0.name.normalizedForSearch == q.normalizedForSearch }
        List {
            if !q.isEmpty && !exact {
                Button { vm.newCategory(q); dismiss() } label: { Label("Criar categoria “\(q)”", systemImage: "plus.circle.fill") }
            }
            Section {
                Button { vm.setCategory(nil); dismiss() } label: {
                    HStack { Text("Sem categoria").foregroundStyle(Color.efInk); Spacer(); if vm.categoryLabel == nil { check } }
                }
                ForEach(list) { c in
                    Button { vm.setCategory(c); dismiss() } label: {
                        HStack(spacing: 12) {
                            CategoryBadge(c, size: 32)
                            Text(c.name).foregroundStyle(Color.efInk)
                            Spacer()
                            if vm.draft.category?.id == c.id { check }
                        }
                    }
                }
            } footer: {
                if let name = vm.draft.newCategoryName { Text("A categoria “\(name)” será criada ao salvar.") }
            }
        }
        .efGroupedList()
        .navigationTitle("Categoria")
        .efLargeTitle(false)
        .searchable(text: $query, prompt: "Buscar ou criar categoria")
    }

    private var check: some View { Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.efTint) }
}

// MARK: - escolher contato

private struct ContactPicker: View {
    @Environment(\.dismiss) private var dismiss
    let vm: TransactionFormViewModel
    @State private var query = ""

    var body: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        let list = vm.contacts.filter { q.isEmpty || $0.name.normalizedForSearch.contains(q.normalizedForSearch) }
        let exact = vm.contacts.contains { $0.name.normalizedForSearch == q.normalizedForSearch }
        List {
            if !q.isEmpty && !exact {
                Button { vm.newContact(q); dismiss() } label: { Label("Criar contato “\(q)”", systemImage: "person.crop.circle.badge.plus") }
            }
            Section {
                Button { vm.setContact(nil); dismiss() } label: {
                    HStack { Text("Nenhum").foregroundStyle(Color.efInk); Spacer(); if vm.contactLabel == nil { check } }
                }
                ForEach(list) { c in
                    Button { vm.setContact(c); dismiss() } label: {
                        HStack(spacing: 12) {
                            InitialsBadge(c.name, color: c.category?.color ?? .efInfo, size: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.name).foregroundStyle(Color.efInk)
                                if let cat = c.category { Text(cat.label).font(.caption).foregroundStyle(Color.secondary) }
                            }
                            Spacer()
                            if vm.draft.contact?.id == c.id { check }
                        }
                    }
                }
            } footer: {
                if let name = vm.draft.newContactName { Text("O contato “\(name)” será criado ao salvar.") }
            }
        }
        .efGroupedList()
        .navigationTitle(vm.draft.type.isIncome ? "Recebido de" : "Pago a")
        .efLargeTitle(false)
        .searchable(text: $query, prompt: "Buscar ou criar contato")
    }

    private var check: some View { Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.efTint) }
}
