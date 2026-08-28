import Foundation

public protocol SettingsStoring: AnyObject {
    var selectedDuration: SessionDuration { get set }
    var batteryThreshold: Int { get set }
    var launchAtLoginRequested: Bool { get set }
    var notificationAuthorizationRequested: Bool { get set }
}
