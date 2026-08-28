import SwiftUI

public struct DurationPicker: View {
    @ObservedObject private var model: AppModel
    @State private var selection: SessionDuration

    public init(model: AppModel) {
        self.model = model
        _selection = State(initialValue: model.selectedDuration)
    }

    public var body: some View {
        Picker(
            "duration.title",
            selection: $selection
        ) {
            ForEach(SessionDuration.allCases, id: \.self) { duration in
                Text(verbatim: duration.localizedTitle)
                    .tag(duration)
                    .accessibilityIdentifier("maccoffee.duration.\(duration.rawValue)")
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("maccoffee.duration.picker")
        .accessibilityValue(Text(verbatim: model.selectedDuration.localizedTitle))
        .onChange(of: selection) { duration in
            Task { @MainActor in
                model.selectDuration(duration)
                selection = model.selectedDuration
            }
        }
        .onChange(of: model.selectedDuration) { duration in
            selection = duration
        }
    }
}

public extension SessionDuration {
    var localizedTitle: String {
        String(localized: String.LocalizationValue(localizationKey), bundle: .main)
    }

    var localizationKey: String {
        switch self {
        case .minutes30: "duration.minutes30"
        case .hours1: "duration.hours1"
        case .hours2: "duration.hours2"
        case .hours4: "duration.hours4"
        case .hours8: "duration.hours8"
        case .indefinite: "duration.indefinite"
        }
    }
}
