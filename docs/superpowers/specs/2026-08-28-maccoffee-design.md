# MacCoffee Design Specification

**Status:** Approved for implementation  
**Date:** 2026-08-28  
**Product name:** Mac Coffee (`MacCoffee` in code)  
**Version:** 2.0.0  
**Minimum OS:** macOS 13 Ventura  

## Fork baseline and root-cause findings

This work is based on the MIT-licensed fork `rekurt/Mac-Coffee` of
`Elliotwu-7/Mac-Coffee`, whose latest upstream release is `v1.0.1`.

The upstream release failure was reproduced on macOS 26.5.2:

- `MacCoffee.dmg` has the published SHA-256 checksum
  `4f5e51a8333a38b33cd255e4c97e04a7ddc59b49f8cdbf3a6f4f3ace2da5a4e8`;
- the application executable and helper contain only the `arm64` architecture;
- the bundle has only a linker-generated ad-hoc signature, its `Info.plist` is
  not bound, and its resources are not sealed;
- `codesign --verify --deep --strict` fails with
  `code has no resources but signature indicates they must be present`;
- Gatekeeper assessment with `spctl` fails with exit code 1;
- a browser download therefore cannot launch normally after quarantine.

The upstream runtime also changes persistent global `pmset` settings through a
root launch daemon and privileged helper. Version 2.0 removes that architecture
entirely. It uses process-owned public IOKit assertions, so normal sleep settings
return automatically when the process exits and the App Store target requires no
privileged helper.

## 1. Purpose

MacCoffee is a lightweight, native menu-bar utility that prevents a Mac from entering idle sleep. It can either keep the Mac awake while allowing the display to turn off, or keep both the Mac and display awake. The user can run a timed or indefinite session.

The product ships from one Xcode project through two independent distribution targets:

- a Developer ID-signed, notarized direct-download build with Sparkle updates;
- a sandboxed Mac App Store build that receives updates only through the store.

The utility uses only public macOS APIs, requires no administrator access, launches no daemon, collects no analytics, and has no account or backend.

## 2. Goals

1. Prevent automatic idle system sleep reliably while an active session exists.
2. Optionally prevent both idle display sleep and idle system sleep.
3. Make the active state unmistakable from the menu-bar icon and panel.
4. Avoid accidentally draining a laptop battery through a configurable safety cutoff.
5. Support finite sessions of 30 minutes, 1, 2, 4, or 8 hours, plus an indefinite session.
6. Start at login only with explicit user consent and always start in the off state.
7. Produce both direct-download and Mac App Store releases from shared code.
8. Remain event-driven and effectively idle when the menu is closed.

## 3. Non-goals

- Bypassing lid-close sleep, user-initiated Sleep, critical-battery shutdown, or thermal protection.
- Forcing unsupported closed-clamshell operation. MacCoffee remains compatible with clamshell operation when macOS itself permits it.
- Simulating mouse or keyboard activity, changing presence in chat applications, or defeating corporate power policies.
- Scheduling sessions by weekday, calendar, application, network, or location in version 2.0.
- Remote control, sync, telemetry, accounts, licensing, subscriptions, or cloud storage.
- Supporting macOS 12 or earlier.

## 4. Product identity and identifiers

- Product name: `Mac Coffee`
- Direct target: `MacCoffeeDirect`
- Mac App Store target: `MacCoffeeAppStore`
- Direct bundle identifier: `com.rekurt.maccoffee.direct`
- Mac App Store bundle identifier: `com.rekurt.maccoffee`
- Executable display name for both channels: `Mac Coffee`
- Initial marketing version: `2.0.0`
- Initial build number: `1`
- Category: Utilities
- Supported architectures: Apple silicon and Intel (`arm64`, `x86_64`)
- Localizations: English (`en`) and Russian (`ru`)

The App Store name must be reserved in App Store Connect before submission. If Apple reports a naming conflict, only the store display name changes; target names, domain model, and source layout remain stable.

## 5. User experience

### 5.1 Application presentation

MacCoffee is an agent-style application:

- `LSUIElement` is enabled;
- no Dock icon or ordinary main window is shown;
- the primary interface is a SwiftUI `MenuBarExtra` using window style;
- Settings opens a small native settings window;
- removing or quitting the menu-bar utility safely ends the active session.

The panel is approximately 320 points wide and contains:

1. current status and remaining time;
2. a three-state mode picker;
3. duration presets;
4. current power source and battery percentage when a battery exists;
5. Settings, About, and Quit actions;
6. Check for Updates only in `MacCoffeeDirect`.

### 5.2 Modes

`WakeMode` has exactly three values:

- `off`: no MacCoffee power assertion;
- `system`: prevent idle system sleep, allow normal display dimming and display sleep;
- `display`: prevent idle display sleep, which also prevents idle system sleep.

The display mode is not presented as independent from system wakefulness. This avoids exposing an impossible or misleading combination.

### 5.3 Duration behavior

`SessionDuration` offers:

- 30 minutes;
- 1 hour;
- 2 hours;
- 4 hours;
- 8 hours;
- indefinite.

The default duration on first launch is 1 hour. The last selected duration is stored as a preference, but an active session is never restored after launch.

Rules:

- turning on a mode creates a new session starting at the current time;
- a finite session stores an absolute `expiresAt` date;
- switching between `system` and `display` preserves the current expiration date;
- selecting a new duration during an active session restarts the duration from the current time;
- turning a session off clears its expiration;
- after relaunch, the mode is always `off` regardless of the prior state;
- if a finite timer expires while the Mac is asleep, MacCoffee is off after wake.

### 5.4 Menu-bar status

The menu-bar item uses template SF Symbols and a localized accessibility label:

- off: `moon.zzz`;
- system mode: `bolt.circle`;
- display mode: `display`.

State is never communicated by color alone. The panel includes text describing the active mode and remaining time.

### 5.5 Notifications

MacCoffee requests local-notification permission the first time the user starts a non-off session. Denial does not block the session and is not requested repeatedly.

Local notifications are emitted when:

- a finite session completes;
- a session is stopped by the low-battery policy.

If notifications are unavailable, the same outcome is shown the next time the panel opens.

### 5.6 Quit behavior

If Quit is selected while a session is active, MacCoffee presents a confirmation explaining that the Mac may sleep after exit. Confirming releases all assertions before termination. If the process crashes or is force-quit, macOS removes process-owned assertions automatically.

## 6. Battery safety policy

The low-battery threshold is configurable from 10% through 30% in 1% increments and defaults to 15%.

`BatteryState` contains:

- power source: `ac`, `battery`, or `unknown`;
- optional charge percentage;
- whether an internal battery exists.

Rules:

1. On AC power, the threshold never blocks a session.
2. On battery at or below the configured threshold, an active session is stopped immediately.
3. While blocked on battery, a new session cannot start.
4. Starting becomes available after AC is connected or battery charge rises above `threshold + 2%`.
5. The 2% hysteresis prevents repeated enable/disable transitions caused by capacity-estimate fluctuation.
6. On a desktop Mac with no internal battery, battery controls are hidden and power is treated as unlimited.
7. A transient failure to read battery state does not stop an active session. The UI shows an unknown state and waits for the next power-source notification.

Battery changes are event-driven through IOPowerSources notifications. MacCoffee does not continuously poll the battery.

## 7. Sleep boundaries

MacCoffee guarantees only prevention of automatic idle sleep while its assertion is active. It deliberately does not intercept:

- Apple menu Sleep;
- lid close;
- critical-battery sleep or shutdown;
- thermal-emergency sleep;
- administrative or operating-system sleep decisions.

When macOS allows a MacBook to operate in closed-clamshell mode with the required external equipment and power, MacCoffee continues to operate normally. It does not enable clamshell mode itself.

## 8. Architecture

### 8.1 Target structure

`project.yml` is the source of truth for XcodeGen 2.46.0. It generates a committed `MacCoffee.xcodeproj` with shared Debug and Release settings and these targets:

- `MacCoffeeDirect`: shared application code plus the direct entry point and Sparkle updater;
- `MacCoffeeAppStore`: shared application code plus the App Store entry point, sandbox entitlement, and no Sparkle dependency;
- `MacCoffeeTests`: unit and integration-style tests against protocols and fakes;
- `MacCoffeeUITests`: focused accessibility/UI tests for the panel and settings.

Both application targets compile the same shared source files. Distribution-only types live in target-specific directories. The App Store target must not link or embed Sparkle.

Both application targets use Xcode's standard macOS architectures (`arm64` and `x86_64`). No source or release script hardcodes `arm64`. Local packaging applies a complete ad-hoc bundle signature only after all executable and resource files are in place; public direct releases replace it with Developer ID signing and notarization.

### 8.2 Domain types

- `WakeMode`: `off`, `system`, `display`.
- `SessionDuration`: finite seconds or indefinite, exposed through fixed presets.
- `WakeSession`: active mode, start date, optional expiration date.
- `BatteryState`: power source, percentage, and internal-battery availability.
- `LowBatteryDecision`: `allowed`, `blocked`, or `stopActiveSession`.
- `AppSettings`: selected duration, battery threshold, and launch-at-login preference.

### 8.3 Components

#### `AppModel`

An `@MainActor` observable object and the single UI-facing state owner. It coordinates services, validates user intents, exposes localized presentation state, and serializes mode transitions.

#### `WakeSessionController`

Owns the active session and expiration task. It uses an absolute `expiresAt`, sleeps until the next deadline without periodic background ticks, and revalidates the deadline after system wake, significant clock changes, and application activation.

#### `PowerAssertionManaging`

A protocol for power-assertion operations. `IOKitPowerAssertionManager` is the production implementation.

- `system` maps to `kIOPMAssertionTypePreventUserIdleSystemSleep`.
- `display` maps to `kIOPMAssertionTypePreventUserIdleDisplaySleep`.
- `off` releases MacCoffee-owned assertions.

An active assertion is represented by its `IOPMAssertionID`. A mode transition creates the replacement assertion before releasing the old one. If creation fails, the old mode remains active. Failed releases are retained in a stale-ID set and retried during the next transition and clean shutdown.

#### `BatteryMonitoring`

A protocol that publishes initial and changed `BatteryState` values. `IOKitBatteryMonitor` reads `IOPSCopyPowerSourcesInfo`, power-source descriptions, `kIOPSPowerSourceStateKey`, capacity keys, and listens with `IOPSNotificationCreateRunLoopSource`.

#### `LowBatteryPolicy`

A pure value-type policy implementing the threshold and hysteresis rules. It has no IOKit or UI dependency and is exhaustively unit tested at boundary values.

#### `SettingsStoring`

A protocol backed by `UserDefaults`. It stores preferences only. It never stores `WakeSession` or an active mode.

#### `LaunchAtLoginManaging`

A protocol backed by `SMAppService.mainApp`. Registration and deregistration occur only in response to the explicit settings toggle. The UI reflects the service's actual status, not an optimistic local flag.

#### `NotificationSending`

A protocol backed by `UNUserNotificationCenter`. It handles authorization once and sends local notifications. A denied authorization is a nonfatal state.

#### `UpdaterProviding`

An interface exposing update availability and a user-initiated check. The direct implementation wraps Sparkle 2.9.4 `SPUStandardUpdaterController`. The App Store composition omits the updater and its UI.

#### `LifecycleObserving`

Publishes wake, termination, application activation, and significant clock-change events used to revalidate timers and release resources.

### 8.4 Data flow

User intent flows through `AppModel`, which checks `LowBatteryPolicy`, requests a session transition, and only publishes the new UI state after the assertion manager confirms success. Timer and battery events flow back into `AppModel` as stop intents. All mutations occur on `MainActor`.

```text
MenuBar UI / Settings
        |
        v
     AppModel <----- BatteryMonitor
        |                  |
        |             LowBatteryPolicy
        v
WakeSessionController ----> NotificationService
        |
        v
IOKitPowerAssertionManager
```

The updater and login-item service are side capabilities. They cannot mutate the wake session directly.

## 9. Error handling and recovery

1. Assertion creation failure leaves the prior confirmed state intact and shows a user-readable error.
2. Assertion release failure is logged, retained, retried, and never represented as a successful complete release until confirmed.
3. Rapid interactions are serialized on `MainActor`; expired operations cannot overwrite newer state.
4. Battery-read failure yields `unknown` and never triggers a false low-battery shutdown.
5. Notification denial leaves all core behavior functional.
6. Login-item denial or failure restores the actual service status and offers a button to open Login Items settings.
7. Sparkle errors affect only updating, never the wake session.
8. Technical errors use `OSLog` with subsystem `com.rekurt.maccoffee`; user-facing copy omits raw IOKit codes.
9. The last nonfatal status is visible in the panel until dismissed or superseded.
10. Both app targets register a termination handler that attempts to release all tracked assertions.

## 10. Performance and resource constraints

- No polling loop runs while the panel is closed.
- Battery monitoring is notification-based.
- The session task sleeps directly until expiration.
- Countdown rendering updates only while the panel is visible: once per minute when more than one minute remains and once per second during the final minute.
- Average idle CPU target with a closed panel: at or below 0.1% over five minutes on a release build.
- Idle physical-footprint target: below 50 MB on a release build. Resident size is recorded as an informational metric because it includes shared AppKit and SwiftUI mappings that are not private process cost.
- No network access occurs in the App Store build. Direct network access is limited to Sparkle update checks over HTTPS.
- The only third-party runtime dependency is Sparkle 2.9.4 in `MacCoffeeDirect`.

## 11. Security and privacy

- No user data is collected or transmitted.
- No tracking, analytics, crash-reporting SDK, advertising, login, or unique device identifier is used.
- Preferences remain in the app's own `UserDefaults` domain.
- Both targets include `PrivacyInfo.xcprivacy` declaring no tracking and no collected data. The manifest declares `UserDefaults` use with approved reason `CA92.1`.
- The App Store target enables App Sandbox and contains no updater or downloaded executable code.
- The direct target enables Hardened Runtime and is signed with Developer ID Application before notarization.
- Sparkle downloads use HTTPS and EdDSA-signed archives/appcasts. The private EdDSA key and Apple signing credentials are release secrets and never enter the repository.
- MacCoffee requests no Accessibility, Automation, Full Disk Access, root, daemon, or privileged-helper entitlement.
- The repository includes a documented, standalone legacy cleanup script for users who previously installed `com.elliotwu.maccoffee.helper`. It is never bundled into either version 2.0 application target and never runs automatically.

## 12. Distribution

### 12.1 Direct distribution

`MacCoffeeDirect`:

- links Sparkle 2.9.4 through Swift Package Manager;
- is not App Sandbox constrained;
- uses Hardened Runtime;
- is signed with Developer ID Application;
- is packaged as a drag-to-Applications DMG;
- is notarized with `notarytool` and stapled;
- publishes versioned artifacts, checksums, release notes, and an EdDSA-signed Sparkle appcast;
- supports user-initiated update checks without background network polling.

The appcast URL is supplied by the release configuration key `MACCOFFEE_APPCAST_URL`. Release builds fail at build time if the value is absent or not HTTPS.

### 12.2 Mac App Store distribution

`MacCoffeeAppStore`:

- enables App Sandbox;
- contains only public APIs;
- has no Sparkle product, code, XPC service, appcast URL, or update menu item;
- uses Apple distribution signing and App Store provisioning;
- is archived and validated through Xcode/App Store Connect;
- includes review notes explaining idle-sleep behavior, battery protection, login-item consent, and public IOKit usage.

### 12.3 External release prerequisites

Publishing, as distinct from building and testing, requires the release operator to provide:

- an active Apple Developer Program membership;
- an Apple development team selected for the project;
- Developer ID and Apple Distribution signing identities/profiles;
- App Store Connect access and a reserved MacCoffee app record;
- notarization credentials stored outside the repository;
- a public HTTPS host or repository for DMG releases and the Sparkle appcast;
- a Sparkle EdDSA signing key stored outside the repository.

Absence of these secrets does not block local builds or automated tests, but it blocks actual notarization and App Store submission.

## 13. Accessibility and localization

- Every control has a localized accessibility label and value.
- Keyboard navigation covers all controls without requiring a pointer.
- Mode state is conveyed by icon shape and text, not color alone.
- Dynamic system font sizes and Increased Contrast are respected.
- English is the development language; Russian is a complete localization.
- Notifications, settings, errors, confirmation dialogs, App Store metadata, and direct release notes are localized.
- UI tests query stable accessibility identifiers rather than localized strings.

## 14. Testing strategy

### 14.1 Unit tests

Unit tests use fake implementations of every external service and cover:

- all `WakeMode` transitions;
- finite and indefinite session creation;
- expiration, cancellation, duration reset, and mode switch with preserved expiration;
- expiration detected after simulated sleep and clock change;
- low-battery threshold boundaries from 10% through 30%;
- 2% hysteresis, AC recovery, desktop/no-battery behavior, and unknown battery state;
- assertion creation failure, release failure, retry, and transition rollback;
- rapid intent ordering;
- settings defaults, bounds, persistence, and the invariant that active mode is not persisted;
- notification authorization granted, denied, and unavailable;
- login-item status success, denial, failure, and reconciliation;
- updater availability only in direct composition.

Domain and coordination code targets at least 90% line coverage. Platform adapters are verified with integration and manual tests rather than mocked line-coverage targets.

### 14.2 UI tests

UI tests verify:

- off/system/display selection;
- all duration presets;
- status and countdown presentation;
- blocked low-battery presentation through a test launch environment;
- Settings bounds and launch-at-login UI reconciliation;
- quit confirmation;
- absence of update controls from the App Store target;
- English and Russian layouts;
- keyboard and accessibility identifiers.

### 14.3 Platform integration tests

On physical macOS hardware:

- `system` creates the expected process-owned system-sleep assertion;
- `display` creates the expected display-sleep assertion;
- `off`, timer completion, graceful quit, and crash leave no MacCoffee assertions;
- display sleep remains available in `system` mode;
- system and display idle sleep are prevented in `display` mode;
- battery source changes are received without polling;
- launch-at-login requires consent and launches in `off` state;
- manual Sleep and lid close remain controlled by macOS;
- supported closed-clamshell operation remains compatible when configured according to macOS requirements.

### 14.4 Build and release verification

The build matrix verifies Debug and Release for both targets on `arm64` and `x86_64`. Release checks include:

- unit and UI tests;
- app bundle inspection;
- verification that `MacCoffeeAppStore.app` contains no Sparkle symbols or bundles;
- sandbox entitlement inspection for the App Store build;
- Hardened Runtime and signature inspection for the direct build;
- archive validation;
- DMG installation smoke test;
- Sparkle upgrade test from the previous signed build;
- `codesign --verify --strict --deep` verification;
- Gatekeeper assessment with `spctl`;
- notarization ticket validation with `stapler`;
- Xcode Organizer/App Store validation;
- idle CPU, memory, and wakeup measurement against the budgets in section 10.

## 15. Acceptance criteria

Mac Coffee 2.0 is complete when:

1. Both application targets build from a clean checkout on a supported Xcode installation.
2. The app is menu-bar-only and starts in `off` after every process launch.
3. System mode prevents idle system sleep while allowing normal display sleep.
4. Display mode prevents both idle display and idle system sleep.
5. Every duration preset works and finite sessions stop at their absolute deadline.
6. Switching active modes preserves the deadline; choosing a new duration resets it.
7. Low-battery cutoff, configurable threshold, and hysteresis match section 6.
8. Assertions are absent after off, expiration, and process termination.
9. Launch at Login reflects `SMAppService` status and never restores a wake session.
10. Direct builds provide working Sparkle 2.9.4 updates from signed HTTPS appcasts.
11. App Store builds are sandboxed and contain no alternate update mechanism.
12. English and Russian UI, notifications, errors, and metadata are complete.
13. Unit, UI, integration, signing, packaging, and performance checks pass.
14. Privacy manifests and store privacy declarations state that no data is collected.
15. Direct artifacts are Developer ID signed, notarized, stapled, and Gatekeeper accepted when release credentials are available.
16. The App Store archive validates successfully when App Store credentials and provisioning are available.
17. The upstream `MacCoffeeHelper` executable, installer script, socket protocol, persistent `pmset` mutation, and launch daemon are absent from both application bundles.
18. The standalone legacy cleanup procedure restores `disablesleep` and removes the old helper only after explicit administrator authorization.

## 16. Risks and mitigations

- **Mac App Store interpretation of power-management utility behavior:** use only documented IOKit assertions, disclose behavior in review notes, and avoid unsupported lid manipulation.
- **Accidental inclusion of Sparkle in the store build:** separate app targets, dependency linkage only on `MacCoffeeDirect`, and an automated bundle/symbol inspection test.
- **Battery estimate fluctuation:** threshold hysteresis and event-driven reconciliation.
- **Timer drift across sleep or clock changes:** absolute expiration plus lifecycle revalidation.
- **Assertion leak during transition:** create-before-release, tracked IDs, release retry, and termination cleanup.
- **Menu-bar UI test fragility:** stable accessibility identifiers, domain-first testing, and a minimal physical UI smoke suite.
- **Name or bundle-ID collision during store registration:** reserve the App Store record before release signing; store metadata can change without altering core architecture.
- **Legacy v1 helper left installed:** provide explicit detection guidance and a standalone removal script; never silently modify privileged system state from the new app.

## 17. Authoritative references

- Apple `MenuBarExtra`: <https://developer.apple.com/documentation/swiftui/menubarextra>
- Apple `SMAppService.mainApp`: <https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp>
- Apple IOPM assertion creation: <https://developer.apple.com/documentation/iokit/1557134-iopmassertioncreatewithname>
- Apple idle system sleep assertion boundaries: <https://developer.apple.com/documentation/iokit/kiopmassertiontypepreventuseridlesystemsleep>
- Apple power-source APIs: <https://developer.apple.com/documentation/iokit/iopowersources_h>
- Apple App Sandbox requirement: <https://developer.apple.com/documentation/security/app-sandbox>
- Apple notarization workflow: <https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution>
- Apple App Review Guidelines: <https://developer.apple.com/app-store/review/guidelines/>
- Sparkle 2 documentation: <https://sparkle-project.org/documentation/>
- Sparkle 2.9.4 release: <https://github.com/sparkle-project/Sparkle/releases/tag/2.9.4>
