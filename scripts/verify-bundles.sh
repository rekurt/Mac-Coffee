#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"
direct_app="${MACCOFFEE_DIRECT_APP_PATH:-$ROOT_DIR/dist/local/Mac Coffee.app}"
store_app="${MACCOFFEE_APP_STORE_APP_PATH:-$ROOT_DIR/dist/local-app-store/Mac Coffee.app}"

for app_path in "$direct_app" "$store_app"; do
  [[ -d "$app_path" ]] || {
    print -u2 "Missing bundle: $app_path"
    exit 66
  }
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$app_path"
  /usr/bin/lipo "$app_path/Contents/MacOS/Mac Coffee" -verify_arch arm64 x86_64
  /usr/bin/lipo "$app_path/Contents/Frameworks/MacCoffeeCore.framework/Versions/A/MacCoffeeCore" -verify_arch arm64 x86_64
  [[ -f "$app_path/Contents/Resources/PrivacyInfo.xcprivacy" ]]
  [[ -f "$app_path/Contents/Resources/en.lproj/Localizable.strings" ]]
  [[ -f "$app_path/Contents/Resources/ru.lproj/Localizable.strings" ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$app_path/Contents/Info.plist")" == true ]]
done

[[ -d "$direct_app/Contents/Frameworks/Sparkle.framework" ]] || {
  print -u2 "Direct bundle does not contain Sparkle."
  exit 65
}
/usr/bin/lipo "$direct_app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle" -verify_arch arm64 x86_64

if /usr/bin/find "$store_app" \( -iname '*Sparkle*' -o -iname '*Updater*' \) -print | /usr/bin/grep -q .; then
  print -u2 "App Store bundle contains an alternate updater."
  exit 65
fi
if /usr/bin/otool -L "$store_app/Contents/MacOS/Mac Coffee" | /usr/bin/grep -q Sparkle; then
  print -u2 "App Store executable links Sparkle."
  exit 65
fi
if /usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$store_app/Contents/Info.plist" >/dev/null 2>&1; then
  print -u2 "App Store Info.plist exposes a Sparkle feed."
  exit 65
fi

if /usr/bin/grep -R -n -E 'pmset|disablesleep|administrator privileges' \
  "$ROOT_DIR/Sources" "$ROOT_DIR/Resources/Shared" "$ROOT_DIR/Resources/Direct" "$ROOT_DIR/Resources/AppStore"; then
  print -u2 "Runtime source contains a forbidden privileged power-management path."
  exit 65
fi

[[ ! -e "$ROOT_DIR/Sources/MacCoffeeHelper.swift" ]]
[[ ! -e "$ROOT_DIR/Resources/install_helper.sh" ]]

print "Verified Direct and App Store bundles."
