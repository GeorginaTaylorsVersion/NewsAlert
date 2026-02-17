// File: Services/CredibilityScorer.swift

import Foundation

protocol CredibilityScoring {
    func score(story: Story) -> StoryCredibility
}

struct HeuristicCredibilityScorer: CredibilityScoring {
    private let trustedSources: Set<String> = [
        "reuters", "associated press", "ap news", "bbc news", "bbc", "financial times",
        "wall street journal", "the new york times", "washington post", "bloomberg",
        "npr", "the guardian", "economist"
    ]

    private let trustedDomains: Set<String> = [
        "reuters.com", "apnews.com", "bbc.com", "ft.com", "wsj.com",
        "nytimes.com", "washingtonpost.com", "bloomberg.com", "theguardian.com"
    ]

    func score(story: Story) -> StoryCredibility {
        let distinctSourceNames = Set(story.articles.map { $0.sourceName.lowercased() })
        let distinctDomains = Set(story.articles.map { $0.sourceDomain.lowercased() })
        let distinctCount = max(distinctSourceNames.count, distinctDomains.count)

        let trustedCount = story.articles.reduce(into: 0) { partial, article in
            let name = article.sourceName.lowercased()
            let domain = article.sourceDomain.lowercased()
            if trustedSources.contains(name) || trustedDomains.contains(domain) {
                partial += 1
            }
        }

        let sourceComponent = min(1.0, Double(distinctCount) / 5.0)
        let trustedComponent = min(1.0, Double(trustedCount) / 3.0)
        let score = (sourceComponent * 0.65) + (trustedComponent * 0.35)

        let level: CredibilityLevel
        switch score {
        case ..<0.4:
            level = .low
        case 0.4..<0.72:
            level = .medium
        default:
            level = .high
        }

        return StoryCredibility(
            level: level,
            score: score,
            trustedSourceCount: trustedCount,
            distinctSourceCount: distinctCount
        )
    }
}
