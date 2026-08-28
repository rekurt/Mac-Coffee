import Foundation
import IOKit.pwr_mgt

public enum PowerAssertionError: LocalizedError, Equatable {
    case createFailed(IOReturn)
    case releaseFailed(IOPMAssertionID, IOReturn)

    public var errorDescription: String? {
        switch self {
        case let .createFailed(code):
            "Could not create a macOS power assertion (IOKit error \(code))."
        case let .releaseFailed(id, code):
            "Could not release macOS power assertion \(id) (IOKit error \(code))."
        }
    }
}

protocol PowerAssertionDriving: AnyObject {
    func create(type: CFString, name: CFString) throws -> IOPMAssertionID
    func release(id: IOPMAssertionID) throws
}

private final class SystemPowerAssertionDriver: PowerAssertionDriving {
    func create(type: CFString, name: CFString) throws -> IOPMAssertionID {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name,
            &assertionID
        )
        guard result == kIOReturnSuccess else {
            throw PowerAssertionError.createFailed(result)
        }
        return assertionID
    }

    func release(id: IOPMAssertionID) throws {
        let result = IOPMAssertionRelease(id)
        guard result == kIOReturnSuccess else {
            throw PowerAssertionError.releaseFailed(id, result)
        }
    }
}

public final class IOKitPowerAssertionManager: PowerAssertionManaging {
    private struct ActiveAssertion {
        let mode: WakeMode
        let id: IOPMAssertionID
    }

    private static let assertionName = "Mac Coffee active wake session"

    private let driver: PowerAssertionDriving
    private var activeAssertion: ActiveAssertion?
    private var pendingReleaseIDs: [IOPMAssertionID] = []

    public var activeMode: WakeMode { activeAssertion?.mode ?? .off }

    public convenience init() {
        self.init(driver: SystemPowerAssertionDriver())
    }

    init(driver: PowerAssertionDriving) {
        self.driver = driver
    }

    deinit {
        releaseAll()
    }

    public func transition(to mode: WakeMode) throws {
        guard mode != activeMode else { return }

        if mode == .off {
            try transitionToOff()
            return
        }

        let newID = try driver.create(
            type: assertionType(for: mode),
            name: Self.assertionName as CFString
        )
        let previous = activeAssertion
        activeAssertion = ActiveAssertion(mode: mode, id: newID)

        guard let previous else { return }
        do {
            try driver.release(id: previous.id)
        } catch {
            trackForRelease(previous.id)
            throw error
        }
    }

    public func releaseAll() {
        var ids = pendingReleaseIDs
        if let activeID = activeAssertion?.id, !ids.contains(activeID) {
            ids.append(activeID)
        }

        var failures: [IOPMAssertionID] = []
        for id in ids {
            do {
                try driver.release(id: id)
                if activeAssertion?.id == id {
                    activeAssertion = nil
                }
            } catch {
                failures.append(id)
            }
        }
        pendingReleaseIDs = failures.filter { $0 != activeAssertion?.id }
    }

    private func transitionToOff() throws {
        guard let activeAssertion else { return }
        try driver.release(id: activeAssertion.id)
        self.activeAssertion = nil
    }

    private func assertionType(for mode: WakeMode) -> CFString {
        switch mode {
        case .system:
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString
        case .display:
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
        case .off:
            preconditionFailure("Off has no assertion type")
        }
    }

    private func trackForRelease(_ id: IOPMAssertionID) {
        if !pendingReleaseIDs.contains(id) {
            pendingReleaseIDs.append(id)
        }
    }
}
