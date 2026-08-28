import XCTest
@testable import MacCoffeeCore

@MainActor
final class CompositionTests: XCTestCase {
    func testAppStoreCompositionHasNoUpdateCapability() {
        let environment = makeEnvironment(updater: nil)

        XCTAssertNil(environment.updater)
    }

    func testDirectCompositionUsesInjectedUpdaterCapability() {
        let updater = FakeUpdater()
        let environment = makeEnvironment(updater: updater)

        XCTAssertTrue(environment.updater === updater)
    }

    private func makeEnvironment(updater: UpdaterProviding?) -> AppEnvironment {
        AppEnvironment(
            powerAssertions: FakePowerAssertionManager(),
            battery: FakeBatteryMonitor(),
            scheduler: FakeSessionScheduler(),
            settings: FakeSettingsStore(),
            launchAtLogin: FakeLaunchAtLoginManager(),
            notifications: FakeNotificationSender(),
            lifecycle: FakeLifecycleObserver(),
            updater: updater
        )
    }
}

@MainActor
private final class FakeUpdater: UpdaterProviding {
    var canCheckForUpdates = true
    func checkForUpdates() {}
}
