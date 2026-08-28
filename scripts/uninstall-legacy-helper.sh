#!/bin/zsh
set -euo pipefail

legacy_helper='/Library/PrivilegedHelperTools/com.elliotwu.maccoffee.helper'
legacy_plist='/Library/LaunchDaemons/com.elliotwu.maccoffee.helper.plist'
legacy_socket='/var/run/com.elliotwu.maccoffee.helper.sock'

for target in "$legacy_helper" "$legacy_plist" "$legacy_socket"; do
  case "$target" in
    /Library/PrivilegedHelperTools/com.elliotwu.maccoffee.helper|\
    /Library/LaunchDaemons/com.elliotwu.maccoffee.helper.plist|\
    /var/run/com.elliotwu.maccoffee.helper.sock) ;;
    *)
      print -u2 "Refusing unexpected cleanup target: $target"
      exit 65
      ;;
  esac
done

print "This removes only the Mac Coffee 1.x privileged helper and restores battery disablesleep to 0."
/usr/bin/sudo -v
/usr/bin/sudo /bin/launchctl bootout system/com.elliotwu.maccoffee.helper >/dev/null 2>&1 || true
/usr/bin/sudo /bin/rm -f "$legacy_helper" "$legacy_plist" "$legacy_socket"
/usr/bin/sudo /usr/bin/pmset -b disablesleep 0

print "Legacy Mac Coffee helper removed. Other power settings were not changed."
