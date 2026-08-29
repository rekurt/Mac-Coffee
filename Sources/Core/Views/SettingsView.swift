import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var model: AppModel
    @ObservedObject private var localization: LocalizationController

    public init(model: AppModel) {
        self.model = model
        _localization = ObservedObject(wrappedValue: model.environment.localization)
    }

    public var body: some View {
        Form {
            Section {
                Picker(
                    "settings.language",
                    selection: Binding(
                        get: { localization.selectedLanguage },
                        set: { localization.select($0) }
                    )
                ) {
                    ForEach(SupportedLanguage.allCases, id: \.self) { language in
                        Text(verbatim: language.localizedName(using: localization))
                            .tag(language)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityIdentifier("maccoffee.settings.language")

                Text("settings.language.help")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("settings.language")
            }

            if model.batteryState.hasInternalBattery {
                Section {
                    HStack {
                        Text("settings.batteryThreshold")
                        Spacer()
                        Stepper(
                            value: Binding(
                                get: { model.batteryThreshold },
                                set: { threshold in model.setBatteryThreshold(threshold) }
                            ),
                            in: LowBatteryPolicy.thresholdRange
                        ) {
                            Text(verbatim: localization.format(
                                "settings.batteryThresholdValue",
                                arguments: model.batteryThreshold
                            ))
                                .monospacedDigit()
                        }
                        .accessibilityIdentifier("maccoffee.settings.batteryThreshold")
                    }
                    Text("settings.batteryHelp")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle(
                    "settings.launchAtLogin",
                    isOn: Binding(
                        get: { model.launchAtLoginStatus == .enabled },
                        set: { try? model.setLaunchAtLogin($0) }
                    )
                )
                .disabled(model.launchAtLoginStatus == .unavailable)
                .accessibilityIdentifier("maccoffee.settings.launchAtLogin")

                if model.launchAtLoginStatus == .requiresApproval {
                    Text("settings.launchRequiresApproval")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if model.launchAtLoginStatus == .unavailable {
                    Text("settings.launchUnavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 480)
        .fixedSize(horizontal: false, vertical: true)
        .navigationTitle(Text("settings.title"))
    }
}

private extension SupportedLanguage {
    @MainActor
    func localizedName(using localization: LocalizationController) -> String {
        switch self {
        case .system:
            localization.localized("settings.language.system")
        default:
            displayName
        }
    }
}
