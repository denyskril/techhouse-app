import Foundation

@MainActor
final class ThreadListViewModel: ObservableObject {
    @Published var threads: [ThreadSummary] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var api: XenForoService

    init(api: XenForoService) {
        self.api = api
    }

    func update(api: XenForoService) {
        self.api = api
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            threads = try await api.fetchLatestThreads(page: 1, limit: AppConfig.defaultPageSize)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    var filteredThreads: [ThreadSummary] {
        guard !searchText.isEmpty else { return threads }
        return threads.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
}
