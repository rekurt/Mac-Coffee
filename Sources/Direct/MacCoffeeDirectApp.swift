import MacCoffeeCore
import SwiftUI

@main
@MainActor
struct MacCoffeeDirectApp: App {
    @StateObject private var model: AppModel
    private let updater: SparkleUpdater

    init() {
        let updater = SparkleUpdater()
        self.updater = updater
        _model = StateObject(wrappedValue: AppModel(environment: .live(updater: updater)))
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
}
