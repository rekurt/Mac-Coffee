# Mac Coffee 2.0 — App Store Review Notes

## Purpose

Mac Coffee is a menu-bar utility that prevents idle sleep while the user explicitly enables a wake session. It supports keeping the Mac awake or keeping both the Mac and display awake for 30 minutes, 1, 2, 4, or 8 hours, or indefinitely.

The utility does not override manual Sleep, lid-close sleep, shutdown, restart, thermal protection, or other macOS safety decisions.

## Review flow

1. Launch Mac Coffee. It appears only in the menu bar and starts in Off mode.
2. Open its coffee-cup menu-bar item.
3. Select **Keep Mac Awake** or **Keep Display Awake** and a duration.
4. Select **Off** to release the power assertion immediately.
5. Open **Settings…** to adjust the 10–30% battery cutoff (15% by default) or explicitly enable Launch at Login.

## Platform APIs and privileges

- Wake sessions use public, process-owned IOKit power assertions (`IOPMAssertionCreateWithName`). Assertions disappear when the app exits or crashes.
- Battery state is read locally through IOPowerSources notifications.
- Launch at Login uses `SMAppService` and is changed only after an explicit user action.
- Local notifications report session expiry and low-battery shutdown. Assertion errors remain local, appear as readable in-app status, and record technical details in the system log.
- The app does not request administrator privileges and includes no privileged helper, daemon, shell command, or activity simulation.

## App Store distribution boundary

The `com.rekurt.maccoffee` App Store target does not link or bundle Sparkle, does not declare an update feed, and presents no alternate update action. The separate Direct target is not submitted to App Review.

## Privacy

No data is collected or transmitted. Battery state and preferences remain on device. There is no account, analytics, tracking, advertising, or backend. See <https://github.com/rekurt/Mac-Coffee/blob/main/PRIVACY.md>.
