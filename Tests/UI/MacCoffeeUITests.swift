import XCTest

@MainActor
final class MacCoffeeUITests: XCTestCase {
    private var app: XCUIApplication!

    func testEnglishModeDurationSettingsAndQuitFlow() {
        launch(language: "en", batteryPercentage: 80)

        XCTAssertTrue(app.windows["Mac Coffee"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.radioGroups["maccoffee.mode.picker"].exists)
        XCTAssertTrue(app.radioGroups["maccoffee.duration.picker"].exists)

        app.radioButtons["maccoffee.mode.system"].click()
        XCTAssertTrue(app.staticTexts["Mac Coffee is active"].waitForExistence(timeout: 2))

        app.radioButtons["maccoffee.mode.display"].click()
        app.radioButtons["maccoffee.mode.off"].click()
        XCTAssertTrue(app.staticTexts["Mac Coffee is off"].waitForExistence(timeout: 2))
        app.radioButtons["maccoffee.mode.system"].click()

        for duration in ["minutes30", "hours1", "hours4", "hours8", "indefinite", "hours2"] {
            let button = app.radioButtons["maccoffee.duration.\(duration)"]
            button.click()
            XCTAssertEqual(integerValue(of: button), 1)
        }
        let countdown = app.staticTexts.matching(
            NSPredicate(format: "identifier == %@ AND value CONTAINS %@", "maccoffee.status.card", "remaining")
        ).firstMatch
        XCTAssertTrue(countdown.exists)

        app.buttons["maccoffee.action.settings"].click()
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

        XCTAssertTrue(app.windows["Mac Coffee"].waitForExistence(timeout: 5))
        app.radioButtons["maccoffee.mode.system"].click()

        let banner = app.descendants(matching: .any)["maccoffee.status.banner"].firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Wake mode stopped to protect the battery."].exists)
    }

    func testBatteryThresholdIsClampedToSupportedBounds() {
        launch(language: "en", batteryPercentage: 80, batteryThreshold: 5)
        app.buttons["maccoffee.action.settings"].click()
        let minimumStepper = app.steppers["maccoffee.settings.batteryThreshold"]
        XCTAssertTrue(minimumStepper.waitForExistence(timeout: 2))
        XCTAssertEqual(integerValue(of: minimumStepper), 10)

        app.terminate()
        launch(language: "en", batteryPercentage: 80, batteryThreshold: 40)
        app.buttons["maccoffee.action.settings"].click()
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

        XCTAssertTrue(app.windows["Mac Coffee"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.radioButtons["maccoffee.mode.system"].exists)
        XCTAssertTrue(app.staticTexts["Длительность"].exists)
        XCTAssertFalse(app.buttons["maccoffee.action.update"].exists)
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
        if app.windows["Mac Coffee"].waitForExistence(timeout: 2) {
            return
        }
        let statusItem = app.descendants(matching: .statusItem)["Mac Coffee"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        XCTAssertTrue(app.windows["Mac Coffee"].waitForExistence(timeout: 5))
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
}
