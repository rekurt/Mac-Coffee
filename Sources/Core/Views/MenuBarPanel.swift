import AppKit
import SwiftUI

/// Supplies one runtime-selected locale to an entire SwiftUI root.
public struct LocalizedRootView<Content: View>: View {
    @ObservedObject private var localization: LocalizationController
    private let content: Content

    public init(
        localization: LocalizationController,
        @ViewBuilder content: () -> Content
    ) {
        _localization = ObservedObject(wrappedValue: localization)
        self.content = content()
    }

    public var body: some View {
        content.environment(\.locale, localization.locale)
    }
}

public struct MenuBarPanel: View {
    @ObservedObject private var model: AppModel
    @ObservedObject private var localization: LocalizationController
    private let updater: UpdaterProviding?
    @State private var showsQuitConfirmation = false

    public init(model: AppModel, updater: UpdaterProviding? = nil) {
        self.model = model
        _localization = ObservedObject(wrappedValue: model.environment.localization)
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
        .frame(minWidth: 0, idealWidth: 420, maxWidth: 420)
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
        ViewThatFits(in: .horizontal) {
            horizontalFooter
                .fixedSize(horizontal: true, vertical: false)
            compactFooter
        }
        .font(.caption)
    }

    private var horizontalFooter: some View {
        HStack(spacing: 14) {
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Text("action.settings")
                }
                .buttonStyle(.plain)
                .frame(minWidth: 70)
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
    }

    private var compactFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                if #available(macOS 14.0, *) {
                    SettingsLink { Text("action.settings") }
                        .buttonStyle(.plain)
                        .frame(minWidth: 70)
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
            }
            Button("action.quit") { showsQuitConfirmation = true }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
                .accessibilityIdentifier("maccoffee.action.quit")
        }
    }

    private var batteryText: String {
        guard model.batteryState.hasInternalBattery else {
            return localization.localized("battery.ac")
        }
        guard let percentage = model.batteryState.percentage else {
            return localization.localized("battery.unknown")
        }
        return localization.format("battery.percent", arguments: percentage)
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
