import Foundation

public enum AppNotificationEvent: Equatable, Sendable {
    case timerCompleted
    case lowBatteryStopped
}

@MainActor
public protocol NotificationSending: AnyObject {
    func requestAuthorizationIfNeeded()
    func send(_ event: AppNotificationEvent)
}
