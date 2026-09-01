import Foundation

public enum MCPBrokerRegistrarError: Error, Equatable, Sendable {
  case unavailable
  case unauthorized
  case registrationConflict
  case internalError
}

public final class MCPBrokerRegistrar: @unchecked Sendable {
  public typealias ConnectionFactory = () -> NSXPCConnection

  private let connectionFactory: ConnectionFactory
  private let lock = NSLock()
  private var registration: (token: UUID, connection: NSXPCConnection)?

  public init(
    connectionFactory: @escaping ConnectionFactory = {
      NSXPCConnection(serviceName: MCPBrokerConstants.serviceName)
    }
  ) {
    self.connectionFactory = connectionFactory
  }

  public func register(_ endpoint: NSXPCListenerEndpoint) async throws {
    await unregister()

    let connection = connectionFactory()
    let token = UUID()
    connection.remoteObjectInterface = MCPBrokerInterfaces.service()
    connection.invalidationHandler = { [weak self] in
      self?.clearRegistration(token: token)
    }
    connection.interruptionHandler = { [weak self] in
      self?.clearRegistration(token: token)
    }
    lock.withLock {
      registration = (token, connection)
    }
    connection.activate()
    do {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, any Error>) in
        let gate = MCPBrokerReplyGate(continuation)
        DispatchQueue.global(qos: .utility).asyncAfter(
          deadline: .now() + 5
        ) {
          gate.resolve(.failure(MCPBrokerRegistrarError.unavailable))
        }
        guard
          let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
            gate.resolve(.failure(MCPBrokerRegistrarError.unavailable))
          }) as? MCPBrokerService
        else {
          gate.resolve(.failure(MCPBrokerRegistrarError.unavailable))
          return
        }
        proxy.registerAppEndpoint(endpoint) { error in
          if let error {
            gate.resolve(.failure(Self.map(error.code)))
          } else {
            gate.resolve(.success(()))
          }
        }
      }
    } catch {
      clearRegistration(token: token)
      connection.invalidate()
      throw error
    }
  }

  public func unregister() async {
    let registration = lock.withLock {
      let registration = self.registration
      self.registration = nil
      return registration
    }
    guard let connection = registration?.connection else { return }

    _ = try? await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, any Error>) in
      let gate = MCPBrokerReplyGate(continuation)
      DispatchQueue.global(qos: .utility).asyncAfter(
        deadline: .now() + 0.5
      ) {
        gate.resolve(.success(()))
      }
      guard
        let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
          gate.resolve(.success(()))
        }) as? MCPBrokerService
      else {
        gate.resolve(.success(()))
        return
      }
      proxy.unregisterAppEndpoint { _ in gate.resolve(.success(())) }
    }
    connection.invalidate()
  }

  private func clearRegistration(token: UUID) {
    lock.withLock {
      if registration?.token == token {
        registration = nil
      }
    }
  }

  private static func map(_ code: MCPBrokerErrorCode) -> MCPBrokerRegistrarError {
    switch code {
    case .appNotRunning:
      .unavailable
    case .unauthorized:
      .unauthorized
    case .registrationConflict:
      .registrationConflict
    case .internalError:
      .internalError
    }
  }
}
