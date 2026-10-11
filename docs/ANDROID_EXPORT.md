# Android export guide

**Current status: no APK has been produced.** The project and its Android export preset are ready,
but the machine used for this milestone had no Java JDK, no Android SDK and no Godot export templates
(and could not download them). An export was attempted with the preset in this repo and stopped with
exactly these toolchain errors:

```
ERROR: Cannot export project with preset "Android" due to configuration errors:
No export template found at the expected path:
~/.local/share/godot/export_templates/4.7.2.stable/android_debug.apk
No export template found at the expected path:
~/.local/share/godot/export_templates/4.7.2.stable/android_release.apk
A valid Java SDK path is required in Editor Settings.
Invalid Android SDK path in Editor Settings. Missing 'platform-tools' directory!
Unable to find Android SDK platform-tools' adb command.
Invalid Android SDK path in Editor Settings. Missing 'build-tools' directory!
Unable to find Android SDK build-tools' apksigner command.
```

The preset itself raised no configuration errors. Everything below is free (₹0).

## What the project already does for Android

| Setting | Value | Where |
|---|---|---|
| Renderer | Compatibility (OpenGL ES 3.0) — best support for low-end phones | `project.godot` |
| Min / target SDK | 24 (Android 7.0) / 36 — Godot 4.7.2 defaults | export preset (blank = default) |
| Architectures | `arm64-v8a` + `armeabi-v7a` (older budget phones) | export preset |
| Orientation | Sensor landscape | `display/window/handheld/orientation=4` |
| Screen | Immersive (full screen), UI respects notches/cut-outs | preset + HUD safe-area code |
| Back button | Opens/closes pause; quits from the title screen | `quit_on_go_back=false` + scripts |
| Focus loss | Game auto-pauses when the app is backgrounded | `PauseMenu` |
| Permissions | None requested | preset |
| Package name | `com.avenoxgames.thelastsignal` — **placeholder, confirm before publishing** (cannot be changed after release on Google Play) | preset |
| Version | code `1`, name `0.1.0` | preset |

## One-time setup

Versions below are what Godot **4.7.2** expects (from its Android build configuration:
compileSdk/targetSdk 36, minSdk 24, build-tools 36.1.0, Java 17).

1. **Install Godot 4.7.2** (standard build) from <https://godotengine.org/download>.
2. **Install export templates:** Editor → *Manage Export Templates* → *Download and Install* (4.7.2).
   (Offline alternative: download `Godot_v4.7.2-stable_export_templates.tpz` from the same page and
   use *Install from File*.)
3. **Install a JDK 17** (free), e.g. Eclipse Temurin 17 from <https://adoptium.net>.
4. **Install the Android SDK** (free). Easiest: install Android Studio and use its SDK Manager; or use the
   command-line tools only:
   ```bash
   # after unpacking Android "cmdline-tools" into $ANDROID_HOME/cmdline-tools/latest
   sdkmanager --licenses
   sdkmanager "platform-tools" "build-tools;36.1.0" "platforms;android-36" "cmdline-tools;latest"
   ```
   (The NDK, CMake and Gradle are only needed for *custom Gradle builds*, which this project does not use.)
5. **Point Godot at them:** Editor → *Editor Settings* → *Export → Android*:
   * `Java SDK Path` → your JDK 17 folder
   * `Android SDK Path` → your Android SDK folder (must contain `platform-tools/` and `build-tools/`)
6. **Debug keystore:** Godot normally creates/uses a debug keystore automatically. If it asks for one:
   ```bash
   keytool -genkeypair -v -keystore debug.keystore -storepass android -alias androiddebugkey \
     -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
   ```
   and set *Editor Settings → Export → Android → Debug Keystore* (user `androiddebugkey`, password `android`).

## Build a debug APK (for testing on a phone)

* In the editor: *Project → Export… → Android → Export Project* (tick *Export With Debug*), choose
  `builds/android/the-last-signal-debug.apk`.
* Or from a terminal:
  ```bash
  godot --headless --path . --export-debug "Android" builds/android/the-last-signal-debug.apk
  ```
* Install on a phone with USB debugging enabled: `adb install -r builds/android/the-last-signal-debug.apk`
  (or use the editor's one-click deploy button that appears when a device is connected).

`builds/` is git-ignored — never commit APKs/AABs.

## Release builds (later, for Google Play)

1. Create a **release keystore** and keep it (and its passwords) **out of the repository** — losing it means
   you cannot update the app:
   ```bash
   keytool -genkeypair -v -keystore the-last-signal-release.keystore -alias thelastsignal \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
2. In the Android preset set *Keystore → Release / Release User / Release Password*. Godot 4 stores these in
   `.godot/export_credentials.cfg` (git-ignored), not in `export_presets.cfg`. For CI you can instead use the
   environment variables `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` and
   `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`.
3. Google Play requires an **AAB**: enable *Gradle Build → Use Gradle Build*, set *Export Format* to AAB,
   run *Project → Install Android Build Template…* (creates `android/`, git-ignored) — this additionally needs
   the NDK version Godot asks for.
4. Bump `version/code` for every upload.

## Device testing checklist

See [TESTING.md](TESTING.md#manual-on-device-checklist). Prioritise a low-end phone (2–3 GB RAM, Mali/Adreno
entry-level GPU) for frame rate, and a phone with a notch for UI placement.
