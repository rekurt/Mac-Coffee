#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

required=(
  MACCOFFEE_DEVELOPER_ID
  MACCOFFEE_NOTARY_PROFILE
  MACCOFFEE_APPCAST_URL
  MACCOFFEE_SPARKLE_PRIVATE_KEY_FILE
)
for key in $required; do
  [[ -n "${(P)key:-}" ]] || {
    print -u2 "Missing required release setting: $key"
    exit 64
  }
done
[[ "$MACCOFFEE_APPCAST_URL" == https://* ]] || {
  print -u2 "MACCOFFEE_APPCAST_URL must use HTTPS."
  exit 65
}
[[ -f "$MACCOFFEE_SPARKLE_PRIVATE_KEY_FILE" ]] || {
  print -u2 "Sparkle private key file not found."
  exit 66
}

cd "$ROOT_DIR"
xcodegen generate
release_dir="$ROOT_DIR/dist/release"
archive_path="$release_dir/MacCoffee.xcarchive"
export_dir="$release_dir/export"
derived_dir="$ROOT_DIR/build/release-direct"
/bin/mkdir -p "$release_dir"
/bin/rm -rf "$archive_path" "$export_dir" "$derived_dir"

public_key=$(/usr/bin/swift -e '
import CryptoKit
import Foundation
let text = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
let secret = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines))!
if secret.count == 32 {
    let key = try Curve25519.Signing.PrivateKey(rawRepresentation: secret)
    print(key.publicKey.rawRepresentation.base64EncodedString())
} else if secret.count == 96 {
    print(secret.suffix(32).base64EncodedString())
} else {
    FileHandle.standardError.write(Data("Invalid Sparkle key length.\n".utf8))
    exit(65)
}
' "$MACCOFFEE_SPARKLE_PRIVATE_KEY_FILE")

xcodebuild archive \
  -project MacCoffee.xcodeproj \
  -scheme MacCoffeeDirect \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$archive_path" \
  -derivedDataPath "$derived_dir" \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$MACCOFFEE_DEVELOPER_ID" \
  MACCOFFEE_APPCAST_URL="$MACCOFFEE_APPCAST_URL" \
  MACCOFFEE_SPARKLE_PUBLIC_KEY="$public_key"

xcodebuild -exportArchive \
  -archivePath "$archive_path" \
  -exportPath "$export_dir" \
  -exportOptionsPlist "$ROOT_DIR/ExportOptions/DeveloperID.plist"

app_path="$export_dir/Mac Coffee.app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app_path"
/usr/bin/lipo "$app_path/Contents/MacOS/Mac Coffee" -verify_arch arm64 x86_64

notary_zip="$release_dir/MacCoffee-2.0.0-notary.zip"
/bin/rm -f "$notary_zip"
/usr/bin/ditto -c -k --keepParent "$app_path" "$notary_zip"
xcrun notarytool submit "$notary_zip" --keychain-profile "$MACCOFFEE_NOTARY_PROFILE" --wait
xcrun stapler staple "$app_path"
xcrun stapler validate "$app_path"

export MACCOFFEE_APP_PATH="$app_path"
export MACCOFFEE_DMG_PATH="$release_dir/MacCoffee-2.0.0.dmg"
export MACCOFFEE_SIGN_IDENTITY="$MACCOFFEE_DEVELOPER_ID"
"$SCRIPT_DIR/package-dmg.sh"

xcrun notarytool submit "$MACCOFFEE_DMG_PATH" --keychain-profile "$MACCOFFEE_NOTARY_PROFILE" --wait
xcrun stapler staple "$MACCOFFEE_DMG_PATH"
xcrun stapler validate "$MACCOFFEE_DMG_PATH"
/usr/sbin/spctl --assess --type execute --verbose=2 "$app_path"
/usr/sbin/spctl --assess --type open --context context:primary-signature --verbose=2 "$MACCOFFEE_DMG_PATH"

sign_update=$(/usr/bin/find "$derived_dir/SourcePackages/artifacts" -type f -path '*/bin/sign_update' -perm -111 -print -quit)
[[ -x "$sign_update" ]] || {
  print -u2 "Sparkle 2.9.4 sign_update tool was not resolved."
  exit 69
}
"$sign_update" --ed-key-file "$MACCOFFEE_SPARKLE_PRIVATE_KEY_FILE" "$MACCOFFEE_DMG_PATH" \
  | /usr/bin/tee "$release_dir/MacCoffee-2.0.0.sparkle-signature.txt"

print "Release artifacts are signed, notarized, stapled, and ready in: $release_dir"
