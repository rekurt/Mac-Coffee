# Mac Coffee 2.0

Lightweight, native macOS menu-bar control for keeping a Mac awake on your terms.

[Русский](README.ru.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [简体中文](README.zh-Hans.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

![Mac Coffee menu-bar panel](docs/images/panel-en.png)

Mac Coffee 2.0 is a security-focused rewrite of the original utility. It uses public, process-owned IOKit power assertions instead of a privileged helper or persistent `pmset` changes. The app starts Off, changes macOS idle-sleep behavior only after an explicit choice, and releases every assertion when the session ends or the app terminates.

## Features

- Three clear modes: **Off**, **Keep Mac Awake**, and **Keep Display Awake**.
- Timed sessions for 30 minutes, 1, 2, 4, or 8 hours, plus an indefinite session.
- Configurable low-battery cutoff from 10% to 30%, with a 15% default and hysteresis to avoid rapid state changes.
- Immediate assertion release when a timer expires, battery protection activates, the user turns the mode Off, or the app terminates.
- Launch at Login through the public `SMAppService` API.
- Local notifications for completed sessions and low-battery stops.
- Instant language switching without restarting the process or interrupting an active wake session.
- System language selection with an English fallback for unsupported macOS languages.
- English, Russian, German, French, Simplified Chinese, Japanese, Korean, and Spanish interface localizations.
- Localized Settings, About, confirmation dialogs, notifications, errors, countdowns, and accessibility labels.
- One localized confirmation flow for the footer Quit action and `⌘Q`.
- Separate Direct and Mac App Store products; Sparkle exists only in the Direct build.
- Universal `arm64` and `x86_64` Release builds.
- No administrator privileges, daemon, account, analytics, advertising, activity simulation, or backend.

Mac Coffee prevents idle sleep only. Manual Sleep, lid closure, shutdown, restart, thermal protection, and other macOS safety decisions always remain effective.

## Screenshots

| Active wake session | Localized settings |
| --- | --- |
| ![Active English session](docs/images/panel-en.png) | ![Russian settings](docs/images/settings-ru.png) |

Reproducible 1280×800 App Store screenshots for every supported language live in [`metadata`](metadata). Regenerate them from the production localization resources and representative application states with `./scripts/generate-screenshots.sh`.

## Requirements

- macOS 13 Ventura or later.
- A full Xcode installation for source builds.
- Homebrew and the build tools in [`Brewfile`](Brewfile).

## Install and use

Official signed downloads will appear under [Releases](https://github.com/rekurt/Mac-Coffee/releases). Until a signed and notarized release is published, build locally:

```sh
brew bundle
./scripts/build-local.sh direct
open "dist/local/Mac Coffee.app"
```

1. Open the Mac Coffee status item in the menu bar; its icon reflects the current wake mode.
2. Choose **Keep Mac Awake** or **Keep Display Awake**.
3. Choose a duration. Selecting another duration updates the active session immediately.
4. Choose **Off** to release the wake request.
5. Use **Settings** to select the interface language, battery cutoff, and Launch at Login behavior.

The local build is ad-hoc signed for testing on the current Mac. It is not an official distributable artifact and must not be published as a release.

## Architecture and distribution boundaries

| Component | Responsibility |
| --- | --- |
| `MacCoffeeCore` | Domain model, IOKit assertions, battery/lifecycle adapters, localization, and SwiftUI views |
| `MacCoffeeDirect` | Direct-distribution composition root and Sparkle update UI |
| `MacCoffeeAppStore` | Sandboxed App Store composition root with no alternate updater |
| `MacCoffeeTests` | Unit, integration, resource, localization, and real IOKit boundary tests |
| `MacCoffeeUITests` | Localized panel, Settings, timer, footer, and quit-flow scenarios |
| `MacCoffeeScreenshots` | Developer-only deterministic renderer; never shipped in either app |

Wake sessions use `IOPMAssertionCreateWithName`. Assertions belong to the app process, so macOS also removes them if the process crashes. Battery state comes from IOPowerSources notifications; there is no idle polling loop. Preferences remain in UserDefaults and contain no activity history.

See [Architecture](docs/ARCHITECTURE.md), [Privacy](PRIVACY.md), and [App Store submission](docs/APP_STORE_SUBMISSION.md) for the detailed boundaries.

## Build and verify

```sh
brew bundle
xcodegen generate

./scripts/build-local.sh direct
./scripts/build-local.sh app-store
./scripts/verify-release-assets.sh
./scripts/verify-bundles.sh
```

Run the automated test suite:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
  -project MacCoffee.xcodeproj \
  -scheme MacCoffeeTests \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

The XCUITest scheme requires an unlocked interactive desktop. CI builds the same two products and exercises UI scenarios when macOS permits accessibility event delivery.

Create a local smoke-test DMG:

```sh
./scripts/package-dmg.sh
open dist/local/MacCoffee-2.0.0.dmg
```

## Release paths

The Direct release script refuses to continue without a Developer ID certificate, notarization credentials, an HTTPS appcast URL, and a Sparkle EdDSA key:

```sh
./scripts/release-direct.sh
```

The App Store archive path is isolated from Sparkle and requires an Apple Developer Team ID plus valid App Store signing assets:

```sh
MACCOFFEE_APP_STORE_TEAM=YOUR_TEAM_ID ./scripts/archive-app-store.sh
```

Neither script stores credentials in the repository. See the [release checklist](docs/RELEASE_CHECKLIST.md) before publishing or submitting anything.

## Privacy and security

Mac Coffee collects and transmits no personal data. The Direct build accesses the network only through Sparkle when the user asks to check for an update; the App Store build contains no third-party updater.

Report security issues privately according to the [security policy](docs/SECURITY.md). For bugs and support questions, use [GitHub Issues](https://github.com/rekurt/Mac-Coffee/issues).

## Upgrading from 1.x

Version 2.0 never installs or invokes the original privileged helper. If Mac Coffee 1.x was previously installed, follow the explicit, administrator-authorized [legacy cleanup guide](docs/LEGACY_CLEANUP.md). The cleanup script is not bundled with either application and never runs automatically.

## Contributing and license

Contributions are welcome. Read [CONTRIBUTING.md](docs/CONTRIBUTING.md) and the [Code of Conduct](docs/CODE_OF_CONDUCT.md) before opening a pull request.

Mac Coffee is available under the [MIT License](LICENSE).

Forked from [Elliotwu-7/Mac-Coffee](https://github.com/Elliotwu-7/Mac-Coffee).
