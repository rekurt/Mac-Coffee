import SwiftUI

public struct MenuBarLabel: View {
    @ObservedObject private var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        Image(systemName: model.mode.systemImage)
            .symbolVariant(model.mode == .off ? .none : .fill)
            .accessibilityLabel(Text("app.name"))
            .accessibilityValue(Text(verbatim: model.mode.localizedTitle))
    }
}
