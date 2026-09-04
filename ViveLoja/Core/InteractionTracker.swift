import Foundation

enum InteractionTracker {
    private struct Request: Encodable, Sendable {
        let action = "directions"
        let kind: String
        let itemId: String
        let source = "ios"
    }

    static func directions(kind: String, itemId: String) {
        guard !ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return }
        Task {
            let _: EmptyResponse? = try? await APIClient.shared.post(
                "/interactions", body: Request(kind: kind, itemId: itemId)
            )
        }
    }

    static func directions(item: ExploreItem) {
        switch item {
        case .venue(let venue): directions(kind: "venue", itemId: venue.id)
        case .event(let event): directions(kind: "event", itemId: event.id)
        }
    }
}
