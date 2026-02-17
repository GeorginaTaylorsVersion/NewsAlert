// File: Services/BriefingsBuilder.swift

import Foundation

struct BriefingsBuilder {
    func makeBriefing(type: BriefingType, allStories: [Story], now: Date = Date()) -> Briefing {
        let window = type.window(referenceDate: now)
        let nearbyWindow = DateInterval(
            start: window.start.addingTimeInterval(-6 * 3600),
            end: min(now, window.end.addingTimeInterval(6 * 3600))
        )
        let recentWindow = DateInterval(
            start: now.addingTimeInterval(-24 * 3600),
            end: now
        )

        let inWindow = allStories.filter { storyHasArticle($0, in: window) }
        let nearby = allStories.filter { storyHasArticle($0, in: nearbyWindow) }
        let recent = allStories.filter { storyHasArticle($0, in: recentWindow) }

        let rankedInWindow = rankStories(inWindow, now: now, targetWindow: window)
        let rankedNearby = rankStories(nearby, now: now, targetWindow: window)
        let rankedRecent = rankStories(recent, now: now, targetWindow: window)

        let politics = pickStories(
            targetCount: 2,
            category: .politics,
            rankedTiers: [rankedInWindow, rankedNearby, rankedRecent],
            briefingType: type,
            now: now
        )
        let technology = pickStories(
            targetCount: 2,
            category: .technology,
            rankedTiers: [rankedInWindow, rankedNearby, rankedRecent],
            briefingType: type,
            now: now
        )
        let finance = pickStories(
            targetCount: 2,
            category: .finance,
            rankedTiers: [rankedInWindow, rankedNearby, rankedRecent],
            briefingType: type,
            now: now
        )
        let entertainment = pickStories(
            targetCount: 0,
            category: .entertainment,
            rankedTiers: [rankedInWindow, rankedNearby, rankedRecent],
            briefingType: type,
            now: now
        )

        return Briefing(
            type: type,
            date: now,
            politics: politics,
            technology: technology,
            finance: finance,
            entertainment: entertainment
        )
    }
}

private extension BriefingsBuilder {
    func rankStories(_ stories: [Story], now: Date, targetWindow: DateInterval) -> [Story] {
        stories.sorted { lhs, rhs in
            let lhsScore = rankingScore(lhs, now: now, targetWindow: targetWindow)
            let rhsScore = rankingScore(rhs, now: now, targetWindow: targetWindow)

            if lhsScore == rhsScore {
                return lhs.publishedAtRange.end > rhs.publishedAtRange.end
            }
            return lhsScore > rhsScore
        }
    }

    func rankingScore(_ story: Story, now: Date, targetWindow: DateInterval) -> Double {
        let hoursOld = max(0, now.timeIntervalSince(story.publishedAtRange.end) / 3600)
        let recencyBoost = max(0, 18 - hoursOld) * 0.12
        let base = story.importanceScore + recencyBoost + Double(story.sourceCount) * 0.25

        let midPoint = targetWindow.start.addingTimeInterval(targetWindow.duration / 2)
        let distanceHours = abs(story.publishedAtRange.end.timeIntervalSince(midPoint) / 3600)
        let proximityBoost = max(0, 8 - distanceHours) * 0.2
        let inWindowBoost = storyHasArticle(story, in: targetWindow) ? 1.25 : 0

        return base + proximityBoost + inWindowBoost
    }

    func pickStories(
        targetCount: Int,
        category: NewsCategory,
        rankedTiers: [[Story]],
        briefingType: BriefingType,
        now: Date
    ) -> [Story] {
        var selected: [Story] = []
        var seen = Set<UUID>()

        for tier in rankedTiers {
            for story in tier where story.category == category {
                guard seen.insert(story.id).inserted else { continue }
                selected.append(story)
                if selected.count == targetCount {
                    return selected
                }
            }
        }

        while selected.count < targetCount {
            selected.append(
                placeholderStory(
                    for: category,
                    briefingType: briefingType,
                    now: now,
                    index: selected.count + 1
                )
            )
        }

        return selected
    }

    func storyHasArticle(_ story: Story, in window: DateInterval) -> Bool {
        story.articles.contains { window.contains($0.publishedAt) }
    }

    func placeholderStory(for category: NewsCategory, briefingType: BriefingType, now: Date, index: Int) -> Story {
        let title = "\(briefingType.displayName) \(category.displayName) item \(index)"
        let placeholderArticle = Article(
            title: title,
            sourceName: "NewsAlarm",
            sourceDomain: "newsalarm.local",
            publishedAt: now,
            url: URL(string: "https://example.com")!,
            snippet: "No matching story was available in this window, so this slot is reserved for the next refresh.",
            category: category,
            country: "US",
            imageURL: nil
        )

        return Story(
            mainTitle: title,
            category: category,
            summary: placeholderArticle.snippet,
            articles: [placeholderArticle],
            primarySourceName: placeholderArticle.sourceName,
            publishedAtRange: DateInterval(start: now, end: now),
            countries: [placeholderArticle.country],
            importanceScore: 0
        )
    }
}
