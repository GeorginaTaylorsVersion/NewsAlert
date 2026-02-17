// File: Services/NewsService.swift

import Foundation

protocol NewsService {
    func fetchArticles() async throws -> [Article]
}
