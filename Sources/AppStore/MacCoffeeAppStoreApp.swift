import AppKit
import MacCoffeeCore
import SwiftUI

@main
@MainActor
struct MacCoffeeAppStoreApp: App {
    @StateObject private var model: AppModel
    @ObservedObject private var localization: LocalizationController
#if DEBUG
    private static var uiTestWindowController: NSWindowController?
#endif

    init() {
        let model = AppModel(environment: .live())
        _model = StateObject(wrappedValue: model)
        _localization = ObservedObject(wrappedValue: model.environment.localization)
#if DEBUG
        Self.openUITestWindowIfRequested(model: model)
#endif
    }

    var body: some Scene {
        MenuBarExtra {
            LocalizedRootView(localization: localization) {
                MenuBarPanel(model: model)
            }
        } label: {
            LocalizedRootView(localization: localization) {
                MenuBarLabel(model: model)
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            LocalizedRootView(localization: localization) {
                SettingsView(model: model)
            }
        }

        Window("about.title", id: "maccoffee.about") {
            LocalizedRootView(localization: localization) {
                AboutView()
            }
        }
        .windowResizability(.contentSize)
    }

#if DEBUG
    private static func openUITestWindowIfRequested(model: AppModel) {
        guard CommandLine.arguments.contains("--ui-testing-window") else { return }
        DispatchQueue.main.async {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 680),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Mac Coffee"
            window.identifier = NSUserInterfaceItemIdentifier("maccoffee.ui-test.window")
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(
                rootView: LocalizedRootView(localization: model.environment.localization) {
                    MenuBarPanel(model: model)
                }
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
