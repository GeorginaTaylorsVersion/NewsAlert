// File: Services/GuardianService.swift

import Foundation

struct GuardianService: NewsService {
    private let config: AppConfig
    private let apiClient: APIClient

    init(config: AppConfig = .load(), apiClient: APIClient = APIClient()) {
        self.config = config
        self.apiClient = apiClient
    }

    func fetchArticles() async throws -> [Article] {
        guard config.hasUsableGuardianKey else {
            return []
        }

        let queries: [GuardianQuery] = [
            GuardianQuery(category: .politics, section: "politics"),
            GuardianQuery(category: .technology, section: "technology"),
            GuardianQuery(category: .finance, section: "business"),
            GuardianQuery(category: .entertainment, section: "culture"),
            GuardianQuery(category: .world, section: "world"),
            GuardianQuery(category: .local, section: "us-news")
        ]

        var collected: [Article] = []

        try await withThrowingTaskGroup(of: [Article].self) { group in
            for query in queries {
                group.addTask {
                    try await fetchArticles(for: query)
                }
            }

            for try await chunk in group {
                collected.append(contentsOf: chunk)
            }
        }

        return dedupeArticles(collected)
    }
}

private extension GuardianService {
    struct GuardianQuery {
        let category: NewsCategory
        let section: String
    }

    struct GuardianEnvelope: Decodable {
        let response: Payload

        struct Payload: Decodable {
            let results: [ResultItem]
        }

        struct ResultItem: Decodable {
            let webTitle: String
            let webURL: String
            let webPublicationDate: String?
            let sectionName: String?
            let fields: Fields?

            private enum CodingKeys: String, CodingKey {
                case webTitle
                case webURL = "webUrl"
                case webPublicationDate
                case sectionName
                case fields
            }

            struct Fields: Decodable {
                let trailText: String?
                let thumbnail: String?
            }
        }
    }

    func fetchArticles(for query: GuardianQuery) async throws -> [Article] {
        guard let endpoint = endpointURL() else {
            return []
        }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "api-key", value: config.guardianAPIKey),
            URLQueryItem(name: "section", value: query.section),
            URLQueryItem(name: "order-by", value: "newest"),
            URLQueryItem(name: "page-size", value: "30"),
            URLQueryItem(name: "show-fields", value: "trailText,thumbnail")
        ]

        guard let url = components?.url else {
            return []
        }

        let response: GuardianEnvelope = try await apiClient.fetchJSON(url: url)
        return response.response.results.compactMap { item in
            guard let articleURL = URL(string: item.webURL) else {
                return nil
            }

            let publishedAt = parseDate(item.webPublicationDate) ?? Date()
            let domain = extractDomain(from: articleURL)
            let country = countryCode(fromSection: query.section, fallbackDomain: domain)
            let snippet = bestSnippet(item.fields?.trailText)

            return Article(
                title: item.webTitle,
                sourceName: "The Guardian",
                sourceDomain: domain,
                publishedAt: publishedAt,
                url: articleURL,
                snippet: snippet,
                category: query.category,
                country: country,
                imageURL: item.fields?.thumbnail.flatMap(URL.init(string:))
            )
        }
    }

    func endpointURL() -> URL? {
        guard var components = URLComponents(url: config.guardianBaseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        if components.path.isEmpty || components.path == "/" {
            components.path = "/search"
        }

        return components.url
    }

    func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let parsed = DateFormatting.iso8601Decoder.date(from: value) {
            return parsed
        }
        return DateFormatting.iso8601Fallback.date(from: value)
    }

    func bestSnippet(_ raw: String?) -> String {
        let cleaned = stripHTML(raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            return String(cleaned.prefix(220))
        }

        return "Summary unavailable."
    }

    func stripHTML(_ input: String) -> String {
        input
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    func dedupeArticles(_ articles: [Article]) -> [Article] {
        var seen = Set<String>()
        var output: [Article] = []

        for article in articles.sorted(by: { $0.publishedAt > $1.publishedAt }) {
            let titleKey = normalizeTitle(article.title)
            guard !titleKey.isEmpty else { continue }

            let key = "\(article.sourceDomain.lowercased())|\(titleKey)"
            guard seen.insert(key).inserted else { continue }
            output.append(article)
        }

        return output
    }

    func normalizeTitle(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func extractDomain(from url: URL) -> String {
        let host = url.host?.lowercased() ?? "unknown"
        return host.replacingOccurrences(of: "www.", with: "")
    }

    func countryCode(fromSection section: String, fallbackDomain domain: String) -> String {
        if section.contains("us") || domain.contains(".com") {
            return "US"
        }
        return "UK"
    }
}
