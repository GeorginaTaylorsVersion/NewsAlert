// File: Services/MockNewsService.swift

import Foundation

struct MockNewsService: NewsService {
    func fetchArticles() async throws -> [Article] {
        SampleData.mockArticles()
    }
}
