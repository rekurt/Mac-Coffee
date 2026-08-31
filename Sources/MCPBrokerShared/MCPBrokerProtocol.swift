import Foundation

public enum MCPBrokerConstants {
  public static let serviceName = "com.rekurt.maccoffee.mcp-broker"
}

public enum MCPBrokerErrorCode: Int, Sendable {
  case appNotRunning = 1
  case unauthorized = 2
  case registrationConflict = 3
  case internalError = 4
}

public final class MCPBrokerXPCError: NSObject, NSSecureCoding, @unchecked Sendable {
  public static var supportsSecureCoding: Bool { true }

  public let code: MCPBrokerErrorCode

  public init(code: MCPBrokerErrorCode) {
    self.code = code
    super.init()
  }

  public required init?(coder: NSCoder) {
    guard let code = MCPBrokerErrorCode(rawValue: coder.decodeInteger(forKey: "code")) else {
      return nil
    }
    self.code = code
    super.init()
  }

  public func encode(with coder: NSCoder) {
    coder.encode(code.rawValue, forKey: "code")
  }
}

@objc public protocol MCPBrokerService {
  func registerAppEndpoint(
    _ endpoint: NSXPCListenerEndpoint,
    withReply reply: @escaping (MCPBrokerXPCError?) -> Void
  )

  func unregisterAppEndpoint(
    _ reply: @escaping (MCPBrokerXPCError?) -> Void
  )

  func currentAppEndpoint(
    _ reply: @escaping (NSXPCListenerEndpoint?, MCPBrokerXPCError?) -> Void
  )
}

public enum MCPBrokerInterfaces {
  public static func service() -> NSXPCInterface {
    NSXPCInterface(with: MCPBrokerService.self)
  }
}
