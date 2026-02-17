// File: Services/StoryClusteringService.swift

import Foundation

protocol StoryClusteringService {
    func cluster(_ articles: [Article]) -> [Story]
}

struct SimpleStoryClusteringService: StoryClusteringService {
    let timeWindowHours: Int
    let titleSimilarityThreshold: Double
    let minimumSummaryWords: Int

    init(
        timeWindowHours: Int = 6,
        titleSimilarityThreshold: Double = 0.32,
        minimumSummaryWords: Int = 160
    ) {
        self.timeWindowHours = timeWindowHours
        self.titleSimilarityThreshold = titleSimilarityThreshold
        self.minimumSummaryWords = minimumSummaryWords
    }

    func cluster(_ articles: [Article]) -> [Story] {
        let grouped = Dictionary(grouping: articles) { $0.category }
        var stories: [Story] = []

        for category in NewsCategory.allCases {
            guard let categoryArticles = grouped[category] else { continue }
            let categoryStories = clusterCategoryArticles(categoryArticles, category: category)
            stories.append(contentsOf: categoryStories)
        }

        return stories.sorted {
            if $0.importanceScore == $1.importanceScore {
                return $0.publishedAtRange.end > $1.publishedAtRange.end
            }
            return $0.importanceScore > $1.importanceScore
        }
    }
}

private extension SimpleStoryClusteringService {
    func clusterCategoryArticles(_ articles: [Article], category: NewsCategory) -> [Story] {
        let sorted = articles.sorted { $0.publishedAt > $1.publishedAt }
        var clusters: [[Article]] = []

        for article in sorted {
            if let index = matchingClusterIndex(for: article, clusters: clusters) {
                clusters[index].append(article)
            } else {
                clusters.append([article])
            }
        }

        return clusters.compactMap { cluster in
            makeStory(from: cluster, category: category)
        }
    }

    func matchingClusterIndex(for article: Article, clusters: [[Article]]) -> Int? {
        let timeWindow = TimeInterval(timeWindowHours * 3600)

        for (index, cluster) in clusters.enumerated() {
            guard let seed = cluster.first else { continue }

            let timeGap = abs(seed.publishedAt.timeIntervalSince(article.publishedAt))
            guard timeGap <= timeWindow else { continue }

            let similarity = titleSimilarity(seed.title, article.title)
            if similarity >= titleSimilarityThreshold {
                return index
            }
        }

        return nil
    }

    func makeStory(from cluster: [Article], category: NewsCategory) -> Story? {
        let sortedCluster = cluster.sorted { $0.publishedAt > $1.publishedAt }
        guard let top = sortedCluster.first,
              let oldest = sortedCluster.last?.publishedAt else {
            return nil
        }

        // TODO: Replace this title/snippet strategy with server-side semantic summarization.
        let summary = buildSummary(from: sortedCluster)
        let distinctCountries = Array(Set(sortedCluster.map { $0.country })).sorted()
        let sourceCount = Set(sortedCluster.map { $0.sourceName.lowercased() }).count

        let hoursSinceTop = max(0, Date().timeIntervalSince(top.publishedAt) / 3600)
        let recencyBoost = max(0, 12 - hoursSinceTop) * 0.15
        let importanceScore = Double(sourceCount) * 1.8 + recencyBoost

        return Story(
            mainTitle: top.title,
            category: category,
            summary: summary,
            articles: sortedCluster,
            primarySourceName: top.sourceName,
            publishedAtRange: DateInterval(start: oldest, end: top.publishedAt),
            countries: distinctCountries,
            importanceScore: importanceScore
        )
    }

    func buildSummary(from articles: [Article]) -> String {
        let snippets = articles
            .map { $0.snippet }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        if !snippets.isEmpty {
            let combined = snippets
                .joined(separator: " ")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return ensureMinimumWords(combined, minimumWords: minimumSummaryWords)
        }

        return ensureMinimumWords(
            "Details are still loading for this story. Additional reporting from multiple outlets will be reflected after the next refresh cycle.",
            minimumWords: minimumSummaryWords
        )
    }

    func titleSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let lhsWords = normalizedWords(from: lhs)
        let rhsWords = normalizedWords(from: rhs)

        guard !lhsWords.isEmpty, !rhsWords.isEmpty else { return 0 }

        let intersection = lhsWords.intersection(rhsWords)
        let denominator = Double(max(lhsWords.count, rhsWords.count))
        return Double(intersection.count) / denominator
    }

    func normalizedWords(from text: String) -> Set<String> {
        let stopWords: Set<String> = [
            "the", "a", "an", "and", "or", "to", "for", "of", "in", "on", "with",
            "new", "after", "amid", "as", "at", "from", "by", "into", "over"
        ]

        let cleaned = text
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)

        let components = cleaned
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 && !stopWords.contains($0) }

        return Set(components)
    }

    func ensureMinimumWords(_ text: String, minimumWords: Int) -> String {
        let base = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var words = base.split(separator: " ").map(String.init)

        if words.count >= minimumWords {
            return base
        }

        let additions = [
            "This summary is based on currently available reporting and may evolve as additional verified details are published.",
            "Early headlines can shift as official statements and timelines are clarified through follow-up coverage.",
            "Reviewing multiple outlets helps separate confirmed facts from speculation during fast-moving updates.",
            "Use linked source articles for complete context, direct quotes, and chronology."
        ]

        var index = 0
        while words.count < minimumWords {
            words.append(contentsOf: additions[index % additions.count].split(separator: " ").map(String.init))
            index += 1
        }

        return words.joined(separator: " ")
    }
}
