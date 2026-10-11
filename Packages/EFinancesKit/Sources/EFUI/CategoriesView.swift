import SwiftUI
import PhotosUI
import ImageIO
import UniformTypeIdentifiers
import EFCore
import EFFeatures

/// Categorias com o gasto do mês na conta em uso, limite, filtros e a aparência (ícone e cor, marca ou logo próprio).
struct CategoriesView: View {
    let filter: CategoryFilter

    var body: some View {
        Screen({ CategoriesViewModel(app: $0, filter: filter) }) { vm in CategoriesContent(vm: vm) }
    }
}

/// Categoria aberta na folha (nova ou existente).
private struct CategoryEdit: Identifiable {
    let id = UUID()
    var view: CategoryView?
}

private struct CategoriesContent: View {
    @Environment(AppModel.self) private var app
    let vm: CategoriesViewModel
    @State private var editing: CategoryEdit?

    var body: some View {
        @Bindable var vm = vm
        List {
            Section {
                HStack {
                    Button { Task { await vm.changeMonth(-1) } } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Mês anterior")
                    Spacer()
                    Text("\(DateFormats.monthYearTitle(vm.month)) · \(vm.accountName)").font(.subheadline.weight(.semibold))
                    Spacer()
                    Button { Task { await vm.changeMonth(1) } } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Próximo mês")
                }
                .buttonStyle(.borderless)
                if let o = vm.state.value {
                    HStack(spacing: 10) {
                        KPITile("Gasto no mês", value: o.spent, detail: "na conta em uso")
                        KPITile("Assinaturas", value: vm.subscriptions?.monthlyTotal ?? 0, detail: "por mês · \(o.subscriptions) categorias")
                    }
                    if o.overLimit > 0 || o.nearLimit > 0 {
                        NoticeBanner(symbol: "flag.fill",
                                     title: [o.overLimit > 0 ? "\(o.overLimit) passou do limite" : nil, o.nearLimit > 0 ? "\(o.nearLimit) \(o.nearLimit == 1 ? "está perto" : "estão perto") do limite" : nil].compactMap { $0 }.joined(separator: " · "),
                                     text: "Toque na categoria para ajustar o limite.", color: .efExpense)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CategoryFilter.allCases, id: \.self) { f in
                            FilterChip("\(f.label) (\(vm.count(f)))", selected: vm.filter == f) { vm.filter = f }
                        }
                    }
                }
            }
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowSeparator(.hidden)

            switch vm.state {
            case .loading: Section { LoadingView().frame(minHeight: 220) }.listRowBackground(Color.clear)
            case .failed(let e): Section { ErrorView(e) { await vm.load() } }.listRowBackground(Color.clear)
            case .ready:
                Section {
                    if vm.filtered.isEmpty { Text("Nenhuma categoria encontrada.").foregroundStyle(.secondary) }
                    ForEach(vm.filtered.sorted { $0.spent > $1.spent }) { v in
                        Button { editing = CategoryEdit(view: v) } label: { row(v) }
                            .swipeActions {
                                if !v.category.systemDefault {
                                    Button(role: .destructive) { Task { _ = await vm.delete(v.category) } } label: { Label("Excluir", systemImage: "trash") }
                                }
                            }
                    }
                } footer: {
                    Label("As padrão do sistema só mudam o limite. As suas mudam nome, aparência e se contam como assinatura.", systemImage: "lock")
                }
                .listRowBackground(Color.efSurface)
            }
        }
        .efGroupedList()
        .scrollContentBackground(.hidden)
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle("Categorias")
        .efLargeTitle()
        .searchable(text: $vm.query, prompt: "Buscar categoria")
        .refreshable { await vm.load() }
        .toolbar {
            ToolbarItem(placement: .efTrailing) {
                Button { editing = CategoryEdit() } label: { Image(systemName: "plus") }.accessibilityLabel("Nova categoria")
            }
        }
        .sheet(item: $editing) { e in CategoryEditor(vm: vm, editing: e.view) }
        .task { if vm.state.value == nil { await vm.load() } }
    }

    private func row(_ v: CategoryView) -> some View {
        let color: Color = v.limitStatus == .over ? .efExpense : v.limitStatus == .warn ? .efWarn : .efIncome
        return HStack(alignment: .top, spacing: 12) {
            CategoryBadge(v.category, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(v.category.name).foregroundStyle(Color.efInk).lineLimit(1)
                    if v.category.subscription { Tag("Assinatura", color: Color(hex: 0xC026D3)) }
                }
                HStack(spacing: 4) {
                    if v.category.systemDefault { Image(systemName: "lock.fill").font(.caption2) }
                    Text("\(plural(Int(v.count), "lançamento", "lançamentos"))\(v.category.isIncomeCategory ? " · receita" : "")")
                }
                .font(.footnote).foregroundStyle(.secondary)
                if let p = v.limitPercent {
                    ProgressBar(min(Double(p) / 100, 1), color: color, height: 5).padding(.top, 4)
                }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 1) {
                MoneyText(v.category.isIncomeCategory ? v.income : v.spent, currency: vm.currency, font: .subheadline.weight(.medium))
                if let l = v.limit {
                    HStack(spacing: 2) {
                        Text("de").font(.caption2).foregroundStyle(.secondary)
                        MoneyText(l, currency: vm.currency, font: .caption2, color: .secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - editor

private enum LookKind: Hashable { case icon, brand, logo }

private struct CategoryEditor: View {
    @Environment(\.dismiss) private var dismiss
    let vm: CategoriesViewModel
    let editing: CategoryView?
    @State private var form: CategoryForm
    @State private var look: LookKind
    @State private var brandQuery = ""
    @State private var photo: PhotosPickerItem?
    @State private var confirmDelete = false

    init(vm: CategoriesViewModel, editing: CategoryView?) {
        self.vm = vm
        self.editing = editing
        let f = editing.map(CategoryForm.init) ?? CategoryForm()
        _form = State(initialValue: f)
        _look = State(initialValue: f.logo != nil ? .logo : f.brand != nil ? .brand : .icon)
    }

    private var systemDefault: Bool { editing?.category.systemDefault == true }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        CategoryBadge(form.look, size: 72, fallbackName: form.name)
                        Text(form.name.isEmpty ? "Nova categoria" : form.name).font(.sora(20, .semibold, relativeTo: .title3))
                        if systemDefault { Text("Padrão do sistema: só o limite muda.").font(.footnote).foregroundStyle(.secondary) }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                if !systemDefault {
                    Section {
                        TextField("Nome (ex.: Viagens)", text: $form.name)
                        TextField("Descrição (opcional)", text: $form.description)
                    }
                    Section("Aparência") {
                        Picker("Aparência", selection: $look) {
                            Text("Ícone e cor").tag(LookKind.icon)
                            Text("Marca").tag(LookKind.brand)
                            Text("Logo próprio").tag(LookKind.logo)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                        switch look {
                        case .icon: iconPicker
                        case .brand: brandPicker
                        case .logo: logoPicker
                        }
                    }
                    Section {
                        Toggle(isOn: $form.subscription) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("É assinatura")
                                Text("Os lançamentos desta categoria entram em Assinaturas.").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Limite por mês")
                        Spacer()
                        Text("R$").foregroundStyle(.secondary)
                        TextField("Sem limite", text: $form.limit).efDecimalField().multilineTextAlignment(.trailing).frame(maxWidth: 130)
                    }
                    if !form.limit.trimmingCharacters(in: .whitespaces).isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Avisar quando chegar em")
                                Spacer()
                                Text("\(form.alertPercent)%").fontWeight(.semibold).foregroundStyle(Color.efTint).monospacedDigit()
                            }
                            Slider(value: Binding(get: { Double(form.alertPercent) }, set: { form.alertPercent = Int($0) }), in: 50...100, step: 5).tint(.efGreen)
                        }
                    }
                } footer: { Text("Deixe vazio para não ter limite.") }

                if let e = editing, !systemDefault {
                    Section {
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Excluir categoria", systemImage: "trash") }
                    } footer: {
                        if e.usage > 0 { Text("Categoria com lançamentos não pode ser excluída: mude os lançamentos de categoria antes.") }
                    }
                }
            }
            .navigationTitle(editing == nil ? "Nova categoria" : systemDefault ? "Categoria padrão" : "Editar categoria")
            .efLargeTitle(false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.saving { ProgressView() } else { Button("Salvar") { save() }.fontWeight(.semibold) }
                }
            }
            .confirmationDialog("Excluir “\(form.name)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Excluir", role: .destructive) {
                    Task { if let c = editing?.category, await vm.delete(c) { dismiss() } }
                }
            } message: { Text("Dá para restaurar logo depois.") }
            .onChange(of: photo) { _, item in Task { await loadPhoto(item) } }
        }
    }

    private func save() {
        var f = form
        switch look {
        case .icon: f.brand = nil; f.logo = nil
        case .brand: f.logo = nil
        case .logo: f.brand = nil
        }
        Task { if await vm.save(f, editing: editing) { dismiss() } }
    }

    // MARK: aparência

    private var iconPicker: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(CategoryLooks.icons, id: \.self) { icon in
                    let on = form.icon == icon
                    Button { form.icon = icon } label: {
                        Image(systemName: Icons.symbol(prime: icon))
                            .font(.body)
                            .frame(width: 38, height: 38)
                            .foregroundStyle(on ? Color.white : Color.efInk)
                            .background(on ? (Color(hexString: form.color) ?? .efTint) : Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(icon.replacingOccurrences(of: "pi-", with: ""))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 10) {
                ForEach(CategoryLooks.colors, id: \.self) { hex in
                    let on = form.color?.uppercased() == hex.uppercased()
                    Button { form.color = hex } label: {
                        Circle().fill(Color(hexString: hex) ?? .gray).frame(width: 30, height: 30)
                            .overlay { if on { Circle().strokeBorder(Color.efSurface, lineWidth: 3) } }
                            .padding(3)
                            .overlay { if on { Circle().strokeBorder(Color(hexString: hex) ?? .gray, lineWidth: 2) } }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cor \(hex)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var brandPicker: some View {
        let q = brandQuery.normalizedForSearch
        let groups = BrandCatalog.shared.byGroup.compactMap { g, items -> (String, [(String, Brand)])? in
            let f = q.isEmpty ? items : items.filter { $0.1.name.normalizedForSearch.contains(q) }
            return f.isEmpty ? nil : (g, f)
        }
        return VStack(alignment: .leading, spacing: 12) {
            TextField("Buscar marca", text: $brandQuery)
                .padding(10).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(groups, id: \.0) { g, items in
                        Text(g).font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
                            ForEach(items, id: \.0) { key, brand in
                                let on = form.brand == key
                                Button {
                                    form.brand = key
                                    if form.name.trimmingCharacters(in: .whitespaces).isEmpty { form.name = brand.name }
                                } label: {
                                    VStack(spacing: 4) {
                                        BrandMark(key, size: 44)
                                            .overlay { if on { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.efTint, lineWidth: 3).padding(-4) } }
                                        Text(brand.name).font(.caption2).lineLimit(1).foregroundStyle(Color.efInk)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 300)
        }
        .padding(.vertical, 6)
    }

    private var logoPicker: some View {
        let title = form.logo == nil ? "Escolher imagem nas Fotos" : "Trocar imagem"
        return VStack(spacing: 10) {
            PhotosPicker(selection: $photo, matching: .images) {
                Label(title, systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.efTint)
            if form.logo != nil {
                Button("Remover imagem", role: .destructive) { form.logo = nil }.font(.footnote)
            }
            Text("O app reduz a imagem para 128 × 128 antes de enviar.").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        if let url = LogoImage.dataURL(from: data, maxPixel: 128) { form.logo = url }
    }
}

/// Reduz a imagem escolhida (PNG, até [maxPixel] de lado) e devolve "data:image/png;base64,...", como a web guarda.
enum LogoImage {
    static func dataURL(from data: Data, maxPixel: Int) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return "data:image/png;base64," + (out as Data).base64EncodedString()
    }
}
