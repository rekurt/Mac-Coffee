# Mac Coffee 2.0

Lightweight, native macOS menu-bar control for keeping a Mac awake on your terms.

**English** · [Русский](README.ru.md) · [简体中文](README.zh-Hans.md)

![Mac Coffee menu-bar panel](docs/images/panel-en.png)

Mac Coffee is a privacy-first rewrite of the original utility. It uses public, process-owned IOKit power assertions: no privileged helper, persistent `pmset` changes, account, analytics, or backend. The app starts Off and releases every assertion when a session ends or the process terminates.

## Highlights

- **Three explicit modes:** Off, Keep Mac Awake, and Keep Display Awake.
- **Flexible sessions:** 30 minutes, 1, 2, 4, or 8 hours, plus indefinite.
- **Battery protection:** configurable cutoff from 10% to 30%, with a safe 15% default and hysteresis.
- **Native macOS integration:** Launch at Login through `SMAppService`, local notifications, VoiceOver labels, and one confirmation flow for the footer Quit action and `⌘Q`.
- **Instant localization:** System, English, Russian, German, French, Simplified Chinese, Japanese, Korean, and Spanish; switching language never restarts or interrupts an active session.
- **Direct updates:** Sparkle checks in the background, shows one unobtrusive update note per version, and keeps the manual Check for Updates action in Settings.
- **Optional local MCP control:** the Direct build can expose Mac Coffee to Codex, Claude Desktop, or another stdio MCP client after explicit enablement and pairing.
- **Two distribution boundaries:** a universal Direct build with Sparkle and MCP, and a sandboxed Mac App Store build containing neither.

Mac Coffee prevents idle sleep only. Manual Sleep, lid closure, shutdown, restart, thermal protection, and other macOS safety decisions always remain effective.

## Screenshots

| Active wake session | Localized settings |
| --- | --- |
| ![Active English session](docs/images/panel-en.png) | ![Russian settings](docs/images/settings-ru.png) |

Reproducible 1280×800 App Store screenshots are maintained for English, Russian, and Simplified Chinese under [`metadata`](metadata). The application interface itself remains available in all eight languages. Regenerate the images from production SwiftUI views with:

```sh
./scripts/generate-screenshots.sh
```

## Requirements

- macOS 13 Ventura or later.
- A full Xcode installation for source builds.
- Homebrew and the tools declared in [`Brewfile`](Brewfile).

## Install and use

Signed and notarized Direct builds will appear under [Releases](https://github.com/rekurt/Mac-Coffee/releases). Until one is published, build locally:

```sh
brew bundle
./scripts/build-local.sh direct
open "dist/local/Mac Coffee.app"
```

1. Open the Mac Coffee status item in the menu bar.
2. Choose Keep Mac Awake or Keep Display Awake.
3. Choose a duration; changing it updates the active session immediately.
4. Choose Off to release the wake request.
5. Open Settings to change the language, battery cutoff, Launch at Login, updates, or the optional MCP integration.

The local build is ad-hoc signed for testing on the current Mac. It is not a distributable release artifact.

## Local MCP server (Direct build)

Mac Coffee ships an optional, disabled-by-default stdio MCP server. Enable it in **Settings → AI & automation**, open the setup wizard, review the proposed diff, and confirm installation for Codex or Claude Desktop. A generic stdio configuration is available for other clients.

The server never launches Mac Coffee automatically. A client must pair with the running app, and Mac Coffee shows pending requests, trusted clients, revocation controls, and a bounded local activity log. Credentials are stored in Keychain; connections are limited to the current macOS user and validated across the embedded helper, broker, and app boundary.

Available tools:

- `maccoffee_get_status`
- `maccoffee_set_session`
- `maccoffee_stop_session`
- `maccoffee_set_battery_threshold`
- `maccoffee_set_launch_at_login`
- `maccoffee_set_language`

Available resources:

- `maccoffee://status`
- `maccoffee://capabilities`
- `maccoffee://activity`

See the complete [MCP setup, security model, schemas, and troubleshooting guide](docs/MCP.md).

## Architecture

| Component | Responsibility | Ships in |
| --- | --- | --- |
| `MacCoffeeCore` | Domain model, IOKit assertions, battery/lifecycle adapters, localization, and shared SwiftUI views | Direct |
| `MacCoffeeAppStoreCore` | Store-safe core compiled without MCP symbols | App Store |
| `MacCoffeeDirect` | Direct composition root, Sparkle update note, MCP settings and lifecycle | Direct |
| `MacCoffeeMCP` | Embedded stdio MCP helper using the official Swift MCP SDK | Direct |
| `MacCoffeeMCPBroker` | Embedded XPC broker that lets the helper locate a running app instance | Direct |
| `MacCoffeeAppStore` | Sandboxed Store composition root with no alternate updater or MCP artifacts | App Store |
| `MacCoffeeScreenshots` | Deterministic developer-only renderer of production views | Never |

Wake sessions use `IOPMAssertionCreateWithName`. Assertions belong to the process, so macOS also removes them if it crashes. Battery state comes from IOPowerSources notifications rather than polling. Preferences contain no activity history; MCP activity is bounded and kept only in memory.

Read [Architecture](docs/ARCHITECTURE.md), [Privacy](PRIVACY.md), [Security](docs/SECURITY.md), and [App Store submission](docs/APP_STORE_SUBMISSION.md) for the detailed boundaries.

## Build and verify

```sh
brew bundle
xcodegen generate

./scripts/build-local.sh direct
./scripts/build-local.sh app-store
./scripts/verify-release-assets.sh
./scripts/verify-bundles.sh
```

Run the automated suite:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
  -project MacCoffee.xcodeproj \
  -scheme MacCoffeeTests \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

XCUITests require an unlocked interactive desktop. CI builds both shipping products and exercises UI scenarios whenever macOS permits accessibility event delivery.

Create a local smoke-test DMG:

```sh
./scripts/package-dmg.sh
open dist/local/MacCoffee-2.0.0.dmg
```

## Release paths

The Direct release script refuses to continue without a Developer ID certificate, notarization credentials, an HTTPS appcast URL, and a Sparkle EdDSA public key:

```sh
./scripts/release-direct.sh
```

The App Store archive is isolated from Sparkle and MCP and requires an Apple Developer Team ID plus valid App Store signing assets:

```sh
MACCOFFEE_APP_STORE_TEAM=YOUR_TEAM_ID ./scripts/archive-app-store.sh
```

Neither path stores credentials in the repository. Complete the [release checklist](docs/RELEASE_CHECKLIST.md) before publishing or submitting anything.

## Privacy and security

Mac Coffee collects no personal data. The Direct build contacts only the configured Sparkle HTTPS appcast for scheduled or manual update checks. MCP communication stays local to the current macOS account; the App Store build has no MCP helper, broker, Sparkle framework, or alternate update path.

Report vulnerabilities privately according to the [security policy](docs/SECURITY.md). For bugs and support questions, use [GitHub Issues](https://github.com/rekurt/Mac-Coffee/issues).

## Upgrading from 1.x

Version 2.0 never installs or invokes the original privileged helper. If Mac Coffee 1.x was previously installed, follow the explicit, administrator-authorized [legacy cleanup guide](docs/LEGACY_CLEANUP.md). The cleanup script is not bundled with either application and never runs automatically.

## Contributing and license

Contributions are welcome. Read [Contributing](docs/CONTRIBUTING.md) and the [Code of Conduct](docs/CODE_OF_CONDUCT.md) before opening a pull request.

Mac Coffee is available under the [MIT License](LICENSE).

Forked from [Elliotwu-7/Mac-Coffee](https://github.com/Elliotwu-7/Mac-Coffee).
