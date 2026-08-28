# Mac Coffee 2.0

Mac Coffee is a lightweight native macOS menu-bar app that prevents idle sleep when you choose. Version 2.0 replaces the original privileged helper and persistent `pmset` changes with public, process-owned IOKit power assertions.

> This repository is the maintained fork at [rekurt/Mac-Coffee](https://github.com/rekurt/Mac-Coffee). The upstream 1.0.1 download was arm64-only and not sealed for Gatekeeper, which is why it could fail to launch after a browser download.

## Features

- Three explicit states: Off, Keep Mac Awake, and Keep Display Awake
- 30-minute, 1-hour, 2-hour, 4-hour, 8-hour, and indefinite sessions
- Low-battery cutoff from 10% to 30%, defaulting to 15%, with hysteresis
- Event-driven battery and lifecycle handling—no polling while idle
- Launch at Login through `SMAppService`
- English and Russian localization with VoiceOver identifiers
- No root helper, daemon, analytics, account, backend, or activity simulation
- Separate Direct and Mac App Store targets; Sparkle is present only in Direct
- Universal `arm64` + `x86_64` local builds

Mac Coffee prevents idle sleep only. It does not override manual Sleep, lid closure, thermal protection, shutdown, or other macOS safety decisions.

## Requirements

- macOS 13 or later
- Xcode 26.6 or a compatible full Xcode installation
- Homebrew and XcodeGen 2.46.0 for source builds

## Build and run

```sh
brew bundle
./scripts/build-local.sh direct
open "dist/local/Mac Coffee.app"
```

The local build is ad-hoc signed for testing on this Mac and intentionally omits Hardened Runtime, which requires a real signing identity for nested frameworks. Official Direct and App Store archives keep Hardened Runtime enabled. Create the local DMG with:

```sh
./scripts/package-dmg.sh
open dist/local/MacCoffee-2.0.0.dmg
```

Build the Sparkle-free App Store variant and verify both boundaries:

```sh
./scripts/build-local.sh app-store
./scripts/verify-bundles.sh
```

## Tests

```sh
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeTests \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -project MacCoffee.xcodeproj -scheme MacCoffeeUITests \
  -destination 'platform=macOS'
```

## Signed releases

`scripts/release-direct.sh` intentionally refuses to run without a Developer ID identity, notarytool profile, HTTPS appcast URL, and Sparkle EdDSA private-key file. It archives, exports, verifies Hardened Runtime and release entitlements, notarizes, staples, assesses with Gatekeeper, and generates an EdDSA-signed `appcast.xml` plus a SHA-256 checksum. The ad-hoc local DMG must never be published as an official release.

The tag workflow creates an isolated temporary keychain and requires these GitHub Actions secrets: `MACCOFFEE_DEVELOPER_ID`, `MACCOFFEE_DEVELOPER_ID_P12_BASE64`, `MACCOFFEE_DEVELOPER_ID_P12_PASSWORD`, `MACCOFFEE_NOTARY_APPLE_ID`, `MACCOFFEE_NOTARY_APP_PASSWORD`, `MACCOFFEE_NOTARY_TEAM_ID`, `MACCOFFEE_APPCAST_URL`, and `MACCOFFEE_SPARKLE_PRIVATE_KEY`. It uploads the notarized DMG, checksum, and signed appcast to the same GitHub release.

The App Store pipeline is isolated in `scripts/archive-app-store.sh` and never invokes Sparkle tooling.

## Upgrading from 1.x

Mac Coffee 2.0 never installs or invokes the old privileged helper. If 1.x was installed, read [the explicit legacy cleanup guide](docs/LEGACY_CLEANUP.md). The cleanup is a separate administrator-authorized script and is never bundled or run automatically.

## Privacy

Mac Coffee collects no data and performs no tracking. Direct builds access the network only when the user explicitly checks for a signed update. App Store builds contain no alternate updater.

## License

[MIT](LICENSE)
