import Combine
import Foundation

@MainActor
public final class LocalizationController: ObservableObject {
    @Published public private(set) var selectedLanguage: SupportedLanguage
    @Published public private(set) var locale: Locale

    private let settings: SettingsStoring
    private let systemLocale: () -> Locale
    private let bundle: Bundle

    public init(
        settings: SettingsStoring,
        systemLocale: @escaping () -> Locale = { .current },
        bundle: Bundle = .main
    ) {
        self.settings = settings
        self.systemLocale = systemLocale
        self.bundle = bundle
        let language = settings.selectedLanguage
        selectedLanguage = language
        locale = Self.resolvedLocale(for: language, systemLocale: systemLocale())
    }

    public func select(_ language: SupportedLanguage) {
        selectedLanguage = language
        settings.selectedLanguage = language
        locale = Self.resolvedLocale(for: language, systemLocale: systemLocale())
    }

    public func refreshSystemLocale() {
        guard selectedLanguage == .system else { return }
        locale = Self.resolvedLocale(for: selectedLanguage, systemLocale: systemLocale())
    }

    public func localized(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    public func format(_ key: String, arguments: CVarArg...) -> String {
        String(format: localized(key), locale: locale, arguments: arguments)
    }

    private static func resolvedLocale(for language: SupportedLanguage, systemLocale: Locale) -> Locale {
        guard language == .system else { return Locale(identifier: language.rawValue) }

        let identifier = systemLocale.identifier.replacingOccurrences(of: "_", with: "-")
        let components = identifier.split(separator: "-").map(String.init)
        let baseLanguage = components.first?.lowercased()
        let languageSubtags = components.dropFirst().map { $0.lowercased() }
        let isTraditionalChinese = languageSubtags.contains("hant")
            || languageSubtags.contains(where: ["tw", "hk", "mo"].contains)

        let resolvedLanguage: SupportedLanguage?
        if baseLanguage == "zh", !isTraditionalChinese {
            resolvedLanguage = .simplifiedChinese
        } else if let baseLanguage {
            resolvedLanguage = SupportedLanguage(rawValue: baseLanguage)
        } else {
            resolvedLanguage = nil
        }

        return Locale(identifier: (resolvedLanguage ?? .english).rawValue)
    }

    private var localizedBundle: Bundle {
        let candidates = [
            locale.identifier.replacingOccurrences(of: "_", with: "-"),
            locale.language.languageCode?.identifier
        ].compactMap { $0 }
        for identifier in candidates {
            let localizationURL = bundle.bundleURL.appendingPathComponent("\(identifier).lproj")
            if FileManager.default.fileExists(atPath: localizationURL.path),
               let localizedBundle = Bundle(url: localizationURL) {
                return localizedBundle
            }
        }
        return bundle
    }
}
