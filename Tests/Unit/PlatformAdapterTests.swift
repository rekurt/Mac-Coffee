import Foundation
import IOKit.ps
import XCTest
@testable import MacCoffeeCore

final class PlatformAdapterTests: XCTestCase {
    @MainActor
    func testMissingMainAppRegistrationIsTreatedAsDisabledSoItCanBeRegistered() {
        XCTAssertEqual(SMAppLaunchAtLoginManager().status, .disabled)
    }

    func testBatteryDescriptionUsesCurrentOverMaximumCapacity() {
        let description: [String: Any] = [
            kIOPSTransportTypeKey: kIOPSInternalType,
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
            kIOPSCurrentCapacityKey: 40,
            kIOPSMaxCapacityKey: 80
        ]

        let state = IOKitBatteryMonitor.parse(description: description)

        XCTAssertEqual(state.percentage, 50)
        XCTAssertEqual(state.powerSource, .battery)
        XCTAssertTrue(state.hasInternalBattery)
    }

    func testBatteryPercentageIsClamped() {
        let description: [String: Any] = [
            kIOPSTransportTypeKey: kIOPSInternalType,
            kIOPSPowerSourceStateKey: kIOPSACPowerValue,
            kIOPSCurrentCapacityKey: 120,
            kIOPSMaxCapacityKey: 100
        ]

        XCTAssertEqual(IOKitBatteryMonitor.parse(description: description).percentage, 100)
    }

    @MainActor
    func testSchedulerCancellationPreventsAction() async throws {
        let scheduler = TaskSessionScheduler()
        var fired = false
        scheduler.schedule(deadline: Date().addingTimeInterval(60)) {
            fired = true
        }

        scheduler.cancel()
        try await Task.sleep(for: .milliseconds(20))

        XCTAssertFalse(fired)
        XCTAssertFalse(scheduler.hasScheduledAction)
    }

    @MainActor
    func testSchedulerFiresPastDeadlineImmediately() async throws {
        let scheduler = TaskSessionScheduler()
        let fired = expectation(description: "scheduled action")

        scheduler.schedule(deadline: Date().addingTimeInterval(-1)) {
            fired.fulfill()
        }

        await fulfillment(of: [fired], timeout: 1)
        XCTAssertFalse(scheduler.hasScheduledAction)
    }

    @MainActor
    func testCancelledTaskCannotClearReplacementSchedule() async throws {
        let scheduler = TaskSessionScheduler()
        scheduler.schedule(deadline: Date().addingTimeInterval(60)) {}
        scheduler.schedule(deadline: Date().addingTimeInterval(120)) {}

        try await Task.sleep(for: .milliseconds(20))

        XCTAssertTrue(scheduler.hasScheduledAction)
        scheduler.cancel()
    }

    func testBatteryReadFailurePreservesLaptopIdentityAsUnknown() {
        let previous = BatteryState(powerSource: .battery, percentage: 12, hasInternalBattery: true)

        let fallback = IOKitBatteryMonitor.stateAfterReadFailure(previous: previous)

        XCTAssertEqual(fallback.powerSource, .unknown)
        XCTAssertNil(fallback.percentage)
        XCTAssertTrue(fallback.hasInternalBattery)
    }
}
