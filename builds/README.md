# Android phone preview

[Download the playable Android APK](https://github.com/Yesgiants/Underworld_Game/raw/refs/heads/main/builds/underworld-android-debug.apk).

This is **0.2.0-mobile-preview**, an offline, debug-signed prototype for
**64-bit ARM Android phones running Android 7.0 (API 24) or newer**. It is an
installable development build, not a Google Play release. Its package identifier
is `org.yesgiants.underworld`. iPhone packaging is not included in this build.

## Install and play

1. Download `underworld-android-debug.apk` on your Android phone.
2. Open the download. If Android asks, allow installation from that browser or
   file manager, then install Underworld.
3. Open the game. Tap a district, open **Orders**, and choose an action.
4. **Next day** settles business income, payroll, rivals, and police activity.
   **Ledger** shows finances and events; **Crew** opens member profiles.
5. Progress autosaves after actions and days. Returning to the app leaves time
   paused. **Menu** contains manual Save/Load, New city, and all debug tools.

The preview retains all existing simulation systems. Skills, assignments,
classes, and optional palette customization shown in earlier concept art remain
future features. Tobacco & Teal is the playable default theme.

Uninstalling deletes local progress. Updating with an APK signed by the same
debug key preserves data; a separately generated debug key may require
uninstalling the previous build. Production signing is a separate release task.

## Rebuild

Use official Godot 4.6.3, its matching Android export templates, a supported JDK,
and Android SDK platform/build tools. Configure the SDK paths and a debug key in
Godot's Editor Settings. Signing material stays outside version control.

The supplied shell workflow uses Bash, ripgrep, GNU timeout, and sha256sum:

```bash
bash scripts/build_android.sh
```

It imports the project, requires all six test suites to complete successfully,
exports the ARM64 APK, and writes its SHA-256 checksum alongside the download.
`--emulator` additionally exports an ignored x86_64 test APK from the same source.
The engine also supports exporting directly from Godot's Export dialog using
the **Android Prototype** preset.

The prebuilt phone APK is retained here to make this first preview easy to
download. The x86_64 emulator APK and private signing files are excluded from Git.

## Validation

Simulation, roster, city, desktop navigation, desktop UI, and native-touch mobile
tests cover the existing rules and the phone workflow. Rendered mobile checks
verify the City and Crew pages. Device-specific performance, real touch feel,
camera cutouts, and virtual keyboard behavior still need testing on physical
phones before a store release.

The x86_64 counterpart installed successfully in the cloud's Android 15
emulator. Full Android gameplay validation was blocked by repeated emulator
system-process hangs under software CPU emulation and graphics-driver limits.
The cloud has no hardware CPU acceleration or connected physical phone.
Installation, exported assets, APK signatures, and the rendered native-touch
test workflow were verified; a complete physical-phone playthrough is pending.
