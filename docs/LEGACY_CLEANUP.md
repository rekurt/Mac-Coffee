# Removing the Mac Coffee 1.x helper

Mac Coffee 2.0 does not install or require a privileged helper. If version 1.x was installed previously, its helper may remain on the Mac and its battery `disablesleep` setting may still be enabled.

Inspect the exact legacy state first:

```sh
ls -l /Library/PrivilegedHelperTools/com.elliotwu.maccoffee.helper \
      /Library/LaunchDaemons/com.elliotwu.maccoffee.helper.plist \
      /var/run/com.elliotwu.maccoffee.helper.sock 2>/dev/null
pmset -g custom | grep disablesleep
```

Then run the standalone cleanup script from this repository:

```sh
./scripts/uninstall-legacy-helper.sh
```

The script asks for administrator authorization, unloads only `com.elliotwu.maccoffee.helper`, removes only the three paths listed above, and runs `pmset -b disablesleep 0`. It does not modify unrelated power settings. Mac Coffee 2.0 never runs this script automatically and does not include it inside the application bundle.
