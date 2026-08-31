import Foundation

@MainActor
public protocol MCPControlServicing: AnyObject {
    func execute(_ command: MCPCommand) throws -> MCPEnvelope<MCPStatusSnapshot>
}
