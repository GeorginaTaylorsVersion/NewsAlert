// File: NotificationManager.swift

import Foundation
import Combine
import BackgroundTasks
import UserNotifications

@MainActor
final class BriefingNotificationScheduler: NSObject, ObservableObject {
    static let shared = BriefingNotificationScheduler()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationAndSchedule() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            let settings = await center.notificationSettings()
            authorizationStatus = settings.authorizationStatus

            guard granted else { return }
            try await scheduleDailyBriefingNotifications()
        } catch {
            // Keep failure non-blocking for core reading experience.
        }
    }

    func scheduleDailyBriefingNotifications() async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: BriefingType.allCases.map(\ .rawValue))

        for briefing in BriefingType.allCases {
            var components = DateComponents()
            components.hour = briefing.scheduleHour
            components.minute = 0

            let content = UNMutableNotificationContent()
            content.title = "NewsAlarm"
            content.body = "Check your \(briefing.displayName) Briefing"
            content.sound = .default
            content.userInfo = ["briefingType": briefing.rawValue]

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: briefing.rawValue,
                content: content,
                trigger: trigger
            )

            try await center.add(request)
        }
    }
}

extension BriefingNotificationScheduler: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

// MARK: - Background Refresh

enum BackgroundRefreshManager {
    private static let minimumRefreshInterval: TimeInterval = 10 * 60
    private static let lastRefreshTimestampKey = "BackgroundRefreshManager.lastRefreshTimestamp"

    static var taskIdentifier: String {
        "\(Bundle.main.bundleIdentifier ?? "georgina.NewsAlert").briefings.refresh"
    }

    static func scheduleNextRefresh(now: Date = Date(), calendar: Calendar = .current) {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)

        let nextSlot = nextBriefingSlot(after: now, calendar: calendar)
        let prefetchDate = nextSlot.addingTimeInterval(-10 * 60) // try to prefetch shortly before the slot
        let minimumLead = now.addingTimeInterval(60)
        request.earliestBeginDate = prefetchDate > minimumLead ? prefetchDate : minimumLead

        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if DEBUG
            print("BG refresh schedule failed: \(error.localizedDescription)")
            #endif
        }
    }

    static func handleAppRefresh() async {
        defer { scheduleNextRefresh() }

        let refreshTask = Task { _ = await refreshIfNeeded() }

        await withTaskCancellationHandler {
            await refreshTask.value
        } onCancel: {
            refreshTask.cancel()
        }
    }

    @discardableResult
    static func refreshIfNeeded(now: Date = Date(), force: Bool = false) async -> Bool {
        if !force {
            if let lastRefresh = UserDefaults.standard.object(forKey: lastRefreshTimestampKey) as? Date {
                let elapsed = now.timeIntervalSince(lastRefresh)
                if elapsed < minimumRefreshInterval {
                    return false
                }
            }
        }

        let repository = NewsRepository()
        guard let stories = try? await repository.refreshStories(), !stories.isEmpty else {
            return false
        }

        UserDefaults.standard.set(now, forKey: lastRefreshTimestampKey)
        return true
    }
}

private extension BackgroundRefreshManager {
    static func nextBriefingSlot(after date: Date, calendar: Calendar) -> Date {
        let slotHours = [7, 12, 19]
        let startOfDay = calendar.startOfDay(for: date)

        for hour in slotHours {
            guard let slot = calendar.date(byAdding: .hour, value: hour, to: startOfDay) else {
                continue
            }

            if slot > date {
                return slot
            }
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        return calendar.date(byAdding: .hour, value: slotHours[0], to: tomorrow) ?? tomorrow
    }
}
