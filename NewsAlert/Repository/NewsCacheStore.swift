// File: Repository/NewsCacheStore.swift

import Foundation

final class NewsCacheStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileName: String = "news_stories_cache_v2_2_2_0.json") {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.fileURL = cachesDirectory.appendingPathComponent(fileName)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadStories() -> [Story] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        return (try? decoder.decode([Story].self, from: data)) ?? []
    }

    func saveStories(_ stories: [Story]) {
        guard let data = try? encoder.encode(stories) else {
            return
        }

        try? data.write(to: fileURL, options: [.atomic])
    }
}
