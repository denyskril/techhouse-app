import SwiftUI

@MainActor
final class ConversationListViewModel: ObservableObject {
    @Published var conversations: [ConversationSummary] = []
    @Published var isLoading = false
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
            conversations = try await api.fetchConversations()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct ConversationListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ConversationListViewModel(api: PreviewXenForoAPI())

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    List(viewModel.conversations) { conversation in
                        NavigationLink(destination: ConversationDetailView(conversation: conversation)) {
                            ConversationRow(conversation: conversation)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .task { await refreshIfNeeded() }
            .navigationTitle("Direct Messages")
        }
        .onAppear { viewModel.update(api: appState.environment.api) }
    }

    private func refreshIfNeeded() async {
        if viewModel.conversations.isEmpty {
            await viewModel.load()
        }
    }
}

private struct ConversationRow: View {
    let conversation: ConversationSummary

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: conversation.avatarURL, initials: initials)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(conversation.lastMessageDate, style: .time)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Text(conversation.lastMessageSnippet)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
            if conversation.unread {
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 8)
    }

    private var initials: String {
        let components = conversation.starterUsername.split(separator: " ")
        return components.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}
