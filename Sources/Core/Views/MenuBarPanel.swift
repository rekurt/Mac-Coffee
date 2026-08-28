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
    @Environment(\.openWindow) private var openWindow
    private let updater: UpdaterProviding?
    private let panelWidth: CGFloat?
    @State private var showsQuitConfirmation = false

    public init(model: AppModel, updater: UpdaterProviding? = nil, panelWidth: CGFloat? = nil) {
        self.model = model
        _localization = ObservedObject(wrappedValue: model.environment.localization)
        self.updater = updater
        self.panelWidth = panelWidth
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            ModePicker(model: model)
                .frame(width: panelWidth)

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
        // A deterministic UI-test host supplies an explicit panel width. Keep all
        // three constraints equal in that case so the hosted AppKit window and
        // SwiftUI content report the same geometry. Production remains flexible.
        .frame(
            minWidth: panelWidth ?? 0,
            idealWidth: panelWidth ?? 420,
            maxWidth: panelWidth ?? 420
        )
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
                    CountdownText(deadline: model.session?.expiresAt, localization: localization)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
        .overlay(alignment: .topLeading) {
            uiTestSessionMarker
        }
        .accessibilityIdentifier("maccoffee.status.card")
    }

    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            actionGrid
                .frame(width: 388)
            actionList
        }
        .frame(width: footerWidth, alignment: .leading)
        .font(.caption)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("maccoffee.footer")
    }

    private var footerWidth: CGFloat {
        max((panelWidth ?? 420) - 32, 0)
    }

    private var actionGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                settingsAction
                    .frame(maxWidth: .infinity)
                aboutAction
                    .frame(maxWidth: .infinity)
            }
            if hasUpdateAction {
                HStack(spacing: 8) {
                    updateAction
                        .frame(maxWidth: .infinity)
                    quitAction
                        .frame(maxWidth: .infinity)
                }
            } else {
                quitAction
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("maccoffee.footer.grid")
        .background(footerLayoutMarker("maccoffee.footer.grid"))
    }

    private var actionList: some View {
        VStack(spacing: 8) {
            settingsAction
            aboutAction
            if hasUpdateAction {
                updateAction
            }
            quitAction
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("maccoffee.footer.list")
        .background(footerLayoutMarker("maccoffee.footer.list"))
    }

    private var hasUpdateAction: Bool {
        if updater?.canCheckForUpdates == true {
            return true
        }
#if DEBUG
        // Sparkle has no feed in the deterministic host. Expose the real Direct
        // action there so UI tests can verify the four-action production layout.
        return updater != nil && CommandLine.arguments.contains("--ui-testing-force-update-action")
#else
        return false
#endif
    }

    @ViewBuilder
    private var settingsAction: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                FooterActionLabel(title: "action.settings", symbol: "gearshape")
            }
            .buttonStyle(FooterActionButtonStyle())
            .accessibilityIdentifier("maccoffee.action.settings")
        } else {
            Button(action: openLegacySettings) {
                FooterActionLabel(title: "action.settings", symbol: "gearshape")
            }
            .buttonStyle(FooterActionButtonStyle())
            .accessibilityIdentifier("maccoffee.action.settings")
        }
    }

    private var aboutAction: some View {
        Button {
            openWindow(id: "maccoffee.about")
        } label: {
            FooterActionLabel(title: "action.about", symbol: "info.circle")
        }
        .buttonStyle(FooterActionButtonStyle())
        .accessibilityIdentifier("maccoffee.action.about")
    }

    private var updateAction: some View {
        Button {
            updater?.checkForUpdates()
        } label: {
            FooterActionLabel(title: "action.checkUpdates", symbol: "arrow.triangle.2.circlepath")
        }
        .buttonStyle(FooterActionButtonStyle())
        .accessibilityIdentifier("maccoffee.action.update")
    }

    private var quitAction: some View {
        Button {
            showsQuitConfirmation = true
        } label: {
            FooterActionLabel(title: "action.quit", symbol: "power", isDestructive: true)
        }
        .buttonStyle(FooterActionButtonStyle())
        .keyboardShortcut("q")
        .accessibilityIdentifier("maccoffee.action.quit")
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

    /// Gives UI automation a frame-bearing layout node without changing the
    /// visual size or hit-testing of the footer itself.
    @ViewBuilder
    private func footerLayoutMarker(_ identifier: String) -> some View {
#if DEBUG
        Text(verbatim: identifier)
            .font(.system(size: 1))
            .lineLimit(1)
            .fixedSize()
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityIdentifier(identifier)
#endif
    }

    private var batterySymbol: String {
        guard model.batteryState.hasInternalBattery else { return "powerplug.fill" }
        return model.batteryState.powerSource == .ac ? "battery.100.bolt" : "battery.50"
    }

    @ViewBuilder
    private var uiTestSessionMarker: some View {
#if DEBUG
        if CommandLine.arguments.contains("--ui-testing-window"), let session = model.session {
            Text(verbatim: "\(session.startedAt.timeIntervalSince1970)|\(session.expiresAt?.timeIntervalSince1970.description ?? "indefinite")")
                .font(.system(size: 1))
                .opacity(0.01)
                .allowsHitTesting(false)
                .accessibilityIdentifier("maccoffee.session.marker")
        }
#endif
    }

    private func openLegacySettings() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

private struct FooterActionLabel: View {
    let title: LocalizedStringKey
    let symbol: String
    var isDestructive = false
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 16)
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 38)
        .padding(.horizontal, 10)
        .foregroundStyle(isDestructive ? Color.red : Color.primary)
        .background(
            Color.secondary.opacity(isHovering ? 0.16 : 0.09),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onHover { hover in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovering = hover
            }
        }
    }
}

private struct FooterActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
