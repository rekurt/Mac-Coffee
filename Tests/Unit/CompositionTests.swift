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

    func testFooterLayoutLeavesNilPanelWidthUnconstrainedForViewThatFits() {
        XCTAssertEqual(FooterLayoutMetrics.panelMaximumWidth(panelWidth: nil), 420)
        XCTAssertEqual(FooterLayoutMetrics.panelMaximumWidth(panelWidth: 280), 280)
        XCTAssertNil(FooterLayoutMetrics.footerMaximumWidth(panelWidth: nil))
        XCTAssertEqual(FooterLayoutMetrics.footerMaximumWidth(panelWidth: 280), 280)
        XCTAssertEqual(FooterLayoutMetrics.gridMinimumWidth, 388)
    }

    func testMCPStartsDisabledAndUsesTheExistingAppModel() async {
        let system = makeMCPSystem(enabled: false)

        system.mcp.startIfEnabled()
        await system.mcp.waitForIdle()

        XCTAssertTrue(system.mcp.model === system.model)
        XCTAssertEqual(system.mcp.connectionState, .disabled)
        XCTAssertEqual(system.listener.startCount, 0)
        XCTAssertEqual(system.broker.registerCount, 0)
    }

    func testEnablingMCPStartsListenerAndRegistersItsEndpoint() async {
        let system = makeMCPSystem(enabled: false)

        system.mcp.setEnabled(true)
        await system.mcp.waitForIdle()

        XCTAssertTrue(system.settings.mcpEnabled)
        XCTAssertEqual(system.listener.startCount, 1)
        XCTAssertEqual(system.broker.registerCount, 1)
        XCTAssertEqual(system.mcp.connectionState, .ready)
    }

    func testDisablingMCPClosesConnectionsBeforeUnregisteringEndpoint() async {
        let events = EventLog()
        let system = makeMCPSystem(enabled: true, events: events)
        system.mcp.startIfEnabled()
        await system.mcp.waitForIdle()

        events.values.removeAll()
        system.mcp.setEnabled(false)

        XCTAssertEqual(events.values, ["listener.integrationDisabled"])
        await system.mcp.waitForIdle()
        XCTAssertEqual(
            events.values,
            ["listener.integrationDisabled", "broker.unregister"]
        )
        XCTAssertEqual(system.mcp.connectionState, .disabled)
    }

    func testTerminationStopsMCPBeforePowerAssertionsAreReleased() async throws {
        let events = EventLog()
        let system = makeMCPSystem(enabled: true, events: events)
        system.environment.termination.register { [weak mcp = system.mcp] in
            mcp?.prepareForTermination()
        }
        system.power.onReleaseAll = { events.values.append("assertions.release") }
        system.mcp.startIfEnabled()
        await system.mcp.waitForIdle()
        events.values.removeAll()
        try system.model.setMode(.system)

        system.model.prepareForTermination()

        XCTAssertEqual(
            Array(events.values.prefix(2)),
            ["listener.appTermination", "assertions.release"]
        )
        await system.mcp.waitForIdle()
        XCTAssertEqual(events.values.last, "broker.unregister")
    }

    func testBrokerFailureDoesNotAlterTheActiveWakeSession() async throws {
        let system = makeMCPSystem(enabled: false)
        system.broker.registerError = TestMCPError.unavailable
        system.model.selectDuration(.hours2)
        try system.model.setMode(.display)
        let originalSession = system.model.session

        system.mcp.setEnabled(true)
        await system.mcp.waitForIdle()

        XCTAssertEqual(system.mcp.connectionState, .failed)
        XCTAssertEqual(system.model.mode, .display)
        XCTAssertEqual(system.model.session, originalSession)
        XCTAssertEqual(system.power.transitions, [.display])
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

    private func makeMCPSystem(
        enabled: Bool,
        events: EventLog = EventLog()
    ) -> MCPCompositionSystem {
        let settings = FakeSettingsStore(mcpEnabled: enabled)
        let power = FakePowerAssertionManager()
        let environment = AppEnvironment(
            powerAssertions: power,
            battery: FakeBatteryMonitor(),
            scheduler: FakeSessionScheduler(),
            settings: settings,
            launchAtLogin: FakeLaunchAtLoginManager(),
            notifications: FakeNotificationSender(),
            lifecycle: FakeLifecycleObserver()
        )
        let model = AppModel(environment: environment)
        let trustStore = MCPTrustStore(credentials: FakeMCPCredentialStore())
        let pairing = MCPPairingCoordinator(
            trustStore: trustStore,
            nonceGenerator: CompositionNonceGenerator(),
            signatureVerifier: MCPP256SignatureVerifier()
        )
        let listener = FakeMCPListener(events: events)
        let broker = FakeMCPBroker(events: events)
        let mcp = DirectMCPEnvironment(
            model: model,
            settings: MCPSettings(store: settings),
            trustStore: trustStore,
            pairingCoordinator: pairing,
            controlService: MCPControlService(model: model),
            listener: listener,
            broker: broker
        )
        return MCPCompositionSystem(
            environment: environment,
            model: model,
            settings: settings,
            power: power,
            listener: listener,
            broker: broker,
            mcp: mcp
        )
    }
}

@MainActor
private struct MCPCompositionSystem {
    let environment: AppEnvironment
    let model: AppModel
    let settings: FakeSettingsStore
    let power: FakePowerAssertionManager
    let listener: FakeMCPListener
    let broker: FakeMCPBroker
    let mcp: DirectMCPEnvironment
}

private final class EventLog {
    var values: [String] = []
}

private enum TestMCPError: Error {
    case unavailable
}

private final class CompositionNonceGenerator: MCPNonceGenerating {
    func nextNonce(byteCount: Int) throws -> Data {
        Data(repeating: 7, count: byteCount)
    }
}

@MainActor
private final class FakeMCPListener: MCPListenerLifecycle {
    private let listener = NSXPCListener.anonymous()
    private let events: EventLog
    private(set) var startCount = 0

    init(events: EventLog) {
        self.events = events
    }

    func start() -> NSXPCListenerEndpoint {
        startCount += 1
        return listener.endpoint
    }

    func stop(reason: MCPXPCCloseReason) {
        events.values.append("listener.\(reason.rawValue)")
    }

    func closeConnections(clientIdentifier: String, reason: MCPXPCCloseReason) {}
}

@MainActor
private final class FakeMCPBroker: MCPBrokerRegistration {
    private let events: EventLog
    var registerError: Error?
    private(set) var registerCount = 0

    init(events: EventLog) {
        self.events = events
    }

    func register(_ endpoint: NSXPCListenerEndpoint) async throws {
        registerCount += 1
        if let registerError { throw registerError }
        events.values.append("broker.register")
    }

    func unregister() async {
        events.values.append("broker.unregister")
    }
}

@MainActor
private final class FakeUpdater: UpdaterProviding {
    var canCheckForUpdates = true
    func checkForUpdates() {}
}
