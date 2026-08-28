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

    func testTurningOffClearsSessionAndSchedule() throws {
        let harness = Harness()
        try harness.model.setMode(.system)

        try harness.model.setMode(.off)

        XCTAssertEqual(harness.model.mode, .off)
        XCTAssertNil(harness.model.session)
        XCTAssertFalse(harness.scheduler.hasScheduledAction)
    }

    func testIndefiniteSessionHasNoScheduledAction() throws {
        let harness = Harness()
        harness.model.selectDuration(.indefinite)

        try harness.model.setMode(.display)

        XCTAssertNil(harness.model.session?.expiresAt)
        XCTAssertFalse(harness.scheduler.hasScheduledAction)
    }

    func testLowBatteryStopsAndNotifies() throws {
        let harness = Harness()
        try harness.model.setMode(.system)

        harness.battery.emit(.init(powerSource: .battery, percentage: 15, hasInternalBattery: true))

        XCTAssertEqual(harness.model.mode, .off)
        XCTAssertTrue(harness.model.isBatteryBlocked)
        XCTAssertEqual(harness.notifications.events, [.lowBatteryStopped])
    }

    func testBlockedBatteryRejectsActivationAndStatusCanBeDismissed() {
        let harness = Harness(
            batteryState: BatteryState(powerSource: .battery, percentage: 15, hasInternalBattery: true)
        )

        XCTAssertThrowsError(try harness.model.setMode(.system))
        XCTAssertEqual(harness.model.mode, .off)
        XCTAssertNotNil(harness.model.statusMessage)

        harness.model.dismissStatus()
        XCTAssertNil(harness.model.statusMessage)
    }

    func testBatteryThresholdClampsPersistsAndReevaluatesBattery() {
        let harness = Harness(
            batteryState: BatteryState(powerSource: .battery, percentage: 20, hasInternalBattery: true)
        )

        harness.model.setBatteryThreshold(50)

        XCTAssertEqual(harness.model.batteryThreshold, 30)
        XCTAssertEqual(harness.settings.batteryThreshold, 30)
        XCTAssertTrue(harness.model.isBatteryBlocked)

        harness.model.setBatteryThreshold(0)
        XCTAssertEqual(harness.model.batteryThreshold, 10)
        XCTAssertEqual(harness.settings.batteryThreshold, 10)
        XCTAssertFalse(harness.model.isBatteryBlocked)
    }

    func testAssertionFailureKeepsPriorModeAndShowsError() throws {
        let harness = Harness()
        try harness.model.setMode(.system)
        harness.power.failNextTransition = true

        XCTAssertThrowsError(try harness.model.setMode(.display))

        XCTAssertEqual(harness.model.mode, .system)
        XCTAssertNotNil(harness.model.statusMessage)
    }

    func testLaunchAtLoginSuccessFailureAndActivationRefresh() throws {
        let harness = Harness()

        try harness.model.setLaunchAtLogin(true)
        XCTAssertEqual(harness.model.launchAtLoginStatus, .enabled)
        XCTAssertTrue(harness.settings.launchAtLoginRequested)

        harness.launchAtLogin.shouldFail = true
        XCTAssertThrowsError(try harness.model.setLaunchAtLogin(false))
        XCTAssertEqual(harness.model.launchAtLoginStatus, .enabled)
        XCTAssertNotNil(harness.model.statusMessage)

        harness.launchAtLogin.shouldFail = false
        try harness.launchAtLogin.setEnabled(false)
        harness.lifecycle.onActivation?()
        XCTAssertEqual(harness.model.launchAtLoginStatus, .disabled)
    }

    func testTimerCompletionStopsAndNotifies() throws {
        let harness = Harness(now: Date(timeIntervalSince1970: 1_000))
        harness.model.selectDuration(.minutes30)
        try harness.model.setMode(.system)

        harness.clock.now = Date(timeIntervalSince1970: 2_800)
        harness.scheduler.fire()

        XCTAssertEqual(harness.model.mode, .off)
        XCTAssertNil(harness.model.session)
        XCTAssertEqual(harness.notifications.events, [.timerCompleted])
        XCTAssertEqual(
            harness.model.statusMessage,
            String(localized: "notification.timerCompleted", bundle: .main)
        )
    }

    func testBackwardClockChangeReschedulesInsteadOfExpiringEarly() throws {
        let harness = Harness(now: Date(timeIntervalSince1970: 1_000))
        harness.model.selectDuration(.hours1)
        try harness.model.setMode(.system)
        XCTAssertEqual(harness.scheduler.scheduleCount, 1)

        harness.clock.now = Date(timeIntervalSince1970: 900)
        harness.scheduler.fire()

        XCTAssertEqual(harness.model.mode, .system)
        XCTAssertNotNil(harness.model.session)
        XCTAssertTrue(harness.scheduler.hasScheduledAction)
        XCTAssertEqual(harness.scheduler.scheduleCount, 2)
    }

    func testLifecycleWakeAndClockChangeRevalidateDeadline() throws {
        let harness = Harness(now: Date(timeIntervalSince1970: 1_000))
        try harness.model.setMode(.system)
        XCTAssertEqual(harness.scheduler.scheduleCount, 1)

        harness.lifecycle.onWake?()
        harness.lifecycle.onClockChange?()

        XCTAssertEqual(harness.scheduler.scheduleCount, 3)
    }

    func testTimerReleaseFailureKeepsConfirmedModeAndShowsError() throws {
        let harness = Harness(now: Date(timeIntervalSince1970: 1_000))
        harness.model.selectDuration(.minutes30)
        try harness.model.setMode(.system)
        harness.clock.now = Date(timeIntervalSince1970: 2_800)
        harness.power.failNextTransition = true

        harness.scheduler.fire()

        XCTAssertEqual(harness.model.mode, .system)
        XCTAssertEqual(harness.model.session?.mode, .system)
        XCTAssertNotNil(harness.model.statusMessage)
    }

    func testTimerReleaseFailureReconcilesAChangedConfirmedAssertion() throws {
        let harness = Harness(now: Date(timeIntervalSince1970: 1_000))
        harness.model.selectDuration(.minutes30)
        try harness.model.setMode(.display)
        harness.clock.now = Date(timeIntervalSince1970: 2_800)
        harness.power.failNextTransition = true
        harness.power.confirmedModeOnFailure = .system

        harness.scheduler.fire()

        XCTAssertEqual(harness.model.mode, .system)
        XCTAssertEqual(harness.model.session?.mode, .system)
        XCTAssertFalse(harness.scheduler.hasScheduledAction)
    }

    func testPersistentExpiredReleaseFailureDoesNotBusyRetry() async throws {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let power = FakePowerAssertionManager()
        let scheduler = TaskSessionScheduler(now: { clock.now })
        let model = AppModel(environment: AppEnvironment(
            powerAssertions: power,
            battery: FakeBatteryMonitor(),
            scheduler: scheduler,
            settings: FakeSettingsStore(savedDuration: .minutes30),
            launchAtLogin: FakeLaunchAtLoginManager(),
            notifications: FakeNotificationSender(),
            lifecycle: FakeLifecycleObserver(),
            now: { clock.now }
        ))
        try model.setMode(.system)
        clock.now = Date(timeIntervalSince1970: 2_800)
        power.failEveryTransition = true

        model.revalidateDeadline()
        let transitionCount = power.transitions.count
        try await Task.sleep(for: .milliseconds(30))

        XCTAssertEqual(power.transitions.count, transitionCount)
        XCTAssertEqual(model.mode, .system)
        XCTAssertFalse(scheduler.hasScheduledAction)
    }

    func testTerminationCancelsAndReleasesEverything() throws {
        let harness = Harness()
        try harness.model.setMode(.display)

        harness.lifecycle.onTermination?()

        XCTAssertFalse(harness.scheduler.hasScheduledAction)
        XCTAssertTrue(harness.power.releaseAllCalled)
        XCTAssertFalse(harness.battery.started)
        XCTAssertFalse(harness.lifecycle.started)
    }
}

@MainActor
private final class Harness {
    let clock: TestClock
    let settings: FakeSettingsStore
    let power = FakePowerAssertionManager()
    let battery: FakeBatteryMonitor
    let scheduler = FakeSessionScheduler()
    let launchAtLogin = FakeLaunchAtLoginManager()
    let notifications = FakeNotificationSender()
    let lifecycle = FakeLifecycleObserver()
    let model: AppModel

    init(
        now: Date = Date(timeIntervalSince1970: 1_000),
        savedDuration: SessionDuration = .hours1,
        batteryState: BatteryState = .acDesktop
    ) {
        clock = TestClock(now: now)
        battery = FakeBatteryMonitor(state: batteryState)
        settings = FakeSettingsStore(savedDuration: savedDuration)
        model = AppModel(environment: AppEnvironment(
            powerAssertions: power,
            battery: battery,
            scheduler: scheduler,
            settings: settings,
            launchAtLogin: launchAtLogin,
            notifications: notifications,
            lifecycle: lifecycle,
            now: { [clock] in clock.now }
        ))
    }
}

private final class TestClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
