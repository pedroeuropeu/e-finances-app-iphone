import SwiftUI
import StoreKit
import EFCore
import EFFeatures

/// O restante do sistema no estilo dos Ajustes do iPhone.
struct MoreView: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    @Environment(\.requestReview) private var requestReview
    @State private var confirmLogout = false

    var body: some View {
        List {
            Section {
                NavigationLink(value: Route.profile) {
                    HStack(spacing: 14) {
                        Text(app.profile?.initials ?? "").font(.title3.weight(.semibold)).foregroundStyle(.white)
                            .frame(width: 58, height: 58).background(Color.efNavy, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.profile?.fullName ?? "Minha conta").font(.title3.weight(.semibold))
                            Text(app.profile?.email ?? app.settings.lastEmail).font(.subheadline).foregroundStyle(Color.secondary)
                            if let plan = app.profile?.planName { Tag(plan, symbol: "crown.fill", color: .efTint) }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                link(.reports, "chart.bar.fill", Color(hex: 0x4338CA), "Relatórios")
                link(.categories(.all), "tag.fill", Color(hex: 0xF97316), "Categorias", sub: "Limites, marcas e assinaturas")
                link(.contacts, "person.2.fill", Color(hex: 0x059669), "Contatos")
                link(.costCenters, "point.3.connected.trianglepath.dotted", Color(hex: 0x7C3AED), "Centros de custo")
            }

            Section {
                link(.companies, "building.2.fill", Color(hex: 0x0E7490), "Empresas e contas", sub: "Onde ficam seus lançamentos")
                web("doc.badge.plus", Color(hex: 0x0284C7), "Importar extrato", path: "finances/transactions")
                web("square.and.arrow.up.fill", Color(hex: 0x0284C7), "Exportar transações", path: "finances/transactions")
                web("doc.text.fill", Color(hex: 0x64748B), "Modelos de recibo", path: "finances/receipt")
            } footer: { Text("Importar, exportar e recibos abrem na web, dentro do app.") }

            Section {
                link(.profile, "person.crop.circle.fill", Color(hex: 0x1D4E89), "Minha conta")
                link(.billing, "crown.fill", Color(hex: 0xCA8A04), "Plano e faturas", value: app.profile?.planName)
                link(.notifications, "bell.badge.fill", Color(hex: 0xDC2626), "Notificações", value: app.unread > 0 ? "\(app.unread)" : nil)
                link(.appearance, "paintpalette.fill", Color(hex: 0xDB2777), "Aparência", value: app.settings.theme.label)
                link(.security, DeviceAuth.symbol, Color(hex: 0x16A34A), "\(DeviceAuth.biometryName) e segurança", value: app.settings.lockEnabled ? "Ativado" : "Desativado")
            }

            Section {
                link(.help, "lifepreserver.fill", Color(hex: 0x0EA5E9), "Ajuda e suporte")
                Button { requestReview() } label: { row("star.fill", Color(hex: 0xF59E0B), "Avaliar na App Store") }
                link(.about, "info.circle.fill", Color(hex: 0x64748B), "Sobre o app")
            }

            Section {
                Button("Sair", role: .destructive) { confirmLogout = true }.frame(maxWidth: .infinity)
            } footer: {
                Text("e-Finances \(DeviceInfo.appVersion)\(app.envLabel.isEmpty ? "" : " · \(app.envLabel)")").frame(maxWidth: .infinity).padding(.top, 8)
            }
        }
        .efGroupedList()
        .navigationTitle("Mais")
        .efLargeTitle()
        .confirmationDialog("Sair do e-Finances?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Sair", role: .destructive) { Task { await app.logout() } }
        } message: { Text("Você vai precisar do e-mail e da senha para entrar de novo.") }
    }

    private func link(_ route: Route, _ symbol: String, _ color: Color, _ title: String, sub: String? = nil, value: String? = nil) -> some View {
        NavigationLink(value: route) { row(symbol, color, title, sub: sub, value: value) }
    }

    private func web(_ symbol: String, _ color: Color, _ title: String, path: String) -> some View {
        Button { router.web = app.page(title, path) } label: {
            HStack {
                row(symbol, color, title, sub: "Abre na web")
                Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.efTertiary)
            }
        }
    }

    private func row(_ symbol: String, _ color: Color, _ title: String, sub: String? = nil, value: String? = nil) -> some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol, color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).foregroundStyle(Color.efInk)
                if let sub { Text(sub).font(.footnote).foregroundStyle(Color.secondary) }
            }
            Spacer(minLength: 4)
            if let value { Text(value).foregroundStyle(Color.secondary) }
        }
    }
}

// MARK: - minha conta

struct ProfileView: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router
    @State private var sendingReset = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Text(app.profile?.initials ?? "").font(.largeTitle.weight(.semibold)).foregroundStyle(.white)
                        .frame(width: 88, height: 88).background(Color.efNavy, in: Circle())
                    Text(app.profile?.fullName ?? "").font(.sora(22, .semibold, relativeTo: .title2))
                    if let plan = app.profile?.planName { Tag(plan, symbol: "crown.fill", color: .efTint) }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            Section {
                LabeledContent("Nome", value: app.profile?.firstName ?? "—")
                LabeledContent("Sobrenome", value: app.profile?.lastName ?? "—")
                LabeledContent("E-mail", value: app.profile?.email ?? app.settings.lastEmail)
                if let end = app.profile?.planEndDate { LabeledContent("Plano válido até", value: DateFormats.api(end)) }
            } footer: {
                Text("Para mudar seus dados, use a web. Para trocar o e-mail, fale com o suporte.")
            }
            Section {
                Button { router.web = app.page("Meu perfil", "profileuser") } label: { Label("Editar perfil na web", systemImage: "person.text.rectangle") }
                Button {
                    Task {
                        sendingReset = true
                        let email = app.profile?.email ?? app.settings.lastEmail
                        switch await app.repos.auth.forgotPassword(email: email) {
                        case .success: app.messenger.show("Enviamos um link para trocar a senha", icon: "envelope")
                        case .failure(let e): app.messenger.show(e.message, icon: "exclamationmark.circle")
                        }
                        sendingReset = false
                    }
                } label: {
                    HStack {
                        Label("Trocar senha", systemImage: "key")
                        Spacer()
                        if sendingReset { ProgressView() }
                    }
                }
                .disabled(sendingReset)
            } footer: { Text("Enviamos um link para o seu e-mail.") }
            Section("Privacidade e dados") {
                Button { router.web = app.page("Política de privacidade", "privacidade") } label: { Label("Política de privacidade", systemImage: "checkmark.shield") }
                NavigationLink(value: Route.deleteAccount) {
                    Label("Excluir minha conta", systemImage: "person.crop.circle.badge.minus").foregroundStyle(Color.efExpense)
                }
            }
        }
        .efGroupedList()
        .navigationTitle("Minha conta")
        .efLargeTitle(false)
    }
}

// MARK: - excluir conta

/// Exclusão da conta pedida no app (App Store, diretriz 5.1.1(v)): vira o chamado "Exclusão de conta", como na web.
struct AccountDeletionView: View {
    var body: some View {
        Screen(AccountDeletionViewModel.init) { vm in AccountDeletionContent(vm: vm) }
    }
}

private struct AccountDeletionContent: View {
    let vm: AccountDeletionViewModel
    @State private var confirm = false
    @State private var confirmCancel = false

    var body: some View {
        @Bindable var vm = vm
        List {
            Section {
                VStack(spacing: 10) {
                    IconBadge(symbol: "person.crop.circle.badge.minus", color: .efExpense, size: 72)
                    Text("Excluir sua conta do e-Finances").font(.sora(22, .semibold, relativeTo: .title2)).multilineTextAlignment(.center)
                    Text("Vale para você e para todas as empresas da conta.").font(.subheadline).foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            if vm.loading {
                Section { ProgressView().frame(maxWidth: .infinity) }.listRowBackground(Color.clear)
            } else if let t = vm.pending {
                Section {
                    NoticeBanner(symbol: "checkmark.circle.fill", title: "Pedido enviado\(t.createdAt.map { " em \(DateFormats.api($0.date))" } ?? "")",
                                 text: "A equipe confirma em até 2 dias úteis. Até lá, e por 30 dias depois, você pode reativar tudo entrando com a sua senha.",
                                 color: .efIncome, action: "Cancelar o pedido") { confirmCancel = true }
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            Section("O que acontece") {
                step("clock.fill", Color(hex: 0x0EA5E9), "O pedido é analisado", "Vira um chamado “Exclusão de conta” e a equipe confirma.")
                step("lock.fill", Color(hex: 0x64748B), "Ninguém mais entra", "As sessões são encerradas, inclusive na web.")
                step("arrow.uturn.backward", Color(hex: 0x16A34A), "30 dias para voltar atrás", "Entrando com a senha: reativar tudo ou começar do zero.")
                step("trash.fill", Color(hex: 0xDC2626), "Depois, tudo é apagado", "Empresas, lançamentos, comprovantes, bancos conectados e o seu acesso.")
                step("doc.text.fill", Color(hex: 0xCA8A04), "O que a lei obriga a guardar", "As faturas pagas ficam, com o titular anonimizado.")
            }
            if !vm.loading && vm.pending == nil {
                Section("Conte o motivo (opcional)") {
                    ForEach(AccountDeletionViewModel.reasonOptions, id: \.self) { r in
                        Button {
                            if vm.reasons.contains(r) { vm.reasons.remove(r) } else { vm.reasons.insert(r) }
                        } label: {
                            HStack {
                                Text(r).foregroundStyle(Color.efInk)
                                Spacer()
                                if vm.reasons.contains(r) { Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.efTint) }
                            }
                        }
                        .accessibilityAddTraits(vm.reasons.contains(r) ? .isSelected : [])
                    }
                    TextField("Quer contar mais alguma coisa?", text: $vm.note, axis: .vertical).lineLimit(2...5)
                }
                Section {
                    Button {
                        confirm = true
                    } label: {
                        HStack(spacing: 8) {
                            if vm.sending { ProgressView().tint(.white) }
                            Text("Pedir a exclusão da conta")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .efExpense, foreground: .white))
                    .disabled(vm.sending)
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                } footer: {
                    Text("Pedido em nome de \(vm.email). Também dá para pedir pela web.")
                }
            }
        }
        .efGroupedList()
        .navigationTitle("Excluir conta")
        .efLargeTitle(false)
        .task { await vm.load() }
        .confirmationDialog("Excluir sua conta?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Excluir", role: .destructive) { Task { _ = await vm.request() } }
        } message: {
            Text("Você e as pessoas convidadas perdem o acesso. Você tem 30 dias para reativar; depois disso, os dados são apagados.")
        }
        .confirmationDialog("Cancelar o pedido de exclusão?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Manter minha conta") { Task { await vm.cancel() } }
        }
    }

    private func step(_ symbol: String, _ color: Color, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            SettingsIcon(symbol, color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(text).font(.footnote).foregroundStyle(Color.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - plano e faturas (só leitura)

/**
 Plano e faturas só para consulta. Na 1ª versão não há compra dentro do app (App Store, diretriz 3.1.1): sem preços,
 sem botão de assinar e sem link para pagar em outro lugar.
 */
struct BillingView: View {
    var body: some View {
        Screen(BillingViewModel.init) { vm in BillingContent(vm: vm) }
    }
}

private struct BillingContent: View {
    let vm: BillingViewModel

    var body: some View {
        LoadableContent(vm.state, retry: { await vm.load() }) { b in
            List {
                Section {
                    HeroCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Seu plano").font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.78))
                            Text(b.plan.name).font(.sora(32, .bold, relativeTo: .largeTitle)).foregroundStyle(.white)
                            Text([b.plan.period?.label, b.plan.validUntil.map { "válido até \(DateFormats.api($0))" }].compactMap { $0 }.joined(separator: " · "))
                                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                            Tag(b.plan.status.label, symbol: b.plan.status == .expired ? "exclamationmark.circle" : "checkmark.circle",
                                color: b.plan.status == .expired ? Color(hex: 0xFCA5A5) : .efGreen)
                            if let s = b.storage {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label("Comprovantes", systemImage: "icloud").font(.caption).foregroundStyle(.white.opacity(0.75))
                                    Text("\(Int(s.usedMb.rounded())) MB de \(s.totalMb >= 1024 ? "\(s.totalMb / 1024) GB" : "\(s.totalMb) MB")")
                                        .font(.callout.weight(.semibold)).foregroundStyle(.white)
                                    ProgressBar(Double(s.percent) / 100, color: .efGreen, track: .white.opacity(0.2), height: 4)
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())

                Section {
                    if b.invoices.isEmpty { Text("Nenhuma fatura ainda.").foregroundStyle(Color.secondary) }
                    ForEach(b.invoices) { i in
                        HStack(spacing: 12) {
                            SettingsIcon("doc.text.fill", i.status == .paid ? Color(hex: 0x059669) : Color(hex: 0x64748B))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(i.description).lineLimit(1)
                                Text([i.date.map(DateFormats.api), i.planName].compactMap { $0 }.joined(separator: " · ")).font(.footnote).foregroundStyle(Color.secondary)
                            }
                            Spacer(minLength: 6)
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(i.totalFormatted.isEmpty ? Money.format(i.total) : i.totalFormatted).font(.subheadline.weight(.medium)).monospacedDigit()
                                Text(i.status.label).font(.caption2).foregroundStyle(i.status == .paid ? Color.efIncome : Color.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: { Text("Faturas") } footer: {
                    Text("Para mudar de plano ou pagar uma fatura, entre no e-Finances pelo computador.")
                }
            }
            .efGroupedList()
            .refreshable { await vm.load() }
        }
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle("Plano e faturas")
        .efLargeTitle()
        .task { if vm.state.value == nil { await vm.load() } }
    }
}

// MARK: - aparência

struct AppearanceView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var settings = app.settings
        List {
            Section("Tema") {
                Picker("Tema", selection: $settings.theme) {
                    ForEach(ThemeMode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section {
                Toggle("Esconder valores ao abrir", isOn: $settings.hideOnOpen)
            } header: { Text("Privacidade na tela") } footer: {
                Text("Mostra R$ •••• até você tocar no olho do Início.")
            }
            Section {
                Button { DeviceInfo.openSettings() } label: {
                    HStack {
                        Label("Idioma do app", systemImage: "globe")
                        Spacer()
                        Text("Português").foregroundStyle(Color.secondary)
                    }
                }
            } footer: { Text("No iPhone, o idioma de cada app muda nos Ajustes.") }
        }
        .efGroupedList()
        .navigationTitle("Aparência")
        .efLargeTitle()
    }
}

// MARK: - segurança

struct SecurityView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var settings = app.settings
        let available = DeviceAuth.available
        List {
            Section {
                Toggle("Desbloquear com \(DeviceAuth.biometryName)", isOn: Binding(get: { settings.lockEnabled && available }, set: { on in
                    if on {
                        Task { if await DeviceAuth.authenticate("Ativar o desbloqueio do e-Finances") { settings.lockEnabled = true } }
                    } else { settings.lockEnabled = false }
                }))
                .disabled(!available)
                Toggle("Cobrir no alternador de apps", isOn: $settings.coverInSwitcher)
            } footer: {
                Text(available ? "Ao abrir o app. Sem \(DeviceAuth.biometryName), vale o código do iPhone. A senha não fica guardada no iPhone."
                     : "Ative um código no iPhone (Ajustes › Face ID e Código) para bloquear o app.")
            }
            if settings.lockEnabled && available {
                Section("Bloquear o app depois de") {
                    Picker("Tempo", selection: $settings.lockTimeoutMinutes) {
                        Text("Na hora").tag(0)
                        Text("1 minuto").tag(1)
                        Text("5 minutos").tag(5)
                        Text("15 minutos").tag(15)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    Button { app.lockNow() } label: { Label("Bloquear agora", systemImage: "lock") }
                }
            }
            Section {
                EmptyView()
            } footer: {
                Text("A sessão fica guardada no Keychain deste iPhone e só é lida com o aparelho desbloqueado.")
            }
        }
        .efGroupedList()
        .navigationTitle("Segurança")
        .efLargeTitle()
    }
}

// MARK: - sobre

struct AboutView: View {
    @Environment(AppModel.self) private var app
    @Environment(Router.self) private var router

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    EFLogo(size: 76)
                    (Text("e") + Text("·").foregroundColor(.efGreen) + Text("finances")).font(.sora(28, .semibold))
                    Text("Versão \(DeviceInfo.appVersion) · iOS 17 ou mais novo").font(.subheadline).foregroundStyle(Color.secondary)
                    if app.demo { Tag("Modo demonstração: dados de exemplo", symbol: "sparkles", color: .efInfo) }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            Section {
                Button { router.web = app.page("Termos de uso", "terms") } label: { Label("Termos de uso", systemImage: "doc.text") }
                Button { router.web = app.page("Política de privacidade", "privacidade") } label: { Label("Política de privacidade", systemImage: "checkmark.shield") }
                Button { router.web = WebPage(title: "e-Finances", url: app.webURL) } label: { Label("Abrir o e-Finances na web", systemImage: "safari") }
            }
            Section {
                LabeledContent("Fontes", value: "Sora (SIL OFL 1.1)")
                LabeledContent("Logos de marcas", value: "Simple Icons (CC0)")
            } header: { Text("Licenças") }
        }
        .efGroupedList()
        .navigationTitle("Sobre o app")
        .efLargeTitle(false)
    }
}
