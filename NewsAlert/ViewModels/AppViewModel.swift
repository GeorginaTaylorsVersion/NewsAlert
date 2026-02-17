// File: ViewModels/AppViewModel.swift

import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var stories: [Story] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?

    private let repository: NewsRepositorying
    private var didLoadInitialData = false
    private var autoRefreshTask: Task<Void, Never>?
    private var lastAutoRefreshSlotID: String?

    init(repository: NewsRepositorying? = nil) {
        self.repository = repository ?? NewsRepository()
    }

    func loadInitialDataIfNeeded() async {
        guard !didLoadInitialData else { return }
        didLoadInitialData = true

        let cachedStories = repository.loadCachedStories()
        if !cachedStories.isEmpty {
            stories = cachedStories
        }

        await refresh()
        startAutoRefreshLoopIfNeeded()
    }

    func refresh() async {
        isRefreshing = true
        errorMessage = nil

        do {
            let latest = try await repository.refreshStories()
            stories = latest
            lastUpdated = Date()
        } catch {
            if stories.isEmpty {
                stories = SampleData.mockStories()
            }
            errorMessage = error.localizedDescription
        }

        isRefreshing = false
    }

    func startAutoRefreshLoopIfNeeded() {
        guard autoRefreshTask == nil else { return }

        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshIfReachedNewBriefingSlot()
                try? await Task.sleep(nanoseconds: 180 * 1_000_000_000) // every 3 minutes
            }
        }
    }

    private func refreshIfReachedNewBriefingSlot(now: Date = Date()) async {
        guard let slotID = latestBriefingSlotID(onOrBefore: now) else {
            return
        }

        guard slotID != lastAutoRefreshSlotID else {
            return
        }

        lastAutoRefreshSlotID = slotID
        await refresh()
    }

    private func latestBriefingSlotID(onOrBefore now: Date, calendar: Calendar = .current) -> String? {
        let startOfDay = calendar.startOfDay(for: now)
        let slots = [7, 12, 19]

        for hour in slots.reversed() {
            guard let slotDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay) else {
                continue
            }

            if now >= slotDate {
                let dayKey = DateFormatting.dayKey.string(from: now)
                return "\(dayKey)-\(hour)"
            }
        }

        return nil
    }

    deinit {
        autoRefreshTask?.cancel()
    }
}

extension AppViewModel {
    static var preview: AppViewModel {
        let repository = NewsRepository(services: [MockNewsService()])
        let viewModel = AppViewModel(repository: repository)
        viewModel.stories = SampleData.mockStories()
        viewModel.lastUpdated = Date()
        return viewModel
    }
}
