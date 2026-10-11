import SwiftUI
import EFCore
import EFFeatures

/// Início: saldo e previsão, contas da empresa, vencimentos, agenda, para onde foi o dinheiro, limites, parcelas,
/// assinaturas e fluxo de caixa.
struct HomeView: View {
    var body: some View {
        Screen(HomeViewModel.init) { vm in HomeContent(vm: vm) }
    }
}

private struct HomeContent: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    let vm: HomeViewModel

    var body: some View {
        LoadableContent(vm.state, retry: { await vm.load() }) { data in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: EFLayout.section) {
                    header
                    HomeHero(data: data).padding(.horizontal, EFLayout.gutter)
                    AccountsCarousel(data: data)
                    alert(data)
                    quickActions(data)
                    if let story = data.story { storyCard(story) }
                    dueSoon(data)
                    agenda(data)
                    spending(data)
                    limits(data)
                    installments(data)
                    subscriptions(data)
                    flow(data)
                    if app.demo {
                        Text("Dados de exemplo · modo demonstração").font(.footnote).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 24)
            }
            .refreshable { await vm.load(silent: true) }
        }
        .background(Color.efBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .efLeading) { WorkspaceButton() }
            ToolbarItemGroup(placement: .efTrailing) {
                Button { app.toggleHide() } label: { Image(systemName: app.settings.hideValues ? "eye.slash" : "eye") }
                    .accessibilityLabel(app.settings.hideValues ? "Mostrar valores" : "Esconder valores")
                NavigationLink(value: Route.notifications) {
                    Image(systemName: app.unread > 0 ? "bell.badge" : "bell")
                }
                .accessibilityLabel(app.unread > 0 ? "Notificações, \(app.unread) não lidas" : "Notificações")
                NewTransactionMenu()
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { if vm.state.value == nil { await vm.load() } }
        .onChange(of: app.dataVersion) { Task { await vm.load(silent: true) } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(app.greeting), \(app.profile?.firstName ?? "")").font(.sora(30, .bold, relativeTo: .largeTitle)).lineLimit(1).minimumScaleFactor(0.7)
            Text(DateFormats.longDay(app.today).capitalizedFirst).foregroundStyle(.secondary)
        }
        .padding(.horizontal, EFLayout.gutter)
        .padding(.top, 4)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: alerta e ações

    @ViewBuilder private func alert(_ d: HomeData) -> some View {
        if d.mode != .frozen && (!d.late.isEmpty || !d.soon.isEmpty) {
            let parts = [d.late.isEmpty ? nil : plural(d.late.count, "conta atrasada", "contas atrasadas"),
                         d.soon.isEmpty ? nil : "\(d.soon.count) \(d.soon.count == 1 ? "vence" : "vencem") nos próximos 7 dias"].compactMap { $0 }
            NoticeBanner(symbol: d.late.isEmpty ? "clock" : "exclamationmark.circle.fill", title: "Fechamento do mês",
                         text: parts.joined(separator: " e ") + ".", color: d.late.isEmpty ? .efWarn : .efExpense,
                         action: "Ver contas") { router.showTransactions(TxFilters(status: .pending)) }
                .padding(.horizontal, EFLayout.gutter)
        }
    }

    private func quickActions(_ d: HomeData) -> some View {
        HStack(spacing: 10) {
            if d.mode == .manual {
                quick("Recebimento", "arrow.down.left") { router.newTransaction(.income) }
                quick("Despesa", "arrow.up.right") { router.newTransaction(.variable) }
            } else {
                quick("Organizar", "tag") { router.showTransactions() }
                quick("Contas", "building.columns") { router.open(.accounts) }
            }
            quick("A pagar", "calendar.badge.clock") { router.showTransactions(TxFilters(status: .pending)) }
            quick("Relatórios", "chart.bar") { router.push(.reports) }
        }
        .padding(.horizontal, EFLayout.gutter)
    }

    private func quick(_ label: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.title3).foregroundStyle(Color.efTint)
                    .frame(width: 52, height: 52)
                    .background(Color.efSurface, in: Circle())
                Text(label).font(.caption).foregroundStyle(Color.efInk).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func storyCard(_ story: Story) -> some View {
        Button {
            app.pendingStory = story
            router.showStory = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().strokeBorder(AngularGradient(colors: [.efGreen, .efInfo, .efGreen], center: .center), lineWidth: 3)
                    EFLogo(size: 30)
                }
                .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fechamento de \(story.periodLabel)").font(.subheadline.weight(.semibold)).foregroundStyle(Color.efInk)
                    Text("Quanto entrou, saiu e sobrou. Toque para ver.").font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .efCard(padding: 14)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, EFLayout.gutter)
    }

    // MARK: vencimentos e agenda

    @ViewBuilder private func dueSoon(_ d: HomeData) -> some View {
        if !d.due.isEmpty && d.mode == .manual {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Vencem em breve", subtitle: "Atrasadas e próximos 7 dias", action: "Ver todas") {
                    router.showTransactions(TxFilters(status: .pending))
                }
                rows(d.due, today: d.today)
            }
            .padding(.horizontal, EFLayout.gutter)
        }
    }

    private func rows(_ list: [Tx], today: LocalDate) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.element.id) { i, t in
                NavigationLink(value: Route.transaction(t.id, t.date.yearMonth)) {
                    TransactionRow(t, today: today) { Task { await vm.togglePaid(t) } }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                if i < list.count - 1 { Divider().padding(.leading, 66) }
            }
        }
        .background(Color.efSurface, in: RoundedRectangle(cornerRadius: EFLayout.cardRadius, style: .continuous))
    }

    private func agenda(_ d: HomeData) -> some View {
        @Bindable var vm = vm
        let dayList = d.day(vm.agendaDay)
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Agenda", subtitle: DateFormats.monthYearTitle(d.month), action: "Transações") { router.showTransactions() }
            VStack(spacing: 10) {
                MonthCalendar(month: d.month, today: d.today, selected: vm.agendaDay, dots: { day in
                    let items = d.monthTransactions.filter { $0.date == day }
                    var colors: [Color] = []
                    if items.contains(where: { $0.dueStatus(today: d.today).isLate }) { colors.append(.efWarn) }
                    if items.contains(where: { $0.type.isIncome }) { colors.append(.efIncome) }
                    if items.contains(where: { !$0.type.isIncome }) { colors.append(.efExpense) }
                    return colors
                }) { day in withAnimation(.snappy) { vm.agendaDay = day } }
                HStack(spacing: 14) {
                    legend("Recebimento", .efIncome)
                    legend("Despesa", .efExpense)
                    legend("Atrasada", .efWarn)
                }
                .font(.caption)
            }
            .efCard(padding: 12)
            HStack {
                Text("\(vm.agendaDay.day) de \(DateFormats.monthNames[vm.agendaDay.month - 1])").font(.subheadline.weight(.semibold))
                Spacer()
                if !dayList.isEmpty { Text(plural(dayList.count, "lançamento", "lançamentos")).font(.footnote).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 4).padding(.top, 4)
            if dayList.isEmpty {
                VStack(spacing: 10) {
                    Text("Nada marcado para este dia.").font(.subheadline).foregroundStyle(.secondary)
                    if d.mode == .manual {
                        Button { router.newTransaction(.variable, date: vm.agendaDay) } label: { Label("Lançar neste dia", systemImage: "plus") }
                            .buttonStyle(.bordered).buttonBorderShape(.capsule).tint(.efTint)
                    }
                }
                .frame(maxWidth: .infinity)
                .efCard()
            } else {
                rows(dayList, today: d.today)
            }
        }
        .padding(.horizontal, EFLayout.gutter)
    }

    private func legend(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 7, height: 7); Text(label).foregroundStyle(.secondary) }
    }

    // MARK: gastos

    @ViewBuilder private func spending(_ d: HomeData) -> some View {
        if !d.categories.isEmpty {
            let slices = d.categories.donutSlices()
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Para onde foi o dinheiro", subtitle: "Despesas de \(DateFormats.monthName(d.month))", action: "Relatórios") { router.push(.reports) }
                HStack(spacing: 18) {
                    DonutChart(slices, centerLabel: "Despesas",
                               centerValue: app.settings.hideValues ? "••••" : Money.compact(d.totals.expense, currency: d.currency))
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
            }
            .padding(.horizontal, EFLayout.gutter)
        }
    }

    @ViewBuilder private func limits(_ d: HomeData) -> some View {
        if let l = d.limits, !l.items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Limites por categoria", subtitle: l.attention > 0 ? "\(l.attention) \(l.attention == 1 ? "pede" : "pedem") atenção" : "Tudo dentro do limite",
                             action: "Ver todos") { router.showPlanning(.limits) }
                VStack(spacing: 14) {
                    ForEach(l.items.sorted { $0.percent > $1.percent }.prefix(3)) { item in LimitRow(item: item, look: d.looksByName[item.categoryName]) }
                }
                .efCard()
            }
            .padding(.horizontal, EFLayout.gutter)
        }
    }

    @ViewBuilder private func installments(_ d: HomeData) -> some View {
        if !d.installments.isEmpty {
            let remaining = d.installments.reduce(Decimal(0)) { $0 + $1.remainingAmount }
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Parcelamentos", subtitle: app.settings.hideValues ? "Falta pagar R$ ••••" : "Falta pagar \(Money.format(remaining, currency: d.currency))",
                             action: "Ver todos") { router.showPlanning(.installments) }
                    .padding(.horizontal, EFLayout.gutter)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(d.installments) { i in
                            Button { router.showPlanning(.installments) } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 10) {
                                        InstallmentRing(paid: i.paid, total: i.total, size: 44)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(i.name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.efInk).lineLimit(1)
                                            HStack(spacing: 0) { MoneyText(i.amount, font: .caption, color: .secondary); Text("/mês").font(.caption).foregroundStyle(.secondary) }
                                        }
                                    }
                                    if let end = i.endDate { Text("Termina em \(DateFormats.shortMonthYear(end))").font(.caption).foregroundStyle(.secondary) }
                                }
                                .padding(14)
                                .frame(width: 200, alignment: .leading)
                                .background(Color.efSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, EFLayout.gutter)
                }
            }
        }
    }

    @ViewBuilder private func subscriptions(_ d: HomeData) -> some View {
        if let s = d.subscriptions, !s.subscriptions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Assinaturas",
                             subtitle: "\(app.settings.hideValues ? "R$ ••••" : Money.format(s.monthlyTotal, currency: s.currency)) por mês · \(s.subscriptions.count) \(s.subscriptions.count == 1 ? "ativa" : "ativas")",
                             action: "Ver todas") { router.showPlanning(.subscriptions) }
                Button { router.showPlanning(.subscriptions) } label: {
                    HStack(spacing: 0) {
                        ForEach(Array(s.subscriptions.prefix(6).enumerated()), id: \.element.id) { k, item in
                            CategoryBadge(item.look, size: 34)
                                .padding(2).background(Color.efSurface, in: Circle())
                                .padding(.leading, k == 0 ? 0 : -10)
                        }
                        HStack(spacing: 0) {
                            MoneyText(s.yearlyTotal, currency: s.currency, font: .subheadline, color: .secondary)
                            Text(" por ano").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.leading, 12)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .efCard(padding: 12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, EFLayout.gutter)
        }
    }

    @ViewBuilder private func flow(_ d: HomeData) -> some View {
        if !d.yearFlow.isEmpty {
            let done = d.yearFlow.filter { !$0.projected }
            let result = done.reduce(Decimal(0)) { $0 + $1.income - $1.expense }
            let best = done.max { ($0.income - $0.expense) < ($1.income - $1.expense) }
            let projected = d.yearFlow.filter(\.projected)
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Fluxo de caixa \(String(d.month.year))",
                             subtitle: "Resultado até agora \(app.settings.hideValues ? "R$ ••••" : Money.format(result, currency: d.currency))\(best.map { " · melhor mês: \(DateFormats.shortMonths[$0.month.month - 1])" } ?? "")")
                VStack(alignment: .leading, spacing: 10) {
                    FlowChart(d.yearFlow)
                    HStack(spacing: 14) {
                        legend("Receitas", .efGreen)
                        legend("Despesas", .efExpense)
                        if let first = projected.first, let last = projected.last {
                            legend(first == last ? "\(DateFormats.shortMonths[first.month.month - 1].capitalizedFirst): previsto"
                                   : "\(DateFormats.shortMonths[first.month.month - 1].capitalizedFirst) a \(DateFormats.shortMonths[last.month.month - 1]): previsto", .secondary.opacity(0.4))
                        }
                    }
                    .font(.caption)
                }
                .efCard()
            }
            .padding(.horizontal, EFLayout.gutter)
        }
    }
}

// MARK: - cartão principal

/// Saldo da conta manual, saldo/fatura do banco ou saldo guardado (congelada).
struct HomeHero: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    let data: HomeData

    var body: some View {
        let account = data.workspace.account
        let bank = data.connections.bankAccount(for: account?.id)
        Button { if data.mode != .frozen { router.showTransactions() } } label: {
            Group {
                switch data.mode {
                case .connected:
                    if let bank, bank.1.kind == .credit { creditHero(bank.0, bank.1) } else { bankHero(bank?.0) }
                case .frozen: frozenHero
                case .manual: manualHero
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(data.mode == .frozen ? "" : "Ver transações do mês")
    }

    private var manualHero: some View {
        HeroCard {
            VStack(alignment: .leading, spacing: 6) {
                label("Saldo da conta")
                BigMoney(data.balance, currency: data.currency).foregroundStyle(.white)
                HStack(spacing: 4) {
                    Text("Previsão de fechamento").foregroundStyle(.white.opacity(0.78))
                    MoneyText(data.forecast, currency: data.currency, font: .subheadline.weight(.semibold), color: .white)
                }
                .font(.subheadline)
                HStack(alignment: .top, spacing: 14) {
                    split("Receitas do mês", "arrow.down.left", data.totals.income, pct: data.totals.incomePaidPct, done: "recebido", color: .efGreen)
                    split("Despesas do mês", "arrow.up.right", data.totals.expense, pct: data.totals.expensePaidPct, done: "pago", color: Color(hex: 0xFCA5A5))
                }
                .padding(.top, 10)
            }
        }
    }

    private func bankHero(_ conn: BankConnection?) -> some View {
        HeroCard(colors: heroColors(conn?.color)) {
            VStack(alignment: .leading, spacing: 6) {
                HStack { label("Saldo no banco"); bankTag }
                BigMoney(data.balance, currency: data.currency).foregroundStyle(.white)
                if let conn { Text("\(conn.bankName) · \(conn.updatedLabel(now: app.clock.localNow()))").font(.subheadline).foregroundStyle(.white.opacity(0.8)) }
                HStack(alignment: .top, spacing: 14) {
                    split("Entrou no mês", "arrow.down.left", data.totals.income, pct: nil, done: "", color: .efGreen)
                    split("Saiu no mês", "arrow.up.right", data.totals.expense, pct: nil, done: "", color: .white)
                }
                .padding(.top, 10)
            }
        }
    }

    private func creditHero(_ conn: BankConnection, _ b: BankAccount) -> some View {
        HeroCard(colors: heroColors(conn.color)) {
            VStack(alignment: .leading, spacing: 6) {
                HStack { label("Fatura atual"); bankTag }
                BigMoney(b.headline, currency: b.currency).foregroundStyle(.white)
                if let limit = b.creditLimit, let available = b.availableCredit, limit > 0 {
                    HStack(spacing: 4) {
                        Text("Disponível").foregroundStyle(.white.opacity(0.78))
                        MoneyText(available, currency: b.currency, font: .subheadline.weight(.semibold), color: .white)
                        Text("de").foregroundStyle(.white.opacity(0.78))
                        MoneyText(limit, currency: b.currency, font: .subheadline, color: .white.opacity(0.78))
                    }
                    .font(.subheadline)
                    ProgressBar(((limit - available) / limit).doubleValue, color: .white, track: .white.opacity(0.25)).padding(.top, 4)
                }
                Text("\(conn.bankName) · \(conn.updatedLabel(now: app.clock.localNow()))").font(.footnote).foregroundStyle(.white.opacity(0.8)).padding(.top, 2)
            }
        }
    }

    private var frozenHero: some View {
        HeroCard(colors: [Color(hex: 0x334155), Color(hex: 0x1E293B)]) {
            VStack(alignment: .leading, spacing: 6) {
                HStack { label("Saldo guardado"); Tag("Congelada", symbol: "snowflake", color: .white) }
                BigMoney(data.balance, currency: data.currency).foregroundStyle(.white)
                Text("O \(data.workspace.account?.bankName ?? "banco") foi desconectado. Esta conta fica só para consulta.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var bankTag: some View { Tag("Do banco", symbol: "link", color: .white) }

    private func label(_ text: String) -> some View { Text(text).font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.78)) }

    private func heroColors(_ hex: String?) -> [Color] {
        guard let c = Color(hexString: hex), let dark = Color(hexString: hex, darkenedBy: 0.4) else { return [.efHeroTop, .efHeroBottom] }
        return [c, dark]
    }

    private func split(_ title: String, _ symbol: String, _ value: Decimal, pct: Int?, done: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.white.opacity(0.75)).labelStyle(.titleAndIcon)
            MoneyText(value, currency: data.currency, font: .callout.weight(.semibold), color: .white)
            if let pct {
                ProgressBar(Double(pct) / 100, color: color, track: .white.opacity(0.2), height: 4)
                Text("\(pct)% \(done)").font(.caption2).foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - carrossel de contas

/// Contas da empresa em uso (manuais e do banco): tocar passa a usar a conta.
struct AccountsCarousel: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    let data: HomeData

    var body: some View {
        let company = data.workspace.company
        let accounts = company?.accounts ?? []
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Contas em \(company?.name ?? "")", subtitle: "\(plural(accounts.count, "conta", "contas")) · manuais e do banco", action: "Ver todas") {
                router.open(.accounts)
            }
            .padding(.horizontal, EFLayout.gutter)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(accounts) { a in card(a, companyId: company?.id ?? 0).id(a.id) }
                        Button { router.open(.accounts) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                IconBadge(symbol: "link", color: Color(hex: 0x059669), size: 32)
                                Text("Conectar banco").font(.subheadline.weight(.semibold)).foregroundStyle(Color.efInk)
                                Text("Open Finance, só leitura").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(14).frame(width: 160, height: 118, alignment: .topLeading)
                            .background(Color.efSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, EFLayout.gutter)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .onAppear { if let id = data.workspace.account?.id { proxy.scrollTo(id, anchor: .leading) } }
            }
        }
    }

    private func card(_ a: Account, companyId: Int64) -> some View {
        let on = data.workspace.account?.id == a.id
        let bank = data.connections.bankAccount(for: a.id)
        let sub: String
        switch a.mode {
        case .connected: sub = bank?.1.kind == .credit ? "fatura do cartão" : "saldo · \(bank?.0.updatedLabel(now: app.clock.localNow()) ?? "do banco")"
        case .frozen: sub = "congelada · só consulta"
        case .manual: sub = "conta manual"
        }
        let needsAction = bank.map { !$0.0.updated } ?? false
        return Button {
            Task { await app.select(companyId: companyId, accountId: a.id) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    AccountBadge(a, companyId: companyId, size: 24)
                    Text(a.mode == .manual ? "e-Finances" : a.bankName ?? bank?.0.bankName ?? "Banco").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                    if needsAction { Image(systemName: "arrow.triangle.2.circlepath").font(.caption).foregroundStyle(Color.efWarn) }
                    else if on { Image(systemName: "checkmark.circle.fill").font(.subheadline).foregroundStyle(Color.efTint).accessibilityLabel("Em uso") }
                }
                Text(a.name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.efInk).lineLimit(1)
                MoneyText(bank?.1.headline ?? a.balance, currency: a.currency, font: .headline)
                Text(sub).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(14)
            .frame(width: 172, height: 118, alignment: .topLeading)
            .background(Color.efSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { if on { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.efTint, lineWidth: 2) } }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityHint(on ? "" : "Passar a usar esta conta")
    }
}

// MARK: - limite

/// Linha de limite: categoria, gasto de limite e barra (verde, âmbar ou vermelha).
struct LimitRow: View {
    let item: LimitItem
    var look: TransactionCategory?

    var body: some View {
        let color: Color = item.status == .over ? .efExpense : item.status == .warn ? .efWarn : .efIncome
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                CategoryBadge(look, size: 30, fallbackName: item.categoryName)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.categoryName).font(.subheadline.weight(.semibold)).lineLimit(1)
                    HStack(spacing: 3) {
                        MoneyText(item.spent, font: .caption, color: .secondary)
                        Text("de").font(.caption).foregroundStyle(.secondary)
                        MoneyText(item.limit, font: .caption, color: .secondary)
                    }
                }
                Spacer()
                Text("\(item.percent)%").font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(color)
            }
            ProgressBar(min(Double(item.percent) / 100, 1), color: color)
        }
        .accessibilityElement(children: .combine)
    }
}
