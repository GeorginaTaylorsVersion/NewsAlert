// File: ViewModels/BriefingsViewModel.swift

import Foundation
import Combine

@MainActor
final class BriefingsViewModel: ObservableObject {
    @Published var selectedType: BriefingType = .morning {
        didSet {
            rebuildBriefing()
        }
    }
    @Published private(set) var briefing: Briefing = .empty(type: .morning)

    private let builder: BriefingsBuilder
    private var allStories: [Story] = []

    init(builder: BriefingsBuilder? = nil) {
        self.builder = builder ?? BriefingsBuilder()
    }

    func updateStories(_ stories: [Story], now: Date = Date()) {
        allStories = stories
        briefing = builder.makeBriefing(type: selectedType, allStories: allStories, now: now)
    }

    private func rebuildBriefing(now: Date = Date()) {
        briefing = builder.makeBriefing(type: selectedType, allStories: allStories, now: now)
    }
}
