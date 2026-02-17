// File: Services/NewsCatcherService.swift

import Foundation

struct NewsCatcherService: NewsService {
    private let config: AppConfig
    private let apiClient: APIClient

    init(config: AppConfig = .load(), apiClient: APIClient = APIClient()) {
        self.config = config
        self.apiClient = apiClient
    }

    func fetchArticles() async throws -> [Article] {
        guard config.hasUsableNewsCatcherKey else {
            return []
        }

        let queries: [NewsQuery] = [
            NewsQuery(category: .politics, query: "politics OR election OR government"),
            NewsQuery(category: .technology, query: "technology OR artificial intelligence OR software"),
            NewsQuery(category: .finance, query: "finance OR business OR markets"),
            NewsQuery(category: .entertainment, query: "entertainment OR film OR music"),
            NewsQuery(category: .world, query: "world news OR diplomacy OR conflict"),
            NewsQuery(category: .local, query: "city council OR local government OR metro")
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

private extension NewsCatcherService {
    struct NewsQuery {
        let category: NewsCategory
        let query: String
    }

    struct NewsCatcherResponse: Decodable {
        let articles: [Item]
    }

    struct Item: Decodable {
        let title: String?
        let summary: String?
        let excerpt: String?
        let snippet: String?
        let publishedDate: String?
        let link: String?
        let url: String?
        let sourceName: String?
        let cleanURL: String?
        let media: String?
        let country: String?

        private enum CodingKeys: String, CodingKey {
            case title
            case summary
            case excerpt
            case snippet
            case publishedDate = "published_date"
            case publishedAt
            case publishedAtSnake = "published_at"
            case link
            case url
            case sourceName = "source_name"
            case source
            case cleanURL = "clean_url"
            case media
            case country
            case countries
        }

        private struct SourceObject: Decodable {
            let name: String?
            let title: String?
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            title = try container.decodeIfPresent(String.self, forKey: .title)
            summary = try container.decodeIfPresent(String.self, forKey: .summary)
            excerpt = try container.decodeIfPresent(String.self, forKey: .excerpt)
            snippet = try container.decodeIfPresent(String.self, forKey: .snippet)
            link = try container.decodeIfPresent(String.self, forKey: .link)
            url = try container.decodeIfPresent(String.self, forKey: .url)
            media = try container.decodeIfPresent(String.self, forKey: .media)

            publishedDate =
                (try? container.decodeIfPresent(String.self, forKey: .publishedDate))
                ?? (try? container.decodeIfPresent(String.self, forKey: .publishedAt))
                ?? (try? container.decodeIfPresent(String.self, forKey: .publishedAtSnake))

            let sourceObject = try? container.decode(SourceObject.self, forKey: .source)
            sourceName =
                (try? container.decodeIfPresent(String.self, forKey: .sourceName))
                ?? (try? container.decodeIfPresent(String.self, forKey: .source))
                ?? sourceObject?.name
                ?? sourceObject?.title

            cleanURL = try container.decodeIfPresent(String.self, forKey: .cleanURL)

            if let countryValue = try? container.decodeIfPresent(String.self, forKey: .country) {
                country = countryValue
            } else if let countries = try? container.decode([String].self, forKey: .country) {
                country = countries.first
            } else if let countries = try? container.decode([String].self, forKey: .countries) {
                country = countries.first
            } else {
                country = nil
            }
        }
    }

    func fetchArticles(for query: NewsQuery) async throws -> [Article] {
        guard let endpoint = endpointURL() else {
            return []
        }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query.query),
            URLQueryItem(name: "lang", value: config.newsAPILanguage),
            URLQueryItem(name: "sort_by", value: "relevancy"),
            URLQueryItem(name: "page_size", value: "30")
        ]

        guard let url = components?.url else {
            return []
        }

        let headers = [
            "x-api-token": config.newsCatcherAPIKey
        ]

        let response: NewsCatcherResponse = try await apiClient.fetchJSON(url: url, headers: headers)
        return response.articles.compactMap { item in
            guard let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
                  let rawURL = item.link ?? item.url,
                  let articleURL = URL(string: rawURL),
                  let publishedValue = item.publishedDate,
                  let publishedAt = parseDate(publishedValue) else {
                return nil
            }

            let sourceName = (item.sourceName ?? "Unknown Source").trimmingCharacters(in: .whitespacesAndNewlines)
            let domain = normalizeDomain(item.cleanURL) ?? extractDomain(from: articleURL)
            let inferredCountry = (item.country ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

            return Article(
                title: title,
                sourceName: sourceName,
                sourceDomain: domain,
                publishedAt: publishedAt,
                url: articleURL,
                snippet: bestSnippet(summary: item.summary, excerpt: item.excerpt, snippet: item.snippet),
                category: query.category,
                country: inferredCountry.isEmpty ? countryCode(fromDomain: domain) : inferredCountry,
                imageURL: item.media.flatMap(URL.init(string:))
            )
        }
    }

    func endpointURL() -> URL? {
        guard var components = URLComponents(url: config.newsCatcherBaseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        if components.path.isEmpty || components.path == "/" {
            components.path = "/v3/search"
        }

        return components.url
    }

    func parseDate(_ value: String) -> Date? {
        if let parsed = DateFormatting.iso8601Decoder.date(from: value) {
            return parsed
        }

        if let parsed = DateFormatting.iso8601Fallback.date(from: value) {
            return parsed
        }

        return DateFormatting.newsCatcherFallback.date(from: value)
    }

    func bestSnippet(summary: String?, excerpt: String?, snippet: String?) -> String {
        let first = [summary, excerpt, snippet]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        guard let first else {
            return "Summary unavailable."
        }

        return String(first.prefix(220))
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

    func normalizeDomain(_ raw: String?) -> String? {
        guard let raw else { return nil }

        let host = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)

        return host.isEmpty ? nil : host
    }

    func extractDomain(from url: URL) -> String {
        let host = url.host?.lowercased() ?? "unknown"
        return host.replacingOccurrences(of: "www.", with: "")
    }

    func countryCode(fromDomain domain: String) -> String {
        if domain.hasSuffix(".co.uk") || domain.contains("bbc") || domain.contains("theguardian") {
            return "UK"
        }
        if domain.contains("reuters") || domain.contains("apnews") || domain.contains("wsj") || domain.contains("nytimes") {
            return "US"
        }
        if domain.hasSuffix(".ca") {
            return "CA"
        }
        return "US"
    }
}
