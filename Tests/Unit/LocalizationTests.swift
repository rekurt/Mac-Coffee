import Foundation
import XCTest

final class LocalizationTests: XCTestCase {
    func testEnglishAndRussianContainRequiredKeys() throws {
        let required = Set([
            "mode.off", "mode.system", "mode.display", "duration.indefinite",
            "battery.blocked", "settings.launchAtLogin", "action.quit"
        ])
        let english = try keys(in: "en")
        let russian = try keys(in: "ru")

        XCTAssertTrue(english.isSuperset(of: required))
        XCTAssertEqual(english, russian)
    }

    private func keys(in language: String) throws -> Set<String> {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repository
            .appendingPathComponent("Resources/Shared/\(language).lproj/Localizable.strings")
        let data = try Data(contentsOf: url)
        let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
        let dictionary = try XCTUnwrap(propertyList as? [String: String])
        return Set(dictionary.keys)
    }
}
