// File: Support/AppConfig.swift

import Foundation

struct AppConfig {
    let backendBaseURL: URL?
    let backendAuthToken: String
    let newsAPIBaseURL: URL
    let newsAPIKey: String
    let newsAPILanguage: String
    let newsAPICountry: String
    let newsCatcherBaseURL: URL
    let newsCatcherAPIKey: String
    let guardianBaseURL: URL
    let guardianAPIKey: String
    let newsDataBaseURL: URL
    let newsDataAPIKey: String
    let theNewsAPIBaseURL: URL
    let theNewsAPIKey: String

    static func load(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppConfig {
        let info = bundle.infoDictionary ?? [:]

        func value(_ key: String, fallback: String) -> String {
            if let envValue = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !envValue.isEmpty {
                return envValue
            }

            if let infoValue = (info[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !infoValue.isEmpty {
                return infoValue
            }

            return fallback
        }

        let newsAPIBase = value("NEWS_API_BASE_URL", fallback: "https://newsapi.org")
        let backendBase = value("BACKEND_BASE_URL", fallback: "")
        let newsCatcherBase = value("NEWSCATCHER_API_BASE_URL", fallback: "https://api.newscatcherapi.com")
        let guardianBase = value("GUARDIAN_API_BASE_URL", fallback: "https://content.guardianapis.com")
        let newsDataBase = value("NEWSDATA_API_BASE_URL", fallback: "https://newsdata.io")
        let theNewsAPIBase = value("THENEWSAPI_BASE_URL", fallback: "https://api.thenewsapi.com")

        return AppConfig(
            backendBaseURL: URL(string: backendBase),
            backendAuthToken: value("BACKEND_AUTH_TOKEN", fallback: ""),
            newsAPIBaseURL: URL(string: newsAPIBase) ?? URL(string: "https://newsapi.org")!,
            newsAPIKey: value("NEWS_API_KEY", fallback: "REPLACE_WITH_REAL_KEY"),
            newsAPILanguage: value("NEWS_API_LANGUAGE", fallback: "en"),
            newsAPICountry: value("NEWS_API_COUNTRY", fallback: "us"),
            newsCatcherBaseURL: URL(string: newsCatcherBase) ?? URL(string: "https://api.newscatcherapi.com")!,
            newsCatcherAPIKey: value("NEWSCATCHER_API_KEY", fallback: "REPLACE_WITH_REAL_KEY"),
            guardianBaseURL: URL(string: guardianBase) ?? URL(string: "https://content.guardianapis.com")!,
            guardianAPIKey: value("GUARDIAN_API_KEY", fallback: "REPLACE_WITH_REAL_KEY"),
            newsDataBaseURL: URL(string: newsDataBase) ?? URL(string: "https://newsdata.io")!,
            newsDataAPIKey: value("NEWSDATA_API_KEY", fallback: "REPLACE_WITH_REAL_KEY"),
            theNewsAPIBaseURL: URL(string: theNewsAPIBase) ?? URL(string: "https://api.thenewsapi.com")!,
            theNewsAPIKey: value("THENEWSAPI_API_KEY", fallback: "REPLACE_WITH_REAL_KEY")
        )
    }

    var hasUsableBackendBaseURL: Bool {
        guard let backendBaseURL else { return false }
        return backendBaseURL.scheme != nil && backendBaseURL.host != nil
    }

    var hasUsableAPIKey: Bool {
        !newsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && newsAPIKey != "REPLACE_WITH_REAL_KEY"
    }

    var hasUsableNewsCatcherKey: Bool {
        !newsCatcherAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && newsCatcherAPIKey != "REPLACE_WITH_REAL_KEY"
    }

    var hasUsableGuardianKey: Bool {
        !guardianAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && guardianAPIKey != "REPLACE_WITH_REAL_KEY"
    }

    var hasUsableNewsDataKey: Bool {
        !newsDataAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && newsDataAPIKey != "REPLACE_WITH_REAL_KEY"
    }

    var hasUsableTheNewsAPIKey: Bool {
        !theNewsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && theNewsAPIKey != "REPLACE_WITH_REAL_KEY"
    }
}
