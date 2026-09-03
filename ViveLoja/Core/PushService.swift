import Foundation
import Observation
import UIKit
import UserNotifications

/// Remote notifications: permission, APNs registration, token sync and taps.
///
/// `LocalReminderScheduler` stays as the offline fallback for saved events —
/// it fires without a network round trip — while everything the server decides
/// (review replies, claim results, messages, moderation) arrives through here.
@MainActor
@Observable
final class PushService: NSObject {
    enum Authorization: Equatable {
        case notDetermined
        case denied
        case authorized
    }

    private(set) var authorization: Authorization = .notDetermined
    /// Kept so logout can tell the backend to drop this device immediately.
    private(set) var deviceToken: String?

    private let api: APIClient
    private let center: UNUserNotificationCenter
    private weak var session: SessionStore?
    private weak var router: DeepLinkRouter?
    /// Registration is retried once a session exists, because the endpoint is
    /// authenticated and APNs usually answers before the user signs in.
    private var pendingRegistration = false

    init(api: APIClient = .shared, center: UNUserNotificationCenter = .current()) {
        self.api = api
        self.center = center
        super.init()
    }

    func attach(session: SessionStore, router: DeepLinkRouter) {
        self.session = session
        self.router = router
        center.delegate = self
    }

    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        authorization = PushService.authorization(from: settings.authorizationStatus)
        // Already granted in a previous launch: APNs tokens can rotate, so ask
        // for a fresh one on every cold start.
        if authorization == .authorized {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// Asks for permission in context — when the user saves an event or opens
    /// notification settings — never on first launch.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        authorization = granted ? .authorized : .denied
        if granted { UIApplication.shared.registerForRemoteNotifications() }
        return granted
    }

    // MARK: - APNs token

    func didRegister(deviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        Task { await syncToken() }
    }

    func didFailToRegister(error: Error) {
        // Simulators without a paired Mac push environment land here; the app
        // keeps working with local reminders only.
        print("[push] APNs registration failed: \(error.localizedDescription)")
    }

    /// Called after sign-in so a token obtained while signed out is claimed.
    func syncPendingRegistration() async {
        guard pendingRegistration || deviceToken != nil else { return }
        await syncToken()
    }

    private func syncToken() async {
        guard let token = deviceToken else { return }
        guard let session, let accessToken = session.accessToken else {
            pendingRegistration = true
            return
        }

        let body = DeviceRegistrationRequest(
            token: token,
            platform: "IOS",
            environment: PushService.apnsEnvironment,
            locale: Locale.current.identifier,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        )

        let response: DeviceRegistrationResponse? = try? await api.post(
            "/me/devices",
            body: body,
            bearer: accessToken
        )
        pendingRegistration = response == nil
    }

    /// Stops this device from receiving the signed-out account's notifications.
    func revokeToken() async {
        guard let token = deviceToken, let accessToken = session?.accessToken else { return }
        let _: EmptyResponse? = try? await api.delete(
            "/me/devices",
            body: DeviceRevocationRequest(token: token),
            bearer: accessToken
        )
    }

    // MARK: - Helpers

    private static func authorization(from status: UNAuthorizationStatus) -> Authorization {
        switch status {
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        default: return .notDetermined
        }
    }

    /// Read from the build settings rather than guessed from #if DEBUG, which
    /// got the Staging configuration wrong: it is a release build signed for the
    /// sandbox, so it would have registered production tokens against a
    /// development entitlement.
    private static var apnsEnvironment: String {
        AppEnvironment.current.apnsEnvironment
    }
}

extension PushService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Foreground notifications are worth showing: they are always about
        // something that happened elsewhere.
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // `userInfo` is [AnyHashable: Any] and therefore not Sendable, so the
        // link is read here and only the String crosses to the main actor.
        let link = PushService.deepLink(in: response.notification.request.content.userInfo)
        guard let link else { return }
        await MainActor.run { open(link: link) }
    }

    /// Routes the payload's `deepLink` through the same parser Universal Links
    /// use, so a tapped notification lands exactly where a shared link would.
    func handle(userInfo: [AnyHashable: Any]) {
        guard let link = PushService.deepLink(in: userInfo) else { return }
        open(link: link)
    }

    func open(link: String) {
        guard let url = URL(string: link) else { return }
        router?.handle(url)
    }

    nonisolated static func deepLink(in userInfo: [AnyHashable: Any]) -> String? {
        userInfo["deepLink"] as? String ?? userInfo["url"] as? String
    }
}
