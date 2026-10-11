import SwiftUI
import EFCore
import EFFeatures
#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

/* Aparência que vem da web: ícone e cor das categorias, marcas com logo (assinaturas), logo próprio e logo do banco. */

// MARK: - ícones (PrimeIcons da web → SF Symbols)

public enum Icons {
    private static let prime: [String: String] = [
        "pi-tag": "tag", "pi-tags": "tag.square", "pi-home": "house", "pi-shopping-cart": "cart", "pi-shopping-bag": "bag", "pi-car": "car",
        "pi-map": "map", "pi-send": "paperplane", "pi-bolt": "bolt", "pi-cloud": "cloud", "pi-phone": "phone", "pi-wifi": "wifi", "pi-heart": "heart",
        "pi-heart-fill": "heart.fill", "pi-plus-circle": "cross.case", "pi-book": "book", "pi-briefcase": "briefcase", "pi-wallet": "wallet.bifold",
        "pi-chart-line": "chart.line.uptrend.xyaxis", "pi-money-bill": "banknote", "pi-credit-card": "creditcard", "pi-building": "building.2",
        "pi-percentage": "percent", "pi-file": "doc.text", "pi-shield": "shield", "pi-gift": "gift", "pi-ticket": "ticket", "pi-video": "play.rectangle",
        "pi-desktop": "desktopcomputer", "pi-mobile": "iphone", "pi-server": "server.rack", "pi-box": "shippingbox", "pi-sun": "sun.max",
        "pi-flag": "flag", "pi-users": "person.2", "pi-user": "person", "pi-megaphone": "megaphone", "pi-replay": "arrow.counterclockwise",
        "pi-star": "star", "pi-camera": "camera", "pi-palette": "paintpalette", "pi-wrench": "wrench.adjustable", "pi-globe": "globe",
        "pi-arrow-down-left": "arrow.down.left", "pi-arrow-right-arrow-left": "arrow.left.arrow.right", "pi-ellipsis-h": "ellipsis",
        "pi-print": "printer", "pi-save": "square.and.arrow.down", "pi-sitemap": "point.3.connected.trianglepath.dotted"
    ]

    /// "pi-home" → "house" (desconhecido = ícone genérico).
    public static func symbol(prime name: String?) -> String {
        guard let n = name?.replacingOccurrences(of: "pi ", with: "").trimmingCharacters(in: .whitespaces) else { return "square.grid.2x2" }
        return prime[n] ?? "square.grid.2x2"
    }

    private static let palette: [UInt32] = [0x4338CA, 0x0E7490, 0x7C3AED, 0xB45309, 0x15803D, 0xBE185D, 0x1D4ED8, 0x0F766E]

    private static let rules: [([String], String, UInt32)] = [
        (["salario", "pro-labore", "prolabore"], "banknote", 0x059669),
        (["servico", "freela", "honorario", "venda"], "briefcase", 0x16A34A),
        (["alugueis", "aluguel recebido", "rendimento"], "building.2", 0x0F766E),
        (["moradia", "aluguel", "casa", "condominio"], "house", 0x6366F1),
        (["consumo", "energia", "luz", "agua", "internet", "telefone", "gas"], "bolt", 0xCA8A04),
        (["aliment", "mercado", "restaurante", "comida", "padaria"], "fork.knife", 0xEA580C),
        (["transporte", "combust", "carro", "uber", "onibus"], "car", 0x0284C7),
        (["saude", "farmacia", "medic", "plano de saude"], "heart", 0xDB2777),
        (["educa", "escola", "curso", "faculdade"], "graduationcap", 0x7C3AED),
        (["lazer", "viagem", "passeio"], "party.popper", 0xF97316),
        (["assinatura", "streaming"], "play.rectangle", 0xE11D48),
        (["compra", "vestuario", "roupa"], "bag", 0x0D9488),
        (["imposto", "taxa", "tarifa", "ipva", "iptu"], "building.columns", 0x64748B),
        (["filho", "crianca"], "figure.and.child.holdinghands", 0x7C3AED),
        (["pet"], "pawprint", 0xB45309),
        (["voo", "passagem"], "airplane", 0x0369A1)
    ]

    /// Ícone e cor pelo nome (categorias antigas sem aparência escolhida).
    public static func visual(forName name: String?) -> (String, Color) {
        guard let name, !name.isEmpty else { return ("square.grid.2x2", Color(hex: 0x64748B)) }
        let n = name.normalizedForSearch
        if let r = rules.first(where: { $0.0.contains { n.contains($0) } }) { return (r.1, Color(hex: r.2)) }
        return ("square.grid.2x2", Color(hex: palette[stableHash(n) % palette.count]))
    }

    /// Cor fixa por empresa (mesma regra da web).
    public static func companyColor(_ id: Int64) -> Color {
        let list: [UInt32] = [0x4338CA, 0x0E7490, 0x7C3AED, 0xB45309, 0x15803D, 0xBE185D, 0x1D4ED8]
        return Color(hex: list[Int(((id % 7) + 7) % 7)])
    }

    static func stableHash(_ s: String) -> Int {
        var h: UInt32 = 2_166_136_261
        for u in s.unicodeScalars { h ^= u.value; h = h &* 16_777_619 }
        return Int(h % 10_000)
    }
}

// MARK: - caminho SVG (logos das marcas do simple-icons, viewBox 24×24)

/// Lê o atributo "d" de um caminho SVG (M, L, H, V, C, S, Q, T, A, Z e as versões relativas).
public enum SVGPath {
    nonisolated(unsafe) private static var cache: [String: Path] = [:]
    private static let lock = NSLock()

    public static func path(_ d: String) -> Path {
        lock.lock()
        if let p = cache[d] { lock.unlock(); return p }
        lock.unlock()
        let p = parse(d)
        lock.lock(); cache[d] = p; lock.unlock()
        return p
    }

    private static func tokens(_ d: String) -> [Any] {
        var out: [Any] = []
        var num = ""
        var hasDot = false, hasExp = false
        func flush() { if !num.isEmpty, let v = Double(num) { out.append(v) }; num = ""; hasDot = false; hasExp = false }
        for ch in d {
            if ch.isLetter && ch != "e" && ch != "E" { flush(); out.append(ch); continue }
            if ch == "e" || ch == "E" { num.append(ch); hasExp = true; continue }
            if ch == "-" || ch == "+" {
                if let last = num.last, last == "e" || last == "E" { num.append(ch) } else { flush(); num.append(ch) }
                continue
            }
            if ch == "." {
                if hasDot || hasExp { flush() }
                num.append(ch); hasDot = true; continue
            }
            if ch.isNumber { num.append(ch); continue }
            flush() // espaço ou vírgula
        }
        flush()
        return out
    }

    private static func parse(_ d: String) -> Path {
        var path = Path()
        let toks = tokens(d)
        var i = 0
        var cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero, lastCtrl: CGPoint?, lastQuad: CGPoint?
        func num() -> CGFloat? {
            guard i < toks.count, let v = toks[i] as? Double else { return nil }
            i += 1
            return CGFloat(v)
        }
        func flag() -> Bool? {
            // flags de arco podem vir grudadas ("a1 1 0 011 1")
            guard i < toks.count, let v = toks[i] as? Double else { return nil }
            i += 1
            return v != 0
        }
        while i < toks.count {
            if let c = toks[i] as? Character { cmd = c; i += 1; if c == "z" || c == "Z" { path.closeSubpath(); cur = start; lastCtrl = nil; lastQuad = nil; continue } }
            let rel = cmd.isLowercase
            let base = rel ? cur : .zero
            switch cmd.uppercased().first! {
            case "M":
                guard let x = num(), let y = num() else { i += 1; continue }
                cur = CGPoint(x: base.x + x, y: base.y + y); start = cur
                path.move(to: cur)
                cmd = rel ? "l" : "L"
                lastCtrl = nil; lastQuad = nil
            case "L":
                guard let x = num(), let y = num() else { i += 1; continue }
                cur = CGPoint(x: base.x + x, y: base.y + y); path.addLine(to: cur); lastCtrl = nil; lastQuad = nil
            case "H":
                guard let x = num() else { i += 1; continue }
                cur = CGPoint(x: (rel ? cur.x : 0) + x, y: cur.y); path.addLine(to: cur); lastCtrl = nil; lastQuad = nil
            case "V":
                guard let y = num() else { i += 1; continue }
                cur = CGPoint(x: cur.x, y: (rel ? cur.y : 0) + y); path.addLine(to: cur); lastCtrl = nil; lastQuad = nil
            case "C":
                guard let x1 = num(), let y1 = num(), let x2 = num(), let y2 = num(), let x = num(), let y = num() else { i += 1; continue }
                let c1 = CGPoint(x: base.x + x1, y: base.y + y1), c2 = CGPoint(x: base.x + x2, y: base.y + y2)
                cur = CGPoint(x: base.x + x, y: base.y + y)
                path.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2; lastQuad = nil
            case "S":
                guard let x2 = num(), let y2 = num(), let x = num(), let y = num() else { i += 1; continue }
                let c1 = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = CGPoint(x: base.x + x2, y: base.y + y2)
                cur = CGPoint(x: base.x + x, y: base.y + y)
                path.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2; lastQuad = nil
            case "Q":
                guard let x1 = num(), let y1 = num(), let x = num(), let y = num() else { i += 1; continue }
                let c = CGPoint(x: base.x + x1, y: base.y + y1)
                cur = CGPoint(x: base.x + x, y: base.y + y)
                path.addQuadCurve(to: cur, control: c); lastQuad = c; lastCtrl = nil
            case "T":
                guard let x = num(), let y = num() else { i += 1; continue }
                let c = lastQuad.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                cur = CGPoint(x: base.x + x, y: base.y + y)
                path.addQuadCurve(to: cur, control: c); lastQuad = c; lastCtrl = nil
            case "A":
                guard let rx = num(), let ry = num(), let rot = num(), let large = flag(), let sweep = flag(), let x = num(), let y = num() else { i += 1; continue }
                let end = CGPoint(x: base.x + x, y: base.y + y)
                arc(&path, from: cur, to: end, rx: rx, ry: ry, rotation: rot, large: large, sweep: sweep)
                cur = end; lastCtrl = nil; lastQuad = nil
            default:
                i += 1
            }
        }
        return path
    }

    /// Arco elíptico → curvas de Bézier (conversão do ponto final para o centro, SVG 1.1 F.6).
    private static func arc(_ path: inout Path, from p1: CGPoint, to p2: CGPoint, rx rxIn: CGFloat, ry ryIn: CGFloat, rotation: CGFloat, large: Bool, sweep: Bool) {
        var rx = abs(rxIn), ry = abs(ryIn)
        if rx == 0 || ry == 0 || p1 == p2 { path.addLine(to: p2); return }
        let phi = rotation * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (p1.x - p2.x) / 2, dy = (p1.y - p2.y) / 2
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        var coef = den == 0 ? 0 : sqrt(max(0, num / den))
        if large == sweep { coef = -coef }
        let cxp = coef * rx * y1p / ry
        let cyp = -coef * ry * x1p / rx
        let cx = cosPhi * cxp - sinPhi * cyp + (p1.x + p2.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p1.y + p2.y) / 2
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let a = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
            return a
        }
        let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var delta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi } else if sweep && delta < 0 { delta += 2 * .pi }
        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let step = delta / CGFloat(segments)
        let t = 4 / 3 * tan(step / 4)
        var theta = theta1
        for _ in 0..<segments {
            let cos1 = cos(theta), sin1 = sin(theta), cos2 = cos(theta + step), sin2 = sin(theta + step)
            func map(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: cx + rx * x * cosPhi - ry * y * sinPhi, y: cy + rx * x * sinPhi + ry * y * cosPhi) }
            let c1 = map(cos1 - t * sin1, sin1 + t * cos1)
            let c2 = map(cos2 + t * sin2, sin2 - t * cos2)
            path.addCurve(to: map(cos2, sin2), control1: c1, control2: c2)
            theta += step
        }
    }
}

/// Forma que desenha um caminho SVG 24×24 escalado para caber no espaço.
struct SVGShape: Shape {
    let d: String
    func path(in rect: CGRect) -> Path {
        let p = SVGPath.path(d)
        let s = min(rect.width, rect.height) / 24
        return p.applying(CGAffineTransform(translationX: rect.minX + (rect.width - 24 * s) / 2, y: rect.minY + (rect.height - 24 * s) / 2).scaledBy(x: s, y: s))
    }
}

// MARK: - selos

/// Logo da marca (desenho do simple-icons) na cor da marca; sem desenho, a sigla.
public struct BrandMark: View {
    let key: String
    var size: CGFloat = 40

    public init(_ key: String, size: CGFloat = 40) { self.key = key; self.size = size }

    public var body: some View {
        let brand = BrandCatalog.shared.brands[key]
        let bg = Color(hexString: brand?.color) ?? Color(hex: 0x6366F1)
        let ink: Color = brand?.light == true ? Color(hex: 0x111827) : .white
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(bg)
            if let d = brand?.path {
                SVGShape(d: d).fill(ink, style: FillStyle(eoFill: false)).frame(width: size * 0.58, height: size * 0.58)
            } else {
                let short = (brand?.short).flatMap { $0.isEmpty ? nil : $0 } ?? (brand?.name ?? key).initials
                Text(short).font(.system(size: size * (short.count > 3 ? 0.24 : 0.34), weight: .bold)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.5)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(brand?.name ?? key)
    }
}

/// "data:image/png;base64,..." → imagem.
enum DataURL {
    nonisolated(unsafe) private static var cache: [String: PlatformImage] = [:]
    private static let lock = NSLock()

    static func image(_ dataUrl: String) -> PlatformImage? {
        lock.lock()
        if let img = cache[dataUrl] { lock.unlock(); return img }
        lock.unlock()
        guard dataUrl.hasPrefix("data:image/"), let comma = dataUrl.firstIndex(of: ","),
              let data = Data(base64Encoded: String(dataUrl[dataUrl.index(after: comma)...]), options: .ignoreUnknownCharacters),
              let img = PlatformImage(data: data) else { return nil }
        lock.lock(); cache[dataUrl] = img; lock.unlock()
        return img
    }
}

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}

/// Selo da categoria, na mesma ordem da web: logo próprio, marca do catálogo, ícone + cor escolhidos e, para
/// categorias antigas sem aparência, o ícone e a cor pelo nome.
public struct CategoryBadge: View {
    let category: TransactionCategory?
    var size: CGFloat = 40
    var fallbackName: String?

    public init(_ category: TransactionCategory?, size: CGFloat = 40, fallbackName: String? = nil) {
        self.category = category; self.size = size; self.fallbackName = fallbackName
    }

    public var body: some View {
        if let logo = category?.logo, let img = DataURL.image(logo) {
            Image(platformImage: img).resizable().scaledToFit().padding(size * 0.1)
                .frame(width: size, height: size)
                .background(.white, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).stroke(.black.opacity(0.08), lineWidth: 1))
                .accessibilityLabel(category?.name ?? "")
        } else if let brand = category?.brand, BrandCatalog.shared.brands[brand] != nil {
            BrandMark(brand, size: size)
        } else {
            let byName = Icons.visual(forName: category?.name ?? fallbackName)
            let symbol = category?.icon.map { Icons.symbol(prime: $0) } ?? byName.0
            let color = Color(hexString: category?.color) ?? byName.1
            IconBadge(symbol: symbol, color: color, size: size)
                .accessibilityLabel(category?.name ?? fallbackName ?? "Sem categoria")
        }
    }
}

/// Ícone dentro de um círculo suave na cor (lista de lançamentos).
public struct IconBadge: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 40
    var solid = false

    public init(symbol: String, color: Color, size: CGFloat = 40, solid: Bool = false) {
        self.symbol = symbol; self.color = color; self.size = size; self.solid = solid
    }

    public var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .medium))
            .foregroundStyle(solid ? .white : color)
            .frame(width: size, height: size)
            .background(solid ? color : color.opacity(0.15), in: Circle())
    }
}

/// Ícone branco num quadrado colorido (como nos Ajustes do iPhone).
public struct SettingsIcon: View {
    let symbol: String
    let color: Color
    public init(_ symbol: String, _ color: Color) { self.symbol = symbol; self.color = color }
    public var body: some View {
        Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            .frame(width: 29, height: 29).background(color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

/// Logo do banco (do conector do Open Finance). Sem logo, as iniciais na cor do banco. Congelada: cinza com floco.
public struct BankBadge: View {
    let name: String?
    let logoUrl: String?
    let color: String?
    var size: CGFloat = 32
    var frozen = false

    public init(name: String?, logoUrl: String?, color: String?, size: CGFloat = 32, frozen: Bool = false) {
        self.name = name; self.logoUrl = logoUrl; self.color = color; self.size = size; self.frozen = frozen
    }

    public var body: some View {
        let bg = Color(hexString: color) ?? Color(hex: 0x4338CA)
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let logoUrl, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image { img.resizable().scaledToFit().padding(size * 0.12).background(.white) }
                        else { initials(bg) }
                    }
                } else { initials(bg) }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .saturation(frozen ? 0 : 1)
            .opacity(frozen ? 0.7 : 1)
            if frozen {
                Image(systemName: "snowflake").font(.system(size: size * 0.26, weight: .bold)).foregroundStyle(Color(hex: 0x475569))
                    .frame(width: size * 0.46, height: size * 0.46).background(.white, in: Circle()).offset(x: size * 0.12, y: size * 0.12)
            }
        }
        .accessibilityLabel(name ?? "Banco")
    }

    private func initials(_ bg: Color) -> some View {
        Text((name ?? "Banco").replacingOccurrences(of: "[^\\p{L}\\p{N} ]", with: " ", options: .regularExpression).initials)
            .font(.system(size: size * 0.36, weight: .bold)).foregroundStyle(.white)
            .frame(width: size, height: size).background(bg)
    }
}

/// Selo de uma conta do e-Finances: manual (carteira na cor da empresa), do banco (logo) ou congelada.
public struct AccountBadge: View {
    let account: Account
    var companyId: Int64 = 0
    var size: CGFloat = 36

    public init(_ account: Account, companyId: Int64 = 0, size: CGFloat = 36) { self.account = account; self.companyId = companyId; self.size = size }

    public var body: some View {
        if account.fromBank {
            BankBadge(name: account.bankName ?? account.name, logoUrl: account.bankLogoUrl, color: account.bankColor, size: size, frozen: account.mode == .frozen)
        } else {
            Image(systemName: "wallet.bifold").font(.system(size: size * 0.42, weight: .medium)).foregroundStyle(Icons.companyColor(companyId))
                .frame(width: size, height: size)
                .background(Icons.companyColor(companyId).opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        }
    }
}

/// Iniciais em círculo (pessoas e contatos).
public struct InitialsBadge: View {
    let name: String
    let color: Color
    var size: CGFloat = 40
    public init(_ name: String, color: Color, size: CGFloat = 40) { self.name = name; self.color = color; self.size = size }
    public var body: some View {
        Text(name.initials).font(.sora(size * 0.36, .semibold)).foregroundStyle(.white)
            .frame(width: size, height: size).background(color, in: Circle())
    }
}

public extension ContactCategory {
    var color: Color {
        switch self { case .client: Color(hex: 0x059669); case .supplier: Color(hex: 0x1D4E89); case .worker: Color(hex: 0x7C3AED) }
    }
}

/// Logo do e-Finances: círculo azul-marinho com o "e" branco e a barra verde.
public struct EFLogo: View {
    var size: CGFloat = 48
    var onDark = false
    public init(size: CGFloat = 48, onDark: Bool = false) { self.size = size; self.onDark = onDark }

    public var body: some View {
        Canvas { ctx, s in
            let k = s.width / 120
            ctx.fill(Path(ellipseIn: CGRect(x: 4 * k, y: 4 * k, width: 112 * k, height: 112 * k)), with: .color(onDark ? Color(hex: 0x16304F) : .efNavy))
            // o mesmo desenho da web: "M84 60 A24 24 0 1 0 77 77"
            let e = SVGPath.path("M84 60 A24 24 0 1 0 77 77").applying(CGAffineTransform(scaleX: k, y: k))
            ctx.stroke(e, with: .color(.white), style: StrokeStyle(lineWidth: 11 * k, lineCap: .round))
            var bar = Path()
            bar.move(to: CGPoint(x: 36 * k, y: 60 * k))
            bar.addLine(to: CGPoint(x: 84 * k, y: 60 * k))
            ctx.stroke(bar, with: .color(.efGreen), style: StrokeStyle(lineWidth: 11 * k, lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
