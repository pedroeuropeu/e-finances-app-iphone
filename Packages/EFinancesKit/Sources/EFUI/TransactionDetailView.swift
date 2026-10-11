import SwiftUI
import EFCore
import EFFeatures

/// Tudo sobre um lançamento: situação, parcela, categoria, contato, conta, centro de custo, pagamento e repetição.
struct TransactionDetailView: View {
    let id: Int64
    let month: YearMonth?

    var body: some View {
        Screen({ TransactionDetailViewModel(app: $0, id: id, month: month) }) { vm in DetailContent(vm: vm) }
    }
}

private struct DetailContent: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let vm: TransactionDetailViewModel
    @State private var scopeFor: Tx?

    var body: some View {
        LoadableContent(vm.state, retry: { await vm.load() }) { t in content(t) }
            .background(Color.efBackground.ignoresSafeArea())
            .navigationTitle(vm.state.value?.description ?? "Lançamento")
            .efLargeTitle(false)
            .toolbar { if let t = vm.state.value { toolbar(t) } }
            .scopeDialog(item: $scopeFor, question: "O que você quer excluir?") { _, scope in remove(scope) }
            .task { if vm.state.value == nil { await vm.load() } }
            .onChange(of: app.dataVersion) { Task { await vm.load() } }
    }

    private var manual: Bool { vm.mode == .manual }

    @ToolbarContentBuilder private func toolbar(_ t: Tx) -> some ToolbarContent {
        ToolbarItemGroup(placement: .efTrailing) {
            switch vm.mode {
            case .manual:
                Button("Editar") { router.edit(t) }
                Menu {
                    Button { duplicate() } label: { Label("Duplicar", systemImage: "plus.square.on.square") }
                    Menu {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Button { Task { await vm.move(to: type) } } label: {
                                if type == t.type { Label(type.label, systemImage: "checkmark") } else { Text(type.label) }
                            }
                        }
                    } label: { Label("Mover de tipo", systemImage: "arrow.left.arrow.right") }
                    Button { router.web = app.page("Recibo", "finances/transactions") } label: { Label("Emitir recibo (web)", systemImage: "doc.text") }
                    ShareLink(item: shareText(t)) { Label("Compartilhar", systemImage: "square.and.arrow.up") }
                    Divider()
                    Button(role: .destructive) { delete(t) } label: { Label("Excluir", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Mais ações")
            case .connected:
                Button("Organizar") { router.edit(t) }
            case .frozen:
                ShareLink(item: shareText(t)) { Image(systemName: "square.and.arrow.up") }
            }
        }
    }

    private func content(_ t: Tx) -> some View {
        let status = t.dueStatus(today: vm.today)
        return List {
            Section {
                VStack(spacing: 10) {
                    CategoryBadge(t.category, size: 64, fallbackName: t.description)
                    Text(t.description).font(.sora(22, .semibold, relativeTo: .title2)).multilineTextAlignment(.center)
                    Text([t.type.label, t.contact?.name].compactMap { $0 }.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                    MoneyText(t.value, signedIncome: t.type.isIncome, font: .sora(34, .semibold, relativeTo: .largeTitle), color: t.type.isIncome ? .efIncome : .efInk)
                    statusTag(t, status)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            switch vm.mode {
            case .frozen:
                Section { NoticeBanner(symbol: "snowflake", title: "Conta congelada", text: "Só consulta: o banco foi desconectado.", color: .secondary) }
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            case .connected:
                Section { NoticeBanner(symbol: "lock", title: "Valor e data vêm do banco", text: "Você pode organizar: descrição, categoria, contato, centro de custo e observações.") }
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            case .manual:
                Section {
                    Button { Task { await vm.togglePaid() } } label: {
                        Label(t.paid ? "Voltar para pendente" : t.type.isIncome ? "Marcar como recebido" : "Marcar como pago",
                              systemImage: t.paid ? "arrow.uturn.backward" : "checkmark")
                    }
                    .buttonStyle(t.paid ? .efSoft : status.isLate ? PrimaryButtonStyle(color: .efExpense, foreground: .white) : .efPrimary)
                    .sensoryFeedback(.success, trigger: t.paid)
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }

            if let inst = t.installment {
                let (n, total) = inst
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Parcela \(n) de \(total)").font(.headline)
                            Spacer()
                            HStack(spacing: 3) {
                                Text("Faltam \(total - n) ·").foregroundStyle(.secondary)
                                MoneyText(t.value * Decimal(total - n), font: .subheadline, color: .secondary)
                            }
                            .font(.subheadline)
                        }
                        ProgressBar(Double(n) / Double(max(total, 1)))
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                LabeledContent(t.type.isIncome ? "Recebimento em" : "Vencimento", value: DateFormats.api(t.date))
                LabeledContent("Competência", value: DateFormats.monthYear((t.refDate ?? t.date).yearMonth).capitalizedFirst)
                LabeledContent("Categoria") {
                    HStack(spacing: 6) {
                        if let c = t.category { CategoryBadge(c, size: 22) }
                        Text(t.category?.name ?? "Sem categoria")
                    }
                }
                LabeledContent(t.type.isIncome ? "Recebido de" : "Pago a", value: t.contact?.name ?? "—")
                LabeledContent("Conta", value: t.accountName.map { "\(app.company?.name ?? "") · \($0)" } ?? vm.accountName)
                LabeledContent("Centro de custo", value: t.costCenter?.name ?? "—")
                LabeledContent("Forma de pagamento", value: t.paymentType?.label ?? "—")
                LabeledContent("Repetição", value: repetition(t))
                if let doc = t.docNumber, !doc.isEmpty { LabeledContent("Nº do documento", value: doc) }
                if let notes = t.details, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Observações").foregroundStyle(.secondary).font(.subheadline)
                        Text(notes)
                    }
                }
            }
            .listRowBackground(Color.efSurface)

            if t.attachments > 0 {
                Section("Comprovantes") {
                    Button { router.web = app.page("Comprovantes", "finances/transactions") } label: {
                        Label("\(plural(t.attachments, "arquivo anexado", "arquivos anexados")) · ver na web", systemImage: "paperclip")
                    }
                }
                .listRowBackground(Color.efSurface)
            }

            if manual {
                Section {
                    HStack(spacing: 10) {
                        Button { router.web = app.page("Recibo", "finances/transactions") } label: { Label("Recibo", systemImage: "doc.text") }
                            .buttonStyle(.efSoft)
                        Button { duplicate() } label: { Label("Duplicar", systemImage: "plus.square.on.square") }
                            .buttonStyle(.efSoft)
                    }
                    Button(role: .destructive) { delete(t) } label: { Label("Excluir lançamento", systemImage: "trash") }
                        .buttonStyle(.efDanger)
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
        }
        .efGroupedList()
        .scrollContentBackground(.hidden)
        .refreshable { await vm.load() }
    }

    @ViewBuilder private func statusTag(_ t: Tx, _ s: DueStatus) -> some View {
        if vm.mode != .manual {
            Tag("Veio do \(app.account?.bankName ?? "banco") · \(DateFormats.api(t.date))", symbol: "link", color: .efInfo)
        } else {
            let label = s.label(income: t.type.isIncome) + (t.paid ? " em \(DateFormats.dayMonth(t.date))" : "")
            switch s {
            case .paid: Tag(label, symbol: "checkmark.circle.fill", color: .efIncome)
            case .late: Tag(label, symbol: "exclamationmark.circle.fill", color: .efExpense)
            case .dueSoon: Tag(label, symbol: "clock", color: .efWarn)
            case .scheduled: Tag(label, symbol: "calendar", color: .secondary)
            }
        }
    }

    private func repetition(_ t: Tx) -> String {
        switch t.paymentMode {
        case .oneTime: return t.installment == nil ? "À vista" : "Parcelado"
        case .installments: return "Parcelado"
        case .recurring:
            var s = "Recorrente"
            if let r = vm.series?.frequency ?? t.recurrence { s += " · \(r.label.lowercased())" }
            if let end = vm.series?.endDate { s += " · termina em \(DateFormats.shortMonthYear(end))" }
            return s
        }
    }

    private func shareText(_ t: Tx) -> String {
        let value = Money.format(t.value, currency: app.currency)
        let when = t.paid ? (t.type.isIncome ? "recebido em" : "pago em") : (t.type.isIncome ? "a receber em" : "vence em")
        return "\(t.description) · \(value) · \(when) \(DateFormats.api(t.date))\(t.category.map { " · \($0.name)" } ?? "")"
    }

    private func duplicate() {
        Task {
            if let copy = await vm.duplicate() { router.push(.transaction(copy.id, copy.date.yearMonth)) }
        }
    }

    private func delete(_ t: Tx) {
        if t.hasScope { scopeFor = t } else { remove(.this) }
    }

    private func remove(_ scope: SeriesScope) {
        Task {
            await vm.delete(scope: scope)
            dismiss()
        }
    }
}
