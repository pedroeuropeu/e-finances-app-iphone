import SwiftUI
import EFCore
import EFFeatures

/// Fechamento do mês no estilo stories: entrou, saiu, guardou, onde mais gastou, maior gasto, limites e assinaturas.
struct StoryView: View {
    let story: Story?

    var body: some View {
        Screen({ StoryViewModel(app: $0, story: story) }) { vm in StoryContent(vm: vm) }
    }
}

private enum Slide: Hashable { case cover, income, expenses, balance, categories, biggest, limits, subscriptions, end }

private struct StoryContent: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let vm: StoryViewModel
    @State private var index = 0
    @State private var progress = 0.0
    @State private var paused = false
    @State private var pausedByButton = false

    private let seconds = 5.2

    var body: some View {
        Group {
            switch vm.state {
            case .ready(let s): player(s)
            case .failed(let e):
                VStack(spacing: 16) {
                    ErrorView(e) { await vm.load() }
                    Button("Fechar") { close() }.buttonStyle(.efSoft).padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.efBackground.ignoresSafeArea())
            case .loading:
                ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.efNavy.ignoresSafeArea())
            }
        }
        .task { await vm.load() }
        .preferredColorScheme(.dark)
    }

    private func slides(_ s: Story) -> [Slide] {
        var list: [Slide] = [.cover, .income, .expenses, .balance]
        if !s.categories.isEmpty { list.append(.categories) }
        if s.biggestExpense != nil { list.append(.biggest) }
        if s.limitsTotal > 0 { list.append(.limits) }
        if s.subscriptionsCount > 0 { list.append(.subscriptions) }
        list.append(.end)
        return list
    }

    // MARK: player

    private func player(_ s: Story) -> some View {
        let list = slides(s)
        let current = list[min(index, list.count - 1)]
        return GeometryReader { geo in
            ZStack(alignment: .top) {
                background(current).ignoresSafeArea()
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: current)
                VStack(alignment: .leading, spacing: 0) {
                    bars(list.count)
                    top(s)
                    slide(current, s)
                        .id(current)
                        .transition(.opacity)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(.horizontal, 28)
                        .contentShape(Rectangle())
                        .onTapGesture(coordinateSpace: .local) { p in
                            if p.x < geo.size.width / 3 { previous() } else { next(list.count) }
                        }
                        .onLongPressGesture(minimumDuration: 0.25, perform: {}, onPressingChanged: { pressing in
                            if !pausedByButton { paused = pressing }
                        })
                }
                .foregroundStyle(.white)
            }
        }
        .task(id: list.count) {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard !paused, progress < 1 else { continue }
                progress += 0.05 / seconds
                if progress >= 1 && index < list.count - 1 { next(list.count) }
            }
        }
        .accessibilityAction(named: "Próximo") { next(list.count) }
        .accessibilityAction(named: "Anterior") { previous() }
    }

    private func next(_ count: Int) {
        if index < count - 1 {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { index += 1 }
            progress = 0
        } else { progress = 1 }
    }

    private func previous() {
        if index > 0 { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { index -= 1 } }
        progress = 0
    }

    private func close() {
        Task { await vm.seen() }
        dismiss()
    }

    private func bars(_ count: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { k in
                GeometryReader { g in
                    Capsule().fill(.white.opacity(0.3))
                        .overlay(alignment: .leading) {
                            Capsule().fill(.white).frame(width: g.size.width * (k < index ? 1 : k == index ? min(progress, 1) : 0))
                        }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .accessibilityHidden(true)
    }

    private func top(_ s: Story) -> some View {
        HStack(spacing: 10) {
            EFLogo(size: 30, onDark: true)
            VStack(alignment: .leading, spacing: 0) {
                Text(s.title).font(.subheadline.weight(.semibold))
                Text("\(s.accountName) · \(s.periodLabel)").font(.caption).opacity(0.8)
            }
            Spacer()
            Button {
                pausedByButton.toggle()
                paused = pausedByButton
            } label: {
                Image(systemName: pausedByButton ? "play.fill" : "pause.fill").frame(width: 40, height: 40)
            }
            .accessibilityLabel(pausedByButton ? "Continuar" : "Pausar")
            Button { close() } label: { Image(systemName: "xmark").fontWeight(.semibold).frame(width: 40, height: 40) }
                .accessibilityLabel("Fechar")
        }
        .buttonStyle(.plain)
        .padding(.leading, 16).padding(.trailing, 8).padding(.top, 10)
    }

    // MARK: telas

    @ViewBuilder private func slide(_ slide: Slide, _ s: Story) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()
            Text(s.tag).font(.footnote.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 6)
                .background(.white.opacity(0.18), in: Capsule())
            switch slide {
            case .cover:
                Text("Seu fechamento do mês").font(.sora(40, .bold, relativeTo: .largeTitle))
                Text(s.accountName).font(.title3).opacity(0.85)
                Label("\(plural(Int(s.count), "lançamento", "lançamentos")) no período", systemImage: "list.bullet.rectangle").font(.subheadline).opacity(0.85)
                Spacer()
                Text("Toque para avançar · segure para pausar").font(.footnote).opacity(0.6).frame(maxWidth: .infinity)
            case .income:
                kicker("Entrou")
                money(s.income, s)
                Text("em recebimentos no mês").font(.title3).opacity(0.85)
            case .expenses:
                kicker("Saiu")
                money(s.expenses, s)
                Text("em despesas no mês").font(.title3).opacity(0.85)
                if let d = s.expensesDeltaPct {
                    Label("\(abs(d))% \(d <= 0 ? "a menos" : "a mais") que o mês anterior", systemImage: d <= 0 ? "arrow.down" : "arrow.up")
                        .font(.subheadline.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.white.opacity(0.18), in: Capsule())
                }
            case .balance:
                money(s.balance.magnitude, s, size: 56)
                Text(s.balance >= 0 ? "guardados" : "no vermelho").font(.title2.weight(.semibold))
                Text(s.balance >= 0 ? (s.savingsRate.map { "Você guardou \($0)% do que entrou." } ?? "Sobrou dinheiro no mês.")
                     : "As despesas passaram dos recebimentos. Que tal definir limites?").font(.title3).opacity(0.85)
            case .categories:
                kicker("Onde mais foi o dinheiro")
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(s.categories.prefix(3).enumerated()), id: \.offset) { i, c in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(i + 1). \(c.name)").font(.headline)
                                Spacer()
                                Text(app.settings.hideValues ? "R$ ••••" : Money.format(c.value, currency: s.currency)).font(.headline).monospacedDigit()
                            }
                            ProgressBar(Double(c.percent) / 100, color: .white, track: .white.opacity(0.25), height: 8)
                            Text("\(c.percent)% das despesas").font(.caption).opacity(0.75)
                        }
                    }
                }
            case .biggest:
                kicker("Maior gasto")
                if let b = s.biggestExpense {
                    money(b.value, s)
                    Text(b.description).font(.title3).opacity(0.9)
                    if let d = b.date { Label(DateFormats.api(d), systemImage: "calendar").font(.subheadline).opacity(0.8) }
                }
            case .limits:
                (Text("\(s.limitsWithin)").font(.sora(64, .bold)) + Text(" de \(s.limitsTotal)").font(.sora(30, .semibold))).monospacedDigit()
                Text("categorias dentro do limite").font(.title2.weight(.semibold))
                Text(s.limitsOver > 0 ? "\(s.limitsOver) \(s.limitsOver == 1 ? "passou" : "passaram") do limite. Vale ajustar este mês." : "Nenhuma estourou. Mandou bem!")
                    .font(.title3).opacity(0.85)
            case .subscriptions:
                kicker("Suas assinaturas")
                money(s.subscriptionsMonthly, s)
                Text("por mês em \(plural(s.subscriptionsCount, "assinatura", "assinaturas"))").font(.title3).opacity(0.85)
            case .end:
                Text(s.balance >= 0 ? "Bom trabalho!" : "Novo mês, nova chance").font(.sora(40, .bold, relativeTo: .largeTitle))
                Text("Veja tudo em detalhe ou siga em frente.").font(.title3).opacity(0.85)
                VStack(spacing: 10) {
                    Button {
                        close()
                        router.tab = .home
                        router.homePath.append(Route.reports)
                    } label: { Label("Ver relatórios", systemImage: "chart.bar") }
                        .buttonStyle(PrimaryButtonStyle(color: .white, foreground: .efNavy))
                    Button {
                        close()
                        router.showPlanning(.limits)
                    } label: { Label("Limites por categoria", systemImage: "flag") }
                        .buttonStyle(PrimaryButtonStyle(color: .white.opacity(0.18), foreground: .white))
                    ShareLink(item: summary(s)) { Label("Compartilhar este resumo", systemImage: "square.and.arrow.up") }
                        .buttonStyle(PrimaryButtonStyle(color: .white.opacity(0.18), foreground: .white))
                }
                .padding(.top, 12)
            }
            Spacer()
            Spacer()
        }
    }

    private func kicker(_ text: String) -> some View {
        Text(text).font(.title2.weight(.medium)).opacity(0.85)
    }

    private func money(_ value: Decimal, _ s: Story, size: CGFloat = 48) -> some View {
        BigMoney(value, size: size, currency: s.currency).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
    }

    private func background(_ slide: Slide) -> some View {
        let colors: [UInt32]
        switch slide {
        case .cover: colors = [0x17426F, 0x0B2545, 0x0B2545]
        case .income: colors = [0x065F46, 0x047857, 0x10B981]
        case .expenses: colors = [0x7F1D1D, 0xB91C1C, 0xEF4444]
        case .balance: colors = [0x0B2545, 0x1D4E89, 0x10B981]
        case .categories: colors = [0x312E81, 0x4338CA, 0x6366F1]
        case .biggest: colors = [0x7C2D12, 0xC2410C, 0xF97316]
        case .limits: colors = [0x134E4A, 0x0F766E, 0x14B8A6]
        case .subscriptions: colors = [0x4A044E, 0x86198F, 0xC026D3]
        case .end: colors = [0x0B2545, 0x0B2545, 0x10B981]
        }
        return LinearGradient(colors: colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func summary(_ s: Story) -> String {
        """
        Meu fechamento de \(s.periodLabel) no e-Finances
        Entrou: \(Money.format(s.income, currency: s.currency))
        Saiu: \(Money.format(s.expenses, currency: s.currency))
        \(s.balance >= 0 ? "Guardei" : "Fiquei no vermelho em"): \(Money.format(s.balance.magnitude, currency: s.currency))
        """
    }
}
