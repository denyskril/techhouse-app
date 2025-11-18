import Foundation

struct PreviewXenForoAPI: XenForoService {
    func login(username: String, password: String) async throws -> String { "preview-token" }

    func fetchLatestThreads(page: Int, limit: Int) async throws -> [ThreadSummary] {
        (0..<limit).map { index in
            ThreadSummary(
                threadId: index,
                title: "Preview Thread #\(index)",
                username: "User \(index)",
                lastPostDate: Date().addingTimeInterval(Double(-index) * 3600),
                messagePreview: "Latest update from preview thread #\(index)",
                replyCount: 5 + index,
                viewCount: 50 + index * 10,
                avatarURL: nil
            )
        }
    }

    func fetchThread(threadId: Int) async throws -> [Post] {
        (0..<10).map { index in
            Post(
                postId: index,
                username: index % 2 == 0 ? "Preview" : "User",
                message: "Sample message #\(index) in thread #\(threadId)",
                postDate: Date().addingTimeInterval(Double(-index) * 600),
                avatarURL: nil
            )
        }
    }

    func fetchConversations() async throws -> [ConversationSummary] {
        (0..<5).map { index in
            ConversationSummary(
                conversationId: index,
                title: "Conversation #\(index)",
                starterUsername: "Starter \(index)",
                lastMessageDate: Date().addingTimeInterval(Double(-index) * 7200),
                lastMessageSnippet: "Last DM snippet #\(index)",
                unread: index % 2 == 0,
                avatarURL: nil
            )
        }
    }

    func fetchAlertSummary() async throws -> AlertSummary {
        AlertSummary(totalUnread: 3)
    }

    func reply(to threadId: Int, message: String) async throws { }
}
