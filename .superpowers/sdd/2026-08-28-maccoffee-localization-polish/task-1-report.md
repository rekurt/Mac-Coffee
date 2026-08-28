# Task 1 report — Localization foundation

## Implemented interfaces and files

- Added `Sources/Core/Localization/SupportedLanguage.swift`: the nine persisted choices and exact native names for explicit languages.
- Added `Sources/Core/Localization/LocalizationController.swift`: main-actor observable persisted selection, system-language resolution/fallback, immediate locale publication, deterministic locale-resource lookup, and locale-aware formatting.
- Added `SettingsStoring.selectedLanguage` with `UserDefaultsSettingsStore` persistence and malformed-value fallback to `.system`.
- Added `AppEnvironment.localization`; live composition supplies one shared controller to notification delivery.
- Replaced frozen `AppModel.statusMessage` storage with semantic `AppStatusNotice` cases (`batteryBlocked`, `timerCompleted`, `powerAssertionFailed`, `launchAtLoginFailed`) and a locale-derived compatibility message.
- Updated `UserNotificationSender` to derive notification title/body from the shared controller at delivery time. Its notification-center lookup is lazy so content generation is unit-testable without an Xcode test-host notification center.
- Updated fakes and preference/model tests; added `Tests/Unit/RuntimeLocalizationTests.swift` covering mappings, system matching/fallback, malformed persistence, publish/refresh behavior, localized formatting, notice re-localization, and notification locale selection.
- Regenerated `MacCoffee.xcodeproj/project.pbxproj` with the added sources/tests.

## TDD evidence

### RED

1. `xcodegen generate && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' -only-testing:MacCoffeeTests/RuntimeLocalizationTests -only-testing:MacCoffeeTests/SettingsStoreTests -only-testing:MacCoffeeTests/AppModelTests`
   - Observed expected compile failures: `SupportedLanguage` and `selectedLanguage` were missing.
2. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' -only-testing:MacCoffeeTests/RuntimeLocalizationTests`
   - Observed expected compile failure: `LocalizationController.format` was missing.

### GREEN

1. Focused suite:
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' -only-testing:MacCoffeeTests/RuntimeLocalizationTests -only-testing:MacCoffeeTests/SettingsStoreTests -only-testing:MacCoffeeTests/AppModelTests`
   - Passed: 27 tests, 0 failures.
2. Full unit/integration suite:
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' -enableCodeCoverage YES`
   - Passed: 55 tests, 0 failures, including real IOKit integration.
3. App composition builds:
   - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project MacCoffee.xcodeproj -scheme MacCoffeeDirect -configuration Debug -destination 'platform=macOS'` — `BUILD SUCCEEDED`.
   - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project MacCoffee.xcodeproj -scheme MacCoffeeAppStore -configuration Debug -destination 'platform=macOS'` — `BUILD SUCCEEDED`.

## Self-review

- All localized delivery is routed through the same `AppEnvironment.localization` instance in live composition.
- Selecting an explicit language does not change any wake-session state; `AppModel` keeps notices semantic and derives their UI string on access.
- Explicit locale lookup selects the controller's `.lproj` rather than the process preferred language, which is necessary for immediate in-process switching.
- `git diff --check` passed.

## Risks / follow-up

- `AppStatusNotice.launchAtLoginFailed` uses the new `error.launchAtLogin` localization key. Task 2 must provide it in every locale (the key is intentionally not added here because translation resources belong to Task 2).
- Views are not yet injected with the published SwiftUI locale; that runtime UI wiring is Task 3. The domain, notices, and future notifications already react to controller changes.

---

## Fix round 1/5 — system Simplified Chinese matching

### Change

- Added a focused regression test for `zh_CN`, `zh_SG`, and bare `zh` system locales.
- Updated the system resolver so any `zh` base language resolves to the only supported Chinese choice, `zh-Hans`.

### TDD evidence

1. RED:
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' -only-testing:MacCoffeeTests/RuntimeLocalizationTests`
   - The new regression test failed three assertions: `zh_CN`, `zh_SG`, and `zh` each resolved to `en` rather than `zh-Hans`.
2. GREEN focused:
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' -only-testing:MacCoffeeTests/RuntimeLocalizationTests`
   - Passed: 9 tests, 0 failures.
3. GREEN full suite:
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' -enableCodeCoverage YES`
   - Passed: 56 tests, 0 failures.

### Self-review

- The fallback remains English for unsupported non-Chinese system languages.
- Because only Simplified Chinese is supported by the product contract, the resolver intentionally maps all Chinese regions and bare `zh` to `zh-Hans`.
