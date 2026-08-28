import AppKit

@MainActor
protocol QuitShortcutMonitoring: AnyObject {
    func stop()
}

/// Owns every user-initiated quit path so cleanup cannot be bypassed by a
/// transient menu-bar window or the default application termination command.
@MainActor
public final class QuitConfirmationCoordinator {
    public typealias Presenter = @MainActor (NSAlert) -> NSApplication.ModalResponse
    public typealias Action = @MainActor () -> Void
    typealias ShortcutHandler = @MainActor (NSEvent) -> NSEvent?
    typealias ShortcutMonitorFactory = @MainActor (@escaping ShortcutHandler) -> any QuitShortcutMonitoring

    private let localization: LocalizationController
    private let present: Presenter
    private let prepareForTermination: Action
    private let terminate: Action
    private var isPresenting = false
    private var didConfirmTermination = false
    private var shortcutMonitor: (any QuitShortcutMonitoring)?

    public convenience init(
        model: AppModel,
        application: NSApplication = .shared
    ) {
        self.init(
            localization: model.environment.localization,
            present: { alert in
                application.activate(ignoringOtherApps: true)
                return alert.runModal()
            },
            prepareForTermination: model.prepareForTermination,
            terminate: { application.terminate(nil) },
            shortcutMonitorFactory: { LocalKeyDownMonitor(handler: $0) }
        )
    }

    init(
        localization: LocalizationController,
        present: @escaping Presenter,
        prepareForTermination: @escaping Action,
        terminate: @escaping Action,
        shortcutMonitorFactory: ShortcutMonitorFactory? = nil
    ) {
        self.localization = localization
        self.present = present
        self.prepareForTermination = prepareForTermination
        self.terminate = terminate
        if let shortcutMonitorFactory {
            shortcutMonitor = shortcutMonitorFactory { [weak self] event in
                guard let self, Self.isQuitShortcut(event) else { return event }
                self.requestQuit()
                return nil
            }
        }
    }

    public func requestQuit() {
        guard !isPresenting, !didConfirmTermination else { return }

        isPresenting = true
        let response = present(makeAlert())
        isPresenting = false

        guard response == .alertFirstButtonReturn, !didConfirmTermination else { return }
        didConfirmTermination = true
        stopShortcutMonitoring()
        prepareForTermination()
        terminate()
    }

    static func isQuitShortcut(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown,
              !event.isARepeat,
              event.charactersIgnoringModifiers?.lowercased() == "q"
        else {
            return false
        }

        let relevantFlags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        return relevantFlags == .command
    }

    private func stopShortcutMonitoring() {
        guard let shortcutMonitor else { return }
        shortcutMonitor.stop()
        self.shortcutMonitor = nil
    }

    private func makeAlert() -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localization.localized("action.quit")
        alert.informativeText = localization.localized("quit.message")
        let confirmButton = alert.addButton(
            withTitle: localization.localized("action.confirmQuit")
        )
        confirmButton.hasDestructiveAction = true
        let cancelButton = alert.addButton(
            withTitle: localization.localized("action.cancel")
        )
        cancelButton.keyEquivalent = "\u{1b}"
        let identifier = "maccoffee.quit.confirmation"
        alert.window.identifier = NSUserInterfaceItemIdentifier(identifier)
        alert.window.setAccessibilityIdentifier(identifier)
        confirmButton.setAccessibilityIdentifier("maccoffee.quit.confirm")
        cancelButton.setAccessibilityIdentifier("maccoffee.quit.cancel")
        return alert
    }
}

@MainActor
private final class LocalKeyDownMonitor: QuitShortcutMonitoring, @unchecked Sendable {
    nonisolated(unsafe) private var token: Any?

    init(handler: @escaping @MainActor (NSEvent) -> NSEvent?) {
        token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handler(event)
        }
    }

    func stop() {
        guard let token else { return }
        NSEvent.removeMonitor(token)
        self.token = nil
    }

    deinit {
        if let token {
            NSEvent.removeMonitor(token)
        }
    }
}
