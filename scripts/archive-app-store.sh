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
print "App Store archive ready: $archive_path"
