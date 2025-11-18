import Foundation

struct AuthResponse: Decodable {
    let success: Bool
    let token: String
}

struct ThreadSummary: Decodable, Identifiable {
    let threadId: Int
    let title: String
    let username: String
    let lastPostDate: Date
    let messagePreview: String?
    let replyCount: Int
    let viewCount: Int
    let avatarURL: URL?

    var id: Int { threadId }
}

struct Post: Decodable, Identifiable {
    let postId: Int
    let username: String
    let message: String
    let postDate: Date
    let avatarURL: URL?

    var id: Int { postId }
}

struct ConversationSummary: Decodable, Identifiable {
    let conversationId: Int
    let title: String
    let starterUsername: String
    let lastMessageDate: Date
    let lastMessageSnippet: String
    let unread: Bool
    let avatarURL: URL?

    var id: Int { conversationId }
}

struct AlertSummary: Decodable {
    let totalUnread: Int
}

struct CreatePostRequest: Encodable {
    let threadId: Int
    let message: String
}
