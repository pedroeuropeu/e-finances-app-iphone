import Foundation
import EFCore

/* Conteúdo copiado da web (scripts/sync-web-content.sh): perguntas frequentes e catálogo de marcas. */

public struct HelpTopic: Decodable, Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let description: String?
}

public struct HelpArticle: Decodable, Identifiable, Hashable, Sendable {
    public let id: String
    public let topic: String
    public let title: String
    public let body: [String]
    public let keywords: String?
}

public struct HelpContent: Decodable, Sendable {
    public let topics: [HelpTopic]
    public let articles: [HelpArticle]

    public static let shared: HelpContent = {
        guard let url = Bundle.module.url(forResource: "help", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let c = try? JSONDecoder().decode(HelpContent.self, from: data) else { return HelpContent(topics: [], articles: []) }
        return c
    }()

    public init(topics: [HelpTopic], articles: [HelpArticle]) { self.topics = topics; self.articles = articles }

    /// Busca sem acentos no título, no texto e nas palavras-chave (todas as palavras precisam aparecer).
    public func search(_ query: String) -> [HelpArticle] {
        let words = query.normalizedForSearch.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !words.isEmpty else { return articles }
        return articles.filter { a in
            let text = ([a.title, a.keywords ?? ""] + a.body).joined(separator: " ").normalizedForSearch
            return words.allSatisfy { text.contains($0) }
        }
    }

    public func articles(of topic: String) -> [HelpArticle] { articles.filter { $0.topic == topic } }
}

/// Marca do catálogo da web (logo do simple-icons, CC0): caminho SVG em 24×24 ou, sem desenho, a sigla.
public struct Brand: Decodable, Hashable, Sendable {
    public let name: String
    public let group: String
    public let color: String
    public let path: String?
    public let short: String?
    /// Fundo claro: desenho/sigla em escuro.
    public let light: Bool?
}

public struct BrandCatalog: Decodable, Sendable {
    public let groups: [String]
    public let brands: [String: Brand]

    public static let shared: BrandCatalog = {
        guard let url = Bundle.module.url(forResource: "brands", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let c = try? JSONDecoder().decode(BrandCatalog.self, from: data) else { return BrandCatalog(groups: [], brands: [:]) }
        return c
    }()

    public init(groups: [String], brands: [String: Brand]) { self.groups = groups; self.brands = brands }

    /// Marcas por grupo, na ordem da web.
    public var byGroup: [(String, [(String, Brand)])] {
        groups.compactMap { g in
            let items = brands.filter { $0.value.group == g }.sorted { $0.value.name < $1.value.name }.map { ($0.key, $0.value) }
            return items.isEmpty ? nil : (g, items)
        }
    }
}

/// Ícones e cores que a web oferece para as categorias (PrimeIcons), na mesma ordem do seletor.
public enum CategoryLooks {
    public static let icons = [
        "pi-tag", "pi-home", "pi-shopping-cart", "pi-shopping-bag", "pi-car", "pi-map", "pi-send", "pi-bolt", "pi-cloud",
        "pi-phone", "pi-wifi", "pi-heart", "pi-plus-circle", "pi-book", "pi-briefcase", "pi-wallet", "pi-chart-line", "pi-money-bill", "pi-credit-card",
        "pi-building", "pi-percentage", "pi-file", "pi-shield", "pi-gift", "pi-ticket", "pi-video", "pi-desktop", "pi-mobile", "pi-server", "pi-box",
        "pi-tags", "pi-sun", "pi-flag", "pi-users", "pi-user", "pi-megaphone", "pi-replay", "pi-star", "pi-camera", "pi-palette", "pi-wrench", "pi-globe"
    ]

    public static let colors = [
        "#4338CA", "#6366F1", "#7C3AED", "#A855F7", "#DB2777", "#E11D48", "#EF4444", "#F97316", "#F59E0B", "#16A34A",
        "#0F766E", "#0EA5E9", "#2563EB", "#334155", "#64748B", "#78716C"
    ]
}
