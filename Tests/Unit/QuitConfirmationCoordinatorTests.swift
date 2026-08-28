import AppKit
import Foundation
import XCTest
@testable import MacCoffeeCore

@MainActor
final class QuitConfirmationCoordinatorTests: XCTestCase {
    func testCancelLeavesPreparationAndTerminationUntouched() {
        var events: [String] = []
        let coordinator = makeCoordinator(
            response: .alertSecondButtonReturn,
            prepare: { events.append("prepare") },
            terminate: { events.append("terminate") }
        )

        coordinator.requestQuit()

        XCTAssertEqual(events, [])
    }

    func testConfirmPreparesExactlyOnceBeforeTermination() {
        var events: [String] = []
        var presentationCount = 0
        let coordinator = makeCoordinator(
            response: .alertFirstButtonReturn,
            onPresent: { presentationCount += 1 },
            prepare: { events.append("prepare") },
            terminate: { events.append("terminate") }
        )

        coordinator.requestQuit()
        coordinator.requestQuit()

        XCTAssertEqual(events, ["prepare", "terminate"])
        XCTAssertEqual(presentationCount, 1)
    }

    func testReentrantRequestDoesNotPresentAnotherDialog() {
        let localization = LocalizationController(
            settings: FakeSettingsStore(selectedLanguage: .english)
        )
        let coordinatorReference = QuitCoordinatorReference()
        var presentationCount = 0
        let coordinator = QuitConfirmationCoordinator(
            localization: localization,
            present: { _ in
                presentationCount += 1
                coordinatorReference.value?.requestQuit()
                return .alertSecondButtonReturn
            },
            prepareForTermination: {
                XCTFail("A cancelled reentrant request must not prepare for termination")
            },
            terminate: {
                XCTFail("A cancelled reentrant request must not terminate")
            }
        )
        coordinatorReference.value = coordinator

        coordinator.requestQuit()

        XCTAssertEqual(presentationCount, 1)
    }

    func testEveryRequestUsesTheLanguageActiveAtPresentationTime() throws {
        let fixture = try QuitLocalizationFixture.make()
        defer { try? FileManager.default.removeItem(at: fixture.url) }
        let localization = LocalizationController(
            settings: FakeSettingsStore(selectedLanguage: .english),
            bundle: fixture.bundle
        )
        var presentedCopy: [[String]] = []
        let coordinator = QuitConfirmationCoordinator(
            localization: localization,
            present: { alert in
                presentedCopy.append([
                    alert.messageText,
                    alert.informativeText,
                    alert.buttons[0].title,
                    alert.buttons[1].title
                ])
                XCTAssertEqual(alert.window.identifier?.rawValue, "maccoffee.quit.confirmation")
                return .alertSecondButtonReturn
            },
            prepareForTermination: {
                XCTFail("A cancelled request must not prepare for termination")
            },
            terminate: {
                XCTFail("A cancelled request must not terminate")
            }
        )

        coordinator.requestQuit()
        localization.select(.russian)
        coordinator.requestQuit()

        XCTAssertEqual(presentedCopy, [
            ["Quit Mac Coffee", "Quit Mac Coffee and allow your Mac to sleep normally?", "Quit", "Cancel"],
            ["Выйти из Mac Coffee", "Выйти из Mac Coffee и вернуть обычный режим сна Mac?", "Выйти", "Отмена"]
        ])
    }

    func testQuitShortcutAcceptsOnlyNonRepeatingCommandQ() throws {
        XCTAssertTrue(QuitConfirmationCoordinator.isQuitShortcut(try keyEvent("q", flags: [.command])))
        XCTAssertTrue(QuitConfirmationCoordinator.isQuitShortcut(try keyEvent("Q", flags: [.command])))
        XCTAssertTrue(QuitConfirmationCoordinator.isQuitShortcut(try keyEvent("q", flags: [.command, .capsLock])))

        XCTAssertFalse(QuitConfirmationCoordinator.isQuitShortcut(try keyEvent("q", flags: [])))
        XCTAssertFalse(QuitConfirmationCoordinator.isQuitShortcut(try keyEvent("w", flags: [.command])))
        XCTAssertFalse(QuitConfirmationCoordinator.isQuitShortcut(try keyEvent("q", flags: [.command, .control])))
        XCTAssertFalse(QuitConfirmationCoordinator.isQuitShortcut(try keyEvent("q", flags: [.command, .option])))
        XCTAssertFalse(QuitConfirmationCoordinator.isQuitShortcut(try keyEvent("q", flags: [.command, .shift])))
        XCTAssertFalse(QuitConfirmationCoordinator.isQuitShortcut(try keyEvent("q", flags: [.command], isRepeat: true)))
    }

    func testInstalledShortcutMonitorRoutesCommandQIntoConfirmationAndConsumesIt() throws {
        var installedHandler: QuitConfirmationCoordinator.ShortcutHandler?
        var presentationCount = 0
        let monitor = TestQuitShortcutMonitor()
        let coordinator = QuitConfirmationCoordinator(
            localization: LocalizationController(
                settings: FakeSettingsStore(selectedLanguage: .english)
            ),
            present: { _ in
                presentationCount += 1
                return .alertSecondButtonReturn
            },
            prepareForTermination: {
                XCTFail("A cancelled shortcut request must not prepare for termination")
            },
            terminate: {
                XCTFail("A cancelled shortcut request must not terminate")
            },
            shortcutMonitorFactory: { handler in
                installedHandler = handler
                return monitor
            }
        )
        let handler = try XCTUnwrap(installedHandler)
        let unrelatedEvent = try keyEvent("w", flags: [.command])

        XCTAssertIdentical(handler(unrelatedEvent), unrelatedEvent)
        XCTAssertNil(handler(try keyEvent("q", flags: [.command])))
        XCTAssertEqual(presentationCount, 1)
        XCTAssertEqual(monitor.stopCount, 0)
        withExtendedLifetime(coordinator) {}
    }

    func testProductionLocalMonitorConsumesPostedCommandQBeforeMenuDispatch() throws {
        let application = NSApplication.shared
        let previousMainMenu = application.mainMenu
        let actionProbe = MenuActionProbe()
        application.mainMenu = makeTestMainMenu(target: actionProbe)
        defer { application.mainMenu = previousMainMenu }
        var presentationCount = 0
        var preparationCount = 0
        var terminationCount = 0
        let coordinator = QuitConfirmationCoordinator(
            localization: LocalizationController(
                settings: FakeSettingsStore(selectedLanguage: .english)
            ),
            present: { _ in
                presentationCount += 1
                return .alertSecondButtonReturn
            },
            prepareForTermination: { preparationCount += 1 },
            terminate: { terminationCount += 1 },
            shortcutMonitorFactory: QuitConfirmationCoordinator.productionShortcutMonitorFactory
        )

        try postAndDispatch(
            keyEvent("w", flags: [.command], keyCode: 13),
            expecting: "w",
            through: application
        )
        XCTAssertEqual(actionProbe.invocationCount, 1, "The menu must receive unconsumed shortcuts")
        actionProbe.invocationCount = 0

        try postAndDispatch(
            keyEvent("q", flags: [.command], keyCode: 12),
            expecting: "q",
            through: application
        )

        XCTAssertEqual(presentationCount, 1)
        XCTAssertEqual(preparationCount, 0)
        XCTAssertEqual(terminationCount, 0)
        XCTAssertEqual(actionProbe.invocationCount, 0, "The production monitor must consume Command-Q")
        withExtendedLifetime(coordinator) {}
    }

    private func makeCoordinator(
        response: NSApplication.ModalResponse,
        onPresent: @escaping () -> Void = {},
        prepare: @escaping @MainActor () -> Void,
        terminate: @escaping @MainActor () -> Void
    ) -> QuitConfirmationCoordinator {
        QuitConfirmationCoordinator(
            localization: LocalizationController(
                settings: FakeSettingsStore(selectedLanguage: .english)
            ),
            present: { _ in
                onPresent()
                return response
            },
            prepareForTermination: prepare,
            terminate: terminate
        )
    }

    private func keyEvent(
        _ charactersIgnoringModifiers: String,
        flags: NSEvent.ModifierFlags,
        isRepeat: Bool = false,
        keyCode: UInt16 = 12
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: charactersIgnoringModifiers,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            isARepeat: isRepeat,
            keyCode: keyCode
        ))
    }

    private func makeTestMainMenu(target: MenuActionProbe) -> NSMenu {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu()
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        for key in ["w", "q"] {
            let item = NSMenuItem(
                title: key,
                action: #selector(MenuActionProbe.performAction(_:)),
                keyEquivalent: key
            )
            item.keyEquivalentModifierMask = .command
            item.target = target
            applicationMenu.addItem(item)
        }
        return mainMenu
    }

    private func postAndDispatch(
        _ event: NSEvent,
        expecting expectedCharacters: String,
        through application: NSApplication
    ) throws {
        application.postEvent(event, atStart: true)
        let queuedEvent = try XCTUnwrap(application.nextEvent(
            matching: .keyDown,
            until: Date().addingTimeInterval(1),
            inMode: .default,
            dequeue: true
        ))
        XCTAssertEqual(queuedEvent.charactersIgnoringModifiers, expectedCharacters)
        application.sendEvent(queuedEvent)
    }
}

@MainActor
private final class MenuActionProbe: NSObject {
    var invocationCount = 0

    @objc func performAction(_ sender: Any?) {
        invocationCount += 1
    }
}

@MainActor
private final class TestQuitShortcutMonitor: QuitShortcutMonitoring {
    private(set) var stopCount = 0

    func stop() {
        stopCount += 1
    }
}

@MainActor
private final class QuitCoordinatorReference {
    var value: QuitConfirmationCoordinator?
}

private enum QuitLocalizationFixture {
    static func make() throws -> (bundle: Bundle, url: URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCoffeeQuitLocalization.\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.rekurt.maccoffee.quit-localization-tests</string><key>CFBundleDevelopmentRegion</key><string>en</string><key>CFBundleLocalizations</key><array><string>en</string><string>ru</string></array></dict></plist>
        """.write(to: url.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        try writeStrings([
            "action.quit": "Quit Mac Coffee",
            "action.cancel": "Cancel",
            "action.confirmQuit": "Quit",
            "quit.message": "Quit Mac Coffee and allow your Mac to sleep normally?"
        ], language: "en", in: url)
        try writeStrings([
            "action.quit": "Выйти из Mac Coffee",
            "action.cancel": "Отмена",
            "action.confirmQuit": "Выйти",
            "quit.message": "Выйти из Mac Coffee и вернуть обычный режим сна Mac?"
        ], language: "ru", in: url)
        return (try XCTUnwrap(Bundle(url: url)), url)
    }

    private static func writeStrings(
        _ strings: [String: String],
        language: String,
        in bundleURL: URL
    ) throws {
        let directory = bundleURL.appendingPathComponent("\(language).lproj")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let contents = strings.map { "\"\($0.key)\" = \"\($0.value)\";" }.joined(separator: "\n")
        try contents.write(
            to: directory.appendingPathComponent("Localizable.strings"),
            atomically: true,
            encoding: .utf8
        )
    }
}
