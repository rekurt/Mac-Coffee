# Mac Coffee MCP Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan.

**Goal:** Ship a secure, Direct-only local MCP helper that controls the running Mac Coffee app through its single `AppModel`, while completing the three-language documentation and deterministic screenshot overhaul.

**Architecture:** The bundled `MacCoffeeMCP` executable speaks MCP over stdio, obtains the running Direct app's anonymous endpoint from a minimal bundled XPC rendezvous broker, and then connects directly to the app through authenticated NSXPC. `MCPControlService` serializes validated commands onto `@MainActor` and maps `AppModel` state to versioned snapshots. The broker owns no application data or secrets; the helper owns MCP SDK adaptation and its client private key; the app owns trust decisions, UI, and all application state.

**Tech Stack:** Swift 6, SwiftUI/AppKit, Combine, Foundation NSXPC, CryptoKit P-256, Security/Keychain, official MCP Swift SDK 0.12.1, XCTest/XCUITest, XcodeGen, shell release validation.

**Spec:** [Approved design](../specs/2026-08-31-maccoffee-mcp-design.md)

## Global Constraints

- Work only on `feat/maccoffee-mcp` in the existing linked worktree.
- Use strict red-green-refactor: observe each new test fail for the intended reason before adding production code.
- Preserve the existing 78-test green baseline throughout.
- `AppModel` remains the sole mutable application-state coordinator.
- The helper must never import or invoke IOKit, `UserDefaultsSettingsStore`, `SMAppService`, notification APIs, or `LocalizationController` directly.
- MCP stdout is JSON-RPC only. Diagnostics use stderr or unified logging.
- Never auto-launch Mac Coffee and never expose a network listener.
- MCP is Direct-only and off by default. The App Store target must remain free of helper/SDK symbols and resources.
- The app UI retains all eight localizations. Repository docs, screenshots, and store metadata retain only English, Russian, and Simplified Chinese.
- Commit after each independently green task. Do not commit generated DerivedData or secrets.

## Task 1: Add MCP domain contract and strict argument validation

**Files:**

- Create: `Sources/Core/MCP/MCPContract.swift`
- Create: `Sources/Core/MCP/MCPError.swift`
- Create: `Sources/Core/MCP/MCPCommand.swift`
- Test: `Tests/Unit/MCPContractTests.swift`
- Modify: `project.yml`

**Step 1: Write failing tests**

Cover exact public tool/resource names, `schemaVersion == 1`, stable error codes, mode/duration/language decoding, threshold bounds 10...30, malformed Boolean/string input, and unknown fields. Include this boundary assertion:

```swift
func testBatteryThresholdRejectsInsteadOfClamping() throws {
    XCTAssertThrowsError(try MCPCommand.makeBatteryThreshold(percent: 9, requestID: nil)) {
        XCTAssertEqual(($0 as? MCPServiceError)?.code, .invalidArgument)
    }
}
```

**Step 2: Run the focused test and confirm red**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' \
  -only-testing:MacCoffeeTests/MCPContractTests CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because MCP contract symbols do not exist.

**Step 3: Implement the minimum domain**

Add `MCPToolName`, `MCPResourceURI`, `MCPErrorCode`, `MCPServiceError`, and validated `MCPCommand`. Reuse raw values from `WakeMode`, `SessionDuration`, and `SupportedLanguage`; never create competing app-domain enums.

**Step 4: Regenerate and rerun**

Run `xcodegen generate`, then the focused command. Expected: all `MCPContractTests` pass.

**Step 5: Commit**

```bash
git add project.yml MacCoffee.xcodeproj Sources/Core/MCP Tests/Unit/MCPContractTests.swift
git commit -m "feat(mcp): define stable protocol contract"
```

## Task 2: Build versioned snapshots and localized display text

**Files:**

- Create: `Sources/Core/MCP/MCPSnapshot.swift`
- Create: `Sources/Core/MCP/MCPSnapshotFactory.swift`
- Modify: `Sources/Core/State/AppModel.swift`
- Modify: `Sources/Core/Localization/LocalizationController.swift`
- Modify: `Resources/Shared/{en,ru,de,fr,zh-Hans,ja,ko,es}.lproj/Localizable.strings`
- Test: `Tests/Unit/MCPSnapshotTests.swift`
- Test: `Tests/Unit/LocalizationTests.swift`

**Step 1: Write failing mapping tests**

Assert exact JSON-compatible fields for off/active states, indefinite/null expiry, AC desktop, unknown laptop percentage, battery blocked, all Launch at Login states, busy, localized status notice, selected/effective language, RFC 3339 UTC dates, monotonic sequence, and all eight localized `displayText` values.

**Step 2: Confirm focused tests fail**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' \
  -only-testing:MacCoffeeTests/MCPSnapshotTests CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because the snapshot types do not exist.

**Step 3: Implement immutable Sendable DTOs**

Use `Codable`, `Equatable`, and `Sendable` value types. Inject a clock and sequence source into `MCPSnapshotFactory`. Add only the smallest read-only `AppModel` projection needed; do not expose mutable internals.

**Step 4: Add all eight translations and parity checks**

Add keys for MCP status/action/error summaries. Extend localization tests to compare key sets and format placeholders across every `.lproj`.

**Step 5: Run and commit**

Run snapshot and localization tests, then the full unit scheme. Commit as `feat(mcp): map app state to localized snapshots`.

## Task 3: Route commands through one main-actor control service

**Files:**

- Create: `Sources/Core/MCP/MCPControlServicing.swift`
- Create: `Sources/Core/MCP/MCPControlService.swift`
- Create: `Sources/Core/MCP/MCPActivity.swift`
- Modify: `Sources/Core/State/AppModel.swift`
- Modify: `Tests/Support/Fakes.swift`
- Test: `Tests/Unit/MCPControlServiceTests.swift`

**Step 1: Write failing behavior tests**

Test get status, start system/display, change mode preserving deadline, change duration, stop, battery block, assertion failure reconciliation, threshold, Launch at Login, language, busy rejection, one notification/side effect, and activity recording.

**Step 2: Add atomic AppModel entry points**

Add `applySession(mode:duration:)` and a public throwing `stopSession()` that reuse existing transition/scheduling logic. Validate before the first mutation. Keep UI methods working and covered.

**Step 3: Implement `MCPControlService`**

Make it `@MainActor`. Serialize mutations, map known failures to stable codes, produce snapshots after committed/reconciled state, and never call environment services directly.

**Step 4: Run focused and regression tests**

Expected: MCP service tests and all existing AppModel tests pass.

**Step 5: Commit**

Commit as `feat(mcp): route commands through AppModel`.

## Task 4: Add bounded activity, idempotency, and event coalescing

**Files:**

- Create: `Sources/Core/MCP/MCPActivityStore.swift`
- Create: `Sources/Core/MCP/MCPRequestCache.swift`
- Create: `Sources/Core/MCP/MCPStatusPublisher.swift`
- Modify: `Sources/Core/MCP/MCPControlService.swift`
- Test: `Tests/Unit/MCPRuntimeBehaviorTests.swift`

**Step 1: Write failing tests**

Cover 200-entry FIFO behavior, no persisted data, sanitized input, duplicate request IDs returning the first result, distinct IDs executing separately, coalesced bursts, increasing sequences, subscriber cancellation, and UI-originated state changes.

**Step 2: Implement in-memory actors/value stores**

Keep activity and request caches current-run only. Use bounded dictionaries/order arrays and an injectable debounce clock/scheduler. Ensure no secret-bearing DTO is accepted by activity serialization.

**Step 3: Run tests and commit**

Commit as `feat(mcp): add observable idempotent runtime`.

## Task 5: Persist MCP enabled state and trusted-client records safely

**Files:**

- Create: `Sources/Core/MCP/MCPSettings.swift`
- Create: `Sources/Core/MCP/MCPTrust.swift`
- Create: `Sources/Core/Services/MCPCredentialStoring.swift`
- Create: `Sources/Direct/Security/KeychainMCPCredentialStore.swift`
- Modify: `Sources/Core/Services/SettingsStoring.swift`
- Modify: `Sources/Core/Services/UserDefaultsSettingsStore.swift`
- Modify: `Tests/Support/Fakes.swift`
- Test: `Tests/Unit/MCPSettingsTests.swift`
- Test: `Tests/Unit/MCPTrustStoreTests.swift`

**Step 1: Write failing tests**

Assert MCP defaults off, corrupt values fall back off, enable persistence, trusted-client encode/decode, non-synchronizing Keychain attributes, update/last-seen, revoke, forget, forget-all, and persistence across store recreation.

**Step 2: Implement storage boundaries**

Store only the enable flag in app preferences. Store trust records in Keychain through `MCPCredentialStoring`. Provide an in-memory fake; keep Security framework code in Direct.

**Step 3: Run tests and commit**

Commit as `feat(mcp): persist integration trust settings`.

## Task 6: Implement pairing state machine and P-256 challenge-response

**Files:**

- Create: `Sources/Core/MCP/MCPPairingCoordinator.swift`
- Create: `Sources/Core/MCP/MCPAuthentication.swift`
- Create: `Sources/Direct/Security/SecurityClientIdentityVerifier.swift`
- Create: `Sources/MCPHelper/Security/KeychainClientKeyStore.swift`
- Create: `Sources/MCPHelper/Security/ParentProcessIdentity.swift`
- Test: `Tests/Unit/MCPPairingTests.swift`
- Test: `Tests/Unit/MCPSecurityAdapterTests.swift`

**Step 1: Write failing cryptographic/state tests**

Cover unique nonce per connection, valid/invalid signatures, transcript binding, replay rejection, unpaired pending state, approval, verified identity binding, unsigned warning, parent identity change, revoked rejection, and no private key in exported configuration.

**Step 2: Implement pure pairing coordinator**

Use injected nonce generation, signature verifier, trust store, and clock. Model pending/approved/revoked transitions explicitly. Zero transient secret bytes where practical.

**Step 3: Implement platform adapters**

Use CryptoKit P-256 signatures and Security APIs for code-signing identity and Keychain storage. Mark private keys this-device-only and non-synchronizing.

**Step 4: Run tests and commit**

Commit as `feat(mcp): authenticate and pair local clients`.

## Task 7: Define secure NSXPC DTOs and interfaces

**Files:**

- Create: `Sources/Core/MCP/XPC/MCPXPCProtocol.swift`
- Create: `Sources/Core/MCP/XPC/MCPXPCDTO.swift`
- Create: `Sources/Core/MCP/XPC/MCPXPCCodec.swift`
- Test: `Tests/Unit/MCPXPCTests.swift`

**Step 1: Write failing secure-coding tests**

Round-trip every DTO with `requiringSecureCoding: true`; reject unexpected classes, oversized payloads, unknown schema versions, expired deadlines, missing authentication, and malformed JSON payload data.

**Step 2: Implement interfaces**

Define app service, helper callback, authentication, request, response, subscription, and close DTOs. Keep classes `final`, properties immutable after decode, and allowed classes explicit.

**Step 3: Run tests and commit**

Commit as `feat(mcp): define hardened xpc contract`.

## Task 8: Establish and verify the direct anonymous XPC channel

**Files:**

- Create: `Sources/Direct/MCP/MCPXPCListener.swift`
- Create: `Sources/Direct/MCP/MCPXPCConnection.swift`
- Create: `Sources/MCPHelper/XPC/MCPXPCClient.swift`
- Test: `Tests/Integration/MCPXPCIntegrationTests.swift`
- Modify: `project.yml`

**Step 1: Add an integration test target and failing tests**

Prove absent/invalidated endpoint handling, no app launch, authentication-before-status, timeout/cancellation, reconnect with a fresh endpoint, and active connection closure on revoke/disable.

**Step 2: Implement listener/client**

The anonymous listener delegates authentication to `MCPPairingCoordinator` and commands to `MCPControlService`. The client accepts an endpoint provider, maps absent/invalidated state to `APP_NOT_RUNNING`, and reconnects only with a freshly obtained endpoint. A bundled broker endpoint provider is added in Task 9 because Apple only permits `NSXPCListenerEndpoint` transfer over an existing XPC connection.

**Step 3: Run integration tests and commit**

Commit as `feat(mcp): bridge helper with authenticated xpc`.

## Task 9: Add the official MCP Swift SDK helper target

**Files:**

- Modify: `project.yml`
- Modify: `MacCoffee.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- Create: `Sources/MCPHelper/main.swift`
- Create: `Sources/MCPHelper/MCPServerAdapter.swift`
- Create: `Sources/MCPHelper/MCPToolAdapter.swift`
- Create: `Sources/MCPHelper/MCPResourceAdapter.swift`
- Create: `Sources/MCPHelper/Diagnostics.swift`
- Test: `Tests/Integration/MCPStdioProtocolTests.swift`

**Step 1: Pin the dependency and create the target**

Add `https://github.com/modelcontextprotocol/swift-sdk` at exact `0.12.1`. Create command-line target `MacCoffeeMCP`, macOS 13, Swift 6, product name `MacCoffeeMCP`, `SKIP_INSTALL=YES`.

**Step 2: Write failing process-level protocol tests**

Launch the built helper with pipes. Test initialize/version negotiation, list tools/resources, status read, malformed framing, cancellation, unavailable app error, stderr diagnostics, and that every stdout line/frame parses as protocol output.

**Step 3: Implement the SDK adapter**

Expose the approved six tools, three resources, and status subscriptions. Convert MCP SDK content to/from versioned Core DTOs. The adapter must contain no app business rules.

**Step 4: Run tests and commit**

Commit as `feat(mcp): add stdio helper using official sdk`.

## Task 10: Embed the helper in Direct and prove App Store separation

**Files:**

- Modify: `project.yml`
- Modify: `Config/Direct.entitlements`
- Modify: `Config/AppStore.entitlements`
- Modify: `scripts/verify-bundles.sh`
- Modify: `scripts/verify-release-assets.sh`
- Test: `Tests/Unit/CompositionTests.swift`
- Test: `Tests/Unit/ReleaseAssetTests.swift`

**Step 1: Write failing build-structure tests**

Assert Direct contains `Contents/Helpers/MacCoffeeMCP`, nested helper signing precedes outer signing, App Store has no helper/MCP SDK/MCP Direct resources, and exact helper/app version compatibility values exist.

**Step 2: Add target dependency/copy phase**

Embed the built executable only in `MacCoffeeDirect`. Do not add sandbox exceptions or network entitlements. Update release scripts to inspect architectures and nested code signatures.

**Step 3: Build both distributions and commit**

Expected: Direct and App Store Debug builds pass with `CODE_SIGNING_ALLOWED=NO`; separation tests pass. Commit as `build(mcp): embed helper in direct distribution`.

## Task 11: Compose MCP lifecycle into the Direct app

**Files:**

- Modify: `Sources/Core/State/AppEnvironment.swift`
- Create: `Sources/Direct/MCP/DirectMCPEnvironment.swift`
- Modify: `Sources/Direct/MacCoffeeDirectApp.swift`
- Modify: `Sources/AppStore/MacCoffeeAppStoreApp.swift`
- Test: `Tests/Unit/CompositionTests.swift`
- Test: `Tests/Unit/AppModelTests.swift`

**Step 1: Write failing composition/lifecycle tests**

Assert one shared `AppModel`, MCP off by default, enable creates and registers the listener, disable unregisters the broker endpoint/closes connections, termination shuts listener before assertion release, helper failure does not alter session, and App Store environment has no MCP environment.

**Step 2: Implement Direct-only composition**

Create all MCP objects once in Direct app startup and inject the shared `AppModel`/localization. Add explicit `startIfEnabled`, `setEnabled`, and `prepareForTermination` lifecycle.

**Step 3: Run tests and commit**

Commit as `feat(mcp): integrate direct app lifecycle`.

## Task 12: Build the native MCP Settings and pairing UI

**Files:**

- Create: `Sources/Direct/MCP/MCPSettingsView.swift`
- Create: `Sources/Direct/MCP/MCPPairingView.swift`
- Create: `Sources/Direct/MCP/MCPActivityView.swift`
- Create: `Sources/Direct/MCP/MCPSettingsViewModel.swift`
- Modify: `Sources/Core/Views/SettingsView.swift`
- Modify: `Sources/Direct/MacCoffeeDirectApp.swift`
- Test: `Tests/UI/MacCoffeeUITests.swift`

**Step 1: Add failing Direct/App Store UI tests**

Cover Direct section presence, App Store absence, master switch, pending pairing identity/warning, approve/reject, trusted client badges, last seen, revoke/forget, current activity, keyboard navigation, VoiceOver labels, and layout in en/ru/zh-Hans.

**Step 2: Implement adaptive native UI**

Use `GroupBox`, `LabeledContent`, `Toggle`, tables/lists, sheets, confirmation dialogs, and `ViewThatFits`. Add stable identifiers beginning `mcp.`. Never expose raw keys, signatures, endpoint paths, or config file contents outside the reviewed setup preview.

**Step 3: Run UI tests and commit**

Commit as `feat(mcp): add pairing and trust settings`.

## Task 13: Implement safe configuration setup for Codex and Claude Desktop

**Files:**

- Create: `Sources/Direct/MCP/Setup/MCPClientKind.swift`
- Create: `Sources/Direct/MCP/Setup/MCPConfigurationPlanning.swift`
- Create: `Sources/Direct/MCP/Setup/CodexConfigurationPlanner.swift`
- Create: `Sources/Direct/MCP/Setup/ClaudeConfigurationPlanner.swift`
- Create: `Sources/Direct/MCP/Setup/AtomicConfigurationInstaller.swift`
- Create: `Sources/Direct/MCP/Setup/MCPSetupWizard.swift`
- Test: `Tests/Unit/MCPConfigurationTests.swift`
- Fixtures: `Tests/Fixtures/MCPConfigs/*`

**Step 1: Write fixture-driven failing tests**

Cover empty/existing Codex TOML, empty/existing Claude JSON, unrelated entries/comments, duplicate Mac Coffee entry, malformed file, symlink, permissions, backup name, atomic failure recovery, exact proposed diff, validation, generic command, and no secret material.

**Step 2: Implement planners without writes**

Return a `ConfigurationChangePlan` containing path, before/after representation, validation result, and exact diff. Preserve unrelated data; refuse lossy TOML edits when comment preservation cannot be guaranteed and fall back to manual instructions.

**Step 3: Implement confirmed installer and wizard**

The installer accepts only an explicitly confirmed plan hash, creates a timestamped backup, writes/validates a sibling temporary file, and atomically replaces the target. Never launch/restart clients.

**Step 4: Run tests and commit**

Commit as `feat(mcp): add confirmed client setup wizard`.

## Task 14: Complete eight-language MCP localization

**Files:**

- Modify: `Resources/Shared/{en,ru,de,fr,zh-Hans,ja,ko,es}.lproj/Localizable.strings`
- Modify: `Sources/Direct/MCP/*.swift`
- Modify: `Sources/Direct/MCP/Setup/*.swift`
- Test: `Tests/Unit/LocalizationTests.swift`
- Test: `Tests/Unit/RuntimeLocalizationTests.swift`
- Test: `Tests/UI/MacCoffeeUITests.swift`

**Step 1: Make localization parity tests fail on the complete MCP key manifest**

Include Settings, setup, pairing, verification warning, errors, activity, accessibility, status, and confirmation strings. Verify `%d`, `%@`, and positional placeholder parity.

**Step 2: Add professional translations**

Keep product name `Mac Coffee` untranslated. Use native language names. Ensure a live language change updates open MCP Settings/pairing UI and future `displayText` without changing PID or active session.

**Step 3: Run all localization/UI tests and commit**

Commit as `l10n(mcp): localize integration in eight languages`.

## Task 15: Rebuild repository documentation in English, Russian, and Chinese

**Files:**

- Rewrite: `README.md`, `README.ru.md`, `README.zh-Hans.md`
- Remove: `README.de.md`, `README.es.md`, `README.fr.md`, `README.ja.md`, `README.ko.md`
- Rewrite English: `PRIVACY.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/CONTRIBUTING.md`, `docs/CODE_OF_CONDUCT.md`, `docs/APP_STORE_SUBMISSION.md`, `docs/APP_STORE_REVIEW_NOTES.md`, `docs/RELEASE_CHECKLIST.md`, `docs/LEGACY_CLEANUP.md`
- Create translations: `docs/ru/*.md`, `docs/zh-Hans/*.md`, `PRIVACY.ru.md`, `PRIVACY.zh-Hans.md`
- Keep unchanged: `LICENSE`
- Test: `Tests/Unit/ReleaseAssetTests.swift`

**Step 1: Write failing documentation manifest/link tests**

Assert exactly three README languages, translation navigation, every maintained explanatory doc has ru/zh-Hans peer, valid local links, English-default GitHub entry, upstream fork attribution at each README bottom, MIT license unchanged, and no stale feature/version claims.

**Step 2: Rewrite canonical English docs**

Document installation, usage, features, sleep modes, low-battery safety, language switching, Direct/App Store differences, MCP architecture/setup/security/troubleshooting, development, tests, release process, privacy, and limitations.

**Step 3: Translate faithfully to Russian and Simplified Chinese**

Keep commands, identifiers, file names, code, legal license, and machine enums unchanged. Add cross-language navigation.

**Step 4: Remove obsolete language READMEs recoverably and commit**

Use the system trash for the five obsolete README files after tests identify exact paths. Commit as `docs: publish canonical en ru zh documentation`.

## Task 16: Replace screenshot composition with measured production layouts

**Files:**

- Rewrite: `Tools/Screenshots/main.swift`
- Create: `Tools/Screenshots/ScreenshotScenario.swift`
- Create: `Tools/Screenshots/ScreenshotLayout.swift`
- Create: `Tools/Screenshots/ScreenshotValidator.swift`
- Modify: `scripts/generate-screenshots.sh`
- Test: `Tests/Unit/ScreenshotAssetTests.swift`

**Step 1: Write failing manifest and geometry tests**

Assert 15 expected outputs, 1280×800, opaque sRGB PNG, only en/ru/zh-Hans, correct App Store/docs scenarios, no MCP in App Store, named safe-area containment, no required-frame intersections, and identical hashes across two renders.

**Step 2: Build reusable measured scenes**

Host production views in real offscreen `NSWindow`s. Use adaptive grids, safe-area preference keys, and measured anchors. Create restrained native desktop/marketing frames without hard-coded arbitrary offsets.

**Step 3: Generate and visually inspect every image**

Generate 6 metadata screenshots and 9 docs screenshots. Inspect contact sheets and each full-resolution locale/scenario. Iterate until all text, controls, shadows, and windows align.

**Step 4: Run determinism validation and commit**

Commit as `design: regenerate deterministic product screenshots`.

## Task 17: Reduce store metadata to three release locales

**Files:**

- Rewrite: `metadata/en-US/*`, `metadata/ru/*`, `metadata/zh-Hans/*`
- Remove: `metadata/de-DE`, `metadata/es-ES`, `metadata/fr-FR`, `metadata/ja`, `metadata/ko`
- Modify: `scripts/verify-release-assets.sh`
- Modify: `Tests/Unit/ReleaseAssetTests.swift`

**Step 1: Update tests to expect exactly three metadata locales**

Validate required files, field limits, screenshot count/format, URL syntax, product name, absence of Direct-only MCP claims, and matching version/release notes.

**Step 2: Rewrite the three metadata sets**

English is canonical. Russian and Simplified Chinese are faithful. App Store descriptions include only App Store-shippable features.

**Step 3: Trash obsolete directories and commit**

After exact path verification, move the five metadata locale directories to Trash and report recoverability. Commit as `store: maintain en ru zh metadata only`.

## Task 18: Harden protocol, build, and release validation

**Files:**

- Modify: `scripts/build-local.sh`
- Modify: `scripts/package-dmg.sh`
- Modify: `scripts/release-direct.sh`
- Modify: `scripts/verify-bundles.sh`
- Modify: `scripts/verify-release-assets.sh`
- Create: `scripts/smoke-test-mcp.sh`
- Modify: `docs/RELEASE_CHECKLIST.md` and translations
- Test: `Tests/Integration/MCPStdioProtocolTests.swift`

**Step 1: Add failing negative checks**

Make scripts fail for missing/wrong-arch helper, unsigned nested code, mismatched versions, unexpected App Store helper/SDK, non-JSON stdout, secret in generated config, extra docs/metadata locales, and invalid screenshots.

**Step 2: Implement universal/signing/package flow**

Build arm64 and x86_64 helper/app slices, create universal binaries, sign inside-out with Hardened Runtime, verify designated requirements, then package. Keep notarization conditional on real Developer ID credentials.

**Step 3: Add live smoke flow**

Exercise app absent, app running/MCP disabled, enabled/unpaired, approve, status, mutation, subscription, revoke, disable, and clean termination. Use a temporary isolated preferences/config environment where possible.

**Step 4: Run scripts and commit**

Commit as `build: harden mcp release validation`.

## Task 19: Run the complete verification matrix

**Files:** No intended production changes; fix only evidence-backed failures with new regression tests.

**Step 1: Regenerate project and resolve dependencies**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -resolvePackageDependencies \
  -project MacCoffee.xcodeproj -scheme MacCoffeeDirect
```

Expected: MCP SDK resolves exactly to 0.12.1.

**Step 2: Run unit/integration tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: zero failures.

**Step 3: Run UI tests**

Run `MacCoffeeUITests` for Direct and required locale launch arguments. Expected: zero failures and no leaked Mac Coffee processes.

**Step 4: Build Direct and App Store for both architectures**

Build Debug and Release for `ARCHS=arm64` and `ARCHS=x86_64`, then universal release artifacts. Expected: all builds succeed and separation scripts pass.

**Step 5: Run release, docs, localization, and screenshot checks**

```bash
scripts/generate-screenshots.sh
scripts/verify-release-assets.sh
scripts/verify-bundles.sh <direct-app-path> <app-store-app-path>
scripts/smoke-test-mcp.sh <direct-app-path>
```

Expected: every check reports success; repeated screenshot generation produces identical hashes.

**Step 6: Commit only necessary fixes**

Use narrowly scoped commits that name the failing invariant.

## Task 20: Install locally, review, and prepare the canonical pull request

**Files:**

- Create: `docs/PULL_REQUEST.md`, `docs/ru/PULL_REQUEST.md`, `docs/zh-Hans/PULL_REQUEST.md`
- Update: `docs/RELEASE_CHECKLIST.md` and translations
- Update only if verified: README version/install status

**Step 1: Build and install the current Direct app**

Use `scripts/build-local.sh` and its recoverable `/Applications/Mac Coffee.app` replacement flow. Preserve/restore the previous app on failure. Do not claim notarization for an ad-hoc build.

**Step 2: Perform real local smoke testing**

Launch the installed app, verify the menu item, UI modes/timers/languages/quit, enable MCP, pair a disposable test client, call every v1 tool/resource, test subscription/revocation, disable MCP, and confirm all assertions release on quit.

**Step 3: Deep review the full branch diff**

Check correctness, security, concurrency, privacy, App Store separation, user-visible copy, localization, accessibility, packaging, binary contents, and repository cleanliness. Resolve every actionable finding with a regression test.

**Step 4: Prepare PR copy**

`docs/PULL_REQUEST.md` contains summary, user impact, architecture, security model, screenshots, test evidence with exact commands/results, migration/rollback, App Store boundary, known limitations, and checklist. Add faithful ru/zh-Hans review translations.

**Step 5: Final cleanliness check**

```bash
git status --short
git diff --check
git log --oneline --decorate -20
```

Expected: clean worktree, no whitespace errors, no generated junk/secrets, coherent commits.

**Step 6: Finish branch**

Use `superpowers:verification-before-completion`, then `superpowers:requesting-code-review`, then `superpowers:finishing-a-development-branch`. Create or update the canonical pull request only after the user authorizes the external GitHub write if that authorization is not already explicit.
