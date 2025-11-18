import Foundation

struct HTTPConfiguration {
    let baseURL: URL
    let apiKey: String
    let clientName: String
}

final class HTTPClient {
    private let session: URLSession
    private let configuration: HTTPConfiguration

    init(session: URLSession = .shared, configuration: HTTPConfiguration) {
        self.session = session
        self.configuration = configuration
    }

    func send<T: Decodable>(_ request: URLRequest, decode type: T.Type) async throws -> T {
        var request = request
        request.addValue(configuration.apiKey, forHTTPHeaderField: "XF-Api-Key")
        request.addValue(configuration.clientName, forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.unknown
            }

            switch httpResponse.statusCode {
            case 200..<300:
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw APIError.decodingFailed
                }
            case 401:
                throw APIError.unauthorized
            case 429:
                throw APIError.rateLimited
            default:
                let message = String(data: data, encoding: .utf8) ?? "Unexpected server error"
                throw APIError.server(status: httpResponse.statusCode, message: message)
            }
        } catch let urlError as URLError {
            throw APIError.network(urlError)
        }
    }
}
