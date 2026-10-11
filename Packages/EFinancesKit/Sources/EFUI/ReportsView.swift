import SwiftUI
import EFCore
import EFFeatures

/// Relatórios do período: totais com variação, evolução mensal, gastos por dia, composição e maiores despesas.
struct ReportsView: View {
    var body: some View {
        Screen(ReportsViewModel.init) { vm in ReportsContent(vm: vm) }
    }
}

private struct ReportsContent: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    let vm: ReportsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EFLayout.section) {
                Text("\(app.company?.name ?? "") · \(vm.accountName)").font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, EFLayout.gutter)
                filters
                LoadableContent(vm.state, retry: { await vm.load() }) { r in content(r) }
                    .frame(minHeight: vm.state.value == nil ? 300 : nil)
            }
            .padding(.bottom, 24)
        }
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle("Relatórios")
        .efLargeTitle()
        .refreshable { await vm.load() }
        .toolbar {
            if let r = vm.state.value {
                ToolbarItem(placement: .efTrailing) {
                    ShareLink(item: summary(r)) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Compartilhar resumo")
                }
            }
        }
        .sheet(isPresented: Binding(get: { vm.day != nil }, set: { if !$0 { vm.closeDay() } })) { DaySheet(vm: vm) }
        .task { if vm.state.value == nil { await vm.load() } }
        .onChange(of: app.workspaceVersion) { Task { await vm.load() } }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ReportPeriod.allCases, id: \.self) { p in
                        FilterChip(p.label, selected: vm.period == p) { Task { await vm.setPeriod(p) } }
                    }
                }
                .padding(.horizontal, EFLayout.gutter)
            }
            Picker("Situação", selection: Binding(get: { vm.status }, set: { s in Task { await vm.setStatus(s) } })) {
                ForEach(ReportStatus.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, EFLayout.gutter)
        }
    }

    @ViewBuilder private func content(_ r: ReportOverview) -> some View {
        let c = r.current, p = r.previous
        VStack(alignment: .leading, spacing: EFLayout.section) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                let vi = variationText(c.income, p.income), ve = variationText(c.expense, p.expense, goodUp: false), vn = variationText(c.net, p.net)
                KPITile("Receitas", value: c.income, color: .efIncome, detail: vi.0, detailColor: vi.1)
                KPITile("Despesas", value: c.expense, color: .efExpense, detail: ve.0, detailColor: ve.1)
                KPITile("Resultado", value: c.net, color: c.net >= 0 ? .efIncome : .efExpense, detail: vn.0, detailColor: vn.1)
                KPITile("Margem", text: "\(c.margin)%", detail: "do que entrou")
                KPITile("Despesa média", value: c.expense / Decimal(r.monthsCount), detail: "por mês")
                KPITile("Em aberto", value: c.openExpense, color: c.openExpense > 0 ? .efExpense : nil, detail: "despesas a pagar")
            }
            .padding(.horizontal, EFLayout.gutter)

            if !r.months.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("Evolução mensal", subtitle: "\(DateFormats.monthName(r.start.yearMonth)) a \(DateFormats.monthName(r.end.yearMonth))")
                    VStack(alignment: .leading, spacing: 10) {
                        FlowChart(r.months)
                        HStack(spacing: 14) { legend("Receitas", .efGreen); legend("Despesas", .efExpense) }.font(.caption)
                    }
                    .efCard()
                }
                .padding(.horizontal, EFLayout.gutter)
            }

            heatCalendar(r)
            composition(r)

            if !r.topExpenses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("Maiores despesas")
                    VStack(spacing: 0) {
                        ForEach(Array(r.topExpenses.prefix(5).enumerated()), id: \.element.id) { i, e in
                            NavigationLink(value: Route.transaction(e.id, e.date?.yearMonth)) {
                                HStack(spacing: 12) {
                                    let look = Icons.visual(forName: e.category ?? e.description)
                                    IconBadge(symbol: look.0, color: look.1, size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(e.description).foregroundStyle(Color.efInk).lineLimit(1)
                                        Text([e.date.map(DateFormats.api), e.category].compactMap { $0 }.joined(separator: " · ")).font(.footnote).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 6)
                                    MoneyText(e.value, currency: r.currency, font: .subheadline.weight(.medium))
                                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            if i < min(r.topExpenses.count, 5) - 1 { Divider().padding(.leading, 62) }
                        }
                    }
                    .background(Color.efSurface, in: RoundedRectangle(cornerRadius: EFLayout.cardRadius, style: .continuous))
                }
                .padding(.horizontal, EFLayout.gutter)
            }
        }
    }

    private func legend(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 7, height: 7); Text(label).foregroundStyle(.secondary) }
    }

    // MARK: gastos por dia

    @ViewBuilder private func heatCalendar(_ r: ReportOverview) -> some View {
        let month = r.end.yearMonth
        let days = r.days.filter { $0.date.yearMonth == month }
        let maxDay = days.map(\.expense).max() ?? 0
        let byDay = Dictionary(days.map { ($0.date, $0.expense) }, uniquingKeysWith: +)
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Gastos por dia", subtitle: "\(DateFormats.monthYearTitle(month)) · toque num dia")
            VStack(spacing: 10) {
                MonthCalendar(month: month, today: vm.today, selected: nil,
                              heat: { d in maxDay > 0 ? ((byDay[d] ?? 0) / maxDay).doubleValue : 0 }) { d in Task { await vm.openDay(d) } }
                HStack(spacing: 14) {
                    legend("Pouco", Color.efExpense.opacity(0.2))
                    legend("Muito", Color.efExpense.opacity(0.7))
                }
                .font(.caption)
            }
            .efCard(padding: 12)
        }
        .padding(.horizontal, EFLayout.gutter)
    }

    // MARK: composição

    private func composition(_ r: ReportOverview) -> some View {
        @Bindable var vm = vm
        let shares = vm.composition
        let slices = shares.donutSlices(max: 5)
        let total = shares.reduce(Decimal(0)) { $0 + $1.value }
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Composição das despesas")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ReportDimension.allCases, id: \.self) { d in
                        FilterChip(d.label, selected: vm.dimension == d) { vm.dimension = d }
                    }
                }
            }
            if vm.dimension == .contact {
                Picker("Tipo de contato", selection: $vm.contactKind) {
                    Text("Todos").tag(ContactCategory?.none)
                    ForEach(ContactCategory.allCases, id: \.self) { Text($0.pluralLabel).tag(Optional($0)) }
                }
                .pickerStyle(.segmented)
            }
            if shares.isEmpty {
                Text("Nada no período.").foregroundStyle(.secondary).frame(maxWidth: .infinity).efCard()
            } else {
                HStack(spacing: 18) {
                    DonutChart(slices, centerLabel: "Despesas", centerValue: app.settings.hideValues ? "••••" : Money.compact(total, currency: r.currency))
                        .frame(width: 138, height: 138)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(slices) { s in
                            HStack(spacing: 8) {
                                Circle().fill(s.color).frame(width: 9, height: 9)
                                Text(s.label).font(.subheadline).lineLimit(1)
                                Spacer(minLength: 4)
                                Text("\(s.percent)%").font(.subheadline.weight(.semibold)).monospacedDigit()
                            }
                        }
                    }
                }
                .efCard()
                VStack(spacing: 12) {
                    ForEach(Array(shares.prefix(6).enumerated()), id: \.element.id) { i, s in
                        HStack(spacing: 10) {
                            Text("\(i + 1)").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).frame(width: 20)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(s.name).lineLimit(1)
                                    Spacer()
                                    MoneyText(s.value, currency: r.currency, font: .subheadline.weight(.medium))
                                    Text("\(s.percent)%").font(.caption).foregroundStyle(.secondary).frame(width: 36, alignment: .trailing)
                                }
                                ProgressBar(Double(s.percent) / 100, color: slices.first { $0.label == s.name }?.color ?? .secondary)
                            }
                        }
                    }
                }
                .efCard()
            }
        }
        .padding(.horizontal, EFLayout.gutter)
    }

    private func summary(_ r: ReportOverview) -> String {
        let c = r.current
        return """
        e-Finances · \(vm.accountName) · \(DateFormats.api(r.start)) a \(DateFormats.api(r.end))
        Receitas: \(Money.format(c.income, currency: r.currency))
        Despesas: \(Money.format(c.expense, currency: r.currency))
        Resultado: \(Money.format(c.net, currency: r.currency)) (margem de \(c.margin)%)
        Em aberto: \(Money.format(c.openExpense, currency: r.currency))
        """
    }
}

// MARK: - despesas do dia

private struct DaySheet: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let vm: ReportsViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch vm.day {
                case .ready(let d): list(d)
                case .failed(let e): ErrorView(e) {}
                default: LoadingView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() }.fontWeight(.semibold) }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func list(_ d: DayExpenses) -> some View {
        List {
            if d.items.isEmpty {
                Text("Nenhuma despesa neste dia.").foregroundStyle(.secondary)
            }
            Section {
                ForEach(d.items) { t in
                    Button {
                        dismiss()
                        router.push(.transaction(t.id, d.date.yearMonth))
                    } label: {
                        HStack(spacing: 12) {
                            CategoryBadge(t.category, size: 36, fallbackName: t.description)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.description).foregroundStyle(Color.efInk).lineLimit(1)
                                Text((t.contact ?? t.category?.name ?? "") + (t.paid ? "" : " · em aberto")).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 6)
                            MoneyText(t.value, font: .subheadline.weight(.medium))
                        }
                    }
                }
            } footer: {
                if d.open > 0 { Text("\(Money.format(d.open)) ainda em aberto.") }
            }
            Section {
                Button("Abrir em Transações") {
                    dismiss()
                    router.showTransactions()
                }
            }
        }
        .efGroupedList()
        .navigationTitle("\(d.date.day) de \(DateFormats.monthNames[d.date.month - 1])")
        .efLargeTitle(false)
    }
}

// MARK: - notificações

struct NotificationsView: View {
    var body: some View {
        Screen(NotificationsViewModel.init) { vm in NotificationsContent(vm: vm) }
    }
}

private struct NotificationsContent: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    let vm: NotificationsViewModel

    var body: some View {
        @Bindable var vm = vm
        List {
            Section {
                Picker("Mostrar", selection: Binding(get: { vm.unreadOnly }, set: { v in Task { await vm.setUnreadOnly(v) } })) {
                    Text("Todas").tag(false)
                    Text(vm.unread > 0 ? "Não lidas (\(vm.unread))" : "Não lidas").tag(true)
                }
                .pickerStyle(.segmented)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([NotificationCategory.limit, .payment, .support, .security, .system], id: \.self) { c in
                            FilterChip(c.label, selected: vm.category == c) { vm.category = vm.category == c ? nil : c }
                        }
                    }
                }
            }
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
            .listRowSeparator(.hidden)

            switch vm.state {
            case .loading: Section { LoadingView().frame(minHeight: 240) }.listRowBackground(Color.clear)
            case .failed(let e): Section { ErrorView(e) { await vm.load() } }.listRowBackground(Color.clear)
            case .ready:
                if vm.filtered.isEmpty {
                    Section {
                        EmptyStateView("bell.slash", "Nenhuma notificação", message: vm.unreadOnly ? "Você leu tudo." : "Quando algo acontecer, avisamos aqui.")
                            .frame(maxWidth: .infinity).padding(.vertical, 30)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(grouped(vm.filtered), id: \.0) { title, items in
                        Section(title) {
                            ForEach(items) { n in row(n) }
                        }
                        .listRowBackground(Color.efSurface)
                    }
                }
            }
        }
        .efGroupedList()
        .scrollContentBackground(.hidden)
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle("Notificações")
        .efLargeTitle()
        .refreshable { await vm.load() }
        .toolbar {
            ToolbarItem(placement: .efTrailing) {
                Button { Task { await vm.readAll() } } label: { Image(systemName: "checkmark.circle") }
                    .disabled(vm.unread == 0)
                    .accessibilityLabel("Marcar todas como lidas")
            }
        }
        .task { if vm.state.value == nil { await vm.load() } }
    }

    private func grouped(_ list: [AppNotification]) -> [(String, [AppNotification])] {
        let today = vm.now.date
        func group(_ n: AppNotification) -> Int {
            guard let at = n.createdAt?.date else { return 3 }
            let days = at.days(until: today)
            return days <= 0 ? 0 : days == 1 ? 1 : days < 7 ? 2 : 3
        }
        let titles = ["Hoje", "Ontem", "Esta semana", "Anteriores"]
        return (0..<4).compactMap { g in
            let items = list.filter { group($0) == g }
            return items.isEmpty ? nil : (titles[g], items)
        }
    }

    private func row(_ n: AppNotification) -> some View {
        Button { open(n) } label: {
            HStack(alignment: .top, spacing: 12) {
                SettingsIcon(symbol(n.category), color(n.severity))
                VStack(alignment: .leading, spacing: 3) {
                    Text(n.title).fontWeight(n.read ? .regular : .semibold).foregroundStyle(Color.efInk)
                    Text(n.body).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 6) {
                    if let at = n.createdAt { Text(DateFormats.ago(at, now: vm.now)).font(.caption2).foregroundStyle(.secondary) }
                    if !n.read { Circle().fill(Color.efInfo).frame(width: 9, height: 9).accessibilityLabel("Não lida") }
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .combine)
    }

    private func open(_ n: AppNotification) {
        Task { await vm.open(n) }
        switch NotificationsViewModel.destination(n) {
        case .limits: router.showPlanning(.limits)
        case .story: router.showStory = true
        case .support: router.push(.help)
        case .billing: router.push(.billing)
        case .accounts: router.open(.accounts)
        case .transactions: router.showTransactions()
        case .security: router.push(.security)
        case .none: break
        }
    }

    private func symbol(_ c: NotificationCategory) -> String {
        switch c {
        case .limit: "flag.fill"
        case .payment: "creditcard.fill"
        case .support: "bubble.left.and.bubble.right.fill"
        case .security: "lock.shield.fill"
        case .system: "bell.fill"
        case .admin: "megaphone.fill"
        case .signup: "person.badge.plus"
        case .queue: "tray.full.fill"
        }
    }

    private func color(_ s: NotificationSeverity) -> Color {
        switch s {
        case .info: .efInfo
        case .success: .efIncome
        case .warning: .efWarn
        case .danger: .efExpense
        }
    }
}
