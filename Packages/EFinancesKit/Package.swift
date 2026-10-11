// swift-tools-version:6.0
import PackageDescription

/*
 Código do app e-Finances para iPhone, em camadas:
 - EFCore: modelos, regras de negócio, formatação e contratos dos repositórios (sem UI, sem rede)
 - EFData: API do e-Finances (URLSession), sessão no Keychain e o modo demonstração
 - EFFeatures: estado e ações de cada tela (view models @Observable)
 - EFUI: telas em SwiftUI e o design system
 O alvo do app (Xcode) só junta tudo. A plataforma macOS existe para rodar os testes e compilar as telas neste Mac.
 */
let package = Package(
    name: "EFinancesKit",
    defaultLocalization: "pt-BR",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "EFCore", targets: ["EFCore"]),
        .library(name: "EFData", targets: ["EFData"]),
        .library(name: "EFFeatures", targets: ["EFFeatures"]),
        .library(name: "EFUI", targets: ["EFUI"])
    ],
    targets: [
        .target(name: "EFCore"),
        .target(name: "EFData", dependencies: ["EFCore"]),
        .target(name: "EFFeatures", dependencies: ["EFCore"], resources: [.copy("Resources/help.json"), .copy("Resources/brands.json")]),
        .target(name: "EFUI", dependencies: ["EFCore", "EFData", "EFFeatures"], resources: [.copy("Resources/Fonts")]),
        .testTarget(name: "EFCoreTests", dependencies: ["EFCore"]),
        .testTarget(name: "EFDataTests", dependencies: ["EFCore", "EFData"]),
        .testTarget(name: "EFFeaturesTests", dependencies: ["EFCore", "EFData", "EFFeatures"])
    ]
)
