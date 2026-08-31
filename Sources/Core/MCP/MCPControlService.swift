import Foundation

@MainActor
public final class MCPControlService: MCPControlServicing {
    private let model: AppModel
    private let snapshotFactory: MCPSnapshotFactory

    public init(
        model: AppModel,
        now: @escaping () -> Date = Date.init
    ) {
        self.model = model
        snapshotFactory = MCPSnapshotFactory(
            localization: model.environment.localization,
            now: now
        )
    }

    public func execute(_ command: MCPCommand) throws -> MCPEnvelope<MCPStatusSnapshot> {
        if model.isBusy, command.isMutating {
            throw MCPServiceError(code: .appBusy)
        }

        do {
            switch command {
            case .getStatus:
                break

            case let .setSession(mode, duration, _):
                guard mode != .off else {
                    throw MCPServiceError.invalidArgument(field: "mode")
                }
                try model.applySession(mode: mode, duration: duration)

            case .stopSession:
                try model.stopSession()

            case let .setBatteryThreshold(percent, _):
                guard LowBatteryPolicy.thresholdRange.contains(percent) else {
                    throw MCPServiceError.invalidArgument(field: "percent")
                }
                model.setBatteryThreshold(percent)

            case let .setLaunchAtLogin(enabled, _):
                try model.setLaunchAtLogin(enabled)

            case let .setLanguage(language, _):
                model.environment.localization.select(language)
            }
        } catch let error as MCPServiceError {
            throw error
        } catch let error as AppModelError {
            switch error {
            case .batteryBlocked:
                throw MCPServiceError(code: .batteryBlocked)
            case .invalidWakeMode:
                throw MCPServiceError.invalidArgument(field: "mode")
            }
        } catch {
            if model.statusNotice == .powerAssertionFailed {
                throw MCPServiceError(code: .assertionFailed)
            }
            throw MCPServiceError(code: .internalError)
        }

        return snapshotFactory.makeStatus(
            from: model,
            requestID: command.requestID
        )
    }
}

private extension MCPCommand {
    var isMutating: Bool {
        if case .getStatus = self { return false }
        return true
    }
}
