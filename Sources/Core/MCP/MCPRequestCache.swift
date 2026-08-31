import Foundation

public enum MCPCachedCommandResult: Equatable, Sendable {
    case success(MCPEnvelope<MCPStatusSnapshot>)
    case failure(MCPServiceError)

    var activityOutcome: MCPActivityOutcome {
        switch self {
        case .success:
            .success
        case let .failure(error):
            .failure(error.code)
        }
    }
}

@MainActor
public final class MCPRequestCache {
    private struct Key: Hashable {
        let clientIdentifier: String
        let requestID: String
    }

    private let capacity: Int
    private var values: [Key: MCPCachedCommandResult] = [:]
    private var insertionOrder: [Key] = []

    public init(capacity: Int = 200) {
        self.capacity = max(1, capacity)
    }

    public func result(
        clientIdentifier: String,
        requestID: String
    ) -> MCPCachedCommandResult? {
        values[Key(clientIdentifier: clientIdentifier, requestID: requestID)]
    }

    public func insert(
        _ result: MCPCachedCommandResult,
        clientIdentifier: String,
        requestID: String
    ) {
        let key = Key(clientIdentifier: clientIdentifier, requestID: requestID)
        guard values[key] == nil else { return }

        values[key] = result
        insertionOrder.append(key)
        if insertionOrder.count > capacity {
            let evicted = insertionOrder.removeFirst()
            values.removeValue(forKey: evicted)
        }
    }
}
