// File: Views/BriefingsView.swift

import SwiftUI

struct BriefingsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = BriefingsViewModel()

    private let scorer = HeuristicCredibilityScorer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Briefing", selection: $viewModel.selectedType) {
                    ForEach(BriefingType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                section(title: "Politics", stories: viewModel.briefing.politics)
                section(title: "Technology", stories: viewModel.briefing.technology)
                section(title: "Finance", stories: viewModel.briefing.finance)
                section(title: "Entertainment", stories: viewModel.briefing.entertainment)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Briefings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if appViewModel.isRefreshing {
                    ProgressView()
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let error = appViewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.red.opacity(0.85)))
                    .padding(.bottom, 10)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let lastUpdated = appViewModel.lastUpdated {
                HStack {
                    Text("Updated \(DateFormatting.shortDateTime.string(from: lastUpdated))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
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

    @ViewBuilder
    private func section(title: String, stories: [Story]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())

            ForEach(stories) { story in
                NavigationLink {
                    StoryDetailView(story: story)
                } label: {
                    StoryCardView(story: story, credibility: scorer.score(story: story))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct BriefingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            BriefingsView()
                .environmentObject(AppViewModel.preview)
        }
    }
}
