import Foundation

public final class UserDefaultsSettingsStore: SettingsStoring {
    private enum Key {
        static let selectedLanguage = "selectedLanguage"
        static let selectedDuration = "selectedDuration"
        static let batteryThreshold = "batteryThreshold"
        static let launchAtLoginRequested = "launchAtLoginRequested"
        static let notificationAuthorizationRequested = "notificationAuthorizationRequested"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var selectedLanguage: SupportedLanguage {
        get {
            guard let rawValue = defaults.string(forKey: Key.selectedLanguage),
                  let language = SupportedLanguage(rawValue: rawValue)
            else {
                return .system
            }
            return language
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.selectedLanguage)
        }
    }

    public var selectedDuration: SessionDuration {
        get {
            guard let rawValue = defaults.string(forKey: Key.selectedDuration),
                  let duration = SessionDuration(rawValue: rawValue)
            else {
                return .hours1
            }
            return duration
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.selectedDuration)
        }
    }

    public var batteryThreshold: Int {
        get {
            guard defaults.object(forKey: Key.batteryThreshold) != nil else {
                return LowBatteryPolicy.defaultThreshold
            }
            return Self.clampedThreshold(defaults.integer(forKey: Key.batteryThreshold))
        }
        set {
            defaults.set(Self.clampedThreshold(newValue), forKey: Key.batteryThreshold)
        }
    }

    public var launchAtLoginRequested: Bool {
        get { defaults.bool(forKey: Key.launchAtLoginRequested) }
        set { defaults.set(newValue, forKey: Key.launchAtLoginRequested) }
    }

    public var notificationAuthorizationRequested: Bool {
        get { defaults.bool(forKey: Key.notificationAuthorizationRequested) }
        set { defaults.set(newValue, forKey: Key.notificationAuthorizationRequested) }
    }

    private static func clampedThreshold(_ threshold: Int) -> Int {
        min(LowBatteryPolicy.thresholdRange.upperBound, max(LowBatteryPolicy.thresholdRange.lowerBound, threshold))
    }
}
