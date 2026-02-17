// File: Models/NewsModels.swift

import Foundation

enum NewsCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case politics
    case technology
    case finance
    case entertainment
    case world
    case local

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .politics:
            return "Politics"
        case .technology:
            return "Technology"
        case .finance:
            return "Finance"
        case .entertainment:
            return "Entertainment"
        case .world:
            return "World"
        case .local:
            return "Local"
        }
    }
}

struct Article: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let sourceName: String
    let sourceDomain: String
    let publishedAt: Date
    let url: URL
    let snippet: String
    let category: NewsCategory
    let country: String
    let imageURL: URL?

    init(
        id: String = UUID().uuidString,
        title: String,
        sourceName: String,
        sourceDomain: String,
        publishedAt: Date,
        url: URL,
        snippet: String,
        category: NewsCategory,
        country: String,
        imageURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceName = sourceName
        self.sourceDomain = sourceDomain
        self.publishedAt = publishedAt
        self.url = url
        self.snippet = snippet
        self.category = category
        self.country = country
        self.imageURL = imageURL
    }
}

struct Story: Identifiable, Codable, Hashable {
    let id: UUID
    let mainTitle: String
    let category: NewsCategory
    let summary: String
    let articles: [Article]
    let primarySourceName: String
    let publishedAtRange: DateInterval
    let countries: [String]
    let importanceScore: Double

    init(
        id: UUID = UUID(),
        mainTitle: String,
        category: NewsCategory,
        summary: String,
        articles: [Article],
        primarySourceName: String,
        publishedAtRange: DateInterval,
        countries: [String],
        importanceScore: Double
    ) {
        self.id = id
        self.mainTitle = mainTitle
        self.category = category
        self.summary = summary
        self.articles = articles
        self.primarySourceName = primarySourceName
        self.publishedAtRange = publishedAtRange
        self.countries = countries
        self.importanceScore = importanceScore
    }

    var sourceCount: Int {
        Set(articles.map { $0.sourceName.lowercased() }).count
    }

    var thumbnailURL: URL? {
        articles.compactMap(\.imageURL).first
    }
}

enum CredibilityLevel: String, CaseIterable, Codable {
    case low
    case medium
    case high

    var displayName: String {
        rawValue.capitalized
    }
}

struct StoryCredibility: Codable, Hashable {
    let level: CredibilityLevel
    let score: Double
    let trustedSourceCount: Int
    let distinctSourceCount: Int
}

enum BriefingType: String, CaseIterable, Codable, Identifiable {
    case morning
    case noon
    case evening

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning:
            return "Morning"
        case .noon:
            return "Noon"
        case .evening:
            return "Evening"
        }
    }

    var scheduleHour: Int {
        switch self {
        case .morning:
            return 7
        case .noon:
            return 12
        case .evening:
            return 19
        }
    }

    func window(referenceDate: Date, calendar: Calendar = .current) -> DateInterval {
        let startOfToday = calendar.startOfDay(for: referenceDate)

        let yesterdayEightPM = calendar.date(byAdding: .hour, value: -4, to: startOfToday) ?? startOfToday
        let todayEightAM = calendar.date(byAdding: .hour, value: 8, to: startOfToday) ?? startOfToday
        let todayNoon = calendar.date(byAdding: .hour, value: 12, to: startOfToday) ?? startOfToday
        let todaySevenPM = calendar.date(byAdding: .hour, value: 19, to: startOfToday) ?? startOfToday

        switch self {
        case .morning:
            return DateInterval(start: yesterdayEightPM, end: todayEightAM)
        case .noon:
            return DateInterval(start: todayEightAM, end: todayNoon)
        case .evening:
            return DateInterval(start: todayNoon, end: todaySevenPM)
        }
    }
}

struct Briefing: Codable, Hashable {
    let type: BriefingType
    let date: Date
    let politics: [Story]
    let technology: [Story]
    let finance: [Story]
    let entertainment: [Story]

    static func empty(type: BriefingType, date: Date = Date()) -> Briefing {
        Briefing(type: type, date: date, politics: [], technology: [], finance: [], entertainment: [])
    }
}

enum ExploreCategory: String, CaseIterable, Identifiable {
    case all
    case politics
    case technology
    case finance
    case entertainment
    case world
    case local

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var newsCategory: NewsCategory? {
        switch self {
        case .all:
            return nil
        case .politics:
            return .politics
        case .technology:
            return .technology
        case .finance:
            return .finance
        case .entertainment:
            return .entertainment
        case .world:
            return .world
        case .local:
            return .local
        }
    }
}
