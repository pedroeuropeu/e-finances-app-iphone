import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/* Ajustes que só existem no iOS. O app roda no iPhone; o macOS serve só para compilar e testar as telas neste Mac. */

public extension View {
    /// Título grande (telas das abas) ou pequeno (telas empilhadas).
    @ViewBuilder func efLargeTitle(_ large: Bool = true) -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(large ? .large : .inline)
        #else
        self
        #endif
    }

    /// Lista agrupada com cantos (inset grouped).
    @ViewBuilder func efGroupedList() -> some View {
        #if os(iOS)
        listStyle(.insetGrouped).listSectionSpacing(.compact)
        #else
        listStyle(.inset)
        #endif
    }

    @ViewBuilder func efEmailField() -> some View {
        #if os(iOS)
        keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.username)
        #else
        self
        #endif
    }

    @ViewBuilder func efPasswordField() -> some View {
        #if os(iOS)
        textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder func efDecimalField() -> some View {
        #if os(iOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    /// Só dígitos (valor em centavos).
    @ViewBuilder func efNumberField() -> some View {
        #if os(iOS)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }

    @ViewBuilder func efPhoneField() -> some View {
        #if os(iOS)
        keyboardType(.phonePad).textContentType(.telephoneNumber)
        #else
        self
        #endif
    }

    @ViewBuilder func efNameField() -> some View {
        #if os(iOS)
        textContentType(.givenName).textInputAutocapitalization(.words)
        #else
        self
        #endif
    }

    /// Tela cheia por cima (fechamento do mês); no Mac vira folha.
    @ViewBuilder func efFullScreen<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }

    /// Carrossel de páginas com pontinhos (apresentação).
    @ViewBuilder func efPaged() -> some View {
        #if os(iOS)
        tabViewStyle(.page(indexDisplayMode: .never))
        #else
        self
        #endif
    }

    /// iOS 26: a barra de abas encolhe ao rolar para baixo.
    @ViewBuilder func efMinimizingTabBar() -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) { tabBarMinimizeBehavior(.onScrollDown) } else { self }
        #else
        self
        #endif
    }

    /// Fundo de vidro (iOS 26) ou material translúcido (versões anteriores).
    @ViewBuilder func efGlass(cornerRadius: CGFloat = 24) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

public extension ToolbarItemPlacement {
    /// Canto direito da barra de navegação.
    static var efTrailing: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .primaryAction
        #endif
    }

    /// Canto esquerdo da barra de navegação.
    static var efLeading: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .navigation
        #endif
    }
}

/// Informações do aparelho (User-Agent, chamado de suporte).
@MainActor public enum DeviceInfo {
    public static var system: String {
        #if os(iOS)
        "iOS \(UIDevice.current.systemVersion)"
        #else
        "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        #endif
    }

    /// Identificador do modelo ("iPhone17,1").
    public static var model: String {
        var info = utsname()
        uname(&info)
        let id = withUnsafeBytes(of: &info.machine) { raw in String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self) }
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "iPhone"
        #else
        return id.isEmpty ? "iPhone" : id
        #endif
    }

    public static var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let v = info["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = info["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    /// "iPhone17,1 · iOS 26.1 · app 1.0.0 (1)" (vai junto no chamado de suporte).
    public static var summary: String { "\(model) · \(system) · app \(appVersion)" }

    /// Abre os Ajustes do iPhone na página do app.
    public static func openSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        #endif
    }
}

/// Toque leve de confirmação (as ações principais usam .sensoryFeedback).
@MainActor public enum Haptics {
    public static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    public static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

/// Fontes da marca e títulos das barras em Sora (o resto do visual fica com o sistema).
public enum EFAppearance {
    @MainActor public static func configure() {
        EFFonts.register()
        #if os(iOS)
        let nav = UINavigationBar.appearance()
        if let large = UIFont(name: "Sora-Bold", size: 32) {
            nav.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large)]
        }
        if let small = UIFont(name: "Sora-SemiBold", size: 17) {
            nav.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: small)]
        }
        #endif
    }
}
