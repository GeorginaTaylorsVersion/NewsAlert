//
//  NewsAlertApp.swift
//  NewsAlert
//
//  Created by Georgina on 2026-02-16.
//

import SwiftUI

@main
struct NewsAlertApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase, initial: true) { _, newPhase in
                    switch newPhase {
                    case .active, .background:
                        BackgroundRefreshManager.scheduleNextRefresh()
                    default:
                        break
                    }
                }
        }
        .backgroundTask(.appRefresh(BackgroundRefreshManager.taskIdentifier)) {
            await BackgroundRefreshManager.handleAppRefresh()
        }
    }
}
