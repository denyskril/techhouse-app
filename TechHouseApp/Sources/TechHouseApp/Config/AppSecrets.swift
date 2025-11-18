import Foundation

enum AppSecrets {
    static let xenForoAPIKey: String = {
        if let override = ProcessInfo.processInfo.environment["XF_API_KEY"], !override.isEmpty {
            return override
        }
        return "FHcQL3-HrLaG17HB6mIF-Aeqr9fv-7fy"
    }()
}
