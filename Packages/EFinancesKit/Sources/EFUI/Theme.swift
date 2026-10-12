import SwiftUI
import EFCore
import CoreText
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/*
 Identidade visual do e-Finances no iPhone: azul-marinho #0B2545 e verde #10B981 da marca, Sora nos títulos e
 valores e a fonte do sistema (SF Pro) no resto. Os componentes do sistema (barras, abas, folhas) ficam com o visual
 do iOS (Liquid Glass no iOS 26).
 */

public extension Color {
    /// Cor que muda com o modo claro/escuro.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
        #else
        Color(NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light) })
        #endif
    }

    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }

    /// "#4338CA" ou "820AD1" (nil se inválido).
    init?(hexString: String?) {
        guard var h = hexString?.trimmingCharacters(in: .whitespaces), !h.isEmpty else { return nil }
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count >= 6, let v = UInt32(h.suffix(6), radix: 16) else { return nil }
        self.init(hex: v)
    }

    /// A mesma cor escurecida (degradê do cartão do banco).
    init?(hexString: String?, darkenedBy amount: Double) {
        guard var h = hexString?.trimmingCharacters(in: .whitespaces), !h.isEmpty else { return nil }
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count >= 6, let v = UInt32(h.suffix(6), radix: 16) else { return nil }
        let k = max(0, min(1, 1 - amount))
        self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255 * k, green: Double((v >> 8) & 0xFF) / 255 * k, blue: Double(v & 0xFF) / 255 * k)
    }

    // marca
    static let efNavy = Color(hex: 0x0B2545)
    static let efNavy2 = Color(hex: 0x17426F)
    static let efGreen = Color(hex: 0x10B981)
    /// Cor de destaque do app (links, botões do sistema, selecionados).
    static let efTint = Color.dynamic(light: 0x047857, dark: 0x34D399)
    /// Botão principal (fundo).
    static let efPrimary = Color.dynamic(light: 0x0B2545, dark: 0xA9C7EE)
    static let efOnPrimary = Color.dynamic(light: 0xFFFFFF, dark: 0x0B2545)
    static let efInk = Color.dynamic(light: 0x0B1B33, dark: 0xEEF3F9)
    static let efMuted = Color.dynamic(light: 0x66768D, dark: 0x8E9DB3)
    static let efBackground = Color.dynamic(light: 0xF2F4F8, dark: 0x03060B)
    static let efSurface = Color.dynamic(light: 0xFFFFFF, dark: 0x131A25)
    static let efSurface2 = Color.dynamic(light: 0xEEF1F5, dark: 0x1A2330)

    // semânticas
    static let efIncome = Color.dynamic(light: 0x15803D, dark: 0x4ADE80)
    static let efExpense = Color.dynamic(light: 0xDC2626, dark: 0xF87171)
    /// Cinza mais claro (setas, legendas). Fixo: o estilo .tertiary vira tom da cor de destaque dentro de botões.
    static let efTertiary = Color.secondary.opacity(0.55)
    static let efWarn = Color.dynamic(light: 0xB45309, dark: 0xFBBF24)
    static let efInfo = Color.dynamic(light: 0x2563EB, dark: 0x60A5FA)

    static let efHeroTop = Color.dynamic(light: 0x0B2545, dark: 0x16304F)
    static let efHeroBottom = Color.dynamic(light: 0x17426F, dark: 0x0B2240)
}

#if canImport(UIKit)
extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
#else
extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
#endif

// MARK: - fontes

public enum EFFonts {
    private static let registered: Bool = {
        for name in ["Sora-Medium", "Sora-SemiBold", "Sora-Bold"] {
            if let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") ?? Bundle.module.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        return true
    }()

    /// Registra as fontes da marca (uma vez, na abertura do app).
    public static func register() { _ = registered }
}

public extension Font {
    /// Sora (títulos e valores), acompanhando o tamanho de texto escolhido no iPhone.
    static func sora(_ size: CGFloat, _ weight: Font.Weight = .semibold, relativeTo style: Font.TextStyle = .body) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "Sora-Bold"
        case .medium, .regular, .light, .thin, .ultraLight: name = "Sora-Medium"
        default: name = "Sora-SemiBold"
        }
        return .custom(name, size: size, relativeTo: style)
    }
}

public extension View {
    /// Números alinhados (colunas de valores).
    func efNumbers() -> some View { monospacedDigit() }

    /// Cartão branco/escuro com cantos arredondados (como as listas agrupadas do iOS).
    func efCard(padding: CGFloat = 16, radius: CGFloat = 22) -> some View {
        self.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.efSurface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// Espaçamentos e raios usados nas telas.
public enum EFLayout {
    public static let gutter: CGFloat = 16
    public static let cardRadius: CGFloat = 22
    public static let section: CGFloat = 22
}

/// Lançamento do e-Finances (o SwiftUI também tem um tipo chamado Transaction).
public typealias Tx = EFCore.Transaction
