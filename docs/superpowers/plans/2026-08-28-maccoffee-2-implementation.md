# Mac Coffee 2.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the unlaunchable, privileged upstream Mac Coffee 1.0.1 bundle with a native, tested Mac Coffee 2.0 menu-bar app that uses public IOKit assertions and ships separate Direct and Mac App Store targets.

**Architecture:** A shared `MacCoffeeCore` framework owns domain state, IOKit adapters, battery safety, timers, settings, and SwiftUI views. Two thin application targets compose the framework with either Sparkle (`MacCoffeeDirect`) or no alternate updater (`MacCoffeeAppStore`). `project.yml` is the XcodeGen source of truth, and release scripts refuse to publish an unsigned or unnotarized direct build.

**Tech Stack:** Swift 6, SwiftUI, AppKit, IOKit/IOPMLib, IOPowerSources, ServiceManagement, UserNotifications, OSLog, XCTest/XCUITest, Xcode 26.6, XcodeGen 2.46.0, Sparkle 2.9.4.

**Spec:** `docs/superpowers/specs/2026-08-28-maccoffee-design.md`

## Global Constraints

- Product display name is `Mac Coffee`; code prefix is `MacCoffee`.
- Marketing version is `2.0.0`, build number is `1`.
- Minimum deployment target is macOS 13.0.
- Standard architectures are `arm64` and `x86_64`; no script may hardcode an arm64-only release.
- Direct bundle identifier is `com.rekurt.maccoffee.direct`.
- Mac App Store bundle identifier is `com.rekurt.maccoffee`.
- Runtime code uses no root helper, daemon, `pmset`, AppleScript privilege escalation, activity simulation, analytics, account, or backend.
- The only third-party runtime dependency is Sparkle 2.9.4, linked only by `MacCoffeeDirect`.
- Active mode is never persisted; every process launch starts off.
- English and Russian localizations are complete.
- Commands that use Xcode set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` instead of changing global `xcode-select` state.

---

### Task 1: Deterministic Xcode project and domain foundation

**Files:**
- Create: `Brewfile`
- Create: `project.yml`
- Create: `Config/Shared.xcconfig`
- Create: `Config/Direct.xcconfig`
- Create: `Config/AppStore.xcconfig`
- Create: `Config/Direct.entitlements`
- Create: `Config/AppStore.entitlements`
- Create: `Sources/Core/Domain/WakeMode.swift`
- Create: `Sources/Core/Domain/SessionDuration.swift`
- Create: `Sources/Core/Domain/WakeSession.swift`
- Create: `Sources/Core/Domain/BatteryState.swift`
- Create: `Tests/Unit/DomainTests.swift`
- Delete: `Sources/MacCoffeeHelper.swift`
- Delete: `Resources/install_helper.sh`

**Interfaces:**
- Produces: `WakeMode`, `SessionDuration`, `WakeSession`, `BatteryState`, `PowerSource`.
- Produces build targets: `MacCoffeeCore`, `MacCoffeeDirect`, `MacCoffeeAppStore`, `MacCoffeeTests`, `MacCoffeeUITests`.

- [ ] **Step 1: Install and pin project generation tooling**

```ruby
# Brewfile
brew "xcodegen"
```

Run: `brew bundle && test "$(xcodegen --version)" = "Version: 2.46.0"`
Expected: XcodeGen reports exactly `Version: 2.46.0`.

- [ ] **Step 2: Define the project and distribution boundaries**

Create `project.yml` with a macOS 13 deployment target, Swift 6, standard architectures, the exact five targets above, Sparkle package pinned to `2.9.4`, and Sparkle linked only to `MacCoffeeDirect`. Include the two app resource directories and make both app targets depend on `MacCoffeeCore`.

```yaml
name: MacCoffee
options:
  minimumXcodeGenVersion: 2.46.0
  deploymentTarget:
    macOS: "13.0"
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    exactVersion: 2.9.4
targets:
  MacCoffeeCore:
    type: framework
    platform: macOS
    sources: [Sources/Core]
    settings:
      base: { PRODUCT_BUNDLE_IDENTIFIER: com.rekurt.maccoffee.core }
  MacCoffeeDirect:
    type: application
    platform: macOS
    sources: [Sources/Direct]
    resources: [Resources/Shared, Resources/Direct]
    dependencies:
      - target: MacCoffeeCore
      - package: Sparkle
    configFiles: { Debug: Config/Direct.xcconfig, Release: Config/Direct.xcconfig }
  MacCoffeeAppStore:
    type: application
    platform: macOS
    sources: [Sources/AppStore]
    resources: [Resources/Shared, Resources/AppStore]
    dependencies: [{ target: MacCoffeeCore }]
    configFiles: { Debug: Config/AppStore.xcconfig, Release: Config/AppStore.xcconfig }
```

- [ ] **Step 3: Write failing domain tests**

```swift
import XCTest
@testable import MacCoffeeCore

final class DomainTests: XCTestCase {
    func testDurationPresetsHaveExactIntervals() {
        XCTAssertEqual(SessionDuration.minutes30.interval, 1_800)
        XCTAssertEqual(SessionDuration.hours1.interval, 3_600)
        XCTAssertEqual(SessionDuration.hours2.interval, 7_200)
        XCTAssertEqual(SessionDuration.hours4.interval, 14_400)
        XCTAssertEqual(SessionDuration.hours8.interval, 28_800)
        XCTAssertNil(SessionDuration.indefinite.interval)
    }

    func testFiniteSessionUsesAbsoluteExpiration() {
        let start = Date(timeIntervalSince1970: 1_000)
        let session = WakeSession(mode: .system, startedAt: start, duration: .minutes30)
        XCTAssertEqual(session.expiresAt, Date(timeIntervalSince1970: 2_800))
    }
}
```

- [ ] **Step 4: Generate project and verify the tests fail**

Run: `xcodegen generate && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS'`
Expected: FAIL because the domain types do not exist.

- [ ] **Step 5: Implement immutable domain values**

```swift
public enum WakeMode: String, CaseIterable, Sendable {
    case off, system, display
}

public enum SessionDuration: String, CaseIterable, Sendable {
    case minutes30, hours1, hours2, hours4, hours8, indefinite
    public var interval: TimeInterval? {
        switch self {
        case .minutes30: 1_800
        case .hours1: 3_600
        case .hours2: 7_200
        case .hours4: 14_400
        case .hours8: 28_800
        case .indefinite: nil
        }
    }
}

public struct WakeSession: Equatable, Sendable {
    public let mode: WakeMode
    public let startedAt: Date
    public let expiresAt: Date?
    public init(mode: WakeMode, startedAt: Date, duration: SessionDuration) {
        self.mode = mode
        self.startedAt = startedAt
        self.expiresAt = duration.interval.map(startedAt.addingTimeInterval)
    }
}
```

- [ ] **Step 6: Verify project generation, tests, and target isolation**

Run: `xcodegen generate && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS'`
Expected: PASS.

Run: `rg -n 'Sparkle' project.yml Config Sources/AppStore`
Expected: Sparkle appears in the package definition and Direct target only, never under `Sources/AppStore` or App Store configuration.

- [ ] **Step 7: Commit**

```bash
git add Brewfile project.yml Config Sources/Core Tests/Unit Sources/MacCoffeeHelper.swift Resources/install_helper.sh MacCoffee.xcodeproj
git commit -m "build: establish Mac Coffee 2.0 targets"
```

### Task 2: Low-battery policy and persisted preferences

**Files:**
- Create: `Sources/Core/Policy/LowBatteryPolicy.swift`
- Create: `Sources/Core/Services/SettingsStoring.swift`
- Create: `Sources/Core/Services/UserDefaultsSettingsStore.swift`
- Create: `Tests/Unit/LowBatteryPolicyTests.swift`
- Create: `Tests/Unit/SettingsStoreTests.swift`

**Interfaces:**
- Produces: `LowBatteryPolicy.nextBlockedState(currentlyBlocked:battery:threshold:) -> Bool`.
- Produces: `SettingsStoring.selectedDuration`, `batteryThreshold`, and `launchAtLoginRequested`.

- [ ] **Step 1: Write policy boundary tests**

```swift
func testBatteryAtThresholdBlocks() {
    let state = BatteryState(powerSource: .battery, percentage: 15, hasInternalBattery: true)
    XCTAssertTrue(LowBatteryPolicy.nextBlockedState(currentlyBlocked: false, battery: state, threshold: 15))
}

func testHysteresisRequiresThresholdPlusTwo() {
    let sixteen = BatteryState(powerSource: .battery, percentage: 16, hasInternalBattery: true)
    let eighteen = BatteryState(powerSource: .battery, percentage: 18, hasInternalBattery: true)
    XCTAssertTrue(LowBatteryPolicy.nextBlockedState(currentlyBlocked: true, battery: sixteen, threshold: 15))
    XCTAssertFalse(LowBatteryPolicy.nextBlockedState(currentlyBlocked: true, battery: eighteen, threshold: 15))
}

func testACAndDesktopNeverBlock() {
    XCTAssertFalse(LowBatteryPolicy.nextBlockedState(currentlyBlocked: true, battery: .acDesktop, threshold: 15))
}
```

- [ ] **Step 2: Run policy tests and verify failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' -only-testing:MacCoffeeTests/LowBatteryPolicyTests`
Expected: FAIL because `LowBatteryPolicy` is undefined.

- [ ] **Step 3: Implement threshold, clamping, and settings defaults**

```swift
public enum LowBatteryPolicy {
    public static func nextBlockedState(
        currentlyBlocked: Bool,
        battery: BatteryState,
        threshold: Int
    ) -> Bool {
        guard battery.hasInternalBattery, battery.powerSource == .battery,
              let percentage = battery.percentage else { return false }
        let safeThreshold = min(30, max(10, threshold))
        return currentlyBlocked ? percentage <= safeThreshold + 2 : percentage <= safeThreshold
    }
}
```

Store only duration, threshold, notification prompt state, and launch preference in the app's defaults domain. Do not define a key for mode or session.

- [ ] **Step 4: Verify all policy and settings tests pass**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Core/Policy Sources/Core/Services Tests/Unit
git commit -m "feat: add battery safety and preferences"
```

### Task 3: Process-owned IOKit power assertions

**Files:**
- Create: `Sources/Core/Services/PowerAssertionManaging.swift`
- Create: `Sources/Core/Services/IOKitPowerAssertionManager.swift`
- Create: `Tests/Unit/PowerAssertionManagerTests.swift`
- Create: `Tests/Support/FakePowerAssertionDriver.swift`

**Interfaces:**
- Produces: `PowerAssertionManaging.activeMode`, `transition(to:) throws`, and `releaseAll()`.
- Produces: internal `PowerAssertionDriving.create(type:name:)` and `release(id:)` seam for deterministic tests.

- [ ] **Step 1: Write transition and rollback tests**

```swift
func testSystemModeUsesIdleSystemAssertion() throws {
    let driver = FakePowerAssertionDriver()
    let manager = IOKitPowerAssertionManager(driver: driver)
    try manager.transition(to: .system)
    XCTAssertEqual(driver.createdTypes, [kIOPMAssertionTypePreventUserIdleSystemSleep as String])
    XCTAssertEqual(manager.activeMode, .system)
}

func testReplacementIsCreatedBeforePreviousRelease() throws {
    let driver = FakePowerAssertionDriver()
    let manager = IOKitPowerAssertionManager(driver: driver)
    try manager.transition(to: .system)
    try manager.transition(to: .display)
    XCTAssertEqual(driver.events, [.create(.system), .create(.display), .release(1)])
}

func testCreationFailureKeepsConfirmedMode() throws {
    let driver = FakePowerAssertionDriver(failCreateAtCall: 2)
    let manager = IOKitPowerAssertionManager(driver: driver)
    try manager.transition(to: .system)
    XCTAssertThrowsError(try manager.transition(to: .display))
    XCTAssertEqual(manager.activeMode, .system)
}
```

- [ ] **Step 2: Run the assertion tests and verify failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' -only-testing:MacCoffeeTests/PowerAssertionManagerTests`
Expected: FAIL because the assertion manager is undefined.

- [ ] **Step 3: Implement the IOKit adapter**

Use `IOPMAssertionCreateWithName` with level `kIOPMAssertionLevelOn`, a stable name no longer than 128 characters, and these exact mappings:

```swift
private func assertionType(for mode: WakeMode) -> CFString {
    switch mode {
    case .system: kIOPMAssertionTypePreventUserIdleSystemSleep
    case .display: kIOPMAssertionTypePreventUserIdleDisplaySleep
    case .off: preconditionFailure("Off has no assertion type")
    }
}
```

Track the confirmed active assertion and a set of release IDs that need retry. `transition(to: .off)` reports failure if the active assertion cannot be released. `releaseAll()` retries every tracked ID and is called from termination handling.

- [ ] **Step 4: Run tests and inspect a real assertion**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS'`
Expected: PASS.

The runtime smoke test in Task 9 must confirm the assertion with `pmset -g assertions`; no implementation code may execute `pmset`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Core/Services Tests/Unit/PowerAssertionManagerTests.swift Tests/Support/FakePowerAssertionDriver.swift
git commit -m "feat: manage sleep with IOKit assertions"
```

### Task 4: Event-driven platform services

**Files:**
- Create: `Sources/Core/Services/BatteryMonitoring.swift`
- Create: `Sources/Core/Services/IOKitBatteryMonitor.swift`
- Create: `Sources/Core/Services/SessionScheduling.swift`
- Create: `Sources/Core/Services/TaskSessionScheduler.swift`
- Create: `Sources/Core/Services/LaunchAtLoginManaging.swift`
- Create: `Sources/Core/Services/SMAppLaunchAtLoginManager.swift`
- Create: `Sources/Core/Services/NotificationSending.swift`
- Create: `Sources/Core/Services/UserNotificationSender.swift`
- Create: `Sources/Core/Services/LifecycleObserving.swift`
- Create: `Sources/Core/Services/AppLifecycleObserver.swift`
- Create: `Tests/Unit/PlatformAdapterTests.swift`

**Interfaces:**
- `BatteryMonitoring` publishes initial and changed `BatteryState` without polling.
- `SessionScheduling.schedule(deadline:action:)` sleeps until one absolute deadline and supports cancellation.
- `LaunchAtLoginManaging` reflects `SMAppService.mainApp.status`.
- `NotificationSending` requests authorization once and sends timer/battery events.
- `LifecycleObserving` publishes wake, clock change, activation, and termination.

- [ ] **Step 1: Write tests against service seams**

```swift
func testBatteryDescriptionUsesCurrentOverMaximumCapacity() {
    let description: [String: Any] = [
        kIOPSTransportTypeKey: kIOPSInternalType,
        kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
        kIOPSCurrentCapacityKey: 40,
        kIOPSMaxCapacityKey: 80
    ]
    XCTAssertEqual(IOKitBatteryMonitor.parse(description: description).percentage, 50)
}

func testSchedulerCancellationPreventsAction() async {
    let clock = FakeSessionClock()
    let scheduler = TaskSessionScheduler(clock: clock)
    var fired = false
    scheduler.schedule(deadline: Date(timeIntervalSince1970: 10)) { fired = true }
    scheduler.cancel()
    await clock.resumeAll()
    XCTAssertFalse(fired)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' -only-testing:MacCoffeeTests/PlatformAdapterTests`
Expected: FAIL because the platform adapters are undefined.

- [ ] **Step 3: Implement battery notifications and lifecycle hooks**

Register `IOPSNotificationCreateRunLoopSource` on the main run loop and parse the internal source from `IOPSCopyPowerSourcesInfo`, `IOPSCopyPowerSourcesList`, and `IOPSGetPowerSourceDescription`. Register AppKit/Workspace notifications for wake, `NSSystemClockDidChange`, activation, and termination. Remove every observer and run-loop source in `stop()`/`deinit`.

- [ ] **Step 4: Implement login and local notification adapters**

```swift
public func setEnabled(_ enabled: Bool) throws {
    let service = SMAppService.mainApp
    if enabled { try service.register() } else { try service.unregister() }
}
```

Map `SMAppService.Status` to a UI state and keep notification denial nonfatal.

- [ ] **Step 5: Run full tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS'`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/Core/Services Tests/Unit/PlatformAdapterTests.swift Tests/Support
git commit -m "feat: add event driven macOS services"
```

### Task 5: Session state machine and safety orchestration

**Files:**
- Create: `Sources/Core/State/AppModel.swift`
- Create: `Sources/Core/State/AppEnvironment.swift`
- Create: `Tests/Unit/AppModelTests.swift`
- Create: `Tests/Support/Fakes.swift`

**Interfaces:**
- Produces `@MainActor final class AppModel: ObservableObject` with `mode`, `session`, `selectedDuration`, `batteryState`, `isBatteryBlocked`, `statusMessage`, and `isBusy`.
- Produces user intents: `setMode(_:)`, `selectDuration(_:)`, `setBatteryThreshold(_:)`, `setLaunchAtLogin(_:)`, `revalidateDeadline()`, and `prepareForTermination()`.

- [ ] **Step 1: Write state-machine tests**

```swift
@MainActor
func testEveryLaunchStartsOff() {
    let settings = FakeSettingsStore(savedDuration: .hours4)
    let model = AppModel(environment: .fake(settings: settings))
    XCTAssertEqual(model.mode, .off)
    XCTAssertNil(model.session)
}

@MainActor
func testModeSwitchPreservesDeadline() throws {
    let model = AppModel(environment: .fake(now: Date(timeIntervalSince1970: 1_000)))
    model.selectDuration(.hours1)
    try model.setMode(.system)
    let deadline = model.session?.expiresAt
    try model.setMode(.display)
    XCTAssertEqual(model.session?.expiresAt, deadline)
}

@MainActor
func testLowBatteryStopsAndNotifies() throws {
    let environment = AppEnvironment.fake()
    let model = AppModel(environment: environment)
    try model.setMode(.system)
    environment.battery.emit(.init(powerSource: .battery, percentage: 15, hasInternalBattery: true))
    XCTAssertEqual(model.mode, .off)
    XCTAssertTrue(model.isBatteryBlocked)
    XCTAssertEqual(environment.notifications.events, [.lowBatteryStopped])
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' -only-testing:MacCoffeeTests/AppModelTests`
Expected: FAIL because `AppModel` is undefined.

- [ ] **Step 3: Implement confirmed transitions and absolute deadlines**

`setMode` must check battery block, call `PowerAssertionManaging.transition`, and publish the new mode only after success. Switching between active modes copies the existing `expiresAt`; choosing a new duration creates a new session from `now()` and reschedules the deadline. Timer completion and battery cutoff call the same private stop path with different notification reasons.

```swift
public func revalidateDeadline() {
    guard let deadline = session?.expiresAt, deadline <= environment.now() else { return }
    stop(reason: .timerCompleted)
}
```

- [ ] **Step 4: Test failure rollback, rapid intents, and termination cleanup**

Add cases proving a failed assertion creation keeps the prior mode, an assertion release failure remains visible, and `prepareForTermination()` cancels the scheduler and calls `releaseAll()`.

- [ ] **Step 5: Run all tests and commit**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS'`
Expected: PASS.

```bash
git add Sources/Core/State Tests/Unit/AppModelTests.swift Tests/Support
git commit -m "feat: orchestrate wake sessions safely"
```

### Task 6: Native menu-bar UI, settings, accessibility, and localization

**Files:**
- Create: `Sources/Core/Views/MenuBarPanel.swift`
- Create: `Sources/Core/Views/ModePicker.swift`
- Create: `Sources/Core/Views/DurationPicker.swift`
- Create: `Sources/Core/Views/CountdownText.swift`
- Create: `Sources/Core/Views/SettingsView.swift`
- Create: `Sources/Core/Views/AboutView.swift`
- Create: `Sources/Core/Views/MenuBarLabel.swift`
- Create: `Resources/Shared/en.lproj/Localizable.strings`
- Create: `Resources/Shared/ru.lproj/Localizable.strings`
- Create: `Resources/Shared/PrivacyInfo.xcprivacy`
- Create: `Resources/Shared/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Reuse: `Resources/AppIcon.iconset/*.png`
- Create: `Tests/Unit/LocalizationTests.swift`
- Create: `Tests/UI/MacCoffeeUITests.swift`

**Interfaces:**
- Produces reusable SwiftUI views driven only by `AppModel` and optional `UpdaterProviding`.
- Produces stable accessibility identifiers prefixed with `maccoffee.`.

- [ ] **Step 1: Write localization completeness test**

```swift
func testEnglishAndRussianContainRequiredKeys() throws {
    let required = Set(["mode.off", "mode.system", "mode.display", "duration.indefinite",
                        "battery.blocked", "settings.launchAtLogin", "action.quit"])
    XCTAssertTrue(try keys(in: "en").isSuperset(of: required))
    XCTAssertEqual(try keys(in: "en"), try keys(in: "ru"))
}
```

- [ ] **Step 2: Run localization test and verify failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' -only-testing:MacCoffeeTests/LocalizationTests`
Expected: FAIL because the localization resources are absent.

- [ ] **Step 3: Build the 320-point window-style panel**

Use a three-state segmented picker, duration presets `30m/1h/2h/4h/8h/∞`, power status, deadline, nonfatal status banner, Settings, About, update (when injected), and Quit. Implement dynamic countdown refresh only while visible: minute cadence above 60 seconds and second cadence in the final minute.

- [ ] **Step 4: Add settings and accessible state labels**

Battery threshold uses a 10...30 integer stepper/slider and is hidden on desktops. Launch at Login reflects service status. Menu symbols are `moon.zzz`, `bolt.circle`, and `display`; every state also has text and a localized VoiceOver value.

- [ ] **Step 5: Add resources and run tests**

Create complete English and Russian strings, a privacy manifest with no tracking/data collection and UserDefaults reason `CA92.1`, and an asset catalog that references all existing icon PNG sizes.

Run: `xcodegen generate && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS'`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/Core/Views Resources/Shared Tests/Unit/LocalizationTests.swift Tests/UI project.yml MacCoffee.xcodeproj
git commit -m "feat: add localized accessible menu bar UI"
```

### Task 7: Direct and App Store compositions

**Files:**
- Create: `Sources/Core/Services/UpdaterProviding.swift`
- Create: `Sources/Direct/MacCoffeeDirectApp.swift`
- Create: `Sources/Direct/SparkleUpdater.swift`
- Create: `Sources/AppStore/MacCoffeeAppStoreApp.swift`
- Create: `Resources/Direct/Info.plist`
- Create: `Resources/AppStore/Info.plist`
- Create: `Resources/AppStore/PrivacyInfo.xcprivacy`
- Create: `Tests/Unit/CompositionTests.swift`
- Delete: `Sources/MacCoffeeApp.swift`
- Delete: `Info.plist`

**Interfaces:**
- Direct composition provides `SparkleUpdater` around `SPUStandardUpdaterController`.
- App Store composition passes no updater and exposes no update action.

- [ ] **Step 1: Write composition boundary tests**

```swift
func testAppStoreBundleHasNoUpdateCapability() {
    let environment = AppEnvironment.appStoreForTesting()
    XCTAssertNil(environment.updater)
}

func testDirectBundleUsesUpdaterCapability() {
    let updater = FakeUpdater()
    let environment = AppEnvironment.directForTesting(updater: updater)
    XCTAssertNotNil(environment.updater)
}
```

- [ ] **Step 2: Run composition tests and verify failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' -only-testing:MacCoffeeTests/CompositionTests`
Expected: FAIL because target compositions are absent.

- [ ] **Step 3: Implement both `@main` entries**

Each app declares a `MenuBarExtra("Mac Coffee", systemImage: ...)` with `.menuBarExtraStyle(.window)` and a `Settings` scene. Direct constructs `SparkleUpdater`; App Store does not import Sparkle.

- [ ] **Step 4: Verify both bundles build and App Store is Sparkle-free**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project MacCoffee.xcodeproj -scheme MacCoffeeDirect -configuration Debug -destination 'platform=macOS'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project MacCoffee.xcodeproj -scheme MacCoffeeAppStore -configuration Debug -destination 'platform=macOS'
```

Expected: both PASS.

Inspect the App Store build with `find` and `nm`; expected: no `Sparkle.framework`, `Updater.app`, Sparkle XPC service, `SPU` symbol, or appcast key.

- [ ] **Step 5: Commit**

```bash
git add Sources/Direct Sources/AppStore Sources/Core/Services Resources/Direct Resources/AppStore Tests/Unit project.yml MacCoffee.xcodeproj Sources/MacCoffeeApp.swift Info.plist
git commit -m "feat: compose direct and App Store applications"
```

### Task 8: Safe local builds, signed releases, and legacy cleanup

**Files:**
- Create: `scripts/build-local.sh`
- Create: `scripts/package-dmg.sh`
- Create: `scripts/release-direct.sh`
- Create: `scripts/archive-app-store.sh`
- Create: `scripts/verify-bundles.sh`
- Create: `scripts/uninstall-legacy-helper.sh`
- Create: `docs/LEGACY_CLEANUP.md`
- Create: `ExportOptions/DeveloperID.plist`
- Create: `ExportOptions/AppStore.plist`
- Modify: `.github/workflows/release.yml`
- Create: `.github/workflows/ci.yml`
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Delete: `build.sh`
- Delete: `install.sh`
- Delete: `package_dmg.sh`

**Interfaces:**
- `scripts/build-local.sh [direct|app-store]` creates a fully sealed ad-hoc local `.app` after resources are installed.
- `scripts/package-dmg.sh` packages the already verified direct app.
- `scripts/release-direct.sh` requires Developer ID, notarization, HTTPS appcast, and Sparkle EdDSA inputs; it exits nonzero if any are absent.
- `scripts/uninstall-legacy-helper.sh` removes only exact legacy paths and restores `disablesleep 0` after administrator authorization.

- [ ] **Step 1: Write a verification script that fails the upstream bundle**

```zsh
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
lipo -verify_arch arm64 x86_64 "$APP_PATH/Contents/MacOS/MacCoffeeDirect"
if find "$APP_STORE_PATH" -iname '*Sparkle*' -o -iname '*Updater*' | grep -q .; then
  print -u2 "App Store bundle contains an alternate updater"
  exit 1
fi
```

Run the script against the diagnostic upstream app. Expected: FAIL for invalid sealing and missing `x86_64`.

- [ ] **Step 2: Implement local build and DMG packaging**

Run `xcodebuild` with standard architectures and local ad-hoc signing, copy the `.app` with `ditto`, verify it, then create a UDZO DMG containing the app and an `/Applications` symlink. Never publish this local artifact as a GitHub release.

- [ ] **Step 3: Implement credential-gated direct release**

Require these exact environment keys: `MACCOFFEE_DEVELOPER_ID`, `MACCOFFEE_NOTARY_PROFILE`, `MACCOFFEE_APPCAST_URL`, and `MACCOFFEE_SPARKLE_PRIVATE_KEY_FILE`. Archive/export through Xcode, sign the update with Sparkle 2.9.4, submit with `notarytool --wait`, staple the app and DMG, and run Gatekeeper assessment before publication.

- [ ] **Step 4: Implement App Store archive and CI isolation**

CI builds and tests both schemes. Tag release jobs stop before upload when signing/notary secrets are unavailable. The App Store archive uses the App Store export method and never runs Sparkle tooling.

- [ ] **Step 5: Implement explicit legacy cleanup**

The standalone script validates and removes only:

```text
/Library/PrivilegedHelperTools/com.elliotwu.maccoffee.helper
/Library/LaunchDaemons/com.elliotwu.maccoffee.helper.plist
/var/run/com.elliotwu.maccoffee.helper.sock
```

It runs `launchctl bootout system/com.elliotwu.maccoffee.helper`, restores `/usr/bin/pmset -b disablesleep 0`, and leaves all unrelated power settings untouched. The application bundles do not include this script.

- [ ] **Step 6: Verify scripts and commit**

Run: `zsh -n scripts/*.sh && ./scripts/build-local.sh direct && ./scripts/build-local.sh app-store && ./scripts/verify-bundles.sh`
Expected: all commands PASS; both executables contain `arm64` and `x86_64`; both bundles pass strict code-sign verification; App Store contains no Sparkle.

```bash
git add scripts ExportOptions .github README.md README.zh-CN.md docs/LEGACY_CLEANUP.md build.sh install.sh package_dmg.sh
git commit -m "build: add verified Mac Coffee release pipeline"
```

### Task 9: Runtime, UI, performance, and final artifact verification

**Files:**
- Modify: `Tests/UI/MacCoffeeUITests.swift`
- Create: `docs/RELEASE_CHECKLIST.md`
- Create: `docs/APP_STORE_REVIEW_NOTES.md`
- Create: `metadata/en-US/description.txt`
- Create: `metadata/ru/description.txt`
- Create: `metadata/en-US/privacy_url.txt`
- Create: `metadata/ru/privacy_url.txt`

**Interfaces:**
- Produces locally runnable `dist/local/Mac Coffee.app` and `dist/local/MacCoffee-2.0.0.dmg`.
- Produces an evidence log for assertions, signatures, architectures, bundle isolation, tests, and resource budgets.

- [ ] **Step 1: Complete UI tests**

Cover off/system/display selection, all durations, threshold bounds, blocked battery state through launch arguments, Settings, quit confirmation, accessibility identifiers, both localizations, and the absence of update UI in App Store.

- [ ] **Step 2: Run full test and build matrix**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests -destination 'platform=macOS' -enableCodeCoverage YES
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeUITests -destination 'platform=macOS'
./scripts/build-local.sh direct
./scripts/build-local.sh app-store
./scripts/verify-bundles.sh
```

Expected: zero test failures and both verified bundles.

- [ ] **Step 3: Verify real IOKit behavior**

Launch the local Direct app. Activate system mode and confirm `pmset -g assertions` names `Mac Coffee` under `PreventUserIdleSystemSleep`. Activate display mode and confirm `PreventUserIdleDisplaySleep`. Turn off and quit; confirm no Mac Coffee assertion remains. Inspect source with `rg -n 'pmset|disablesleep|administrator privileges' Sources Resources/Shared Resources/Direct Resources/AppStore`; expected: no matches.

- [ ] **Step 4: Verify runtime resources and packaging**

Measure the release process for five idle minutes with the panel closed. Record average CPU, resident memory, and wakeups in `docs/RELEASE_CHECKLIST.md`; acceptance is CPU at or below 0.1% and resident memory below 50 MB. Run `codesign`, `spctl` where applicable, `lipo`, bundle inspection, DMG mount/copy/launch smoke test, English/Russian UI checks, and Sparkle-free App Store inspection.

- [ ] **Step 5: Write store/release metadata**

Document no-data-collection privacy, public IOKit use, explicit login-item consent, battery cutoff, and the boundaries around manual/lid/thermal sleep. Do not claim that Mac Coffee defeats lid-close sleep.

- [ ] **Step 6: Commit and push the feature branch**

```bash
git add Tests docs metadata
git commit -m "test: verify Mac Coffee 2.0 release"
git push -u origin feat/maccoffee-2
```

Expected: the fork branch is available at `https://github.com/rekurt/Mac-Coffee/tree/feat/maccoffee-2` and the local app/DMG are ready for delivery.
