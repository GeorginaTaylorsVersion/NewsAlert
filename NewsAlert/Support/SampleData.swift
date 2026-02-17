// File: Support/SampleData.swift

import Foundation

enum SampleData {
    static var newsAPIResponseJSON: String {
        """
        {
          "status": "ok",
          "totalResults": 4,
          "articles": [
            {
              "source": { "id": null, "name": "Reuters" },
              "author": "Reporter",
              "title": "Senate committee advances overnight budget package",
              "description": "Negotiators moved a temporary package forward after late-night talks.",
              "url": "https://www.reuters.com/world/",
              "urlToImage": null,
              "publishedAt": "2026-02-17T05:00:00Z",
              "content": "Negotiators moved a temporary package forward after late-night talks."
            },
            {
              "source": { "id": null, "name": "BBC News" },
              "author": "Editor",
              "title": "Chipmakers unveil updated AI processing roadmap",
              "description": "Vendors highlighted on-device inference efficiency gains.",
              "url": "https://www.bbc.com/news/technology",
              "urlToImage": null,
              "publishedAt": "2026-02-17T07:20:00Z",
              "content": "Vendors highlighted on-device inference efficiency gains."
            },
            {
              "source": { "id": null, "name": "Financial Times" },
              "author": "Desk",
              "title": "Bond yields swing as traders reassess rate path",
              "description": "Market participants repriced risk into the afternoon session.",
              "url": "https://www.ft.com/markets",
              "urlToImage": null,
              "publishedAt": "2026-02-17T12:10:00Z",
              "content": "Market participants repriced risk into the afternoon session."
            },
            {
              "source": { "id": null, "name": "Variety" },
              "author": "Culture",
              "title": "Studios test shorter theatrical windows for select titles",
              "description": "Distributors continue experimenting with release timing.",
              "url": "https://variety.com/v/film/",
              "urlToImage": null,
              "publishedAt": "2026-02-17T16:40:00Z",
              "content": "Distributors continue experimenting with release timing."
            }
          ]
        }
        """
    }

    static func mockArticles(referenceDate: Date = Date()) -> [Article] {
        let calendar = Calendar.current
        let twoHoursAgo = calendar.date(byAdding: .hour, value: -2, to: referenceDate) ?? referenceDate
        let threeHoursAgo = calendar.date(byAdding: .hour, value: -3, to: referenceDate) ?? referenceDate
        let fiveHoursAgo = calendar.date(byAdding: .hour, value: -5, to: referenceDate) ?? referenceDate
        let sevenHoursAgo = calendar.date(byAdding: .hour, value: -7, to: referenceDate) ?? referenceDate
        let tenHoursAgo = calendar.date(byAdding: .hour, value: -10, to: referenceDate) ?? referenceDate
        let twelveHoursAgo = calendar.date(byAdding: .hour, value: -12, to: referenceDate) ?? referenceDate

        return [
            Article(
                title: "Senate leaders reopen budget negotiations",
                sourceName: "Reuters",
                sourceDomain: "reuters.com",
                publishedAt: tenHoursAgo,
                url: URL(string: "https://www.reuters.com/world/us/")!,
                snippet: "Negotiators returned to the table after committee members requested a revised spending timeline.",
                category: .politics,
                country: "US",
                imageURL: nil
            ),
            Article(
                title: "Senate leaders reopen budget negotiations as deadline nears",
                sourceName: "Associated Press",
                sourceDomain: "apnews.com",
                publishedAt: twelveHoursAgo,
                url: URL(string: "https://apnews.com/hub/us-news")!,
                snippet: "Lawmakers debated a short-term stopgap while committee staff drafted amendment language.",
                category: .politics,
                country: "US",
                imageURL: nil
            ),
            Article(
                title: "Election officials outline ballot processing changes",
                sourceName: "BBC News",
                sourceDomain: "bbc.com",
                publishedAt: sevenHoursAgo,
                url: URL(string: "https://www.bbc.com/news/world-us-canada")!,
                snippet: "Administrators published updated processing steps before primary voting begins.",
                category: .politics,
                country: "UK",
                imageURL: nil
            ),
            Article(
                title: "Chipmakers push on-device AI acceleration",
                sourceName: "The Verge",
                sourceDomain: "theverge.com",
                publishedAt: fiveHoursAgo,
                url: URL(string: "https://www.theverge.com/tech")!,
                snippet: "Manufacturers highlighted gains in on-device model execution and battery efficiency.",
                category: .technology,
                country: "US",
                imageURL: nil
            ),
            Article(
                title: "Chipmakers push on-device AI acceleration in 2026 flagships",
                sourceName: "TechCrunch",
                sourceDomain: "techcrunch.com",
                publishedAt: threeHoursAgo,
                url: URL(string: "https://techcrunch.com/tag/artificial-intelligence/")!,
                snippet: "Vendors signaled tighter integration of neural units across premium and mid-tier devices.",
                category: .technology,
                country: "US",
                imageURL: nil
            ),
            Article(
                title: "Open-source maintainers expand release signing requirements",
                sourceName: "Ars Technica",
                sourceDomain: "arstechnica.com",
                publishedAt: tenHoursAgo,
                url: URL(string: "https://arstechnica.com/tech-policy/")!,
                snippet: "Package ecosystems moved toward stronger provenance and attestations for production dependencies.",
                category: .technology,
                country: "US",
                imageURL: nil
            ),
            Article(
                title: "Treasury yields rise as traders digest inflation signals",
                sourceName: "Financial Times",
                sourceDomain: "ft.com",
                publishedAt: twoHoursAgo,
                url: URL(string: "https://www.ft.com/markets")!,
                snippet: "Bond desks repriced front-end expectations after stronger-than-expected services data.",
                category: .finance,
                country: "UK",
                imageURL: nil
            ),
            Article(
                title: "Retail earnings point to value-oriented spending",
                sourceName: "Wall Street Journal",
                sourceDomain: "wsj.com",
                publishedAt: fiveHoursAgo,
                url: URL(string: "https://www.wsj.com/news/business")!,
                snippet: "Discount categories outperformed premium lines as margins remained under pressure.",
                category: .finance,
                country: "US",
                imageURL: nil
            ),
            Article(
                title: "Studios experiment with shorter theatrical windows",
                sourceName: "Variety",
                sourceDomain: "variety.com",
                publishedAt: threeHoursAgo,
                url: URL(string: "https://variety.com/v/film/")!,
                snippet: "Studios tested tighter release gaps to retain campaign momentum into streaming launches.",
                category: .entertainment,
                country: "US",
                imageURL: nil
            ),
            Article(
                title: "Regional leaders discuss cross-border energy policy",
                sourceName: "Al Jazeera",
                sourceDomain: "aljazeera.com",
                publishedAt: twelveHoursAgo,
                url: URL(string: "https://www.aljazeera.com/news/")!,
                snippet: "Delegates outlined coordinated energy security measures across multiple markets.",
                category: .world,
                country: "QA",
                imageURL: nil
            ),
            Article(
                title: "City council approves new transit route pilots",
                sourceName: "CBS News New York",
                sourceDomain: "cbsnews.com",
                publishedAt: sevenHoursAgo,
                url: URL(string: "https://www.cbsnews.com/newyork/")!,
                snippet: "Officials approved a phased pilot with performance checkpoints over three months.",
                category: .local,
                country: "US",
                imageURL: nil
            )
        ]
    }

    static func mockStories() -> [Story] {
        let clusterer = SimpleStoryClusteringService()
        return clusterer.cluster(mockArticles())
    }

    static func mockBriefing(type: BriefingType) -> Briefing {
        let stories = mockStories()
        let builder = BriefingsBuilder()
        return builder.makeBriefing(type: type, allStories: stories, now: Date())
    }
}
