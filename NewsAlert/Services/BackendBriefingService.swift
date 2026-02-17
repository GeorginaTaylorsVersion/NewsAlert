import Foundation

struct BackendBriefingService: NewsService {
    private let config: AppConfig
    private let apiClient: APIClient

    init(config: AppConfig = .load(), apiClient: APIClient = APIClient()) {
        self.config = config
        self.apiClient = apiClient
    }

    func fetchArticles() async throws -> [Article] {
        guard config.hasUsableBackendBaseURL, let baseURL = config.backendBaseURL else {
            return []
        }

        guard let url = briefingURL(from: baseURL) else {
            return []
        }

        var headers: [String: String] = [:]
        let token = config.backendAuthToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            headers["Authorization"] = "Bearer \(token)"
        }

        let response: BackendBriefingResponse = try await apiClient.fetchJSON(url: url, headers: headers)
        let generatedAt = parseDate(response.generatedAt) ?? Date()

        var allArticles: [Article] = []
        allArticles.append(contentsOf: mapItems(response.politics, category: .politics, generatedAt: generatedAt))
        allArticles.append(contentsOf: mapItems(response.technology, category: .technology, generatedAt: generatedAt))
        allArticles.append(contentsOf: mapItems(response.finance, category: .finance, generatedAt: generatedAt))
        allArticles.append(contentsOf: mapItems(response.entertainment, category: .entertainment, generatedAt: generatedAt))

        return dedupe(allArticles)
    }
}

private extension BackendBriefingService {
    struct BackendBriefingResponse: Decodable {
        let politics: [BackendItem]
        let technology: [BackendItem]
        let finance: [BackendItem]
        let entertainment: [BackendItem]
        let generatedAt: String
    }

    struct BackendItem: Decodable {
        let id: String?
        let title: String?
        let source: String?
        let summary: String?
        let url: String?
    }

    func briefingURL(from baseURL: URL) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if basePath.isEmpty {
            components.path = "/v1/briefing"
        } else {
            components.path = "/\(basePath)/v1/briefing"
        }

        return components.url
    }

    func mapItems(_ items: [BackendItem], category: NewsCategory, generatedAt: Date) -> [Article] {
        items.compactMap { item in
            guard let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
                return nil
            }

            let articleURL = (item.url ?? "").flatMap(URL.init(string:)) ?? URL(string: "https://newsalarm.local")!
            let trimmedSource = item.source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let sourceName = trimmedSource.isEmpty ? "NewsAlarm Backend" : trimmedSource
            let trimmedSummary = item.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let sourceDomain = extractDomain(from: articleURL)

            return Article(
                id: item.id ?? UUID().uuidString,
                title: title,
                sourceName: sourceName,
                sourceDomain: sourceDomain,
                publishedAt: generatedAt,
                url: articleURL,
                snippet: trimmedSummary.isEmpty ? "Summary unavailable." : String(trimmedSummary.prefix(220)),
                category: category,
                country: countryCode(fromDomain: sourceDomain),
                imageURL: nil
            )
        }
    }

    func parseDate(_ raw: String) -> Date? {
        if let parsed = DateFormatting.iso8601Decoder.date(from: raw) {
            return parsed
        }
        return DateFormatting.iso8601Fallback.date(from: raw)
    }

    func dedupe(_ articles: [Article]) -> [Article] {
        var seen = Set<String>()
        var output: [Article] = []

        for article in articles {
            let key = normalize(article.title)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            output.append(article)
        }

        return output
    }

    func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func extractDomain(from url: URL) -> String {
        let host = url.host?.lowercased() ?? "backend.local"
        return host.replacingOccurrences(of: "www.", with: "")
    }

    func countryCode(fromDomain domain: String) -> String {
        if domain.hasSuffix(".co.uk") {
            return "UK"
        }
        if domain.hasSuffix(".ca") {
            return "CA"
        }
        return "US"
    }
}
