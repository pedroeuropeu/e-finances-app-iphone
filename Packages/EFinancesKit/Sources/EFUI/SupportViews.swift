import SwiftUI
import EFCore
import EFFeatures

/// Perguntas frequentes (o mesmo conteúdo da web), chamados com as respostas e novo chamado.
struct HelpView: View {
    var body: some View {
        Screen(SupportViewModel.init) { vm in HelpContentView(vm: vm) }
    }
}

private struct HelpContentView: View {
    @Environment(Router.self) private var router
    let vm: SupportViewModel
    @State private var newTicket = false

    var body: some View {
        @Bindable var vm = vm
        List {
            if !vm.query.trimmingCharacters(in: .whitespaces).isEmpty {
                Section {
                    if vm.results.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nada encontrado para “\(vm.query)”.").foregroundStyle(Color.secondary)
                            Button("Perguntar ao suporte") { newTicket = true }
                        }
                    }
                    ForEach(vm.results) { a in ArticleRow(article: a) }
                } header: { Text("Resultados") }
            } else {
                Section {
                    Picker("Chamados", selection: Binding(get: { vm.group }, set: { g in Task { await vm.setGroup(g) } })) {
                        ForEach(TicketGroup.allCases, id: \.self) { g in
                            Text(g == .open && vm.counts.open > 0 ? "\(g.label) (\(vm.counts.open))" : g.label).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)
                    switch vm.tickets {
                    case .loading: ProgressView().frame(maxWidth: .infinity)
                    case .failed(let e): Text(e.message).foregroundStyle(Color.secondary)
                    case .ready(let list):
                        if list.isEmpty { Text(vm.group == .open ? "Nenhum chamado aberto." : "Nenhum chamado.").foregroundStyle(Color.secondary) }
                        ForEach(list) { t in
                            NavigationLink(value: Route.ticket(t.id)) { TicketRow(ticket: t) }
                        }
                    }
                    Button { newTicket = true } label: { Label("Novo chamado", systemImage: "plus.circle.fill") }
                } header: { Text("Meus chamados") }

                Section("Perguntas frequentes") {
                    ForEach(vm.content.topics) { topic in
                        NavigationLink {
                            TopicView(topic: topic, articles: vm.content.articles(of: topic.id))
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(topic.label)
                                if let d = topic.description { Text(d).font(.footnote).foregroundStyle(Color.secondary).lineLimit(2) }
                            }
                        }
                    }
                }

                TestimonialSection()

                Section {
                    Button { newTicket = true } label: {
                        HStack(spacing: 12) {
                            SettingsIcon("headphones", Color(hex: 0x0EA5E9))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Falar com o suporte").foregroundStyle(Color.efInk)
                                Text("Respondemos aqui e por e-mail").font(.footnote).foregroundStyle(Color.secondary)
                            }
                        }
                    }
                }
            }
        }
        .efGroupedList()
        .navigationTitle("Ajuda e suporte")
        .efLargeTitle()
        .searchable(text: $vm.query, prompt: "Buscar nas perguntas frequentes")
        .refreshable { await vm.load() }
        .toolbar {
            ToolbarItem(placement: .efTrailing) {
                Button { newTicket = true } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel("Novo chamado")
            }
        }
        .sheet(isPresented: $newTicket) {
            NewTicketView { t in
                Task { await vm.load() }
                router.push(.ticket(t.id))
            }.efToasts()
        }
        .task { if vm.tickets.value == nil { await vm.load() } }
    }
}

private struct TopicView: View {
    let topic: HelpTopic
    let articles: [HelpArticle]

    var body: some View {
        List {
            if let d = topic.description { Section { Text(d).foregroundStyle(Color.secondary) } }
            Section { ForEach(articles) { ArticleRow(article: $0) } }
        }
        .efGroupedList()
        .navigationTitle(topic.label)
        .efLargeTitle(false)
    }
}

/// Pergunta que abre a resposta no lugar.
private struct ArticleRow: View {
    let article: HelpArticle
    @State private var open = false

    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(article.body.enumerated()), id: \.offset) { _, p in
                    Text(p).font(.subheadline).foregroundStyle(Color.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
        } label: {
            Text(article.title).foregroundStyle(Color.efInk)
        }
    }
}

private struct TicketRow: View {
    let ticket: Ticket

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol, ticket.status == .waitingUser ? Color(hex: 0xD97706) : ticket.status.closed ? Color(hex: 0x64748B) : Color(hex: 0x1D4E89))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(ticket.title).foregroundStyle(Color.efInk).lineLimit(1).fontWeight(ticket.unread ? .semibold : .regular)
                    if ticket.unread { Circle().fill(Color.efInfo).frame(width: 8, height: 8).accessibilityLabel("Resposta nova") }
                }
                Text([ticket.protocolNumber, (ticket.lastMessageAt ?? ticket.createdAt).map { DateFormats.api($0.date) }].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote).foregroundStyle(Color.secondary)
            }
            Spacer(minLength: 4)
            Tag(ticket.status.label, color: ticket.status == .waitingUser ? .efWarn : ticket.status.closed ? .secondary : .efInfo)
        }
    }

    private var symbol: String {
        switch ticket.category {
        case .question: "questionmark.circle.fill"
        case .problem: "ladybug.fill"
        case .billing: "creditcard.fill"
        case .account: "person.crop.circle.fill"
        case .accountDeletion: "person.crop.circle.badge.minus"
        case .suggestion: "lightbulb.fill"
        case nil: "bubble.left.fill"
        }
    }
}

// MARK: - chamado

struct TicketView: View {
    let id: Int64

    var body: some View {
        Screen({ TicketViewModel(app: $0, id: id) }) { vm in TicketContent(vm: vm) }
    }
}

private struct TicketContent: View {
    let vm: TicketViewModel
    @State private var reply = ""
    @FocusState private var focused: Bool

    var body: some View {
        LoadableContent(vm.state, retry: { await vm.load() }) { t in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        VStack(spacing: 4) {
                            Text(t.title).font(.headline).multilineTextAlignment(.center)
                            Text("\(t.protocolNumber) · \(t.category?.label ?? "Chamado") · \(t.status.label)").font(.footnote).foregroundStyle(Color.secondary)
                        }
                        .padding(.vertical, 8)
                        ForEach(t.messages) { m in bubble(m).id(m.id) }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear { if let last = t.messages.last { proxy.scrollTo(last.id, anchor: .bottom) } }
                .onChange(of: t.messages.count) { if let last = t.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } } }
            }
            .safeAreaInset(edge: .bottom) { if !t.status.closed { composer } else { closedBar } }
            .navigationTitle(t.protocolNumber)
            .toolbar {
                ToolbarItem(placement: .efTrailing) {
                    Menu {
                        if t.status.closed {
                            Button { Task { await vm.reopen() } } label: { Label("Reabrir chamado", systemImage: "arrow.uturn.backward") }
                        } else {
                            Button { Task { await vm.close(solved: true) } } label: { Label("Encerrar: foi resolvido", systemImage: "checkmark.circle") }
                            Button { Task { await vm.close(solved: false) } } label: { Label("Encerrar sem solução", systemImage: "xmark.circle") }
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("Opções do chamado")
                }
            }
        }
        .background(Color.efBackground.ignoresSafeArea())
        .efLargeTitle(false)
        .task { if vm.state.value == nil { await vm.load() } }
    }

    private func bubble(_ m: TicketMessage) -> some View {
        HStack {
            if !m.fromSupport { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                Text(m.message).fixedSize(horizontal: false, vertical: true)
                Text([m.fromSupport ? (m.authorName ?? "Suporte e-Finances") : "Você", m.createdAt.map { "\(DateFormats.dayMonth($0.date)) \(DateFormats.time($0))" }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption2).opacity(0.7)
            }
            .padding(12)
            .foregroundStyle(m.fromSupport ? Color.efInk : Color.efOnPrimary)
            .background(m.fromSupport ? Color.efSurface : Color.efPrimary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if m.fromSupport { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Responder", text: $reply, axis: .vertical)
                .lineLimit(1...5)
                .focused($focused)
                .padding(.horizontal, 14).padding(.vertical, 10)
            Button {
                let text = reply
                Task { if await vm.reply(text) { reply = "" } }
            } label: {
                Group {
                    if vm.sending { ProgressView() } else { Image(systemName: "arrow.up").fontWeight(.bold) }
                }
                .frame(width: 34, height: 34)
                .foregroundStyle(.white)
                .background(Color.efTint, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.sending)
            .accessibilityLabel("Enviar resposta")
            .padding(5)
        }
        .efGlass(cornerRadius: 24)
        .padding(.horizontal, 12).padding(.bottom, 8)
    }

    private var closedBar: some View {
        Button { Task { await vm.reopen() } } label: { Label("Reabrir chamado", systemImage: "arrow.uturn.backward") }
            .buttonStyle(.efSoft)
            .padding(.horizontal, 16).padding(.bottom, 8)
    }
}

// MARK: - novo chamado

struct NewTicketView: View {
    var category: TicketCategory = .question
    let onCreated: (Ticket) -> Void

    var body: some View {
        Screen({ NewTicketViewModel(app: $0, category: category) }) { vm in NewTicketContent(vm: vm, onCreated: onCreated) }
    }
}

private struct NewTicketContent: View {
    @Environment(\.dismiss) private var dismiss
    let vm: NewTicketViewModel
    let onCreated: (Ticket) -> Void

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            Form {
                Section("Sobre o quê?") {
                    ForEach(TicketCategory.pickable, id: \.self) { c in
                        Button { vm.category = c } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(c.label).foregroundStyle(Color.efInk)
                                    Text(c.hint).font(.footnote).foregroundStyle(Color.secondary)
                                }
                                Spacer()
                                if vm.category == c { Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.efTint) }
                            }
                        }
                        .accessibilityAddTraits(vm.category == c ? .isSelected : [])
                    }
                }
                Section {
                    TextField("Assunto (resuma em poucas palavras)", text: $vm.title)
                    TextField("Conte o que aconteceu", text: $vm.message, axis: .vertical).lineLimit(4...10)
                } footer: {
                    Label("Enviamos junto o modelo do iPhone, a versão do iOS e a do app para agilizar.", systemImage: "iphone")
                }
            }
            .navigationTitle("Novo chamado")
            .efLargeTitle(false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.sending { ProgressView() } else {
                        Button("Enviar") {
                            Task {
                                if let t = await vm.send(deviceInfo: DeviceInfo.summary) {
                                    dismiss()
                                    onCreated(t)
                                }
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(!vm.canSend)
                    }
                }
            }
        }
        .interactiveDismissDisabled(!vm.message.isEmpty)
    }
}

// MARK: - depoimento

/// "Está gostando do e-Finances?": deixar, editar ou retirar o depoimento.
private struct TestimonialSection: View {
    var body: some View {
        Screen(TestimonialViewModel.init) { vm in TestimonialRow(vm: vm) }
    }
}

private struct TestimonialRow: View {
    let vm: TestimonialViewModel
    @State private var editing = false
    @State private var confirmWithdraw = false

    var body: some View {
        Section {
            if vm.loaded {
                HStack(alignment: .top, spacing: 12) {
                    SettingsIcon("heart.fill", Color(hex: 0xDC2626))
                    VStack(alignment: .leading, spacing: 4) {
                        if let mine = vm.mine {
                            Text("Seu depoimento").fontWeight(.semibold)
                            if let st = mine.status {
                                Tag(st.label, color: st == .approved ? .efIncome : st == .pending ? .efWarn : .secondary)
                                Text(st.hint).font(.footnote).foregroundStyle(Color.secondary)
                            }
                        } else {
                            Text("Está gostando do e-Finances?").fontWeight(.semibold)
                            Text("Conte em poucas palavras como ele ajuda você. Com a sua autorização, o depoimento pode aparecer no nosso site.")
                                .font(.footnote).foregroundStyle(Color.secondary)
                        }
                    }
                }
                Button { vm.startEditing(); editing = true } label: {
                    Label(vm.mine == nil ? "Deixar um depoimento" : "Editar depoimento", systemImage: vm.mine == nil ? "quote.bubble" : "pencil")
                }
                if vm.mine != nil {
                    Button("Retirar do site", role: .destructive) { confirmWithdraw = true }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .task { if !vm.loaded { await vm.load() } }
        .sheet(isPresented: $editing) { TestimonialSheet(vm: vm).efToasts() }
        .confirmationDialog("Retirar seu depoimento?", isPresented: $confirmWithdraw, titleVisibility: .visible) {
            Button("Retirar", role: .destructive) { Task { await vm.withdraw() } }
        } message: { Text("Ele sai do site na hora.") }
    }
}

private struct TestimonialSheet: View {
    @Environment(\.dismiss) private var dismiss
    let vm: TestimonialViewModel

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            Form {
                Section("Sua nota") {
                    HStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { n in
                            Button { vm.form.rating = n } label: {
                                Image(systemName: n <= vm.form.rating ? "star.fill" : "star").font(.title)
                                    .foregroundStyle(n <= vm.form.rating ? Color(hex: 0xF59E0B) : Color.secondary.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(n) de 5")
                            .accessibilityAddTraits(vm.form.rating == n ? .isSelected : [])
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                Section {
                    TextField("Ex.: Antes eu me perdia nas contas do mês; agora vejo tudo num lugar só e sei quanto posso gastar.", text: $vm.form.text, axis: .vertical)
                        .lineLimit(4...10)
                } header: { Text("O que o e-Finances mudou para você?") } footer: {
                    Text("\(vm.form.text.count)/\(Testimonial.maxText)").frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundStyle(vm.form.text.count > Testimonial.maxText ? Color.efExpense : .secondary)
                }
                Section {
                    TextField("Como seu nome aparece (ex.: Ana S.)", text: $vm.form.authorName)
                    TextField("Descrição, opcional (ex.: Autônoma · Lisboa)", text: $vm.form.authorRole)
                }
                Section {
                    Toggle(isOn: $vm.form.consent) {
                        Text("Autorizo o e-Finances a publicar este depoimento, com o nome e a descrição acima, no site. Posso retirar quando quiser.")
                            .font(.subheadline)
                    }
                } footer: {
                    if let e = vm.error { Text(e).foregroundStyle(Color.efExpense) }
                    else { Text("A equipe revisa antes de publicar. Editar volta para análise.") }
                }
            }
            .navigationTitle(vm.mine == nil ? "Deixar um depoimento" : "Editar depoimento")
            .efLargeTitle(false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.saving { ProgressView() } else {
                        Button("Enviar") { Task { if await vm.save() { dismiss() } } }.fontWeight(.semibold)
                    }
                }
            }
        }
    }
}
