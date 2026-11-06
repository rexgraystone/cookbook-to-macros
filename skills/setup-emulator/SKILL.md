---
name: setup-emulator
description: Install and configure an Android emulator (SDK command-line tools, emulator, Google Play system image, AVD) with the MyFitnessPal app so Claude can drive it over adb, on Windows, macOS or Linux. Use when the user wants to set up MyFitnessPal automation, when adb or the emulator is missing, when emu_start fails, or before the first enter-recipes or log-food run on a new machine.
---

# Set up the Android emulator for MyFitnessPal

Goal: an AVD (default name `MFP_Pixel`) with Google Play, MyFitnessPal installed and the user signed in, controllable with `${CLAUDE_PLUGIN_ROOT}/scripts/mfp.sh`.

**Never type passwords or sign in for the user.** The user signs in to Google and MyFitnessPal themselves in the emulator window. Ask before accepting SDK licenses on their behalf (show them what's being accepted).

Shell variables and functions don't persist between Bash calls, so every Bash call below starts with `source "${CLAUDE_PLUGIN_ROOT}/scripts/mfp.sh" &&` (it sets `$SDK`, `$EMU` and the helpers).

## 0. Check what's there
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/mfp.sh" && mfp_doctor
```
If adb, the emulator and an AVD already exist, skip to step 5. If the SDK lives somewhere non-standard, set `ANDROID_SDK_ROOT` (and `MFP_AVD` for a different AVD name) in the shell or in the project's `.claude/settings.json` `env`.

Default SDK locations: Windows `%LOCALAPPDATA%\Android\Sdk`, macOS `~/Library/Android/sdk`, Linux `~/Android/Sdk`. Android Studio users already have one.

## 1. Prerequisites
- **Python 3** on PATH (the helpers use only the standard library). On Windows, run everything from **Git Bash**.
- **Java 17+** for `sdkmanager`/`avdmanager`. Check `java -version`. If missing, install a JDK 17 (Windows `winget install EclipseAdoptium.Temurin.17.JDK`; macOS `brew install --cask temurin@17`; Debian/Ubuntu `sudo apt install openjdk-17-jdk-headless`) or unzip a standalone JDK and set `JAVA_HOME` to it.
- **Hardware acceleration**: Windows needs Windows Hypervisor Platform enabled (or the Android Emulator hypervisor driver); Linux needs KVM (`/dev/kvm` readable by the user); Apple silicon needs an `arm64-v8a` image.
- About 10 GB free disk.

## 2. SDK command-line tools
Download "Command line tools only" for the OS from https://developer.android.com/studio#command-line-tools-only. Unzip so that the tools end up at `$SDK/cmdline-tools/latest/bin/sdkmanager` (the zip contains a `cmdline-tools/` folder: move its contents into `cmdline-tools/latest/`).

Ask the user before accepting the SDK licenses (license text: https://developer.android.com/studio/terms). `--licenses` prompts interactively, so after the user agrees pipe `yes` into it:
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/mfp.sh" && SM="$SDK/cmdline-tools/latest/bin/sdkmanager" \
  && { [ -f "$SM" ] || SM="$SM.bat"; } && yes | "$SM" --sdk_root="$SDK" --licenses
```

## 3. Packages
Pick the image ABI: `x86_64` on Intel/AMD, `arm64-v8a` on Apple silicon or ARM Linux. Use a **google_apis_playstore** image (the Play Store is needed to install MyFitnessPal).
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/mfp.sh" && SM="$SDK/cmdline-tools/latest/bin/sdkmanager" \
  && { [ -f "$SM" ] || SM="$SM.bat"; } && "$SM" --sdk_root="$SDK" "platform-tools" "emulator" \
  "platforms;android-34" "system-images;android-34;google_apis_playstore;x86_64"
```
This downloads a few GB; run it in the background.

## 4. Create the AVD
Use the same ABI as in step 3.
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/mfp.sh" && AM="$SDK/cmdline-tools/latest/bin/avdmanager" \
  && { [ -f "$AM" ] || AM="$AM.bat"; } && echo no | "$AM" create avd -n MFP_Pixel -d pixel_7 \
  -k "system-images;android-34;google_apis_playstore;x86_64"
```
Optional, in `~/.android/avd/MFP_Pixel.avd/config.ini` (Windows: `%USERPROFILE%\.android\avd\...`): `hw.ramSize=4096`.

The helpers assume a 1080x2400 screen for a few fallback coordinates; `pixel_7` gives that. Other sizes work but rely on `dump` more.

## 5. Start it and fit the window
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/mfp.sh" && emu_start    # background / long timeout
```
- If the window is taller than the screen: close the emulator, then in `~/.android/avd/<AVD>.avd/emulator-user.ini` set `window.scale` to about screen height ÷ 2700 (e.g. about `0.35` for a 1080 px tall display with a taskbar) and optionally `window.x` / `window.y`. The file appears after the first run. You can also resize the window by dragging its corner.
- **Don't resize or move the emulator window with OS window APIs** (Win32 calls, AppleScript, xdotool); that has crashed it.
- If `emu_start` times out, start it by hand to see the error: `"$EMU" -avd MFP_Pixel` (common causes: no hardware acceleration, wrong ABI, low disk).

## 6. Install MyFitnessPal
1. Ask the user to open the **Play Store** in the emulator window and sign in to their Google account. Wait until they confirm.
2. Open the listing: `adb_ shell am start -a android.intent.action.VIEW -d "market://details?id=com.myfitnesspal.android"`, then `dump` and `tapx Install`.
3. Wait for the install: `adb_ shell pm list packages | grep myfitnesspal`.
4. `mfp_launch`, then ask the user to **sign in to MyFitnessPal** themselves (or create an account). The free tier is enough. Wait for confirmation.

## 7. Verify
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/mfp.sh" && emu_ready && mfp_launch && sleep 4 && dump
```
The dump should show the app's home screen (Dashboard/Today, `buttonManageMyDay`), not a login screen. Dismiss Premium popups with NO THANKS. Record the app version for future troubleshooting:
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/mfp.sh" && adb_ shell dumpsys package com.myfitnesspal.android | grep versionName
```
Write the AVD name, SDK path (if non-default) and app version to `mfp-notes.md` in the project root so later runs don't redo this.

## Notes
- **Sandbox**: if adb works in your own terminal but not from Claude Code, the sandbox may be hiding the SDK folder or blocking adb's local socket. Rerun those commands with the sandbox disabled, or add the SDK path to the sandbox allow list.
- **Windows, MSIX apps**: an SDK installed from inside an MSIX-packaged app (such as the Claude desktop app) can land in that app's virtualized storage (`%LOCALAPPDATA%\Packages\<App>_*\LocalCache\Local\Android\Sdk`) and be invisible to other shells. `mfp.sh` falls back to that location; or set `ANDROID_SDK_ROOT`.
- Snapshots: the emulator saves a quick-boot snapshot on close, so later starts take seconds.
