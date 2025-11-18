import Foundation

enum APIError: LocalizedError, Equatable {
    case unauthorized
    case rateLimited
    case decodingFailed
    case network(URLError)
    case server(status: Int, message: String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .rateLimited:
            return "You are sending requests too quickly. Please slow down."
        case .decodingFailed:
            return "The server response was not understood."
        case .network(let error):
            return error.localizedDescription
        case .server(_, let message):
            return message
        case .unknown:
            return "An unknown error occurred."
        }
    }
}
