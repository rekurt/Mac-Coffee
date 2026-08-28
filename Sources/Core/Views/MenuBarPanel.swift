import AppKit
import SwiftUI

public struct MenuBarPanel: View {
    @ObservedObject private var model: AppModel
    private let updater: UpdaterProviding?
    @State private var showsQuitConfirmation = false

    public init(model: AppModel, updater: UpdaterProviding? = nil) {
        self.model = model
        self.updater = updater
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            ModePicker(model: model)

            VStack(alignment: .leading, spacing: 6) {
                Text("duration.title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DurationPicker(model: model)
            }

            statusCard

            if let statusMessage = model.statusMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(statusMessage)
                        .font(.caption)
                    Spacer(minLength: 0)
                    Button {
                        model.dismissStatus()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("action.dismiss"))
                }
                .padding(10)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityIdentifier("maccoffee.status.banner")
            }

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 340)
        .alert("action.quit", isPresented: $showsQuitConfirmation) {
            Button("action.cancel", role: .cancel) {}
            Button("action.confirmQuit", role: .destructive) {
                model.prepareForTermination()
                NSApplication.shared.terminate(nil)
            }
        } message: {
            Text("quit.message")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: model.mode.systemImage)
                .font(.title2)
                .symbolVariant(model.mode == .off ? .none : .fill)
                .foregroundStyle(model.mode == .off ? Color.secondary : Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("app.name").font(.headline)
                Text(model.mode == .off ? "status.off" : "status.active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isBusy {
                ProgressView().controlSize(.small)
            }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            Image(systemName: batterySymbol)
                .foregroundStyle(model.isBatteryBlocked ? .orange : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(batteryText)
                    .font(.callout)
                if model.mode != .off {
                    CountdownText(deadline: model.session?.expiresAt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
        .accessibilityIdentifier("maccoffee.status.card")
    }

    private var footer: some View {
        HStack(spacing: 14) {
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Text("action.settings")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("maccoffee.action.settings")
            } else {
                Button("action.settings", action: openLegacySettings)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("maccoffee.action.settings")
            }
            Button("action.about") {
                NSApplication.shared.orderFrontStandardAboutPanel(nil)
            }
            .buttonStyle(.plain)
            if let updater, updater.canCheckForUpdates {
                Button("action.checkUpdates") { updater.checkForUpdates() }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("maccoffee.action.update")
            }
            Spacer()
            Button("action.quit") { showsQuitConfirmation = true }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
                .accessibilityIdentifier("maccoffee.action.quit")
        }
        .font(.caption)
    }

    private var batteryText: String {
        guard model.batteryState.hasInternalBattery else {
            return String(localized: "battery.ac", bundle: .main)
        }
        guard let percentage = model.batteryState.percentage else {
            return String(localized: "battery.unknown", bundle: .main)
        }
        return String(format: String(localized: "battery.percent", bundle: .main), percentage)
    }

    private var batterySymbol: String {
        guard model.batteryState.hasInternalBattery else { return "powerplug.fill" }
        return model.batteryState.powerSource == .ac ? "battery.100.bolt" : "battery.50"
    }

    private func openLegacySettings() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
