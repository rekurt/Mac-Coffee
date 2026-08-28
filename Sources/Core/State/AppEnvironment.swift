import Foundation

@MainActor
public struct AppEnvironment {
    public let powerAssertions: PowerAssertionManaging
    public let battery: BatteryMonitoring
    public let scheduler: SessionScheduling
    public let settings: SettingsStoring
    public let launchAtLogin: LaunchAtLoginManaging
    public let notifications: NotificationSending
    public let lifecycle: LifecycleObserving
    public let now: () -> Date

    public init(
        powerAssertions: PowerAssertionManaging,
        battery: BatteryMonitoring,
        scheduler: SessionScheduling,
        settings: SettingsStoring,
        launchAtLogin: LaunchAtLoginManaging,
        notifications: NotificationSending,
        lifecycle: LifecycleObserving,
        now: @escaping () -> Date = Date.init
    ) {
        self.powerAssertions = powerAssertions
        self.battery = battery
        self.scheduler = scheduler
        self.settings = settings
        self.launchAtLogin = launchAtLogin
        self.notifications = notifications
        self.lifecycle = lifecycle
        self.now = now
    }

    public static func live() -> AppEnvironment {
        let settings = UserDefaultsSettingsStore()
        return AppEnvironment(
            powerAssertions: IOKitPowerAssertionManager(),
            battery: IOKitBatteryMonitor(),
            scheduler: TaskSessionScheduler(),
            settings: settings,
            launchAtLogin: SMAppLaunchAtLoginManager(),
            notifications: UserNotificationSender(settings: settings),
            lifecycle: AppLifecycleObserver()
        )
    }
}
