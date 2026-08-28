# Mac Coffee Localization and Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a stable, adaptive Mac Coffee 2.0 with immediate runtime language switching across system language plus eight explicit languages, consistent quit confirmation, complete translations, and release verification.

**Architecture:** A shared `LocalizationController` owns the persisted `SupportedLanguage` and publishes the resolved `Locale`. Both app variants, views, status notices, and notification delivery consume the same controller; user-visible model state stores semantic notice cases rather than frozen strings. SwiftUI uses the published locale while non-view services use the controller's locale-aware string API.

**Tech Stack:** Swift 6, SwiftUI, AppKit, UserNotifications, XCTest/XCUITest, XcodeGen, macOS 13+.

**Spec:** User-approved plan in the Codex task dated 2026-08-28.

## Global Constraints

- Supported choices are `system`, `ru`, `en`, `de`, `fr`, `zh-Hans`, `ja`, `ko`, and `es`; only simplified Chinese is included.
- Default and malformed persisted values resolve to `system`; an unsupported system language falls back to English.
- Language changes update open app UI and subsequent notifications immediately without restarting or recreating a wake session.
- Native language names are `Русский`, `English`, `Deutsch`, `Français`, `简体中文`, `日本語`, `한국어`, and `Español`.
- Keep product name `Mac Coffee`, macOS 13 support, Direct/App Store separation, and universal `arm64` + `x86_64` output.
- Preserve process-owned IOKit assertions, 10–30% battery protection, no privileged helper, no analytics, and no network service beyond Direct Sparkle updates.
- Use TDD: every production behavior starts with a focused failing test and the relevant test is observed failing before implementation.

---

### Task 1: Localization domain, persistence, notices, and notifications

**Files:**
- Create: `Sources/Core/Localization/SupportedLanguage.swift`
- Create: `Sources/Core/Localization/LocalizationController.swift`
- Modify: `Sources/Core/Services/SettingsStoring.swift`
- Modify: `Sources/Core/Services/UserDefaultsSettingsStore.swift`
- Modify: `Sources/Core/State/AppEnvironment.swift`
- Modify: `Sources/Core/State/AppModel.swift`
- Modify: `Sources/Core/Services/UserNotificationSender.swift`
- Modify/Test: `Tests/Support/Fakes.swift`, `Tests/Unit/SettingsStoreTests.swift`, `Tests/Unit/AppModelTests.swift`, new localization unit tests

**Interfaces:**
- Produce `SupportedLanguage: String, CaseIterable, Sendable` with exact persisted values from Global Constraints and native display names.
- Produce `@MainActor final class LocalizationController: ObservableObject` with `@Published private(set) selectedLanguage`, `@Published private(set) locale`, `select(_:)`, `refreshSystemLocale()`, and locale-aware string formatting.
- Add `SettingsStoring.selectedLanguage` and `AppEnvironment.localization`.
- Produce `AppStatusNotice` semantic cases for battery, timer, power assertion, and launch-at-login failures; existing UI-facing `statusMessage` becomes locale-derived.

- [ ] Add focused tests for all language mappings, system matching/fallback, malformed persistence fallback, immediate published locale changes, notice re-localization, and notification locale selection; run and observe expected compile/assertion failures.
- [ ] Implement the minimum domain, persistence, environment, semantic notice, and notification changes required by those tests.
- [ ] Run all unit/integration tests and keep existing wake-session behavior unchanged.
- [ ] Commit as `feat: add runtime localization foundation`.

### Task 2: Complete translations and store metadata

**Files:**
- Create: `Resources/Shared/{de,fr,zh-Hans,ja,ko,es}.lproj/Localizable.strings`
- Modify: `Resources/Shared/{en,ru}.lproj/Localizable.strings`
- Create: `metadata/{de-DE,fr-FR,zh-Hans,ja,ko,es-ES}/description.txt` and `privacy_url.txt`
- Modify/Test: `Tests/Unit/LocalizationTests.swift`, existing `metadata/en-US` and `metadata/ru`

**Interfaces:**
- Every locale must contain the same non-empty keys and the same `%d`/`%@` placeholder signature per key.
- Include keys for language settings, version format, adaptive mode labels/subtitles, generic failures, and quit confirmation.

- [ ] Extend localization tests with literal locale lists, key parity, placeholder parity, non-empty values, and spot checks for native language names; run and observe failures for missing resources.
- [ ] Add professional, concise translations for all user-facing panel, Settings, About, alert, error, notification, and accessibility strings.
- [ ] Add and validate store description/privacy metadata for all requested locales.
- [ ] Run localization tests and `plutil -lint` over every strings/resource file.
- [ ] Commit as `feat: localize Mac Coffee in eight languages`.

### Task 3: Immediate language switching and adaptive UI

**Files:**
- Modify: both app entry points under `Sources/Direct` and `Sources/AppStore`
- Modify: views under `Sources/Core/Views`, especially `MenuBarPanel`, `ModePicker`, `DurationPicker`, `SettingsView`, `CountdownText`, `AboutView`, and `MenuBarLabel`
- Modify/Test: `Sources/Direct/UITestEnvironment.swift`, `Tests/UI/MacCoffeeUITests.swift`

**Interfaces:**
- Settings exposes a language picker with identifier `maccoffee.settings.language` and calls `LocalizationController.select(_:)`.
- All root views receive the controller's locale through SwiftUI environment; manually formatted strings use the same locale.
- Mode selection uses `ViewThatFits`: segmented when it fits, vertical native choices otherwise. Duration labels remain segmented and hidden from layout.

- [ ] Add UI tests that switch language without PID change, preserve the active wake session, and assert all controls stay inside the test window for every supported explicit language; run and observe current failures.
- [ ] Wire the controller into both app variants and the deterministic UI-test environment.
- [ ] Implement the settings language section, immediate view refresh, 420-point ideal panel, adaptive mode/footer layouts, content-sized Settings, localized countdown/About/version/accessibility strings, and stable identifiers.
- [ ] Run the expanded UI suite plus all unit/integration tests.
- [ ] Commit as `feat: add adaptive multilingual interface`.

### Task 4: Unified quit flow and release completion

**Files:**
- Create: `Sources/Core/State/QuitConfirmationCoordinator.swift`
- Modify: app entry points, `MenuBarPanel`, UI tests, `README.md`, and `docs/RELEASE_CHECKLIST.md`
- Verify: existing build/package/release scripts and generated Xcode project

**Interfaces:**
- Produce `@MainActor final class QuitConfirmationCoordinator` with `requestQuit()` used by the footer and replacement `⌘Q` command.
- Confirmation uses active localization; confirm calls `prepareForTermination()` exactly once before termination, cancel changes no state, and system termination releases assertions without a user dialog.

- [ ] Add focused coordinator tests and fix the existing failing `⌘Q` UI scenario; observe failures before production changes.
- [ ] Implement the shared AppKit confirmation and route footer/keyboard user exits through it while leaving lifecycle/system termination non-interactive.
- [ ] Run all unit, integration, and UI tests, including real IOKit assertion checks.
- [ ] Regenerate the project, build and verify universal Direct/App Store bundles, validate resources/signing separation, package the DMG, mount/copy/launch it, and record checksum.
- [ ] Update README/release checklist, run static workflow/script checks and a whole-branch review, then commit as `release: polish Mac Coffee 2.0` and push `feat/maccoffee-2`.
