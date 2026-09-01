import Foundation
import XCTest

@testable import MacCoffeeCore

final class MCPBrokerTests: XCTestCase {
  func testHelperCannotReadEndpointBeforeAppRegisters() {
    let registry = MCPBrokerRegistry()

    XCTAssertThrowsError(
      try registry.currentEndpoint(requesterRole: .helper)
    ) { error in
      XCTAssertEqual(error as? MCPBrokerRegistryError, .appNotRunning)
    }
  }

  func testOnlyAppCanRegisterAndOnlyHelperCanReadEndpoint() throws {
    let registry = MCPBrokerRegistry()
    let listener = NSXPCListener.anonymous()
    let endpoint = listener.endpoint

    XCTAssertThrowsError(
      try registry.register(
        endpoint: endpoint,
        connectionIdentifier: UUID(),
        requesterRole: .helper
      )
    ) { error in
      XCTAssertEqual(error as? MCPBrokerRegistryError, .unauthorized)
    }

    let appConnection = UUID()
    try registry.register(
      endpoint: endpoint,
      connectionIdentifier: appConnection,
      requesterRole: .app
    )
    XCTAssertNotNil(try registry.currentEndpoint(requesterRole: .helper))
    XCTAssertThrowsError(try registry.currentEndpoint(requesterRole: .app)) {
      error in
      XCTAssertEqual(error as? MCPBrokerRegistryError, .unauthorized)
    }
  }

  func testSecondAppConnectionCannotReplaceLiveRegistration() throws {
    let registry = MCPBrokerRegistry()
    let firstListener = NSXPCListener.anonymous()
    let secondListener = NSXPCListener.anonymous()
    try registry.register(
      endpoint: firstListener.endpoint,
      connectionIdentifier: UUID(),
      requesterRole: .app
    )

    XCTAssertThrowsError(
      try registry.register(
        endpoint: secondListener.endpoint,
        connectionIdentifier: UUID(),
        requesterRole: .app
      )
    ) { error in
      XCTAssertEqual(error as? MCPBrokerRegistryError, .registrationConflict)
    }
  }

  func testAppConnectionInvalidationClearsOnlyItsOwnEndpoint() throws {
    let registry = MCPBrokerRegistry()
    let owner = UUID()
    let unrelated = UUID()
    let listener = NSXPCListener.anonymous()
    try registry.register(
      endpoint: listener.endpoint,
      connectionIdentifier: owner,
      requesterRole: .app
    )

    registry.connectionInvalidated(unrelated)
    XCTAssertNotNil(try registry.currentEndpoint(requesterRole: .helper))

    registry.connectionInvalidated(owner)
    XCTAssertThrowsError(
      try registry.currentEndpoint(requesterRole: .helper)
    ) { error in
      XCTAssertEqual(error as? MCPBrokerRegistryError, .appNotRunning)
    }
  }

  func testExplicitUnregisterRequiresOwningAppConnection() throws {
    let registry = MCPBrokerRegistry()
    let owner = UUID()
    let listener = NSXPCListener.anonymous()
    try registry.register(
      endpoint: listener.endpoint,
      connectionIdentifier: owner,
      requesterRole: .app
    )

    XCTAssertThrowsError(
      try registry.unregister(
        connectionIdentifier: UUID(),
        requesterRole: .app
      )
    ) { error in
      XCTAssertEqual(error as? MCPBrokerRegistryError, .unauthorized)
    }

    try registry.unregister(
      connectionIdentifier: owner,
      requesterRole: .app
    )
    XCTAssertThrowsError(
      try registry.currentEndpoint(requesterRole: .helper)
    )
  }

  func testRegistrarAndProviderTransferLiveEndpointOverRealXPC() async throws {
    let roles = BrokerRoleQueue([.app, .helper, .helper])
    let delegate = MCPBrokerListenerDelegate { _ in roles.next() }
    let brokerListener = NSXPCListener.anonymous()
    brokerListener.delegate = delegate
    brokerListener.activate()
    defer { brokerListener.invalidate() }

    let registrar = MCPBrokerRegistrar {
      NSXPCConnection(listenerEndpoint: brokerListener.endpoint)
    }
    let provider = MCPBrokerEndpointProvider {
      NSXPCConnection(listenerEndpoint: brokerListener.endpoint)
    }
    let appListener = NSXPCListener.anonymous()

    try await registrar.register(appListener.endpoint)
    let transferredEndpoint = try await provider.currentEndpoint()
    XCTAssertNotNil(transferredEndpoint)

    await registrar.unregister()
    do {
      _ = try await provider.currentEndpoint()
      XCTFail("Expected the broker to clear the endpoint")
    } catch let error as MCPXPCClientError {
      XCTAssertEqual(error, .appNotRunning)
    }
  }
}

private final class BrokerRoleQueue: @unchecked Sendable {
  private let lock = NSLock()
  private var roles: [MCPBrokerPeerRole]

  init(_ roles: [MCPBrokerPeerRole]) {
    self.roles = roles
  }

  func next() -> MCPBrokerPeerRole? {
    lock.withLock {
      guard !roles.isEmpty else { return nil }
      return roles.removeFirst()
    }
  }
}
