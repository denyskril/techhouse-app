import SwiftUI

@main
struct TechHouseAppApp: App {
    @StateObject private var appState = AppState(environment: .live())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .task {
                    await appState.bootstrap()
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.session.isAuthenticated {
                HomeTabView()
            } else {
                LoginView()
            }
        }
        .preferredColorScheme(.dark)
    }
}
