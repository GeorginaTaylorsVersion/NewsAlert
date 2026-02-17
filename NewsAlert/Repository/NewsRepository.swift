// File: Repository/NewsRepository.swift

import Foundation

protocol NewsRepositorying {
    func loadCachedStories() -> [Story]
    func refreshStories() async throws -> [Story]
}

final class NewsRepository: NewsRepositorying {
    private let services: [NewsService]
    private let clusterer: StoryClusteringService
    private let cacheStore: NewsCacheStore

    init(
        services: [NewsService]? = nil,
        clusterer: StoryClusteringService = SimpleStoryClusteringService(),
        cacheStore: NewsCacheStore = NewsCacheStore()
    ) {
        self.services = services ?? NewsRepository.defaultServices()
        self.clusterer = clusterer
        self.cacheStore = cacheStore
    }

    func loadCachedStories() -> [Story] {
        cacheStore.loadStories()
    }

    func refreshStories() async throws -> [Story] {
        var collected: [Article] = []

        await withTaskGroup(of: [Article].self) { group in
            for service in services {
                group.addTask {
                    (try? await service.fetchArticles()) ?? []
                }
            }

            for await articles in group {
                collected.append(contentsOf: articles)
            }
        }

        if collected.isEmpty {
            // Keep the app functional even when APIs fail.
            collected = SampleData.mockArticles()
        }

        collected = dedupeArticles(collected)

        let stories = clusterer.cluster(collected)
        cacheStore.saveStories(stories)
        return stories
    }
}

private extension NewsRepository {
    static func defaultServices(config: AppConfig = .load()) -> [NewsService] {
        if config.hasUsableBackendBaseURL {
            return [BackendBriefingService(config: config)]
        }

        return [
            NewsAPIService(config: config),
            NewsCatcherService(config: config),
            GuardianService(config: config)
        ]
    }

    func dedupeArticles(_ articles: [Article]) -> [Article] {
        var seenURLs = Set<String>()
        var seenSourceTitle = Set<String>()
        var output: [Article] = []

        for article in articles.sorted(by: { $0.publishedAt > $1.publishedAt }) {
            let urlKey = article.url.absoluteString
            if !seenURLs.insert(urlKey).inserted {
                continue
            }

            let normalizedTitle = normalizeTitle(article.title)
            let sourceTitleKey = "\(article.sourceDomain.lowercased())|\(normalizedTitle)"
            if !normalizedTitle.isEmpty, !seenSourceTitle.insert(sourceTitleKey).inserted {
                continue
            }

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
}
