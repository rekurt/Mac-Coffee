import SwiftUI

public struct ModePicker: View {
    @ObservedObject private var model: AppModel
    @ObservedObject private var localization: LocalizationController
    @State private var selection: WakeMode

    public init(model: AppModel) {
        self.model = model
        _localization = ObservedObject(wrappedValue: model.environment.localization)
        _selection = State(initialValue: model.mode)
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            picker
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 8) {
                Text("mode.title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                picker
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                Text(selection.localizedSubtitle(using: localization))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(model.isBusy)
        .accessibilityIdentifier("maccoffee.mode.picker")
        .accessibilityValue(Text(verbatim: localization.format(
            "accessibility.modeValue",
            arguments: model.mode.localizedTitle(using: localization)
        )))
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

    private var picker: some View {
        Picker("mode.title", selection: $selection) {
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
    }
}

public extension WakeMode {
    @MainActor
    func localizedTitle(using localization: LocalizationController) -> String {
        localization.localized(localizationKey)
    }

    @MainActor
    func localizedSubtitle(using localization: LocalizationController) -> String {
        localization.localized("\(localizationKey).subtitle")
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
