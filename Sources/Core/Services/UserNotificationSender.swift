import Foundation
@preconcurrency import UserNotifications

@MainActor
public final class UserNotificationSender: NotificationSending {
    private let center: UNUserNotificationCenter
    private let settings: SettingsStoring

    public init(
        center: UNUserNotificationCenter = .current(),
        settings: SettingsStoring
    ) {
        self.center = center
        self.settings = settings
    }

    public func requestAuthorizationIfNeeded() {
        guard !settings.notificationAuthorizationRequested else { return }
        settings.notificationAuthorizationRequested = true
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func send(_ event: AppNotificationEvent) {
        requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.title", bundle: .main)
        switch event {
        case .timerCompleted:
            content.body = String(localized: "notification.timerCompleted", bundle: .main)
        case .lowBatteryStopped:
            content.body = String(localized: "notification.lowBatteryStopped", bundle: .main)
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "com.rekurt.maccoffee.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request) { _ in }
    }
}
