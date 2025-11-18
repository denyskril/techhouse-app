import SwiftUI

@MainActor
final class NotificationListViewModel: ObservableObject {
    @Published var alerts: [AlertSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var api: XenForoService

    init(api: XenForoService) {
        self.api = api
    }

    func update(api: XenForoService) { self.api = api }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let summary = try await api.fetchAlertSummary()
            alerts = [summary]
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct NotificationListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = NotificationListViewModel(api: PreviewXenForoAPI())

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red)
            } else if let summary = viewModel.alerts.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unread alerts")
                        .font(.headline)
                    Text("\(summary.totalUnread)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(AppTheme.primary)
                }
            } else {
                Text("You are all caught up")
                    .font(.headline)
                    .foregroundStyle(.gray)
            }
            Spacer()
        }
        .padding()
        .background(AppTheme.background.ignoresSafeArea())
        .task { await refreshIfNeeded() }
        .onAppear { viewModel.update(api: appState.environment.api) }
    }

    private func refreshIfNeeded() async {
        if viewModel.alerts.isEmpty {
            await viewModel.load()
        }
    }
}
