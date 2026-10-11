# WASTE packaging

These scripts build local artifacts without changing the checked-in client or
publishing anything. Both scripts copy the client into a temporary staging
project before Flutter platform generation, so `client/lib`, `client/test`,
and `client/pubspec.yaml` are not generated over.

## Prerequisites

- Flutter on `PATH`, with the Windows and/or Android toolchain configured.
- Windows builds with Flutter plugins require Windows Developer Mode (or an
  elevated build shell) for package symlinks. The script does not enable this
  system setting automatically.
- For Windows packaging, Inno Setup 6 with `ISCC.exe` on `PATH` or installed in
  one of the standard locations.
- For the installed companion browser launcher, Python 3 must be installed and
  available on `PATH`. The installer checks this dependency and installs per
  user under `%LOCALAPPDATA%\Programs\Waste AI`; it does not request elevation.
- For Android, use a device/emulator with a trusted connection to the companion.
  Non-loopback companion URLs must use HTTPS.

## Commands

Run from the repository root:

```powershell
.\packaging\build-windows.ps1
.\packaging\build-android.ps1
```

The Windows command creates a native Flutter release executable and an Inno
Setup installer in `dist\Waste-AI-Setup.exe`. The installer exposes both the
native `waste.exe` shortcut and a separate companion-browser shortcut. The
browser launcher serves the required `client\web-preview\index.html` through
the local companion. Only the three runtime companion modules, `launch.py`,
and the command launcher are packaged; caches, tests, logs, secrets, and other
Python files are excluded.

The Android command creates `dist\Waste-android-debug.apk`. This is an
explicit debug APK for development/device testing and is **not production
signed**. The script does not claim or create a release-signed artifact. Its
staged manifest includes Internet and microphone permissions plus Android
speech-recognition and text-to-speech package-visibility queries.

`-SkipFlutterCreate` is available only when the corresponding existing
`client\windows` or `client\android` directory should be copied into staging;
it still never writes generated files into `client`.

## Checks

Run the tool-free packaging script checks from the repository root:

```powershell
.\packaging\test-packaging.ps1
```

These checks parse every packaging PowerShell script with the actual
PowerShell parser and run both build scripts against a failing mocked Flutter
command to verify non-zero native exits stop the build.
