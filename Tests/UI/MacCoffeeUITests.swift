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

    func testExplicitLanguageSwitchPreservesActiveWakeSessionAndKeepsPanelControlsVisible() {
        launch(language: "en", batteryPercentage: 80)

        testWindow.radioButtons["maccoffee.mode.system"].click()
        XCTAssertEqual(integerValue(of: testWindow.radioButtons["maccoffee.mode.system"]), 1)
        testWindow.radioButtons["maccoffee.duration.hours2"].click()
        let processID = runningAppProcessID()
        XCTAssertEqual(integerValue(of: testWindow.radioButtons["maccoffee.duration.hours2"]), 1)

        testWindow.buttons["maccoffee.action.settings"].click()
        let languagePicker = app.descendants(matching: .any)["maccoffee.settings.language"].firstMatch
        XCTAssertTrue(languagePicker.waitForExistence(timeout: 2))

        for language in ["Русский", "English", "Deutsch", "Français", "简体中文", "日本語", "한국어", "Español"] {
            languagePicker.click()
            app.menuItems[language].click()

            XCTAssertEqual(runningAppProcessID(), processID)
            XCTAssertEqual(integerValue(of: testWindow.radioButtons["maccoffee.mode.system"]), 1)
            XCTAssertEqual(integerValue(of: testWindow.radioButtons["maccoffee.duration.hours2"]), 1)

            app.typeKey("w", modifierFlags: .command)
            openMenuBarPanel()
            assertPanelControlsFitInsideTestWindow()

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
            "maccoffee.action.quit"
        ] {
            let element = testWindow.descendants(matching: .any)[identifier].firstMatch
            XCTAssertTrue(element.exists, "Missing \(identifier)", file: file, line: line)
            XCTAssertTrue(
                windowFrame.contains(element.frame),
                "\(identifier) is outside the test window: \(element.frame)",
                file: file,
                line: line
            )
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
}
