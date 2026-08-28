import Foundation

@MainActor
public struct AppEnvironment {
    public let powerAssertions: PowerAssertionManaging
    public let battery: BatteryMonitoring
    public let scheduler: SessionScheduling
    public let settings: SettingsStoring
    public let localization: LocalizationController
    public let launchAtLogin: LaunchAtLoginManaging
    public let notifications: NotificationSending
    public let lifecycle: LifecycleObserving
    public let updater: UpdaterProviding?
    public let now: () -> Date

    public init(
        powerAssertions: PowerAssertionManaging,
        battery: BatteryMonitoring,
        scheduler: SessionScheduling,
        settings: SettingsStoring,
        launchAtLogin: LaunchAtLoginManaging,
        notifications: NotificationSending,
        lifecycle: LifecycleObserving,
        localization: LocalizationController? = nil,
        updater: UpdaterProviding? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.powerAssertions = powerAssertions
        self.battery = battery
        self.scheduler = scheduler
        self.settings = settings
        self.localization = localization ?? LocalizationController(settings: settings)
        self.launchAtLogin = launchAtLogin
        self.notifications = notifications
        self.lifecycle = lifecycle
        self.updater = updater
        self.now = now
    }

    public static func live(updater: UpdaterProviding? = nil) -> AppEnvironment {
        let settings = UserDefaultsSettingsStore()
        let localization = LocalizationController(settings: settings)
        return AppEnvironment(
            powerAssertions: IOKitPowerAssertionManager(),
            battery: IOKitBatteryMonitor(),
            scheduler: TaskSessionScheduler(),
            settings: settings,
            launchAtLogin: SMAppLaunchAtLoginManager(),
            notifications: UserNotificationSender(settings: settings, localization: localization),
            lifecycle: AppLifecycleObserver(),
            localization: localization,
            updater: updater
        )
    }
}
