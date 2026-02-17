// File: ViewModels/ExploreViewModel.swift

import Foundation
import Combine

@MainActor
final class ExploreViewModel: ObservableObject {
    @Published var selectedCategory: ExploreCategory = .all {
        didSet {
            resetPagination()
        }
    }
    @Published private(set) var visibleStories: [Story] = []

    private var allStories: [Story] = []
    private let pageSize: Int
    private var currentPage: Int = 0

    init(pageSize: Int = 12) {
        self.pageSize = pageSize
    }

    func updateStories(_ stories: [Story]) {
        allStories = stories.sorted { $0.publishedAtRange.end > $1.publishedAtRange.end }
        resetPagination()
    }

    func loadMoreIfNeeded(currentItem: Story?) {
        guard let currentItem,
              let thresholdIndex = visibleStories.index(visibleStories.endIndex, offsetBy: -3, limitedBy: visibleStories.startIndex),
              visibleStories.firstIndex(where: { $0.id == currentItem.id }) == thresholdIndex else {
            return
        }

        appendNextPage()
    }

    private func resetPagination() {
        currentPage = 0
        visibleStories = []
        appendNextPage()
    }

    private func appendNextPage() {
        let filtered = filteredStories()
        let start = currentPage * pageSize
        guard start < filtered.count else { return }

        let end = min(start + pageSize, filtered.count)
        visibleStories.append(contentsOf: filtered[start..<end])
        currentPage += 1
    }

    private func filteredStories() -> [Story] {
        guard let category = selectedCategory.newsCategory else {
            return allStories
        }

        return allStories.filter { $0.category == category }
    }
}
