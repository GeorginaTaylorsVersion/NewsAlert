// File: Support/ArticleLinkResolver.swift

import Foundation

enum ArticleLinkResolver {
    static func preferredURL(for article: Article, session: URLSession = .shared) async -> (url: URL, didFallback: Bool) {
        if await isReachable(article.url, session: session) {
            return (article.url, false)
        }

        let fallback = sourceHomepageURL(for: article.sourceDomain) ?? homepageURL(from: article.url)
        guard let fallback, await isReachable(fallback, session: session) else {
            return (article.url, false)
        }

        return (fallback, true)
    }
}

private extension ArticleLinkResolver {
    static func sourceHomepageURL(for sourceDomain: String) -> URL? {
        let host = sourceDomain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)

        guard !host.isEmpty else {
            return nil
        }

        return URL(string: "https://\(host)")
    }

    static func homepageURL(from url: URL) -> URL? {
        guard let host = url.host?.lowercased(), !host.isEmpty else {
            return nil
        }

        return URL(string: "https://\(host)")
    }

    static func isReachable(_ url: URL, session: URLSession) async -> Bool {
        var headRequest = URLRequest(url: url)
        headRequest.httpMethod = "HEAD"
        headRequest.timeoutInterval = 4

        if let statusCode = await requestStatusCode(for: headRequest, session: session) {
            return (200...399).contains(statusCode)
        }

        // Some publishers reject HEAD; try a minimal GET before falling back.
        var rangedGetRequest = URLRequest(url: url)
        rangedGetRequest.httpMethod = "GET"
        rangedGetRequest.timeoutInterval = 4
        rangedGetRequest.setValue("bytes=0-0", forHTTPHeaderField: "Range")

        guard let statusCode = await requestStatusCode(for: rangedGetRequest, session: session) else {
            return false
        }

        return (200...399).contains(statusCode) || statusCode == 416
    }

    static func requestStatusCode(for request: URLRequest, session: URLSession) async -> Int? {
        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode
        } catch {
            return nil
        }
    }
}
