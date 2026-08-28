import Foundation
import XCTest
@testable import MacCoffeeCore

@MainActor
final class AppModelTests: XCTestCase {
    func testEveryLaunchStartsOff() {
        let harness = Harness(savedDuration: .hours4)

        XCTAssertEqual(harness.model.mode, .off)
        XCTAssertNil(harness.model.session)
        XCTAssertEqual(harness.model.selectedDuration, .hours4)
        XCTAssertTrue(harness.battery.started)
        XCTAssertTrue(harness.lifecycle.started)
    }

    func testModeSwitchPreservesDeadline() throws {
        let harness = Harness(now: Date(timeIntervalSince1970: 1_000))
        harness.model.selectDuration(.hours1)
        try harness.model.setMode(.system)
        let deadline = harness.model.session?.expiresAt

        try harness.model.setMode(.display)

        XCTAssertEqual(harness.model.session?.expiresAt, deadline)
        XCTAssertEqual(harness.model.mode, .display)
    }

    func testLowBatteryStopsAndNotifies() throws {
        let harness = Harness()
        try harness.model.setMode(.system)

        harness.battery.emit(.init(powerSource: .battery, percentage: 15, hasInternalBattery: true))

        XCTAssertEqual(harness.model.mode, .off)
        XCTAssertTrue(harness.model.isBatteryBlocked)
        XCTAssertEqual(harness.notifications.events, [.lowBatteryStopped])
    }

    func testAssertionFailureKeepsPriorModeAndShowsError() throws {
        let harness = Harness()
        try harness.model.setMode(.system)
        harness.power.failNextTransition = true

        XCTAssertThrowsError(try harness.model.setMode(.display))

        XCTAssertEqual(harness.model.mode, .system)
        XCTAssertNotNil(harness.model.statusMessage)
    }

    func testTimerCompletionStopsAndNotifies() throws {
        let harness = Harness(now: Date(timeIntervalSince1970: 1_000))
        harness.model.selectDuration(.minutes30)
        try harness.model.setMode(.system)

        harness.scheduler.fire()

        XCTAssertEqual(harness.model.mode, .off)
        XCTAssertNil(harness.model.session)
        XCTAssertEqual(harness.notifications.events, [.timerCompleted])
    }

    func testTerminationCancelsAndReleasesEverything() throws {
        let harness = Harness()
        try harness.model.setMode(.display)

        harness.model.prepareForTermination()

        XCTAssertFalse(harness.scheduler.hasScheduledAction)
        XCTAssertTrue(harness.power.releaseAllCalled)
        XCTAssertFalse(harness.battery.started)
        XCTAssertFalse(harness.lifecycle.started)
    }
}

@MainActor
private final class Harness {
    let settings: FakeSettingsStore
    let power = FakePowerAssertionManager()
    let battery = FakeBatteryMonitor()
    let scheduler = FakeSessionScheduler()
    let launchAtLogin = FakeLaunchAtLoginManager()
    let notifications = FakeNotificationSender()
    let lifecycle = FakeLifecycleObserver()
    let model: AppModel

    init(
        now: Date = Date(timeIntervalSince1970: 1_000),
        savedDuration: SessionDuration = .indefinite
    ) {
        settings = FakeSettingsStore(savedDuration: savedDuration)
        model = AppModel(environment: AppEnvironment(
            powerAssertions: power,
            battery: battery,
            scheduler: scheduler,
            settings: settings,
            launchAtLogin: launchAtLogin,
            notifications: notifications,
            lifecycle: lifecycle,
            now: { now }
        ))
    }
}
