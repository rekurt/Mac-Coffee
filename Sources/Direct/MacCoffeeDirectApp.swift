import AppKit
import MacCoffeeCore
import SwiftUI

@main
@MainActor
struct MacCoffeeDirectApp: App {
    @StateObject private var model: AppModel
    private let updater: SparkleUpdater
#if DEBUG
    private static var uiTestWindowController: NSWindowController?
#endif

    init() {
        let updater = SparkleUpdater()
        let environment: AppEnvironment
#if DEBUG
        environment = UITestEnvironment.makeIfRequested(updater: updater) ?? .live(updater: updater)
#else
        environment = .live(updater: updater)
#endif
        let model = AppModel(environment: environment)
        self.updater = updater
        _model = StateObject(wrappedValue: model)
#if DEBUG
        Self.openUITestWindowIfRequested(model: model, updater: updater)
#endif
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(model: model, updater: updater)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }

#if DEBUG
    private static func openUITestWindowIfRequested(model: AppModel, updater: SparkleUpdater) {
        guard CommandLine.arguments.contains("--ui-testing-window") else { return }
        DispatchQueue.main.async {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Mac Coffee"
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(
                rootView: MenuBarPanel(model: model, updater: updater)
            )
            window.center()
            let controller = NSWindowController(window: window)
            uiTestWindowController = controller
            controller.showWindow(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
#endif
}
