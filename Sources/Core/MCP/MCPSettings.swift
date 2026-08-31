import Combine
import Foundation

@MainActor
public final class MCPSettings: ObservableObject {
    @Published public private(set) var isEnabled: Bool

    private let store: SettingsStoring

    public init(store: SettingsStoring) {
        self.store = store
        isEnabled = store.mcpEnabled
    }

    public func setEnabled(_ enabled: Bool) {
        store.mcpEnabled = enabled
        isEnabled = enabled
    }
}
