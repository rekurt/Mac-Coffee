import SwiftUI

public struct ModePicker: View {
    @ObservedObject private var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        Picker(
            "mode.title",
            selection: Binding(
                get: { model.mode },
                set: { try? model.setMode($0) }
            )
        ) {
            Label("mode.off", systemImage: "moon.zzz")
                .tag(WakeMode.off)
            Label("mode.system", systemImage: "bolt.circle")
                .tag(WakeMode.system)
            Label("mode.display", systemImage: "display")
                .tag(WakeMode.display)
        }
        .pickerStyle(.segmented)
        .disabled(model.isBusy)
        .accessibilityIdentifier("maccoffee.mode.picker")
        .accessibilityValue(Text(verbatim: model.mode.localizedTitle))
    }
}

public extension WakeMode {
    var localizedTitle: String {
        String(localized: String.LocalizationValue(localizationKey), bundle: .main)
    }

    var localizationKey: String {
        switch self {
        case .off: "mode.off"
        case .system: "mode.system"
        case .display: "mode.display"
        }
    }

    var systemImage: String {
        switch self {
        case .off: "moon.zzz"
        case .system: "bolt.circle"
        case .display: "display"
        }
    }
}
