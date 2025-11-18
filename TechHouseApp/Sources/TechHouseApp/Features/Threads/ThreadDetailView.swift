import SwiftUI

struct ThreadDetailView: View {
    @EnvironmentObject private var appState: AppState
    let thread: ThreadSummary
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var replyText = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(posts) { post in
                                MessageBubbleView(
                                    text: post.message,
                                    alignment: post.username == thread.username ? .trailing : .leading,
                                    timestamp: post.postDate
                                )
                                .padding(.horizontal)
                                .id(post.id)
                            }
                        }
                    }
                    .onChange(of: posts.count) { _ in
                        if let last = posts.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
            composer
                .background(AppTheme.secondary)
        }
        .navigationTitle(thread.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPosts() }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK", role: .cancel) { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        .background(AppTheme.background.ignoresSafeArea())
    }

    private var composer: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $replyText, axis: .vertical)
                .lineLimit(1...4)
                .padding(10)
                .background(AppTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Button(action: { Task { await sendReply() } }) {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(AppTheme.primary)
                    .clipShape(Circle())
            }
            .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
    }

    private func loadPosts() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            posts = try await appState.environment.api.fetchThread(threadId: thread.threadId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendReply() async {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await appState.environment.api.reply(to: thread.threadId, message: trimmed)
            replyText = ""
            await loadPosts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
