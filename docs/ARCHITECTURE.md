# Mac Coffee Architecture

Mac Coffee is a native SwiftUI menu-bar application with two distribution products that share one testable core. It never changes persistent system power settings and never installs a helper.

## Runtime flow

1. A Direct or App Store composition root creates exactly one `AppEnvironment`.
2. `AppModel` owns the visible session state and coordinates the platform adapters.
3. A user selects Off, Keep Mac Awake, or Keep Display Awake and a duration.
4. `IOKitPowerAssertionManager` creates or releases a process-owned IOKit assertion.
5. `SessionScheduler` ends finite sessions. Battery and lifecycle adapters deliver event-driven changes.
6. Termination preparation cancels the schedule, stops observers, and releases all assertions.

No selected wake mode is restored at launch. Preferences contain only language, duration, battery threshold, Launch at Login intent, and notification authorization state.

## Modules

| Module | Boundary |
| --- | --- |
| `Sources/Core/Domain` | Modes, durations, wake-session, and battery value types |
| `Sources/Core/Localization` | Supported languages and runtime bundle selection |
| `Sources/Core/Policy` | Low-battery threshold and hysteresis policy |
| `Sources/Core/Services` | Service protocols plus IOKit, IOPowerSources, scheduling, lifecycle, notifications, settings, and Launch at Login adapters |
| `Sources/Core/State` | `AppEnvironment`, `AppModel`, and coordinated quit state |
| `Sources/Core/Views` | Shared SwiftUI menu-bar panel, Settings, About, and application commands |
| `Sources/Direct` | Direct app entry point and Sparkle adapter |
| `Sources/AppStore` | Sandboxed App Store entry point with no alternate updater |
| `Tools/Screenshots` | Developer-only deterministic renderer that embeds the production views; not a dependency of either product |

Platform dependencies are injected through the focused protocols in `Sources/Core/Services`. Tests and screenshot tooling replace them with in-memory adapters; production composition roots supply the concrete AppKit, IOKit, UserNotifications, and ServiceManagement implementations.

## State and safety invariants

- A confirmed Off transition releases every active or pending Mac Coffee IOKit assertion.
- In steady state, one active wake assertion represents the selected mode. A mode change creates the replacement before releasing the old assertion so protection is not interrupted.
- If releasing a replaced assertion fails, the new assertion remains the confirmed mode, the stale assertion is tracked for retry, and a typed localizable notice is shown. Later transitions and termination retry all tracked releases.
- Timer expiry and low-battery protection turn the app Off before notifying the user.
- User cancellation of quit changes no session state.
- Confirmed quit and noninteractive system termination share idempotent cleanup.
- Manual Sleep, lid closure, shutdown, restart, thermal protection, and other macOS policy remain authoritative.

## Localization

`LocalizationController` is the single runtime string source. The stored language is either System or one of eight supported localizations. System mode follows the first supported macOS preferred language and falls back to English. Explicit selection resolves the matching `.lproj` from the app bundle's resources directory and updates all observing SwiftUI views without restarting or recreating an active assertion.

Localized user-visible failures are represented by `AppStatusNotice`, not preformatted stored strings, so an already-open notice changes language with the rest of the interface. Delivered macOS notifications are immutable; later notifications use the current language.

## Distribution boundary

The products intentionally differ:

| Capability | Direct | App Store |
| --- | ---: | ---: |
| App Sandbox | No | Yes |
| Sparkle | Yes | No |
| `SUFeedURL` | Required for an official release | Forbidden |
| Developer ID + notarization | Required | No |
| App Store distribution profile | No | Required |

`scripts/verify-bundles.sh` enforces this boundary on built applications. `scripts/archive-app-store.sh` repeats the critical checks on the signed archive before it is considered uploadable.

## Generated project

`project.yml` is the source of truth for `MacCoffee.xcodeproj`. Run `xcodegen generate` after changing targets, resources, build settings, or schemes, and commit both the YAML change and generated project diff.
