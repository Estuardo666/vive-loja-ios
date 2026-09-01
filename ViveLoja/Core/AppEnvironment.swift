import Foundation

enum AppEnvironment: Sendable {
    case development
    case staging
    case production

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    var baseURL: URL {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "VL_API_BASE_URL") as? String,
           let url = URL(string: configured), !configured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url
        }
        return URL(string: "https://viveloja.com/api/mobile/v1")!
    }
}
