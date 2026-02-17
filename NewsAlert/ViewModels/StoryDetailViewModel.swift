// File: ViewModels/StoryDetailViewModel.swift

import Foundation
import Combine

@MainActor
final class StoryDetailViewModel: ObservableObject {
    let story: Story
    let credibility: StoryCredibility
    let keyPoints: [String]

    private let scorer: CredibilityScoring

    init(story: Story, scorer: CredibilityScoring? = nil) {
        let scorer = scorer ?? HeuristicCredibilityScorer()
        self.story = story
        self.scorer = scorer
        self.credibility = scorer.score(story: story)
        self.keyPoints = StoryDetailViewModel.makeKeyPoints(from: story)
    }

    var sortedArticles: [Article] {
        story.articles.sorted { $0.publishedAt > $1.publishedAt }
    }
}

private extension StoryDetailViewModel {
    static func makeKeyPoints(from story: Story) -> [String] {
        var points: [String] = []
        var seen = Set<String>()

        for article in story.articles {
            let candidate = article.snippet
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard candidate.count > 20 else { continue }

            let normalized = candidate.lowercased()
            guard seen.insert(normalized).inserted else { continue }

            points.append(String(candidate.prefix(180)))
            if points.count == 3 {
                break
            }
        }

        if points.isEmpty {
            points.append("Additional details will appear as more outlets publish updates.")
        }

        return points
    }
}
