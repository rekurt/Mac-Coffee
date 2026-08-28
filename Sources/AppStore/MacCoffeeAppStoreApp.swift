import AppKit
import MacCoffeeCore
import SwiftUI

@main
@MainActor
struct MacCoffeeAppStoreApp: App {
    @StateObject private var model: AppModel
#if DEBUG
    private static var uiTestWindowController: NSWindowController?
#endif

    init() {
        let model = AppModel(environment: .live())
        _model = StateObject(wrappedValue: model)
#if DEBUG
        Self.openUITestWindowIfRequested(model: model)
#endif
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }

#if DEBUG
    private static func openUITestWindowIfRequested(model: AppModel) {
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
                rootView: MenuBarPanel(model: model)
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
