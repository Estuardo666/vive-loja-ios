import Foundation
import UserNotifications

@MainActor
final class LocalReminderScheduler {
    static let shared = LocalReminderScheduler()
    private let center = UNUserNotificationCenter.current()

    func schedule(for event: ExploreEvent) async throws {
        guard event.startDate > .now else { return }
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else { return }
        let reminderDate = max(event.startDate.addingTimeInterval(-3_600), Date().addingTimeInterval(5))
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let content = UNMutableNotificationContent()
        content.title = "Próximamente en Loja"
        content.body = event.title
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await add(UNNotificationRequest(identifier: "event-\(event.id)", content: content, trigger: trigger))
    }

    func cancel(eventID: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["event-\(eventID)"])
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }
}
