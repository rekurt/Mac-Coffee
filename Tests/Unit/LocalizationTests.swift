import Foundation
import XCTest

final class LocalizationTests: XCTestCase {
    private let locales = ["en", "ru", "de", "fr", "zh-Hans", "ja", "ko", "es"]

    func testEverySupportedLocaleHasMatchingNonEmptyKeysAndPlaceholders() throws {
        let english = try strings(in: "en")

        for locale in locales {
            let localized = try strings(in: locale)

            XCTAssertEqual(Set(localized.keys), Set(english.keys), "\(locale) has a different key set")
            for (key, value) in localized {
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(locale).\(key) is empty")
                XCTAssertEqual(
                    placeholders(in: value),
                    placeholders(in: try XCTUnwrap(english[key])),
                    "\(locale).\(key) has different placeholders"
                )
            }
        }
    }

    func testEnglishDefinesLanguageAndFailureStringsNeededByTheInterface() throws {
        let english = try strings(in: "en")
        let required = Set([
            "settings.language", "settings.language.system", "settings.language.help",
            "about.versionFormat", "error.launchAtLogin", "error.generic",
            "action.quit", "action.cancel", "action.confirmQuit", "quit.message"
        ])

        XCTAssertTrue(Set(english.keys).isSuperset(of: required))
        XCTAssertEqual(placeholders(in: try XCTUnwrap(english["about.versionFormat"])), ["%@", "%@"])
    }

    func testEnglishContainsNativeLanguageNamesForTheLanguagePicker() throws {
        let english = try strings(in: "en")

        XCTAssertEqual(english["language.russian"], "Русский")
        XCTAssertEqual(english["language.english"], "English")
        XCTAssertEqual(english["language.german"], "Deutsch")
        XCTAssertEqual(english["language.french"], "Français")
        XCTAssertEqual(english["language.simplifiedChinese"], "简体中文")
        XCTAssertEqual(english["language.japanese"], "日本語")
        XCTAssertEqual(english["language.korean"], "한국어")
        XCTAssertEqual(english["language.spanish"], "Español")
    }

    func testFrenchAndSpanishRemainingTimeUseNumberNeutralWording() throws {
        XCTAssertEqual(try strings(in: "fr")["status.remaining"], "Temps restant : %@")
        XCTAssertEqual(try strings(in: "es")["status.remaining"], "Tiempo restante: %@")
    }

    private func strings(in language: String) throws -> [String: String] {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repository
            .appendingPathComponent("Resources/Shared/\(language).lproj/Localizable.strings")
        let data = try Data(contentsOf: url)
        let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(propertyList as? [String: String])
    }

    private func placeholders(in value: String) -> [String] {
        let expression = try! NSRegularExpression(pattern: #"%(?:\d+\$)?(?:@|d)"#)
        let range = NSRange(value.startIndex..., in: value)
        return expression.matches(in: value, range: range).map { match in
            String(value[Range(match.range, in: value)!])
        }
    }
}
