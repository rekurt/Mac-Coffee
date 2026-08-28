import MacCoffeeCore
import SwiftUI

@main
@MainActor
struct MacCoffeeAppStoreApp: App {
    @StateObject private var model = AppModel(environment: .live())

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
}
