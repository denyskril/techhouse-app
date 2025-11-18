import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var session: Session
    @Published var unreadCount: Int = 0

    private var cancellables: Set<AnyCancellable> = []
    let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        session = Session(isAuthenticated: environment.secureStore.apiToken != nil)
    }

    func bootstrap() async {
        guard session.isAuthenticated else { return }
        await refreshBadges()
    }

    func authenticate(username: String, password: String) async {
        do {
            let token = try await environment.api.login(username: username, password: password)
            environment.secureStore.apiToken = token
            session = Session(isAuthenticated: true)
            await refreshBadges()
        } catch {
            Logger.error("Authentication failed: \(error.localizedDescription)")
            session = Session(isAuthenticated: false, lastError: error)
        }
    }

    func signOut() {
        environment.secureStore.apiToken = nil
        session = Session(isAuthenticated: false)
    }

    func refreshBadges() async {
        guard session.isAuthenticated else { return }
        do {
            let alerts = try await environment.api.fetchAlertSummary()
            await MainActor.run {
                unreadCount = alerts.totalUnread
            }
        } catch {
            Logger.error("Failed to refresh badges: \(error.localizedDescription)")
        }
    }
}

struct Session {
    var isAuthenticated: Bool
    var lastError: Error?
}
