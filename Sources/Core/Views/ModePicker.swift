import SwiftUI

public struct ModePicker: View {
    @ObservedObject private var model: AppModel
    @State private var selection: WakeMode

    public init(model: AppModel) {
        self.model = model
        _selection = State(initialValue: model.mode)
    }

    public var body: some View {
        Picker(
            "mode.title",
            selection: $selection
        ) {
            Label("mode.off", systemImage: "moon.zzz")
                .tag(WakeMode.off)
                .accessibilityIdentifier("maccoffee.mode.off")
            Label("mode.system", systemImage: "bolt.circle")
                .tag(WakeMode.system)
                .accessibilityIdentifier("maccoffee.mode.system")
            Label("mode.display", systemImage: "display")
                .tag(WakeMode.display)
                .accessibilityIdentifier("maccoffee.mode.display")
        }
        .pickerStyle(.segmented)
        .disabled(model.isBusy)
        .accessibilityIdentifier("maccoffee.mode.picker")
        .accessibilityValue(Text(verbatim: model.mode.localizedTitle))
        .onChange(of: selection) { mode in
            Task { @MainActor in
                try? model.setMode(mode)
                selection = model.mode
            }
        }
        .onChange(of: model.mode) { mode in
            selection = mode
        }
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
