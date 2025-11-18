import Foundation

struct AppEnvironment {
    let api: XenForoAPI
    let secureStore: SecureStore
    let imageLoader: ImageLoader

    static func live(session: URLSession = .shared) -> AppEnvironment {
        let secureStore: SecureStore = KeychainSecureStore()
        let httpClient = HTTPClient(
            session: session,
            configuration: .init(baseURL: AppConfig.baseURL,
                                  apiKey: AppSecrets.xenForoAPIKey,
                                  clientName: AppConfig.clientName)
        )
        let api = XenForoAPI(client: httpClient, secureStore: secureStore)
        let imageLoader = ImageLoader()
        return AppEnvironment(api: api, secureStore: secureStore, imageLoader: imageLoader)
    }
}
