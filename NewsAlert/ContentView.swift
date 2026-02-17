// File: ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var notificationScheduler = BriefingNotificationScheduler.shared
    @State private var didBootstrap = false

    var body: some View {
        TabView {
            NavigationStack {
                BriefingsView()
            }
            .tabItem {
                Label("Briefings", systemImage: "sun.max")
            }

            NavigationStack {
                ExploreView()
            }
            .tabItem {
                Label("Explore", systemImage: "newspaper")
            }
        }
        .environmentObject(appViewModel)
        .task {
            guard !didBootstrap else { return }
            didBootstrap = true

            await notificationScheduler.requestAuthorizationAndSchedule()
            await appViewModel.loadInitialDataIfNeeded()
            BackgroundRefreshManager.scheduleNextRefresh()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
