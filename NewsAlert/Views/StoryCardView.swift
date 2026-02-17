// File: Views/StoryCardView.swift

import SwiftUI

struct StoryCardView: View {
    let story: Story
    let credibility: StoryCredibility

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let imageURL = story.thumbnailURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    default:
                        EmptyView()
                    }
                }
            }

            Text(story.mainTitle)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(story.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                chip(text: story.category.displayName, color: .blue.opacity(0.15), foreground: .blue)
                chip(text: "\(story.sourceCount) sources", color: .gray.opacity(0.18), foreground: .secondary)
                chip(text: credibility.level.displayName, color: credibilityColor.opacity(0.18), foreground: credibilityColor)
            }

            HStack {
                Text(story.countries.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(story.publishedAtRange.end.relativeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var credibilityColor: Color {
        switch credibility.level {
        case .low:
            return .red
        case .medium:
            return .orange
        case .high:
            return .green
        }
    }

    @ViewBuilder
    private func chip(text: String, color: Color, foreground: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color))
            .foregroundStyle(foreground)
    }
}

struct StoryCardView_Previews: PreviewProvider {
    static var previews: some View {
        let story = SampleData.mockStories().first!
        StoryCardView(story: story, credibility: HeuristicCredibilityScorer().score(story: story))
            .padding()
    }
}
