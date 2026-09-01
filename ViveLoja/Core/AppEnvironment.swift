import Foundation

enum AppEnvironment: Sendable {
    case development
    case staging
    case production

    static var current: AppEnvironment { .production }

    var baseURL: URL {
        switch self {
        case .development, .staging, .production:
            URL(string: "https://viveloja.com/api/mobile/v1")!
        }
    }
}
