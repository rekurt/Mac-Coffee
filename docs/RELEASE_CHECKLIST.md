# Mac Coffee 2.0 Release Checklist

This checklist is both the release gate and the evidence record for version 2.0.0 (build 1). A public Direct release must be Developer ID signed, notarized, and stapled; an ad-hoc local build is for local testing only.

## Automated verification

- [x] Regenerate `MacCoffee.xcodeproj` with XcodeGen 2.46.0.
- [x] Pass all `MacCoffeeTests` with code coverage enabled.
- [x] Domain values reach 100% line coverage, `AppModel` 97.37%, and `LowBatteryPolicy` 95.45%.
- [x] Build the eight-language `MacCoffeeUITests` bundle, including both Direct and App Store hosts.
- [ ] Pass all system-language and explicit-language `MacCoffeeUITests`.
- [x] Build universal Direct and App Store applications.
- [x] Verify strict code-signing structure and release entitlements for both bundles.
- [x] Confirm `arm64` and `x86_64` in both executables.
- [x] Confirm Sparkle and `SUFeedURL` exist only in Direct.
- [x] Confirm all eight localizations, PrivacyInfo, and icons in both bundles.
- [x] Confirm source runtime contains no `pmset`, `disablesleep`, or privilege escalation.
- [x] Generate and validate a signed Sparkle appcast with a one-time test key; confirm its DMG URL and EdDSA enclosure signature.
- [x] Tag workflow defines temporary-keychain materialization and cleanup for its Developer ID certificate, notary profile, and Sparkle key.

The final UI rerun remains unchecked until it completes in a stable, unlocked macOS GUI session. A DEBUG-only deterministic test window removes the status-item dependency in CI, but macOS can still reject synthesized UI events or expose a stale accessibility hierarchy after interrupted automation runs. Focused footer cancellation has completed successfully. AppKit integration installs the production local monitor, queues `Command-Q` through `NSApplication`, dispatches it through the real event path, and proves it is consumed before the main menu while routing to the shared coordinator. The attempted live System Events smoke launched the signed Debug app, but the secure black desktop exposed zero windows and did not deliver the synthetic shortcut, so it is not counted as live verification. The full expanded suite and live shortcut smoke must be rerun before a public release. The test-only window is absent from both Release binaries.

## Runtime verification

- [x] System mode appears in `pmset -g assertions` as `Mac Coffee active wake session` under `PreventUserIdleSystemSleep`.
- [x] Display mode appears under `PreventUserIdleDisplaySleep`.
- [x] Off and application termination leave no Mac Coffee assertion.
- [x] AppKit integration proves the production `Command-Q` monitor consumes and routes the shortcut to the same localized confirmation used by footer Quit.
- [ ] On an unlocked desktop, complete a live `Command-Q` Cancel/Confirm smoke and verify the same PID survives Cancel and exits after Confirm.
- [x] Confirmed user quit prepares termination exactly once before terminating; logout and shutdown cleanup remains noninteractive.
- [x] Low battery at the configured boundary stops or blocks a session.
- [x] Launch always begins in Off, including after an active-session termination.
- [x] Manual Sleep, lid close, and macOS thermal/safety decisions remain outside the app's guarantees.

## Packaging smoke test

- [x] Create `dist/local/MacCoffee-2.0.0.dmg` from the verified Direct app.
- [x] Mount the DMG read-only, copy the app to a fresh directory, and verify it again.
- [x] Launch the copied app and confirm its menu-bar process remains running.
- [ ] For an official Direct release, run Gatekeeper assessment after notarization and stapling.
- [ ] Perform the first end-to-end upgrade from a previously published Developer ID-signed build after release credentials are installed.
- [ ] Never publish the local ad-hoc DMG as an official release.

## Resource budget

Measure the Release Direct process with its panel closed for five idle minutes. Record five one-minute samples and compute the mean.

| Metric | Acceptance | Result |
| --- | ---: | ---: |
| Average CPU | ≤ 0.1% | 0.00008% — pass |
| Physical footprint | < 50 MB | 16.34 MB — pass |
| Resident memory (shared mappings included) | Informational | 71.54 MB average (63.03–76.09 MB) |
| Idle wakeups | Event-driven; no polling timer | 0 package-idle and 17 interrupt wakeups over 5 minutes |

Measurements were taken on macOS 26.5.2 from five consecutive one-minute `proc_pid_rusage` intervals with the Release Direct panel closed. Resident size includes mapped shared AppKit/SwiftUI pages; the process-owned physical footprint stayed near 16 MB and is the resource acceptance metric. CPU time is derived from cumulative user and system nanoseconds, not a rounded Activity Monitor snapshot.

## Store and release metadata

- [x] Privacy policy says that no data is collected.
- [x] Store copy accurately describes the battery cutoff and wake-session modes.
- [x] Review notes document IOKit and `SMAppService` use.
- [x] Copy does not claim that Mac Coffee defeats lid-close, manual, or thermal sleep.
- [x] Direct-release secrets remain outside the repository.
