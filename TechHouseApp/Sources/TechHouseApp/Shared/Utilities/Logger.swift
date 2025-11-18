#if canImport(os)
import os
#endif

enum Logger {
    #if canImport(os)
    private static let logger = os.Logger(subsystem: "techhouse.app", category: "general")
    #endif

    static func error(_ message: String) {
        #if canImport(os)
        logger.error("\(message, privacy: .public)")
        #else
        print("ERROR:", message)
        #endif
    }
}
