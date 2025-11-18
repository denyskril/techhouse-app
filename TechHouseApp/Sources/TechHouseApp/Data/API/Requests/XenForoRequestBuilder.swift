import Foundation

struct XenForoRequestBuilder {
    enum Endpoint: String {
        case login = "api/auth"
        case latestThreads = "api/threads/latest"
        case threadDetail = "api/threads"
        case conversations = "api/conversations"
        case alerts = "api/alerts"
        case posts = "api/posts"
    }

    static func make(_ endpoint: Endpoint,
                     queryItems: [URLQueryItem] = [],
                     method: String = "GET",
                     body: Data? = nil) -> URLRequest {
        let url = AppConfig.baseURL.appendingPathComponent(endpoint.rawValue)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        var request = URLRequest(url: components?.url ?? url)
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}
