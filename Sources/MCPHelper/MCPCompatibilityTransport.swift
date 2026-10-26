import Foundation
import Logging
import MCP

/// Adapts standard experimental capabilities to the pinned Swift MCP SDK.
actor MCPCompatibilityTransport: Transport {
  nonisolated let logger: Logger
  private let transport: StdioTransport

  init(transport: StdioTransport = StdioTransport()) {
    self.transport = transport
    self.logger = transport.logger
  }

  func connect() async throws {
    try await transport.connect()
  }

  func disconnect() async {
    await transport.disconnect()
  }

  func send(_ data: Data) async throws {
    try await transport.send(data)
  }

  func receive() -> AsyncThrowingStream<Data, Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          for try await data in await transport.receive() {
            continuation.yield(Self.adaptInitialize(data))
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  private static func adaptInitialize(_ data: Data) -> Data {
    guard var message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      message["method"] as? String == "initialize",
      var params = message["params"] as? [String: Any],
      var capabilities = params["capabilities"] as? [String: Any],
      let experimental = capabilities["experimental"] as? [String: Any]
    else {
      return data
    }

    // SDK 0.12.1 decodes experimental as [String: String], but MCP defines
    // object values. Mac Coffee implements no experimental client features,
    // so ignore those declarations without changing standard capabilities or
    // relaxing SDK validation of malformed fields and non-initialize traffic.
    let supported = experimental.filter { !($0.value is [String: Any]) }
    guard supported.count != experimental.count else { return data }
    capabilities["experimental"] = supported
    params["capabilities"] = capabilities
    message["params"] = params
    return (try? JSONSerialization.data(withJSONObject: message)) ?? data
  }
}
