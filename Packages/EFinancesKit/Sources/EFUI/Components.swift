import SwiftUI
import Charts
import EFCore
import EFFeatures

// MARK: - valores

/// Valor em dinheiro que respeita o "esconder valores" (olho no topo do Início).
public struct MoneyText: View {
    @Environment(AppModel.self) private var app
    let value: Decimal
    var currency: String?
    var signed: Bool?
    var font: Font = .body
    var color: Color?

    public init(_ value: Decimal, currency: String? = nil, signedIncome: Bool? = nil, font: Font = .body, color: Color? = nil) {
        self.value = value; self.currency = currency; self.signed = signedIncome; self.font = font; self.color = color
    }

    public var body: some View {
        let cur = currency ?? app.currency
        let text = app.settings.hideValues ? Money.hidden : signed.map { Money.signed(value, income: $0, currency: cur) } ?? Money.format(value, currency: cur)
        Text(text).font(font).monospacedDigit().foregroundStyle(color ?? .primary)
            .contentTransition(.numericText())
            .privacySensitive()
    }
}

/// Valor grande do cartão de saldo: "R$ 8.432" + ",17" menor.
public struct BigMoney: View {
    @Environment(AppModel.self) private var app
    let value: Decimal
    var size: CGFloat = 40
    var currency: String?

    public init(_ value: Decimal, size: CGFloat = 40, currency: String? = nil) { self.value = value; self.size = size; self.currency = currency }

    public var body: some View {
        if app.settings.hideValues {
            Text("R$ ••••••").font(.sora(size, .semibold, relativeTo: .largeTitle))
        } else {
            let (a, b) = Money.split(value, currency: currency ?? app.currency)
            (Text(a).font(.sora(size, .semibold, relativeTo: .largeTitle)) + Text(b).font(.sora(size * 0.55, .semibold, relativeTo: .title2)))
                .monospacedDigit()
                .contentTransition(.numericText())
                .privacySensitive()
        }
    }
}

// MARK: - cartões e seções

/// Cartão azul-marinho da marca (saldo, plano, totais).
public struct HeroCard<Content: View>: View {
    var colors: [Color] = [.efHeroTop, .efHeroBottom]
    @ViewBuilder var content: Content

    public init(colors: [Color] = [.efHeroTop, .efHeroBottom], @ViewBuilder content: () -> Content) { self.colors = colors; self.content = content() }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
            .background {
                ZStack(alignment: .topTrailing) {
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    RadialGradient(colors: [Color.efGreen.opacity(0.25), .clear], center: .topTrailing, startRadius: 0, endRadius: 220)
                    EFLogo(size: 210, onDark: true).opacity(0.08).offset(x: 56, y: -50).blendMode(.screen)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

/// Barra de progresso fina (limites, faturas, parcelas).
public struct ProgressBar: View {
    let value: Double
    var color: Color = .efGreen
    var track: Color = Color.primary.opacity(0.1)
    var height: CGFloat = 6

    public init(_ value: Double, color: Color = .efGreen, track: Color = Color.primary.opacity(0.1), height: CGFloat = 6) {
        self.value = value; self.color = color; self.track = track; self.height = height
    }

    public var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(color).frame(width: max(height, g.size.width * min(max(value, 0), 1)))
                    .opacity(value <= 0 ? 0 : 1)
            }
        }
        .frame(height: height)
        .accessibilityValue("\(Int(value * 100))%")
    }
}

public struct SectionTitle: View {
    let title: String
    var subtitle: String?
    var action: String?
    var onAction: (() -> Void)?

    public init(_ title: String, subtitle: String? = nil, action: String? = nil, onAction: (() -> Void)? = nil) {
        self.title = title; self.subtitle = subtitle; self.action = action; self.onAction = onAction
    }

    public var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.sora(20, .semibold, relativeTo: .title3)).foregroundStyle(Color.efInk)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            if let action, let onAction {
                Button(action: onAction) { HStack(spacing: 2) { Text(action); Image(systemName: "chevron.right").font(.caption.weight(.bold)) } }
                    .font(.subheadline.weight(.semibold)).tint(.efTint)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Etiqueta pequena (situação, "Do banco", "Em uso").
public struct Tag: View {
    let text: String
    var symbol: String?
    var color: Color = .secondary
    public init(_ text: String, symbol: String? = nil, color: Color = .secondary) { self.text = text; self.symbol = symbol; self.color = color }
    public var body: some View {
        HStack(spacing: 3) {
            if let symbol { Image(systemName: symbol).font(.caption2.weight(.bold)) }
            Text(text).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .foregroundStyle(color)
        .background(color.opacity(0.13), in: Capsule())
    }
}

/// Número de destaque com rótulo (relatórios, planejamento).
public struct KPITile: View {
    let label: String
    let value: Decimal?
    var text: String?
    var color: Color?
    var detail: String?
    var detailColor: Color = .secondary

    public init(_ label: String, value: Decimal? = nil, text: String? = nil, color: Color? = nil, detail: String? = nil, detailColor: Color = .secondary) {
        self.label = label; self.value = value; self.text = text; self.color = color; self.detail = detail; self.detailColor = detailColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            Group {
                if let value { MoneyText(value, font: .sora(19, .semibold, relativeTo: .headline), color: color ?? .efInk) }
                else { Text(text ?? "—").font(.sora(19, .semibold, relativeTo: .headline)).foregroundStyle(color ?? .efInk) }
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            if let detail { Text(detail).font(.caption).foregroundStyle(detailColor).lineLimit(1) }
        }
        .efCard(padding: 14, radius: 20)
        .accessibilityElement(children: .combine)
    }
}

/// Variação percentual em relação ao período anterior.
public func variationText(_ current: Decimal, _ previous: Decimal, goodUp: Bool = true) -> (String, Color) {
    guard let v = variation(current, previous) else { return ("sem comparação", .secondary) }
    let good = goodUp ? v >= 0 : v <= 0
    return ("\(v >= 0 ? "▲" : "▼") \(abs(v))% vs. anterior", v == 0 ? .secondary : good ? .efIncome : .efExpense)
}

// MARK: - estados de tela

public struct LoadingView: View {
    public init() {}
    public var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { _ in RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.efSurface).frame(height: 96) }
        }
        .padding(16)
        .redacted(reason: .placeholder)
        .accessibilityLabel("Carregando")
    }
}

public struct ErrorView: View {
    let error: AppError
    let retry: () async -> Void
    public init(_ error: AppError, retry: @escaping () async -> Void) { self.error = error; self.retry = retry }
    public var body: some View {
        ContentUnavailableView {
            Label(error == .network ? "Sem conexão" : "Não deu para carregar", systemImage: error == .network ? "wifi.slash" : "exclamationmark.triangle")
        } description: {
            Text(error.message)
        } actions: {
            Button("Tentar de novo") { Task { await retry() } }.buttonStyle(.borderedProminent).tint(.efPrimary)
        }
    }
}

/// Ícone grande + texto, quando não há nada para mostrar.
public struct EmptyStateView: View {
    let symbol: String
    let title: String
    var message: String?
    public init(_ symbol: String, _ title: String, message: String? = nil) { self.symbol = symbol; self.title = title; self.message = message }
    public var body: some View {
        ContentUnavailableView { Label(title, systemImage: symbol) } description: { if let message { Text(message) } }
    }
}

// MARK: - aviso (toast) com "Desfazer"

/// Aviso flutuante de vidro acima da barra de abas, com a ação (ex.: "Desfazer").
public struct ToastOverlay: View {
    @Environment(AppModel.self) private var app

    public init() {}

    public var body: some View {
        let m = app.messenger
        VStack {
            Spacer()
            if let msg = m.current {
                HStack(spacing: 12) {
                    if let icon = msg.icon { Image(systemName: icon).foregroundStyle(Color.efTint) }
                    Text(msg.text).font(.subheadline.weight(.medium)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    if let action = msg.action {
                        Button(action) { m.act() }
                            .font(.subheadline.weight(.semibold)).buttonStyle(.bordered).buttonBorderShape(.capsule).tint(.efTint)
                    }
                }
                .padding(.leading, 18).padding(.trailing, msg.action == nil ? 18 : 8).padding(.vertical, 10)
                .efGlass(cornerRadius: 26)
                .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 92)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .gesture(DragGesture(minimumDistance: 10).onEnded { v in if v.translation.height > 20 { m.dismiss() } })
                .id(msg.id)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(.spring(duration: 0.35), value: m.current)
        .allowsHitTesting(m.current != nil)
    }
}

// MARK: - lançamento na lista

/// Linha de lançamento: selo da categoria, descrição, situação, valor e o círculo para pagar.
public struct TransactionRow: View {
    @Environment(AppModel.self) private var app
    let t: Tx
    let today: LocalDate
    var showPay = true
    var selecting = false
    var selected = false
    var onTogglePaid: (() -> Void)?

    public init(_ t: Tx, today: LocalDate, showPay: Bool = true, selecting: Bool = false, selected: Bool = false, onTogglePaid: (() -> Void)? = nil) {
        self.t = t; self.today = today; self.showPay = showPay; self.selecting = selecting; self.selected = selected; self.onTogglePaid = onTogglePaid
    }

    public var body: some View {
        let status = t.dueStatus(today: today)
        let fromBank = app.mode != .manual
        HStack(spacing: 12) {
            if selecting {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(selected ? Color.efTint : Color.secondary)
            }
            CategoryBadge(t.category, size: 40, fallbackName: t.description)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(t.description).font(.body).foregroundStyle(Color.efInk).lineLimit(1)
                    if let plot = t.plot { Text(plot).font(.caption2.weight(.semibold)).padding(.horizontal, 5).padding(.vertical, 1).background(Color.primary.opacity(0.08), in: Capsule()) }
                    if t.attachments > 0 { Image(systemName: "paperclip").font(.caption).foregroundStyle(.secondary) }
                }
                (statusText(status, fromBank: fromBank) + Text(" · \(t.category?.name ?? "Sem categoria")").foregroundColor(.secondary))
                    .font(.footnote).lineLimit(2)
            }
            Spacer(minLength: 6)
            MoneyText(t.value, signedIncome: t.type.isIncome, font: .callout.weight(.medium), color: t.type.isIncome ? .efIncome : .efInk)
                .lineLimit(1).fixedSize()
            if showPay && !selecting {
                if fromBank {
                    Image(systemName: app.mode == .frozen ? "snowflake" : "lock").font(.footnote).foregroundStyle(.tertiary).frame(width: 28)
                        .accessibilityLabel(app.mode == .frozen ? "Só consulta" : "Veio do banco")
                } else {
                    Button { onTogglePaid?() } label: {
                        Image(systemName: t.paid ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(t.paid ? Color.efIncome : Color.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 32, height: 32)
                    .accessibilityLabel(t.paid ? "Voltar para pendente" : t.type.isIncome ? "Marcar como recebido" : "Marcar como pago")
                    .sensoryFeedback(.success, trigger: t.paid)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func statusText(_ s: DueStatus, fromBank: Bool) -> Text {
        if fromBank { return Text(DateFormats.dayMonth(t.date)).foregroundColor(.secondary) }
        let label = s.label(income: t.type.isIncome) + (t.paid ? " \(DateFormats.dayMonth(t.date))" : "")
        switch s {
        case .late: return Text(label).foregroundColor(.efExpense).fontWeight(.semibold)
        case .dueSoon: return Text(label).foregroundColor(.efWarn).fontWeight(.semibold)
        case .paid: return Text(label).foregroundColor(.efIncome).fontWeight(.semibold)
        case .scheduled: return Text(label).foregroundColor(.secondary)
        }
    }
}

// MARK: - filtros

/// Chip de filtro (cápsula).
public struct FilterChip: View {
    let label: String
    let selected: Bool
    var badge: Int?
    let action: () -> Void

    public init(_ label: String, selected: Bool, badge: Int? = nil, action: @escaping () -> Void) {
        self.label = label; self.selected = selected; self.badge = badge; self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if selected { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
                Text(label)
                if let badge, badge > 0 {
                    Text("\(badge)").font(.caption2.weight(.bold)).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 1).background(Color.efExpense, in: Capsule())
                }
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .foregroundStyle(selected ? Color.efOnPrimary : Color.efInk)
            .background(selected ? Color.efPrimary : Color.efSurface, in: Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(selected ? 0 : 0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - gráficos

/// Fatia de gráfico de rosca.
public struct DonutSlice: Identifiable {
    public let id: String
    public let value: Double
    public let color: Color
    public let label: String
    public let percent: Int
}

public extension Array where Element == CategoryShare {
    /// As 4 maiores + "Outras" (como a web), com a cor de cada categoria.
    func donutSlices(max: Int = 4) -> [DonutSlice] {
        let top = prefix(max)
        var out = top.map { s -> DonutSlice in
            let color = Color(hexString: s.category?.color) ?? (s.category?.brand).flatMap { BrandCatalog.shared.brands[$0] }.flatMap { Color(hexString: $0.color) } ?? Icons.visual(forName: s.name).1
            return DonutSlice(id: s.name, value: s.value.doubleValue, color: color, label: s.name, percent: s.percent)
        }
        let rest = dropFirst(max)
        if !rest.isEmpty {
            out.append(DonutSlice(id: "Outras", value: rest.reduce(Decimal(0)) { $0 + $1.value }.doubleValue, color: Color(hex: 0x94A3B8), label: "Outras", percent: rest.reduce(0) { $0 + $1.percent }))
        }
        return out
    }
}

/// Rosca com o total no meio e a legenda ao lado.
public struct DonutChart: View {
    let slices: [DonutSlice]
    let centerLabel: String
    let centerValue: String

    public init(_ slices: [DonutSlice], centerLabel: String, centerValue: String) { self.slices = slices; self.centerLabel = centerLabel; self.centerValue = centerValue }

    public var body: some View {
        HStack(spacing: 18) {
            Chart(slices) { s in
                SectorMark(angle: .value("Valor", s.value), innerRadius: .ratio(0.68), angularInset: 1.5)
                    .foregroundStyle(s.color).cornerRadius(3)
            }
            .chartLegend(.hidden)
            .frame(width: 124, height: 124)
            .overlay {
                VStack(spacing: 0) {
                    Text(centerLabel).font(.caption2).foregroundStyle(.secondary)
                    Text(centerValue).font(.sora(15, .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 22)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(slices) { s in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3).fill(s.color).frame(width: 10, height: 10)
                        Text(s.label).font(.subheadline).lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(s.percent)%").font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Receitas e despesas por mês (barras lado a lado; meses futuros mais claros).
public struct FlowChart: View {
    @Environment(AppModel.self) private var app
    let months: [MonthFlow]
    var height: CGFloat = 170

    public init(_ months: [MonthFlow], height: CGFloat = 170) { self.months = months; self.height = height }

    public var body: some View {
        Chart {
            ForEach(months) { m in
                BarMark(x: .value("Mês", DateFormats.shortMonths[m.month.month - 1]), y: .value("Valor", m.income.doubleValue))
                    .foregroundStyle(Color.efGreen.opacity(m.projected ? 0.35 : 1))
                    .position(by: .value("Tipo", "Receitas"))
                    .cornerRadius(3)
                BarMark(x: .value("Mês", DateFormats.shortMonths[m.month.month - 1]), y: .value("Valor", m.expense.doubleValue))
                    .foregroundStyle(Color.efExpense.opacity(m.projected ? 0.35 : 1))
                    .position(by: .value("Tipo", "Despesas"))
                    .cornerRadius(3)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                AxisValueLabel { if let d = v.as(Double.self) { Text(app.settings.hideValues ? "" : Money.compactNumber(Decimal(d))).font(.caption2) } }
            }
        }
        .chartXAxis { AxisMarks { v in AxisValueLabel { if let s = v.as(String.self) { Text(String(s.prefix(months.count > 8 ? 1 : 3)).capitalized).font(.caption2) } } } }
        .frame(height: height)
        .accessibilityLabel("Receitas e despesas por mês")
    }
}

/// Anel de progresso das parcelas ("3/10").
public struct InstallmentRing: View {
    let paid: Int
    let total: Int
    var size: CGFloat = 46
    public init(paid: Int, total: Int, size: CGFloat = 46) { self.paid = paid; self.total = total; self.size = size }
    public var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.1), lineWidth: 5)
            Circle().trim(from: 0, to: total > 0 ? min(Double(paid) / Double(total), 1) : 0)
                .stroke(Color.efGreen, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
            Text("\(paid)/\(total)").font(.system(size: size * 0.24, weight: .bold)).monospacedDigit()
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(paid) de \(total) parcelas pagas")
    }
}

/// Calendário do mês (agenda do Início e gastos por dia nos relatórios).
public struct MonthCalendar: View {
    let month: YearMonth
    let today: LocalDate
    var selected: LocalDate?
    /// Cores dos pontinhos de cada dia (máx. 3).
    var dots: (LocalDate) -> [Color] = { _ in [] }
    /// Intensidade 0…1 do fundo (calendário de calor).
    var heat: ((LocalDate) -> Double)?
    let onSelect: (LocalDate) -> Void

    public init(month: YearMonth, today: LocalDate, selected: LocalDate?, dots: @escaping (LocalDate) -> [Color] = { _ in [] },
                heat: ((LocalDate) -> Double)? = nil, onSelect: @escaping (LocalDate) -> Void) {
        self.month = month; self.today = today; self.selected = selected; self.dots = dots; self.heat = heat; self.onSelect = onSelect
    }

    public var body: some View {
        let first = month.firstDay.weekday
        let cells: [LocalDate?] = Array(repeating: nil, count: first) + (1...month.lengthOfMonth).map { month.atDay($0) }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(DateFormats.weekdayInitials.enumerated()), id: \.offset) { _, w in
                Text(w).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                if let d = day {
                    Button { onSelect(d) } label: { cell(d) }.buttonStyle(.plain)
                        .accessibilityLabel("\(d.day) de \(DateFormats.monthNames[d.month - 1])")
                        .accessibilityAddTraits(d == selected ? .isSelected : [])
                } else { Color.clear.frame(height: 40) }
            }
        }
    }

    @ViewBuilder private func cell(_ d: LocalDate) -> some View {
        let isSel = d == selected, isToday = d == today
        VStack(spacing: 3) {
            Text("\(d.day)")
                .font(.callout.weight(isToday || isSel ? .bold : .regular)).monospacedDigit()
                .foregroundStyle(isSel ? Color.efOnPrimary : isToday ? Color.efTint : Color.efInk)
                .frame(width: 32, height: 28)
                .background {
                    if isSel { Capsule().fill(Color.efPrimary) }
                    else if let heat, heat(d) > 0 { RoundedRectangle(cornerRadius: 8).fill(Color.efExpense.opacity(0.12 + heat(d) * 0.6)) }
                }
            HStack(spacing: 3) { ForEach(Array(dots(d).prefix(3).enumerated()), id: \.offset) { _, c in Circle().fill(c).frame(width: 5, height: 5) } }
                .frame(height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .contentShape(Rectangle())
    }
}

// MARK: - botões

/// Botão principal em cápsula (azul-marinho no claro).
public struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .efPrimary
    var foreground: Color = .efOnPrimary
    public init(color: Color = .efPrimary, foreground: Color = .efOnPrimary) { self.color = color; self.foreground = foreground }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(foreground)
            .background(color, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

public extension ButtonStyle where Self == PrimaryButtonStyle {
    static var efPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var efGreen: PrimaryButtonStyle { PrimaryButtonStyle(color: .efGreen, foreground: Color(hex: 0x052E20)) }
    static var efSoft: PrimaryButtonStyle { PrimaryButtonStyle(color: Color.primary.opacity(0.08), foreground: .efInk) }
    static var efDanger: PrimaryButtonStyle { PrimaryButtonStyle(color: Color.efExpense.opacity(0.14), foreground: .efExpense) }
}

/// Campo de texto com rótulo em cima (formulários de acesso).
public struct LabeledField<Field: View>: View {
    let label: String
    var error: String?
    @ViewBuilder var field: Field
    public init(_ label: String, error: String? = nil, @ViewBuilder field: () -> Field) { self.label = label; self.error = error; self.field = field() }
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.footnote).foregroundStyle(.secondary)
            field
                .padding(.horizontal, 16).frame(minHeight: 52)
                .background(Color.efSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(error == nil ? Color.clear : Color.efExpense, lineWidth: 1.5))
            if let error { Text(error).font(.footnote).foregroundStyle(Color.efExpense) }
        }
    }
}
