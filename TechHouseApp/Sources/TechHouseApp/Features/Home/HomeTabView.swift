import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            ThreadListView()
                .tabItem {
                    Label("Chats", systemImage: "message.fill")
                }
            ConversationListView()
                .tabItem {
                    Label("DMs", systemImage: "bubble.left.and.bubble.right.fill")
                }
            NotificationListView()
                .tabItem {
                    Label("Alerts", systemImage: "bell.badge.fill")
                        .badge(appState.unreadCount)
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .tint(AppTheme.primary)
        .background(AppTheme.background)
    }
}
