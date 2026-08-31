# Mac Coffee MCP Server Design

**Status:** Approved  
**Date:** 2026-08-31  
**Canonical language:** English  
**Related translations:** [Russian](ru/2026-08-31-maccoffee-mcp-design.md), [Simplified Chinese](zh-Hans/2026-08-31-maccoffee-mcp-design.md)

## 1. Objective

Add a professional, local-only Model Context Protocol (MCP) server to the Direct distribution of Mac Coffee. A trusted local MCP client can inspect the current state and control the same `AppModel` that the menu-bar UI uses. The feature must preserve Mac Coffee's lightweight, native character and must not introduce a network listener, cloud service, analytics, or a second source of application state.

The first supported MCP integrations are Codex and Claude Desktop. The transport and public contract remain client-neutral so any local stdio MCP client can use the helper.

## 2. Scope

### 2.1 Included in v1

- A Direct-only helper executable at `Mac Coffee.app/Contents/Helpers/MacCoffeeMCP`.
- MCP over stdio with stdout reserved exclusively for JSON-RPC.
- A private local NSXPC bridge from the helper to the running Direct app.
- One-time pairing and per-client trust/revocation.
- Status, session control, battery threshold, Launch at Login, and language tools.
- Status, capabilities, and current-run activity resources.
- Resource subscriptions for live status updates.
- A native Settings section and setup wizard for MCP.
- Explicitly confirmed configuration installation for Codex and Claude Desktop.
- Current-run-only activity history.
- English, Russian, and Simplified Chinese documentation, screenshots, and store metadata; English is canonical and default.
- Automated unit, integration, protocol, packaging, security, documentation, and screenshot validation.

### 2.2 Explicitly excluded from v1

- App Store distribution of the helper or MCP controls.
- Auto-launching Mac Coffee when an MCP request arrives.
- TCP, HTTP, WebSocket, Bonjour, or any other network transport.
- Remote control, cloud relay, telemetry, or analytics.
- Quit, restart, update, or update-install MCP tools.
- Persistent activity logs.
- Removing German, French, Japanese, Korean, or Spanish from the app UI.
- iPhone, iPad, or Wi-Fi companion control.

## 3. Compatibility baseline

- macOS deployment target remains 13.0.
- Swift language mode remains Swift 6.
- The helper uses the official `modelcontextprotocol/swift-sdk`, pinned exactly to `0.12.1`.
- The SDK adapter advertises and negotiates MCP protocol version `2025-11-25`, which is the version implemented by that SDK release.
- The MCP SDK is isolated behind an adapter so a future protocol/SDK upgrade does not affect the app-domain or XPC contracts.
- Codex and Claude Desktop are tested clients; other conforming local stdio clients are supported on a best-effort basis.

## 4. Architecture

```text
Local MCP client
      │ stdio JSON-RPC
      ▼
MacCoffeeMCP helper (Direct app bundle only)
      │ authenticated NSXPC
      ▼
MCPControlService (@MainActor)
      │ commands and snapshots
      ▼
AppModel (single source of truth)
      │
      ├── IOKit power assertions
      ├── session scheduler
      ├── battery monitor and low-battery policy
      ├── SettingsStoring
      ├── LaunchAtLoginManaging
      └── LocalizationController
```

### 4.1 Module boundaries

`MacCoffeeCore` owns:

- MCP value types, validation, error mapping, activity models, and service protocols.
- The `MCPControlService` that maps authenticated commands to `AppModel` on the main actor.
- Pairing/trust domain logic and abstractions for credential and trust stores.
- No import of the MCP SDK.

`MacCoffeeDirect` owns:

- The NSXPC listener lifecycle.
- Direct-only Settings UI and setup wizard.
- Code-signature and client-identity verification adapters.
- Direct-only composition of MCP services.

`MacCoffeeMCP` owns:

- The official MCP SDK dependency and stdio transport.
- JSON schema exposure, resource handlers, subscriptions, and protocol error conversion.
- Keychain-backed client credentials and client-parent identity collection.
- XPC endpoint discovery, authentication, reconnect, deadline, and cancellation behavior.
- No direct access to IOKit, app settings, Launch at Login, notification APIs, or app-domain persistence.

`MacCoffeeAppStore` has no helper target dependency, no MCP SDK linkage, no MCP Settings section, and no MCP resources in its bundle.

### 4.2 XPC endpoint lifecycle

- The Direct bundle contains a minimal `MacCoffeeMCPBroker.xpc` rendezvous service. It owns no application data, trust records, private keys, or command implementation.
- When MCP is enabled, the Direct app creates an anonymous `NSXPCListener` and registers its `NSXPCListenerEndpoint` with the broker over an existing XPC connection. The app keeps that registration connection alive for exactly the listener lifetime.
- The broker binds registration to the validated Mac Coffee app connection and clears it on invalidation, explicit disable, or orderly termination.
- The helper asks the broker for the current endpoint and then connects directly to the app. Pairing, authentication, status, commands, events, deadlines, and cancellation never transit the broker.
- The helper never launches Mac Coffee. An absent or invalidated app endpoint maps to `APP_NOT_RUNNING`; an already-connected helper receives `MCP_DISABLED` when the app disables the integration.
- Reconnect fetches a fresh endpoint from the broker with bounded exponential backoff and jitter and never changes wake-session state.
- Every connection is authenticated before any state or command request is accepted.

This broker is required by the macOS XPC object-capability model. `NSXPCListenerEndpoint` is a live Mach-port right that Apple supports sending only over an existing XPC connection; it cannot be archived to disk. Likewise, `NSXPCListener(machServiceName:)` is only valid for names advertised by `launchd`, so an application cannot publish an arbitrary per-launch Mach service name. The broker is the smallest supported rendezvous layer and the authenticated app connection remains the sole carrier of application data.

## 5. Public MCP contract

Public identifiers, field names, enum values, and machine-readable errors are stable English. Human-readable `displayText` is localized by the running app using its active language.

### 5.1 Tools

#### `maccoffee_get_status()`

Returns the current status snapshot. It has no side effects.

#### `maccoffee_set_session(mode, duration, requestId?)`

- `mode`: `system` or `display`.
- `duration`: `minutes30`, `hours1`, `hours2`, `hours4`, `hours8`, or `indefinite`.
- Starts a session when off, changes the active mode, and/or changes duration through `AppModel`.
- Never bypasses low-battery or power-assertion behavior.

#### `maccoffee_stop_session(requestId?)`

- Transitions the app to `off` through `AppModel`.
- Requires MCP enabled and a trusted client.
- Does not show an additional confirmation dialog.

#### `maccoffee_set_battery_threshold(percent, requestId?)`

- `percent` must be an integer from 10 through 30.
- Values outside that range are rejected as `INVALID_ARGUMENT`; they are not silently clamped at the MCP boundary.

#### `maccoffee_set_launch_at_login(enabled, requestId?)`

- `enabled` is Boolean.
- Returns the resulting Launch at Login state, including `requiresApproval` or `unavailable`.

#### `maccoffee_set_language(language, requestId?)`

- `language`: `system`, `ru`, `en`, `de`, `fr`, `zh-Hans`, `ja`, `ko`, or `es`.
- The language changes immediately without restarting or altering the active wake session.

### 5.2 Resources

#### `maccoffee://status`

The latest status snapshot. Supports subscriptions. Events are coalesced and monotonically sequenced.

#### `maccoffee://capabilities`

Static and runtime capabilities: app/helper versions, supported schema/protocol versions, available modes/durations/languages, feature availability, and Direct distribution identity.

#### `maccoffee://activity`

An ordered list of MCP activity events for the current app run only. The list is bounded in memory, cleared on app launch, contains no secrets, and is not written to disk.

### 5.3 Response envelope

Every successful tool result and resource snapshot uses a versioned envelope:

```json
{
  "schemaVersion": 1,
  "sequence": 42,
  "timestamp": "2026-08-31T12:00:00Z",
  "requestId": "optional-client-request-id",
  "data": {},
  "displayText": "Localized human-readable summary"
}
```

The status `data` includes:

- `mode`: `off`, `system`, or `display`.
- `session`: null or `{ mode, duration, startedAt, expiresAt }`.
- `selectedDuration`.
- `battery`: `{ powerSource, percentage, hasInternalBattery, threshold, blocked }`.
- `launchAtLogin`: `enabled`, `disabled`, `requiresApproval`, or `unavailable`.
- `language`: selected language plus effective locale.
- `busy`.
- `notice`: null or a stable notice code with localized text.

Dates use RFC 3339 UTC. Unknown battery percentage is JSON null, never a sentinel number.

### 5.4 Error contract

Errors contain a stable code, localized `displayText`, optional structured details, request ID when present, and a retryability flag.

| Code | Meaning | Retryable |
| --- | --- | --- |
| `APP_NOT_RUNNING` | The Direct app is not reachable; the helper does not launch it. | Yes |
| `CLIENT_UNPAIRED` | This client must complete pairing. | No |
| `CLIENT_REVOKED` | This client's trust was revoked. | No |
| `MCP_DISABLED` | MCP integration is disabled in the app. | No |
| `BATTERY_BLOCKED` | Low-battery policy prevents activation. | Yes, after power state changes |
| `INVALID_ARGUMENT` | Tool input failed schema or domain validation. | No |
| `APP_BUSY` | A conflicting state transition is in progress. | Yes |
| `ASSERTION_FAILED` | macOS power assertion transition failed. | Yes |
| `VERSION_MISMATCH` | Helper/app contract versions are incompatible. | No |
| `INTERNAL_ERROR` | An unexpected local failure occurred. | Context dependent |

Internal errors, file paths, key material, and raw system error descriptions are never exposed to an MCP client.

## 6. Security and pairing

### 6.1 Default state

- MCP integration is disabled by default for existing and new installations.
- Enabling it is a deliberate action in the Direct app's Settings.
- Every client requires one-time approval. Enabling MCP does not implicitly trust any client.

### 6.2 Client identity and credentials

- Each configured helper identity owns a P-256 signing key pair.
- The helper stores the private key in the user's Keychain with a non-synchronizing, this-device-only accessibility class.
- The app stores the trusted public key, generated client identifier, display name, verified/unverified parent identity, first-paired time, last-seen time, and revocation state in an app-owned Keychain record.
- No private key or pairing secret is written into Codex/Claude configuration files.

### 6.3 Authentication

1. The helper connects to the current endpoint and presents its protocol version, public key, client metadata, and parent-process identity.
2. The app verifies that the peer executable is the bundled helper using its path, bundle version, code signing identifier, and designated requirement.
3. The app creates a cryptographically random nonce.
4. The helper signs the nonce and connection transcript with its private key.
5. The app verifies the signature and checks the public key against the trust store.
6. An unpaired key creates a visible pairing request; no control or private status data is returned before approval.
7. A revoked key is rejected and cannot silently pair again under the same identifier.

Authentication is repeated for every XPC connection. A successful old connection does not authorize a new one without a fresh nonce.

### 6.4 Parent-client verification

- The helper records its parent process signing Team ID and signing identifier when available.
- Signed Codex/Claude identities are shown to the user and bound to the pairing record.
- Unsigned or unverifiable local clients can be paired only after a prominent warning and are labeled `Unverified local client`.
- A material parent identity change invalidates the session and requires explicit re-approval.

### 6.5 Revocation and disable behavior

- Settings lists clients individually with display name, verification status, last seen, and revoke action.
- Revoking a client immediately closes its active connections and subscriptions.
- Disabling MCP closes all helper connections, unregisters the broker endpoint, and prevents requests without deleting trusted-client records.
- Trust can be deleted explicitly using `Forget client` or `Forget all clients`.

### 6.6 IPC hardening

- XPC DTOs use `NSSecureCoding` with explicit allowed-class lists.
- Requests have deadlines and cancellation propagation.
- Mutating requests accept an optional `requestId`; duplicate IDs within the bounded current-run cache return the original result and do not repeat side effects.
- Status events are coalesced during bursts and include an increasing sequence number.
- Diagnostic logging goes to stderr and unified logging with privacy annotations. stdout contains JSON-RPC only.

## 7. App integration and state behavior

`MCPControlService` is `@MainActor` and invokes public `AppModel` behavior. It never writes settings or platform services directly.

- `set_session` first validates all inputs, then changes mode/duration as one serialized logical command. If either underlying transition fails, the response reflects the reconciled `AppModel` state.
- `stop_session` uses the same off transition as the UI.
- Battery threshold and Launch at Login use `AppModel` APIs.
- Language uses the shared `LocalizationController`; the active session and PID remain unchanged.
- App status events derive from published state, localization changes, and relevant lifecycle updates.
- App termination shuts down the MCP listener before releasing all IOKit assertions through the existing termination path.

The bridge returns `APP_BUSY` rather than interleaving a second mutating request with an active transition. Read-only status remains available from the last committed snapshot.

## 8. Direct Settings experience

The Direct build receives a native `MCP Integration` section. The App Store build does not render this section.

The section contains:

- A master enable switch, off by default.
- Connection state: unavailable, ready, paired clients connected, or error.
- `Set up MCP client…` button.
- Trusted clients list with verification badge, last seen, revoke, and forget actions.
- Current-run activity disclosure.
- A concise local-security explanation and link to the security documentation.

### 8.1 Setup wizard

1. Choose Codex, Claude Desktop, or generic stdio.
2. Show detected configuration path and the exact proposed change.
3. Explain that Mac Coffee must be running and that pairing will be requested on first connection.
4. Require explicit confirmation before editing any external configuration.
5. Write atomically, preserve unrelated configuration/comments where the format permits, create a timestamped backup, and validate the result before replacing the original.
6. Show manual command/config instructions if automatic installation is unavailable.
7. Never launch, restart, or message the client automatically.

The generic setup displays the absolute helper command path and environment-free invocation. No secret is embedded in the command.

## 9. Activity model

The bounded current-run activity list records:

- timestamp and sequence;
- client identifier and display name;
- tool/resource/subscription action;
- success or stable error code;
- request ID when supplied;
- sanitized input summary without secrets.

It does not record key material, signatures, nonces, raw config contents, or internal system error text. Default capacity is 200 entries; oldest entries are discarded first.

## 10. Localization and documentation

### 10.1 Product UI

The application continues to ship all eight UI localizations: Russian, English, German, French, Simplified Chinese, Japanese, Korean, and Spanish, plus System selection. New user-facing MCP strings are translated for all eight languages so the Settings UI, pairing dialogs, errors, accessibility text, and `displayText` change immediately with the selected app language.

### 10.2 Repository documentation

- English files are canonical and use unsuffixed/default paths where one exists.
- Every maintained explanatory document has Russian and Simplified Chinese counterparts.
- README entry points are `README.md`, `README.ru.md`, and `README.zh-Hans.md` only.
- Navigation between the three language versions appears at the top of each document.
- The MIT `LICENSE` remains canonical English legal text and is not unofficially translated.
- German, French, Japanese, Korean, and Spanish README files are removed after their relevant content is merged into the three maintained versions.

### 10.3 App Store metadata

Only `en-US`, `ru`, and `zh-Hans` metadata directories are maintained. The App Store screenshots must not expose Direct-only MCP functionality.

## 11. Screenshot system

All generated screenshots are deterministic, opaque 1280×800 PNGs rendered from production SwiftUI views hosted inside real offscreen `NSWindow` instances.

### 11.1 Outputs

App Store set:

- 2 scenarios × 3 locales = 6 screenshots.
- Scenarios: active menu-bar session and general Settings.
- No MCP UI appears.

Documentation set:

- 3 scenarios × 3 locales = 9 screenshots.
- Scenarios: active session, Settings, and MCP setup/trusted clients.
- Paths: `docs/images/en`, `docs/images/ru`, and `docs/images/zh-Hans`.
- Each README references only its own locale images.

### 11.2 Layout requirements

- Use a restrained native marketing frame around real product UI.
- Named safe areas and an adaptive grid replace arbitrary positional offsets.
- Measure rendered view frames and fail generation if required elements leave their safe area, clip, or unexpectedly intersect.
- Long Russian and Simplified Chinese strings must be verified at the generated size.
- CI validates pixel dimensions, sRGB profile, opacity, expected files, deterministic hashes from repeated renders, and safe-area assertions.

## 12. Packaging and release behavior

- The Direct app build embeds and signs `MacCoffeeMCP` as nested code before the outer app signature.
- The helper version and XPC contract version must be compatible with the containing app.
- Direct archives, DMGs, Sparkle artifacts, Hardened Runtime validation, and notarization checks include the helper.
- App Store archives fail validation if the helper, broker XPC service, MCP SDK, or Direct-only UI/resources are present.
- A launch smoke test verifies the Direct app, the helper's stdio initialization, `APP_NOT_RUNNING`, enabled/running behavior, pairing, a read, a mutation, revocation, and clean shutdown.
- Release validation verifies only `en-US`, `ru`, and `zh-Hans` metadata while continuing to verify all eight app localization resource sets.

## 13. Test strategy

Implementation follows test-driven development. A failing test precedes each production change.

### 13.1 Unit tests

- MCP argument/schema validation and exact enum values.
- Snapshot mapping, unknown battery percentage, launch states, notices, and RFC 3339 dates.
- Error mapping and localization in all eight app languages.
- Current-run activity bounds and sanitization.
- request ID idempotency.
- event sequencing and coalescing.
- pairing state machine, nonce freshness, signature validation, revocation, parent identity changes, and unsigned-client warning.
- settings defaults and persistence.
- config generation/merge/backup/validation for Codex and Claude fixtures.

### 13.2 Integration tests

- Helper ↔ anonymous NSXPC endpoint authentication.
- App absent/invalidated endpoint maps to `APP_NOT_RUNNING` without launching it.
- MCP disabled maps to `MCP_DISABLED`.
- Trusted request reaches the single `AppModel` and produces one side effect.
- status subscriptions follow UI-originated and MCP-originated state changes.
- revocation and disabling MCP close active connections.
- stdout remains valid JSON-RPC under diagnostic failures.

### 13.3 UI and accessibility tests

- Direct-only MCP Settings presence and App Store absence.
- Enable, setup preview, explicit confirmation, pairing, trusted clients, revoke, and activity flows.
- English, Russian, and Simplified Chinese layout checks; all eight languages checked for string presence and accessibility labels.
- Existing quit, timer, battery, Launch at Login, update, and localization scenarios remain green.

### 13.4 Protocol and packaging tests

- MCP initialize, tool listing/calls, resource listing/reads, subscription updates, cancellation, malformed messages, and version mismatch.
- Exact Swift SDK pin and lockfile validation.
- Direct universal build contains the correctly located helper and expected architectures.
- App Store universal build contains no MCP helper/SDK/resources.
- DMG mount/copy/launch smoke test.
- Screenshot completeness, geometry, color profile, opacity, and determinism.
- Three-language documentation link audit and metadata locale audit.

## 14. Rollout and failure policy

- The feature ships disabled by default.
- MCP failures never compromise the menu-bar UI or active power assertion.
- If the listener or trust store fails, MCP becomes unavailable, the user sees a localized status, and the core app continues normally.
- If the helper crashes or disconnects, the app session remains unchanged.
- If the app exits, the helper reports `APP_NOT_RUNNING` and waits for a future reconnect opportunity; it does not retain or simulate state.
- App Store behavior is unchanged except for shared, non-MCP-safe refactors and documentation/store asset updates.

## 15. Definition of done

The design is complete only when:

- all new and existing tests pass;
- Direct and App Store universal builds pass separation checks;
- the helper is authenticated, paired, revocable, and protocol-conformant;
- no network listener, auto-launch, secret-in-config, or secondary state path exists;
- all eight app localizations contain the new UI/error/accessibility keys;
- English, Russian, and Simplified Chinese documentation and screenshots are complete and visually verified;
- App Store metadata contains exactly the three maintained locales and no Direct-only feature claims;
- release, security, architecture, contribution, submission, review-note, and checklist documentation is synchronized;
- a local signed or ad-hoc Direct build is installed and smoke-tested on the development Mac;
- the branch is reviewed and prepared for a canonical pull request without claiming notarization or App Store approval that has not actually occurred.
