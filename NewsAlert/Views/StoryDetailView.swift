// File: Views/StoryDetailView.swift

import SwiftUI

struct StoryDetailView: View {
    @StateObject private var viewModel: StoryDetailViewModel
    @State private var presentedURL: IdentifiableURL?

    init(story: Story) {
        _viewModel = StateObject(wrappedValue: StoryDetailViewModel(story: story))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(viewModel.story.mainTitle)
                    .font(.title2.bold())

                metadataSection

                keyPointsSection

                articlesSection
            }
            .padding(16)
        }
        .navigationTitle(viewModel.story.category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presentedURL) { item in
            SafariView(url: item.url)
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.story.category.displayName)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.blue.opacity(0.16)))

                Text(viewModel.credibility.level.displayName)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(credibilityColor.opacity(0.18)))

                Spacer()
            }

            Text("\(viewModel.credibility.distinctSourceCount) sources across \(viewModel.story.countries.joined(separator: ", "))")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Coverage window: \(viewModel.story.publishedAtRange.displayRange)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var keyPointsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Key Points")
                .font(.headline)

            ForEach(Array(viewModel.keyPoints.enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .font(.headline)
                    Text(point)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var articlesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All Coverage")
                .font(.headline)

            ForEach(viewModel.sortedArticles) { article in
                articleRow(article)
            }
        }
    }

    private func articleRow(_ article: Article) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.18))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(initials(for: article.sourceName))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(article.sourceName)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(article.country)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(DateFormatting.shortDateTime.string(from: article.publishedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(article.snippet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Button {
                    Task {
                        await openArticle(article)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Open article")
                            .font(.footnote.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func initials(for sourceName: String) -> String {
        let parts = sourceName
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }

        return parts.joined()
    }

    private var credibilityColor: Color {
        switch viewModel.credibility.level {
        case .low:
            return .red
        case .medium:
            return .orange
        case .high:
            return .green
        }
    }

    @MainActor
    private func openArticle(_ article: Article) async {
        let resolved = await ArticleLinkResolver.preferredURL(for: article)
        presentedURL = IdentifiableURL(url: resolved.url)
    }
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct StoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            StoryDetailView(story: SampleData.mockStories().first!)
        }
    }
}
