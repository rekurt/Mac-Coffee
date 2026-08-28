import Foundation
import XCTest
@testable import MacCoffeeCore

final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "MacCoffeeTests.\(UUID().uuidString)")
    }

    override func tearDown() {
        if let suiteName = defaults.volatileDomainNames.first(where: { $0.hasPrefix("MacCoffeeTests.") }) {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        super.tearDown()
    }

    func testDefaultsMatchProductDecisions() {
        let store = UserDefaultsSettingsStore(defaults: defaults)

        XCTAssertEqual(store.selectedDuration, .indefinite)
        XCTAssertEqual(store.batteryThreshold, 15)
        XCTAssertFalse(store.launchAtLoginRequested)
        XCTAssertFalse(store.notificationAuthorizationRequested)
    }

    func testValuesRoundTripAndThresholdIsClamped() {
        let store = UserDefaultsSettingsStore(defaults: defaults)

        store.selectedDuration = .hours4
        store.batteryThreshold = 50
        store.launchAtLoginRequested = true
        store.notificationAuthorizationRequested = true

        let reloaded = UserDefaultsSettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.selectedDuration, .hours4)
        XCTAssertEqual(reloaded.batteryThreshold, 30)
        XCTAssertTrue(reloaded.launchAtLoginRequested)
        XCTAssertTrue(reloaded.notificationAuthorizationRequested)
    }

    func testStoreNeverDefinesActiveModeOrSessionKeys() {
        let store = UserDefaultsSettingsStore(defaults: defaults)
        store.selectedDuration = .hours1

        XCTAssertNil(defaults.object(forKey: "mode"))
        XCTAssertNil(defaults.object(forKey: "session"))
        XCTAssertNil(defaults.object(forKey: "activeMode"))
    }
}
