import SwiftUI
import EFCore
import EFFeatures

/// Antes do login: apresentação (só na primeira abertura), entrar, criar conta e esqueci a senha.
struct AuthFlow: View {
    @Environment(AppModel.self) private var app
    @State private var path: [AuthStep] = []

    enum AuthStep: Hashable { case register, forgot }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if app.settings.onboardingDone { LoginView(path: $path) } else { OnboardingView(path: $path) }
            }
            .navigationDestination(for: AuthStep.self) { step in
                switch step {
                case .register: RegisterView()
                case .forgot: ForgotPasswordView()
                }
            }
        }
    }
}

// MARK: - apresentação

struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @Binding var path: [AuthFlow.AuthStep]
    @State private var page = 0

    private let pages: [(String, String, String)] = [
        ("Seu dinheiro ", "num lugar só", "Contas manuais e bancos conectados na mesma tela. Saiba quanto tem hoje e quanto vai sobrar no fim do mês."),
        ("Parcelas e assinaturas ", "sob controle", "Veja quanto falta de cada parcelamento e quanto as assinaturas custam por mês e por ano."),
        ("Limites que ", "avisam antes", "Defina quanto quer gastar por categoria e receba um aviso no iPhone quando chegar perto. Todo mês, um resumo do que aconteceu.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    VStack(spacing: 24) {
                        OnboardingArt(page: i).frame(maxHeight: .infinity)
                        VStack(alignment: .leading, spacing: 12) {
                            (Text(pages[i].0) + Text(pages[i].1).foregroundColor(.efTint))
                                .font(.sora(32, .bold, relativeTo: .largeTitle))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(pages[i].2).font(.body).foregroundStyle(Color.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 16)
                    }
                    .tag(i)
                }
            }
            .efPaged()
            .animation(.easeInOut, value: page)

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule().fill(i == page ? Color.efInk : Color.secondary.opacity(0.3)).frame(width: i == page ? 22 : 8, height: 8)
                    }
                }
                .padding(.bottom, 10)
                .accessibilityElement()
                .accessibilityLabel("Página \(page + 1) de \(pages.count)")
                if page == pages.count - 1 {
                    Button("Criar conta grátis") { finish(); path.append(.register) }.buttonStyle(.efGreen)
                    Button("Já tenho conta") { finish() }.buttonStyle(.efSoft)
                } else {
                    Button("Continuar") { withAnimation { page += 1 } }.buttonStyle(.efPrimary)
                    Button("Pular") { finish() }.buttonStyle(.plain).foregroundStyle(Color.efTint).padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .animation(.easeInOut(duration: 0.2), value: page)
        }
        .background(Color.efBackground.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private func finish() { app.settings.onboardingDone = true }
}

/// Ilustrações da apresentação, feitas com os próprios componentes do app.
private struct OnboardingArt: View {
    let page: Int

    var body: some View {
        ZStack {
            switch page {
            case 0:
                HeroCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Saldo da conta").font(.footnote).foregroundStyle(.white.opacity(0.75))
                        (Text("R$ 8.432").font(.sora(30)) + Text(",17").font(.sora(18))).foregroundStyle(.white)
                        Text("Previsão de fechamento R$ 7.314,90").font(.caption).foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(width: 262).rotationEffect(.degrees(-4)).offset(y: -40)
                mini(bank: "Nubank", color: 0x820AD1, letters: "Nu", value: "R$ 3.214,55").rotationEffect(.degrees(3)).offset(x: -70, y: 70)
                mini(bank: "Inter", color: 0xFF7A00, letters: "in", value: "R$ 1.045,00").rotationEffect(.degrees(-2)).offset(x: 80, y: 130)
            case 1:
                HStack(spacing: 12) {
                    InstallmentRing(paid: 3, total: 10, size: 52)
                    VStack(alignment: .leading) {
                        Text("Notebook Dell").font(.subheadline.weight(.semibold))
                        Text("R$ 412,90/mês · até jul/2027").font(.caption).foregroundStyle(Color.secondary)
                    }
                }
                .efCard(padding: 14).frame(width: 262).shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                .rotationEffect(.degrees(-3)).offset(y: -60)
                VStack(spacing: 10) {
                    sub("netflix", "Netflix", "R$ 55,90")
                    sub("spotify", "Spotify", "R$ 34,90")
                    sub("smartfit", "Smart Fit", nil)
                }
                .efCard(padding: 14).frame(width: 250).shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                .rotationEffect(.degrees(2)).offset(x: 14, y: 70)
            default:
                HStack(spacing: 10) {
                    SettingsIcon("flag.fill", .efNavy)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Lazer passou do limite").font(.footnote.weight(.semibold))
                        Text("R$ 210,00 de R$ 180,00 em outubro").font(.caption).foregroundStyle(Color.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12).efGlass(cornerRadius: 22).padding(.horizontal, 18)
                .rotationEffect(.degrees(1.5)).offset(y: -120)
                VStack(alignment: .leading, spacing: 10) {
                    limit("Alimentação", 85, .efWarn)
                    limit("Transporte", 57, .efIncome)
                    limit("Lazer", 117, .efExpense)
                }
                .efCard(padding: 16).frame(width: 270).shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                .rotationEffect(.degrees(-2)).offset(y: 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    private func mini(bank: String, color: UInt32, letters: String, value: String) -> some View {
        HStack(spacing: 10) {
            Text(letters).font(.caption.weight(.bold)).foregroundStyle(.white).frame(width: 36, height: 36)
                .background(Color(hex: color), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(bank).font(.subheadline.weight(.semibold))
                Text(value).font(.caption).foregroundStyle(Color.secondary)
            }
        }
        .padding(12).background(Color.efSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }

    private func sub(_ brand: String, _ name: String, _ value: String?) -> some View {
        HStack(spacing: 10) {
            BrandMark(brand, size: 30)
            Text(name).font(.subheadline)
            Spacer()
            if let value { Text(value).font(.subheadline.weight(.semibold)) } else { Tag("+8%", color: .efWarn) }
        }
    }

    private func limit(_ name: String, _ pct: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(pct)%").font(.subheadline.weight(.semibold)).foregroundStyle(color)
            }
            ProgressBar(min(Double(pct) / 100, 1), color: color)
        }
    }
}

// MARK: - entrar

struct LoginView: View {
    @Environment(AppModel.self) private var app
    @Binding var path: [AuthFlow.AuthStep]
    @State private var vm: LoginViewModel?
    @State private var showPassword = false
    @FocusState private var focus: Field?

    enum Field { case email, password }

    var body: some View {
        Group {
            if let vm { form(vm) } else { Color.clear }
        }
        .background(Color.efBackground.ignoresSafeArea())
        .onAppear { if vm == nil { vm = LoginViewModel(app: app) } }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    @ViewBuilder private func form(_ vm: LoginViewModel) -> some View {
        @Bindable var vm = vm
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    EFLogo(size: 56)
                    Text("Entrar").font(.sora(34, .bold, relativeTo: .largeTitle))
                    Text("Use o mesmo e-mail e senha do e-Finances na web.").foregroundStyle(Color.secondary)
                    if vm.isDemo {
                        Tag("Demonstração: qualquer senha entra", symbol: "sparkles", color: .efInfo)
                    } else if !vm.envLabel.isEmpty {
                        Tag("Ambiente \(vm.envLabel)", symbol: "hammer", color: .efWarn)
                    }
                }
                .padding(.top, 36)

                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("E-mail").font(.footnote).foregroundStyle(Color.secondary)
                        TextField("voce@exemplo.com", text: $vm.email)
                            .efEmailField()
                            .focused($focus, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focus = .password }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    Divider().padding(.leading, 16)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Senha").font(.footnote).foregroundStyle(Color.secondary)
                        HStack {
                            Group {
                                if showPassword { TextField("Sua senha", text: $vm.password) } else { SecureField("Sua senha", text: $vm.password) }
                            }
                            .efPasswordField()
                            .focused($focus, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await vm.submit() } }
                            Button { showPassword.toggle() } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye").foregroundStyle(Color.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(showPassword ? "Esconder senha" : "Mostrar senha")
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .background(Color.efSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                if let e = vm.emailError ?? vm.passwordError ?? vm.error {
                    Label(e, systemImage: "exclamationmark.circle.fill").font(.footnote).foregroundStyle(Color.efExpense)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                HStack {
                    Toggle("Manter conectado", isOn: $vm.remember).fixedSize()
                    Spacer()
                    Button("Esqueci a senha") { path.append(.forgot) }.foregroundStyle(Color.efTint)
                }
                .font(.subheadline)

                Button {
                    focus = nil
                    Task { await vm.submit() }
                } label: {
                    HStack(spacing: 8) {
                        if vm.loading { ProgressView().tint(Color.efOnPrimary) }
                        Text(vm.loading ? "Entrando…" : "Entrar")
                    }
                }
                .buttonStyle(.efPrimary)
                .disabled(vm.loading)

                HStack(spacing: 4) {
                    Text("Ainda não tem conta?").foregroundStyle(Color.secondary)
                    Button("Criar conta") { path.append(.register) }.fontWeight(.semibold).foregroundStyle(Color.efTint)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { if vm.email.isEmpty { focus = .email } }
    }
}

// MARK: - criar conta

struct RegisterView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var vm: RegisterViewModel?
    @State private var web: WebPage?

    var body: some View {
        Group {
            if let vm {
                if vm.done { RegisterDoneView(email: vm.email) { dismiss() } } else { form(vm) }
            } else { Color.clear }
        }
        .navigationTitle(vm?.done == true ? "" : "Criar conta")
        .efLargeTitle()
        .onAppear { if vm == nil { vm = RegisterViewModel(app: app) } }
        .sheet(item: $web) { WebSheet(page: $0) }
    }

    @ViewBuilder private func form(_ vm: RegisterViewModel) -> some View {
        @Bindable var vm = vm
        Form {
            Section {
                Text("Comece pelo período grátis. Sem cartão de crédito.").foregroundStyle(Color.secondary).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            Section {
                field("Nome", text: $vm.firstName, error: vm.errors["firstName"]).efNameField()
                field("Sobrenome", text: $vm.lastName, error: vm.errors["lastName"])
                field("E-mail", text: $vm.email, error: vm.errors["email"]).efEmailField()
            }
            Section {
                field("Família ou empresa", text: $vm.companyName, error: vm.errors["company"])
                Picker("País", selection: $vm.country) {
                    ForEach(Country.all) { Text($0.name).tag($0) }
                }
                LabeledContent("Moeda", value: vm.country.currency == "BRL" ? "Real (R$)" : vm.country.currency == "EUR" ? "Euro (€)" : "Dólar (US$)")
            } footer: {
                Text("Dá para criar outras depois, como a sua empresa.")
            }
            Section {
                Toggle(isOn: $vm.terms) {
                    Text("Li e aceito os Termos de uso e a Política de privacidade.").font(.subheadline)
                }
                Button("Ler os Termos de uso") { web = app.page("Termos de uso", "terms") }
                Button("Ler a Política de privacidade") { web = app.page("Política de privacidade", "privacidade") }
            } footer: {
                if let e = vm.errors["terms"] { Text(e).foregroundStyle(Color.efExpense) }
            }
            Section {
                if let e = vm.error { Label(e, systemImage: "exclamationmark.circle.fill").foregroundStyle(Color.efExpense) }
                Button {
                    Task { await vm.submit() }
                } label: {
                    HStack(spacing: 8) {
                        if vm.loading { ProgressView().tint(Color.efOnPrimary) }
                        Text(vm.loading ? "Criando…" : "Criar conta")
                    }
                }
                .buttonStyle(.efPrimary)
                .disabled(vm.loading)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func field(_ label: String, text: Binding<String>, error: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField(label, text: text)
            if let error { Text(error).font(.caption).foregroundStyle(Color.efExpense) }
        }
    }
}

struct RegisterDoneView: View {
    let email: String
    let back: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            IconBadge(symbol: "envelope.badge", color: Color(hex: 0x059669), size: 84)
            Text("Confira seu e-mail").font(.sora(28, .bold, relativeTo: .title))
            (Text("Enviamos para ") + Text(email).bold() + Text(" o link para criar sua senha. Ele vale por 24 horas."))
                .multilineTextAlignment(.center).foregroundStyle(Color.secondary).frame(maxWidth: 320)
            Spacer()
            #if os(iOS)
            if let mail = URL(string: "message://") {
                Link(destination: mail) { Label("Abrir o Mail", systemImage: "envelope") }.buttonStyle(.efPrimary)
            }
            #endif
            Button("Voltar para o login", action: back).buttonStyle(.plain).foregroundStyle(Color.efTint).padding(.vertical, 10)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        #if os(iOS)
        .navigationBarBackButtonHidden()
        #endif
    }
}

// MARK: - esqueci a senha

struct ForgotPasswordView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var vm: ForgotPasswordViewModel?

    var body: some View {
        Group {
            if let vm { content(vm) } else { Color.clear }
        }
        .navigationTitle("Esqueci a senha")
        .efLargeTitle()
        .onAppear { if vm == nil { vm = ForgotPasswordViewModel(app: app) } }
    }

    @ViewBuilder private func content(_ vm: ForgotPasswordViewModel) -> some View {
        @Bindable var vm = vm
        Form {
            if vm.sent {
                Section {
                    VStack(spacing: 12) {
                        IconBadge(symbol: "envelope.badge", color: Color(hex: 0x059669), size: 64)
                        Text("Link enviado").font(.headline)
                        Text("Se houver uma conta com \(vm.email), o link para criar uma senha nova chega em instantes.")
                            .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                Section {
                    Button("Voltar para o login") { dismiss() }.buttonStyle(.efPrimary).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
            } else {
                Section {
                    TextField("E-mail", text: $vm.email).efEmailField().onSubmit { Task { await vm.submit() } }
                } header: {
                    Text("Informe o e-mail da sua conta. Enviaremos um link para criar uma senha nova.").textCase(nil).font(.subheadline)
                } footer: {
                    if let e = vm.error { Text(e).foregroundStyle(Color.efExpense) }
                }
                Section {
                    Button {
                        Task { await vm.submit() }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.loading { ProgressView().tint(Color.efOnPrimary) }
                            Text("Enviar link")
                        }
                    }
                    .buttonStyle(.efPrimary)
                    .disabled(vm.loading)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
        }
    }
}
