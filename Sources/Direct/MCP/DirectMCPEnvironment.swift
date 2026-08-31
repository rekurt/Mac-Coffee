import Combine
import Darwin
import Foundation
import MacCoffeeCore

@MainActor
protocol MCPListenerLifecycle: AnyObject {
  func start() -> NSXPCListenerEndpoint
  func stop(reason: MCPXPCCloseReason)
  func closeConnections(clientIdentifier: String, reason: MCPXPCCloseReason)
}

extension MCPXPCListener: MCPListenerLifecycle {}

@MainActor
protocol MCPBrokerRegistration: AnyObject {
  func register(_ endpoint: NSXPCListenerEndpoint) async throws
  func unregister() async
}

extension MCPBrokerRegistrar: MCPBrokerRegistration {}

@MainActor
final class DirectMCPEnvironment: ObservableObject {
  enum ConnectionState: Equatable, Sendable {
    case disabled
    case starting
    case ready
    case failed
  }

  let model: AppModel
  let settings: MCPSettings
  let trustStore: MCPTrustStore
  let pairingCoordinator: MCPPairingCoordinator
  let controlService: MCPControlService

  @Published private(set) var connectionState: ConnectionState = .disabled

  private let listener: MCPListenerLifecycle
  private let broker: MCPBrokerRegistration
  private var lifecycleTask: Task<Void, Never>?
  private var lifecycleGeneration: UInt64 = 0
  private var isTerminating = false

  init(
    model: AppModel,
    settings: MCPSettings,
    trustStore: MCPTrustStore,
    pairingCoordinator: MCPPairingCoordinator,
    controlService: MCPControlService,
    listener: MCPListenerLifecycle,
    broker: MCPBrokerRegistration
  ) {
    self.model = model
    self.settings = settings
    self.trustStore = trustStore
    self.pairingCoordinator = pairingCoordinator
    self.controlService = controlService
    self.listener = listener
    self.broker = broker
  }

  static func live(
    model: AppModel,
    settingsStore: MCPSettingsStoring
  ) -> DirectMCPEnvironment {
    let trustStore = MCPTrustStore(
      credentials: KeychainMCPCredentialStore()
    )
    let pairingCoordinator = MCPPairingCoordinator(
      trustStore: trustStore,
      nonceGenerator: SecurityRandomNonceGenerator(),
      signatureVerifier: MCPP256SignatureVerifier()
    )
    let controlService = MCPControlService(model: model)
    let listener = MCPXPCListener(
      pairingCoordinator: pairingCoordinator,
      controlService: controlService,
      connectionValidator: { connection in
        connection.effectiveUserIdentifier == geteuid()
      }
    )
    return DirectMCPEnvironment(
      model: model,
      settings: MCPSettings(store: settingsStore),
      trustStore: trustStore,
      pairingCoordinator: pairingCoordinator,
      controlService: controlService,
      listener: listener,
      broker: MCPBrokerRegistrar()
    )
  }

  func startIfEnabled() {
    guard settings.isEnabled else {
      connectionState = .disabled
      return
    }
    enable()
  }

  func setEnabled(_ enabled: Bool) {
    guard !isTerminating else { return }
    settings.setEnabled(enabled)
    if enabled {
      enable()
    } else {
      disable(reason: .integrationDisabled)
    }
  }

  func prepareForTermination() {
    guard !isTerminating else { return }
    isTerminating = true
    advanceGeneration()
    listener.stop(reason: .appTermination)
    connectionState = .disabled
    enqueue { [weak self] in
      await self?.broker.unregister()
    }
  }

  func closeConnections(
    clientIdentifier: String,
    reason: MCPXPCCloseReason
  ) {
    listener.closeConnections(
      clientIdentifier: clientIdentifier,
      reason: reason
    )
  }

  func waitForIdle() async {
    let generation = lifecycleGeneration
    await lifecycleTask?.value
    if generation != lifecycleGeneration {
      await waitForIdle()
    }
  }

  private func enable() {
    let generation = advanceGeneration()
    let endpoint = listener.start()
    connectionState = .starting
    enqueue { [weak self] in
      guard let self else { return }
      do {
        try await broker.register(endpoint)
        guard
          generation == lifecycleGeneration,
          settings.isEnabled,
          !isTerminating
        else {
          await broker.unregister()
          return
        }
        connectionState = .ready
      } catch {
        guard generation == lifecycleGeneration, !isTerminating else { return }
        listener.stop(reason: .integrationDisabled)
        connectionState = .failed
      }
    }
  }

  private func disable(reason: MCPXPCCloseReason) {
    advanceGeneration()
    listener.stop(reason: reason)
    connectionState = .disabled
    enqueue { [weak self] in
      await self?.broker.unregister()
    }
  }

  @discardableResult
  private func advanceGeneration() -> UInt64 {
    lifecycleGeneration =
      lifecycleGeneration == .max
      ? 1
      : lifecycleGeneration + 1
    return lifecycleGeneration
  }

  private func enqueue(
    _ operation: @escaping @MainActor () async -> Void
  ) {
    let previous = lifecycleTask
    lifecycleTask = Task { @MainActor in
      await previous?.value
      await operation()
    }
  }
}
