import Foundation

@MainActor
public protocol UpdaterProviding: AnyObject {
    var canCheckForUpdates: Bool { get }
    func checkForUpdates()
}
