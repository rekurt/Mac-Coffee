import Combine
import Foundation
import XCTest
@testable import MacCoffeeCore

@MainActor
final class RuntimeLocalizationTests: XCTestCase {
    func testSupportedLanguagesUseProductPersistenceValuesAndNativeNames() {
        XCTAssertEqual(
            SupportedLanguage.allCases.map(\.rawValue),
            ["system", "ru", "en", "de", "fr", "zh-Hans", "ja", "ko", "es"]
        )
        XCTAssertEqual(SupportedLanguage.russian.displayName, "Русский")
        XCTAssertEqual(SupportedLanguage.english.displayName, "English")
        XCTAssertEqual(SupportedLanguage.german.displayName, "Deutsch")
        XCTAssertEqual(SupportedLanguage.french.displayName, "Français")
        XCTAssertEqual(SupportedLanguage.simplifiedChinese.displayName, "简体中文")
        XCTAssertEqual(SupportedLanguage.japanese.displayName, "日本語")
        XCTAssertEqual(SupportedLanguage.korean.displayName, "한국어")
        XCTAssertEqual(SupportedLanguage.spanish.displayName, "Español")
    }

    func testSystemLanguageMatchesSupportedBaseLanguageAndFallsBackToEnglish() {
        let russian = LocalizationController(
            settings: FakeSettingsStore(selectedLanguage: .system),
            systemLocale: { Locale(identifier: "ru_RU") }
        )
        let unsupported = LocalizationController(
            settings: FakeSettingsStore(selectedLanguage: .system),
            systemLocale: { Locale(identifier: "it_IT") }
        )

        XCTAssertEqual(russian.locale.identifier, "ru")
        XCTAssertEqual(unsupported.locale.identifier, "en")
    }

    func testSystemSimplifiedChineseIdentifiersResolveToSimplifiedChinese() {
        for identifier in ["zh_CN", "zh_SG", "zh"] {
            let controller = LocalizationController(
                settings: FakeSettingsStore(selectedLanguage: .system),
                systemLocale: { Locale(identifier: identifier) }
            )

            XCTAssertEqual(controller.locale.identifier, "zh-Hans", "Expected \(identifier) to resolve to zh-Hans")
        }
    }

    func testSystemTraditionalChineseIdentifiersFallBackToEnglish() {
        for identifier in ["zh-Hant", "zh_TW", "zh_HK", "zh_MO"] {
            let controller = LocalizationController(
                settings: FakeSettingsStore(selectedLanguage: .system),
                systemLocale: { Locale(identifier: identifier) }
            )

            XCTAssertEqual(controller.locale.identifier, "en", "Expected \(identifier) to fall back to English")
        }
    }

    func testMalformedSavedLanguageDefaultsToSystem() {
        let suiteName = "MacCoffeeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("pt-BR", forKey: "selectedLanguage")

        XCTAssertEqual(UserDefaultsSettingsStore(defaults: defaults).selectedLanguage, .system)
    }

    func testSelectingLanguagePersistsAndPublishesResolvedLocaleImmediately() {
        let settings = FakeSettingsStore(selectedLanguage: .system)
        let controller = LocalizationController(
            settings: settings,
            systemLocale: { Locale(identifier: "en_US") }
        )
        var publishedLocaleIdentifiers: [String] = []
        let observation = controller.$locale.dropFirst().sink { publishedLocaleIdentifiers.append($0.identifier) }

        controller.select(.japanese)

        XCTAssertEqual(settings.selectedLanguage, .japanese)
        XCTAssertEqual(controller.selectedLanguage, .japanese)
        XCTAssertEqual(controller.locale.identifier, "ja")
        XCTAssertEqual(publishedLocaleIdentifiers, ["ja"])
        observation.cancel()
    }

    func testRefreshingSystemLanguagePublishesNewResolvedLocale() {
        var systemLocale = Locale(identifier: "en_US")
        let controller = LocalizationController(
            settings: FakeSettingsStore(selectedLanguage: .system),
            systemLocale: { systemLocale }
        )

        systemLocale = Locale(identifier: "fr_FR")
        controller.refreshSystemLocale()

        XCTAssertEqual(controller.locale.identifier, "fr")
    }

    func testLocalizedFormattingUsesSelectedLocale() throws {
        let fixture = try LocalizationFixture.make()
        let controller = LocalizationController(
            settings: FakeSettingsStore(selectedLanguage: .english),
            systemLocale: { Locale(identifier: "en_US") },
            bundle: fixture.bundle
        )

        XCTAssertEqual(controller.format("item.count", arguments: 2), "2 items")

        controller.select(.russian)

        XCTAssertEqual(controller.format("item.count", arguments: 2), "2 предмета")
    }

    func testCountdownFormattingUsesTheControllerBundleAfterLanguageChanges() throws {
        let fixture = try LocalizationFixture.make()
        let controller = LocalizationController(
            settings: FakeSettingsStore(selectedLanguage: .english),
            systemLocale: { Locale(identifier: "en_US") },
            bundle: fixture.bundle
        )
        let formatter = CountdownFormatter(localization: controller)
        let deadline = Date(timeIntervalSince1970: 3_660)
        let now = Date(timeIntervalSince1970: 0)

        XCTAssertEqual(formatter.remainingText(until: deadline, now: now), "1h 1m remaining")

        controller.select(.russian)

        XCTAssertEqual(formatter.remainingText(until: deadline, now: now), "Осталось 1ч 1мин")
    }

    func testStatusNoticeIsRenderedUsingCurrentLanguageInsteadOfFrozenText() throws {
        let fixture = try LocalizationFixture.make()
        let settings = FakeSettingsStore(selectedLanguage: .english)
        let localization = LocalizationController(
            settings: settings,
            systemLocale: { Locale(identifier: "en_US") },
            bundle: fixture.bundle
        )
        let model = AppModel(environment: makeEnvironment(settings: settings, localization: localization))

        XCTAssertThrowsError(try model.setMode(.system))
        XCTAssertEqual(model.statusNotice, .batteryBlocked)
        XCTAssertEqual(model.statusMessage, "Battery protection")

        localization.select(.russian)

        XCTAssertEqual(model.statusMessage, "Защита батареи")
    }

    func testNotificationMessageUsesCurrentLocalizationAtDeliveryTime() throws {
        let fixture = try LocalizationFixture.make()
        let settings = FakeSettingsStore(selectedLanguage: .english)
        let localization = LocalizationController(
            settings: settings,
            systemLocale: { Locale(identifier: "en_US") },
            bundle: fixture.bundle
        )
        let sender = UserNotificationSender(settings: settings, localization: localization)

        XCTAssertEqual(sender.localizedMessage(for: .timerCompleted).body, "Timer finished")

        localization.select(.russian)

        XCTAssertEqual(sender.localizedMessage(for: .timerCompleted).body, "Таймер завершён")
    }

    private func makeEnvironment(settings: SettingsStoring, localization: LocalizationController) -> AppEnvironment {
        AppEnvironment(
            powerAssertions: FakePowerAssertionManager(),
            battery: FakeBatteryMonitor(state: .init(powerSource: .battery, percentage: 15, hasInternalBattery: true)),
            scheduler: FakeSessionScheduler(),
            settings: settings,
            launchAtLogin: FakeLaunchAtLoginManager(),
            notifications: FakeNotificationSender(),
            lifecycle: FakeLifecycleObserver(),
            localization: localization
        )
    }
}

private enum LocalizationFixture {
    static func make() throws -> (bundle: Bundle, url: URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCoffeeLocalization.\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
        <plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>com.rekurt.maccoffee.localization-tests</string><key>CFBundleDevelopmentRegion</key><string>en</string><key>CFBundleLocalizations</key><array><string>en</string><string>ru</string></array></dict></plist>
        """.write(to: url.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        try writeStrings(["battery.blocked": "Battery protection", "item.count": "%d items", "notification.title": "Mac Coffee", "notification.timerCompleted": "Timer finished", "notification.lowBatteryStopped": "Battery stopped", "countdown.hoursMinutes": "%dh %dm", "countdown.minutes": "%dm", "countdown.seconds": "%ds", "status.remaining": "%@ remaining"], language: "en", in: url)
        try writeStrings(["battery.blocked": "Защита батареи", "item.count": "%d предмета", "notification.title": "Mac Coffee", "notification.timerCompleted": "Таймер завершён", "notification.lowBatteryStopped": "Батарея остановлена", "countdown.hoursMinutes": "%dч %dмин", "countdown.minutes": "%dмин", "countdown.seconds": "%dс", "status.remaining": "Осталось %@"], language: "ru", in: url)
        return (try XCTUnwrap(Bundle(url: url)), url)
    }

    private static func writeStrings(_ strings: [String: String], language: String, in bundleURL: URL) throws {
        let directory = bundleURL.appendingPathComponent("\(language).lproj")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let contents = strings.map { "\"\($0.key)\" = \"\($0.value)\";" }.joined(separator: "\n")
        try contents.write(to: directory.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)
    }
}
