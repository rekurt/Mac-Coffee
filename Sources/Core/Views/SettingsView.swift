import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        Form {
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
                            Text(
                                String(
                                    format: String(localized: "settings.batteryThresholdValue", bundle: .main),
                                    model.batteryThreshold
                                )
                            )
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
        .frame(width: 440, height: model.batteryState.hasInternalBattery ? 260 : 170)
        .navigationTitle(Text("settings.title"))
    }
}
