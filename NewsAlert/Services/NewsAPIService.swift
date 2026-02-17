// File: Services/NewsAPIService.swift

import Foundation

struct NewsAPIService: NewsService {
    private let config: AppConfig
    private let apiClient: APIClient

    init(config: AppConfig = .load(), apiClient: APIClient = APIClient()) {
        self.config = config
        self.apiClient = apiClient
    }

    func fetchArticles() async throws -> [Article] {
        guard config.hasUsableAPIKey else {
            // Preview/development mode: show local samples until a real key is configured.
            let sampleFromJSON = decodeSampleJSONForPreview()
            return dedupeArticles(sampleFromJSON + SampleData.mockArticles())
        }

        let queries: [NewsQuery] = [
            NewsQuery(category: .politics, query: "politics OR government OR election"),
            NewsQuery(category: .technology, query: "technology OR AI OR software"),
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

private extension NewsAPIService {
    struct NewsQuery {
        let category: NewsCategory
        let query: String
    }

    struct NewsAPIResponse: Decodable {
        let status: String
        let articles: [Item]

        struct Item: Decodable {
            let source: Source
            let title: String?
            let description: String?
            let content: String?
            let url: String?
            let urlToImage: String?
            let publishedAt: String?

            struct Source: Decodable {
                let name: String?
            }
        }
    }

    func fetchArticles(for query: NewsQuery) async throws -> [Article] {
        var components = URLComponents(url: config.newsAPIBaseURL, resolvingAgainstBaseURL: false)
        components?.path = "/v2/everything"
        components?.queryItems = [
            URLQueryItem(name: "q", value: query.query),
            URLQueryItem(name: "language", value: config.newsAPILanguage),
            URLQueryItem(name: "sortBy", value: "publishedAt"),
            URLQueryItem(name: "pageSize", value: "35"),
            URLQueryItem(name: "apiKey", value: config.newsAPIKey)
        ]

        guard let url = components?.url else {
            return []
        }

        let response: NewsAPIResponse = try await apiClient.fetchJSON(url: url)

        return response.articles.compactMap { item in
            guard let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
                  let rawURL = item.url,
                  let url = URL(string: rawURL),
                  let publishedString = item.publishedAt,
                  let publishedAt = parseDate(publishedString) else {
                return nil
            }

            let sourceName = (item.source.name ?? "Unknown Source").trimmingCharacters(in: .whitespacesAndNewlines)
            let domain = extractDomain(from: url)

            return Article(
                title: title,
                sourceName: sourceName,
                sourceDomain: domain,
                publishedAt: publishedAt,
                url: url,
                snippet: bestSnippet(description: item.description, content: item.content),
                category: query.category,
                country: countryCode(fromDomain: domain),
                imageURL: item.urlToImage.flatMap(URL.init(string:))
            )
        }
    }

    func decodeSampleJSONForPreview() -> [Article] {
        guard let data = SampleData.newsAPIResponseJSON.data(using: .utf8) else {
            return []
        }

        do {
            let response = try JSONDecoder().decode(NewsAPIResponse.self, from: data)
            let categoryOrder: [NewsCategory] = [.politics, .technology, .finance, .entertainment]

            return response.articles.enumerated().compactMap { index, item in
                guard let title = item.title,
                      let rawURL = item.url,
                      let url = URL(string: rawURL),
                      let publishedString = item.publishedAt,
                      let publishedAt = parseDate(publishedString) else {
                    return nil
                }

                let category = categoryOrder[min(index, categoryOrder.count - 1)]
                let sourceName = item.source.name ?? "Unknown"
                let domain = extractDomain(from: url)

                return Article(
                    title: title,
                    sourceName: sourceName,
                    sourceDomain: domain,
                    publishedAt: publishedAt,
                    url: url,
                    snippet: bestSnippet(description: item.description, content: item.content),
                    category: category,
                    country: countryCode(fromDomain: domain),
                    imageURL: item.urlToImage.flatMap(URL.init(string:))
                )
            }
        } catch {
            return []
        }
    }

    func parseDate(_ value: String) -> Date? {
        if let parsed = DateFormatting.iso8601Decoder.date(from: value) {
            return parsed
        }
        return DateFormatting.iso8601Fallback.date(from: value)
    }

    func bestSnippet(description: String?, content: String?) -> String {
        let desc = description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !desc.isEmpty {
            return String(desc.prefix(220))
        }

        let body = content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !body.isEmpty {
            return String(body.prefix(220))
        }

        return "Summary unavailable."
    }

    func dedupeArticles(_ articles: [Article]) -> [Article] {
        var seen = Set<String>()
        var output: [Article] = []

        for article in articles.sorted(by: { $0.publishedAt > $1.publishedAt }) {
            let key = normalizeTitle(article.title)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
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

    func countryCode(fromDomain domain: String) -> String {
        // TODO: Replace with a real source metadata service for domain->country mapping.
        if domain.hasSuffix(".co.uk") || domain.contains("bbc") || domain.contains("ft.com") {
            return "UK"
        }
        if domain.contains("reuters") || domain.contains("apnews") || domain.contains("wsj") || domain.contains("nytimes") {
            return "US"
        }
        if domain.contains("aljazeera") {
            return "QA"
        }
        if domain.hasSuffix(".ca") {
            return "CA"
        }
        return "US"
    }
}

// TODO: Add additional provider services (NewsData.io / The News API) and include them
// in NewsRepository's default services array when keys are configured.
