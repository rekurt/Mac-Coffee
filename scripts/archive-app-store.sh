#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

[[ -n "${MACCOFFEE_APP_STORE_TEAM:-}" ]] || {
  print -u2 "Missing required setting: MACCOFFEE_APP_STORE_TEAM"
  exit 64
}

cd "$ROOT_DIR"
xcodegen generate
archive_dir="$ROOT_DIR/dist/app-store"
archive_path="$archive_dir/MacCoffeeAppStore.xcarchive"
/bin/mkdir -p "$archive_dir"
/bin/rm -rf "$archive_path" "$archive_dir/export"

xcodebuild archive \
  -project MacCoffee.xcodeproj \
  -scheme MacCoffeeAppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$archive_path" \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  DEVELOPMENT_TEAM="$MACCOFFEE_APP_STORE_TEAM"

xcodebuild -exportArchive \
  -archivePath "$archive_path" \
  -exportPath "$archive_dir/export" \
  -exportOptionsPlist "$ROOT_DIR/ExportOptions/AppStore.plist"

if /usr/bin/find "$archive_path" \( -iname '*Sparkle*' -o -iname '*Updater*' \) -print | /usr/bin/grep -q .; then
  print -u2 "App Store archive contains an alternate updater."
  exit 65
fi
app_path="$archive_path/Products/Applications/Mac Coffee.app"
if ! /usr/bin/codesign -dvv "$app_path" 2>&1 | /usr/bin/grep -q 'flags=.*runtime'; then
  print -u2 "App Store archive does not have Hardened Runtime enabled."
  exit 65
fi
entitlements_file=$(/usr/bin/mktemp -t maccoffee-store-entitlements)
/usr/bin/codesign -d --entitlements - --xml "$app_path" > "$entitlements_file" 2>/dev/null
[[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$entitlements_file")" == true ]] || {
  print -u2 "App Store archive is not sandboxed."
  exit 65
}
if /usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$entitlements_file" >/dev/null 2>&1; then
  print -u2 "App Store archive contains the debug get-task-allow entitlement."
  exit 65
fi
/bin/rm -f "$entitlements_file"
print "App Store archive ready: $archive_path"
