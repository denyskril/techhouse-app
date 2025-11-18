import Foundation

protocol XenForoService {
    func login(username: String, password: String) async throws -> String
    func fetchLatestThreads(page: Int, limit: Int) async throws -> [ThreadSummary]
    func fetchThread(threadId: Int) async throws -> [Post]
    func fetchConversations() async throws -> [ConversationSummary]
    func fetchAlertSummary() async throws -> AlertSummary
    func reply(to threadId: Int, message: String) async throws
}

final class XenForoAPI: XenForoService {
    private let client: HTTPClient
    private let secureStore: SecureStore

    init(client: HTTPClient, secureStore: SecureStore) {
        self.client = client
        self.secureStore = secureStore
    }

    func login(username: String, password: String) async throws -> String {
        let payload = ["login": username, "password": password]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        var request = XenForoRequestBuilder.make(.login, method: "POST", body: data)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let response: AuthResponse = try await client.send(request, decode: AuthResponse.self)
        guard response.success else { throw APIError.unauthorized }
        secureStore.apiToken = response.token
        return response.token
    }

    func fetchLatestThreads(page: Int = 1, limit: Int = AppConfig.defaultPageSize) async throws -> [ThreadSummary] {
        var query: [URLQueryItem] = [
            .init(name: "page", value: String(page)),
            .init(name: "limit", value: String(limit))
        ]
        if let token = secureStore.apiToken {
            query.append(.init(name: "token", value: token))
        }
        let request = XenForoRequestBuilder.make(.latestThreads, queryItems: query)
        return try await client.send(request, decode: [ThreadSummary].self)
    }

    func fetchThread(threadId: Int) async throws -> [Post] {
        var query: [URLQueryItem] = []
        if let token = secureStore.apiToken {
            query.append(.init(name: "token", value: token))
        }
        var request = XenForoRequestBuilder.make(.threadDetail,
                                                 queryItems: query,
                                                 method: "GET")
        request.url?.appendPathComponent("\(threadId)")
        return try await client.send(request, decode: [Post].self)
    }

    func fetchConversations() async throws -> [ConversationSummary] {
        var query: [URLQueryItem] = []
        if let token = secureStore.apiToken {
            query.append(.init(name: "token", value: token))
        }
        let request = XenForoRequestBuilder.make(.conversations, queryItems: query)
        return try await client.send(request, decode: [ConversationSummary].self)
    }

    func fetchAlertSummary() async throws -> AlertSummary {
        var query: [URLQueryItem] = []
        if let token = secureStore.apiToken {
            query.append(.init(name: "token", value: token))
        }
        let request = XenForoRequestBuilder.make(.alerts, queryItems: query)
        return try await client.send(request, decode: AlertSummary.self)
    }

    func reply(to threadId: Int, message: String) async throws {
        let payload = CreatePostRequest(threadId: threadId, message: message)
        let data = try JSONEncoder().encode(payload)
        var request = XenForoRequestBuilder.make(.posts, method: "POST", body: data)
        if let token = secureStore.apiToken {
            request.addValue(token, forHTTPHeaderField: "XF-Api-User")
        }
        _ = try await client.send(request, decode: Post.self)
    }
}
