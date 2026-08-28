import AppKit
import XCTest

@MainActor
final class MacCoffeeUITests: XCTestCase {
    private var app: XCUIApplication!

    func testEnglishModeDurationSettingsAndQuitFlow() {
        launch(language: "en", batteryPercentage: 80)

        XCTAssertTrue(testWindow.waitForExistence(timeout: 5))
        XCTAssertTrue(testWindow.radioGroups["maccoffee.mode.picker"].exists)
        XCTAssertTrue(testWindow.radioGroups["maccoffee.duration.picker"].exists)

        testWindow.radioButtons["maccoffee.mode.system"].click()
        XCTAssertTrue(app.staticTexts["Mac Coffee is active"].waitForExistence(timeout: 2))

        testWindow.radioButtons["maccoffee.mode.display"].click()
        testWindow.radioButtons["maccoffee.mode.off"].click()
        XCTAssertTrue(app.staticTexts["Mac Coffee is off"].waitForExistence(timeout: 2))
        testWindow.radioButtons["maccoffee.mode.system"].click()

        for duration in ["minutes30", "hours1", "hours4", "hours8", "indefinite", "hours2"] {
            let button = testWindow.radioButtons["maccoffee.duration.\(duration)"]
            button.click()
            XCTAssertEqual(integerValue(of: button), 1)
        }
        let countdown = app.staticTexts.matching(
            NSPredicate(format: "identifier == %@ AND value CONTAINS %@", "maccoffee.status.card", "remaining")
        ).firstMatch
        XCTAssertTrue(countdown.exists)

        testWindow.buttons["maccoffee.action.settings"].click()
        let loginToggle = app.switches["maccoffee.settings.launchAtLogin"]
        XCTAssertTrue(loginToggle.waitForExistence(timeout: 2))
        loginToggle.click()
        XCTAssertEqual(integerValue(of: loginToggle), 1)
        XCTAssertTrue(app.steppers["maccoffee.settings.batteryThreshold"].exists)

        app.windows["Mac Coffee Settings"].buttons[XCUIIdentifierCloseWindow].click()
        openMenuBarPanel()
        XCTAssertTrue(app.buttons["maccoffee.action.quit"].waitForExistence(timeout: 2))
        app.buttons["maccoffee.action.quit"].click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 2))
        app.sheets.firstMatch.buttons["Cancel"].click()

        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 2))
        app.sheets.firstMatch.buttons["Cancel"].click()
        XCTAssertTrue(app.exists)
    }

    func testLowBatteryBlocksActivationAndShowsBanner() {
        launch(language: "en", batteryPercentage: 15)

        XCTAssertTrue(testWindow.waitForExistence(timeout: 5))
        testWindow.radioButtons["maccoffee.mode.system"].click()

        let banner = app.descendants(matching: .any)["maccoffee.status.banner"].firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Wake mode stopped to protect the battery."].exists)
    }

    func testBatteryThresholdIsClampedToSupportedBounds() {
        launch(language: "en", batteryPercentage: 80, batteryThreshold: 5)
        testWindow.buttons["maccoffee.action.settings"].click()
        let minimumStepper = app.steppers["maccoffee.settings.batteryThreshold"]
        XCTAssertTrue(minimumStepper.waitForExistence(timeout: 2))
        XCTAssertEqual(integerValue(of: minimumStepper), 10)

        app.terminate()
        launch(language: "en", batteryPercentage: 80, batteryThreshold: 40)
        testWindow.buttons["maccoffee.action.settings"].click()
        let maximumStepper = app.steppers["maccoffee.settings.batteryThreshold"]
        XCTAssertTrue(maximumStepper.waitForExistence(timeout: 2))
        XCTAssertEqual(integerValue(of: maximumStepper), 30)
    }

    func testRussianLocalizationAndAppStoreHasNoUpdateAction() {
        app = XCUIApplication(bundleIdentifier: "com.rekurt.maccoffee.debug")
        app.launchArguments = [
            "--ui-testing-window",
            "-AppleLanguages", "(ru)",
            "-AppleLocale", "ru_RU"
        ]
        app.launch()
        openMenuBarPanel()

        XCTAssertTrue(testWindow.waitForExistence(timeout: 5))
        XCTAssertTrue(testWindow.radioButtons["maccoffee.mode.system"].exists)
        XCTAssertTrue(app.staticTexts["Длительность"].exists)
        XCTAssertFalse(app.buttons["maccoffee.action.update"].exists)
    }

    func testExplicitLanguageSwitchPreservesActiveWakeSessionAndKeepsPanelControlsVisible() throws {
        launch(language: "en", batteryPercentage: 80)

        testWindow.radioButtons["maccoffee.mode.system"].click()
        testWindow.radioButtons["maccoffee.duration.hours2"].click()
        let processID = try XCTUnwrap(runningAppProcessID(), "Could not find the launched Mac Coffee process")
        let initialSessionMarker = try XCTUnwrap(sessionMarker(), "Active wake session has no deterministic marker")

        testWindow.buttons["maccoffee.action.settings"].click()
        let languagePicker = app.descendants(matching: .any)["maccoffee.settings.language"].firstMatch
        XCTAssertTrue(languagePicker.waitForExistence(timeout: 2))

        for expectation in explicitLanguageExpectations {
            languagePicker.click()
            app.menuItems[expectation.nativeName].click()

            XCTAssertEqual(try XCTUnwrap(runningAppProcessID(), "Mac Coffee process disappeared"), processID)
            XCTAssertEqual(try XCTUnwrap(sessionMarker(), "Wake session marker disappeared"), initialSessionMarker)
            XCTAssertEqual(integerValue(of: testWindow.radioButtons["maccoffee.mode.system"]), 1)
            XCTAssertEqual(integerValue(of: testWindow.radioButtons["maccoffee.duration.hours2"]), 1)
            XCTAssertTrue(testWindow.staticTexts[expectation.activeStatus].exists)
            XCTAssertTrue(testWindow.staticTexts["maccoffee.session.countdown"].label.contains(expectation.remainingFragment))
            XCTAssertTrue(String(describing: testWindow.radioGroups["maccoffee.mode.picker"].value).contains(expectation.modeTitle))
            XCTAssertTrue(app.staticTexts[expectation.settingsTitle].exists)
            XCTAssertTrue(String(describing: languagePicker.value).contains(expectation.nativeName))

            app.typeKey("w", modifierFlags: .command)
            openMenuBarPanel()
            assertPanelControlsFitInsideTestWindow()

            testWindow.buttons["maccoffee.action.about"].click()
            let version = app.staticTexts["maccoffee.about.version"]
            XCTAssertTrue(version.waitForExistence(timeout: 2))
            XCTAssertTrue(version.label.contains(expectation.versionPrefix))
            app.typeKey("w", modifierFlags: .command)

            testWindow.buttons["maccoffee.action.settings"].click()
            XCTAssertTrue(languagePicker.waitForExistence(timeout: 2))
        }
    }

    private func launch(language: String, batteryPercentage: Int, batteryThreshold: Int? = nil) {
        app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing-window",
            "--ui-battery-percentage=\(batteryPercentage)",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "ru" ? "ru_RU" : "en_US"
        ]
        if let batteryThreshold {
            app.launchArguments.append("--ui-battery-threshold=\(batteryThreshold)")
        }
        app.launch()
        openMenuBarPanel()
    }

    private func openMenuBarPanel() {
        if testWindow.waitForExistence(timeout: 2) {
            return
        }
        let statusItem = app.descendants(matching: .statusItem)["Mac Coffee"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        XCTAssertTrue(testWindow.waitForExistence(timeout: 5))
    }

    private func integerValue(of element: XCUIElement) -> Int? {
        if let number = element.value as? NSNumber {
            return number.intValue
        }
        if let string = element.value as? String {
            return Int(string)
        }
        return nil
    }

    private func assertPanelControlsFitInsideTestWindow(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let windowFrame = testWindow.frame
        for identifier in [
            "maccoffee.mode.picker",
            "maccoffee.duration.picker",
            "maccoffee.status.card",
            "maccoffee.action.settings",
            "maccoffee.action.about",
            "maccoffee.action.quit"
        ] {
            let element = testWindow.descendants(matching: .any)[identifier].firstMatch
            XCTAssertTrue(element.exists, "Missing \(identifier)", file: file, line: line)
            XCTAssertGreaterThan(element.frame.width, 0, "\(identifier) has no width", file: file, line: line)
            XCTAssertGreaterThan(element.frame.height, 0, "\(identifier) has no height", file: file, line: line)
            XCTAssertTrue(
                windowFrame.contains(element.frame),
                "\(identifier) is outside the test window: \(element.frame)",
                file: file,
                line: line
            )
            XCTAssertTrue(element.isHittable, "\(identifier) is not hittable", file: file, line: line)
        }

        // The App Store variant deliberately omits its updater; when the control is
        // present in the Direct variant, it must satisfy the same panel bounds.
        let update = testWindow.buttons["maccoffee.action.update"]
        if update.exists {
            XCTAssertGreaterThan(update.frame.width, 0, "Update has no width", file: file, line: line)
            XCTAssertGreaterThan(update.frame.height, 0, "Update has no height", file: file, line: line)
            XCTAssertTrue(windowFrame.contains(update.frame), "Update is outside the test window", file: file, line: line)
            XCTAssertTrue(update.isHittable, "Update is not hittable", file: file, line: line)
        }

        for identifier in ["off", "system", "display"] {
            let element = testWindow.radioButtons["maccoffee.mode.\(identifier)"]
            XCTAssertGreaterThan(element.frame.width, 0, "Mode \(identifier) is clipped", file: file, line: line)
            XCTAssertGreaterThan(element.frame.height, 0, "Mode \(identifier) is clipped", file: file, line: line)
            XCTAssertTrue(windowFrame.contains(element.frame), "Mode \(identifier) is outside the test window", file: file, line: line)
            XCTAssertFalse(element.label.isEmpty, "Mode \(identifier) is missing a label", file: file, line: line)
            XCTAssertTrue(element.isHittable, "Mode \(identifier) is not hittable", file: file, line: line)
        }

        let durationButtons = ["minutes30", "hours1", "hours2", "hours4", "hours8", "indefinite"].map {
            testWindow.radioButtons["maccoffee.duration.\($0)"]
        }
        let widths = durationButtons.map(\.frame.width)
        XCTAssertTrue(widths.allSatisfy { $0 > 0 }, "A duration segment is clipped", file: file, line: line)
        for button in durationButtons {
            XCTAssertTrue(windowFrame.contains(button.frame), "Duration \(button.identifier) is outside the test window", file: file, line: line)
            XCTAssertFalse(button.label.isEmpty, "Duration \(button.identifier) is missing a label", file: file, line: line)
            XCTAssertTrue(button.isHittable, "Duration \(button.identifier) is not hittable", file: file, line: line)
        }
        if let firstWidth = widths.first {
            for width in widths.dropFirst() {
                XCTAssertEqual(width, firstWidth, accuracy: 1, "Duration segments must be equal width", file: file, line: line)
            }
        }
    }

    private func runningAppProcessID() -> pid_t? {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.rekurt.maccoffee.direct.debug")
            .first?
            .processIdentifier
    }

    private var testWindow: XCUIElement {
        app.windows["maccoffee.ui-test.window"]
    }

    private func sessionMarker() -> String? {
        let marker = testWindow.staticTexts["maccoffee.session.marker"]
        return marker.exists ? marker.label : nil
    }

    private var explicitLanguageExpectations: [LanguageExpectation] {
        [
            .init("Русский", "Mac Coffee работает", "Осталось", "Язык", "Не усыплять Mac", "Версия"),
            .init("English", "Mac Coffee is active", "remaining", "Language", "Keep Mac awake", "Version"),
            .init("Deutsch", "Mac Coffee ist aktiv", "verbleibend", "Sprache", "Mac wach halten", "Version"),
            .init("Français", "Mac Coffee est actif", "Temps restant", "Langue", "Garder le Mac éveillé", "Version"),
            .init("简体中文", "Mac Coffee 正在运行", "剩余", "语言", "保持 Mac 唤醒", "版本"),
            .init("日本語", "Mac Coffee は有効です", "残り", "言語", "Mac をスリープさせない", "バージョン"),
            .init("한국어", "Mac Coffee가 활성화되어 있습니다", "남음", "언어", "Mac 깨우기 유지", "버전"),
            .init("Español", "Mac Coffee está activo", "Tiempo restante", "Idioma", "Mantener el Mac activo", "Versión")
        ]
    }
}

private struct LanguageExpectation {
    let nativeName: String
    let activeStatus: String
    let remainingFragment: String
    let settingsTitle: String
    let modeTitle: String
    let versionPrefix: String

    init(
        _ nativeName: String,
        _ activeStatus: String,
        _ remainingFragment: String,
        _ settingsTitle: String,
        _ modeTitle: String,
        _ versionPrefix: String
    ) {
        self.nativeName = nativeName
        self.activeStatus = activeStatus
        self.remainingFragment = remainingFragment
        self.settingsTitle = settingsTitle
        self.modeTitle = modeTitle
        self.versionPrefix = versionPrefix
    }
}
