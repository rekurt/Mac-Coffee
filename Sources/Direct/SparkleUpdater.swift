import Foundation
import MacCoffeeCore
import Sparkle

@MainActor
final class SparkleUpdater: UpdaterProviding {
    private let controller: SPUStandardUpdaterController
    private let isConfigured: Bool

    init(bundle: Bundle = .main) {
        let feed = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        isConfigured = feed?.hasPrefix("https://") == true && publicKey?.isEmpty == false
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        if isConfigured {
            controller.startUpdater()
        }
    }

    var canCheckForUpdates: Bool {
        isConfigured && controller.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        controller.checkForUpdates(nil)
    }
}
