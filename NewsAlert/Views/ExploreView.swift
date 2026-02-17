// File: Views/ExploreView.swift

import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = ExploreViewModel()

    private let scorer = HeuristicCredibilityScorer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                categoriesBar

                LazyVStack(spacing: 12) {
                    ForEach(viewModel.visibleStories) { story in
                        NavigationLink {
                            StoryDetailView(story: story)
                        } label: {
                            StoryCardView(story: story, credibility: scorer.score(story: story))
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            viewModel.loadMoreIfNeeded(currentItem: story)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Explore")
        .refreshable {
            await appViewModel.refresh()
        }
        .onAppear {
            viewModel.updateStories(appViewModel.stories)
        }
        .onChange(of: appViewModel.stories) { _, stories in
            viewModel.updateStories(stories)
        }
    }

    private var categoriesBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ExploreCategory.allCases) { category in
                    Button {
                        viewModel.selectedCategory = category
                    } label: {
                        Text(category.displayName)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedCategory == category ? Color.blue.opacity(0.2) : Color.gray.opacity(0.16))
                            )
                            .foregroundStyle(viewModel.selectedCategory == category ? .blue : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct ExploreView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ExploreView()
                .environmentObject(AppViewModel.preview)
        }
    }
}
