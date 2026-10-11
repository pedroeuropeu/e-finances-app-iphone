import SwiftUI
import EFFeatures
import EFUI

/// Ponto de entrada: monta o app para o ambiente do Info.plist (Demonstração, Local ou Produção) e abre a raiz.
@main
struct EFinancesApp: App {
    @State private var app: AppModel

    init() {
        EFAppearance.configure()
        _app = State(initialValue: AppFactory.make())
    }

    var body: some Scene {
        WindowGroup {
            RootView(app: app)
        }
    }
}
