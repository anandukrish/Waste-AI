# WASTE packaging

These scripts are local build recipes. They do not publish anything and do not
claim an artifact exists until a build completes and the expected file is
verified. Both scripts copy the client into a temporary staging project before
Flutter platform generation, so `client/lib`, `client/test`, and
`client/pubspec.yaml` are not generated over.

## Prerequisites

- Flutter on `PATH`, with the Windows and/or Android toolchain configured. Run
  `flutter doctor` first and accept the Android SDK licenses where required.
- Windows Flutter builds need Visual Studio's Desktop development with C++
  workload and a Windows SDK. Android builds need an Android SDK/build-tools
  installation and a compatible device or emulator; use a JDK when the local
  Flutter installation does not provide one.
- Windows builds with Flutter plugins require Windows Developer Mode (or an
  elevated build shell) for package symlinks. The script does not enable this
  system setting automatically.
- For Windows packaging, Inno Setup 6 with `ISCC.exe` on `PATH` or installed in
  one of the standard locations. The current checkout has no `iscc` command.
- For the installed companion browser launcher, Python 3 must be installed and
  available on `PATH`. The installer checks this dependency and installs per
  user under `%LOCALAPPDATA%\Programs\Waste AI`; it does not request elevation.
- For Android, use a device/emulator with a trusted connection to the companion.
  Non-loopback companion URLs must use HTTPS.

The companion itself only needs Python 3. Flutter, Dart, Android tooling,
Ollama, and Inno Setup are separate prerequisites; the scripts do not install
them or change system settings. The verified Android build produced a local
debug APK; the Windows installer remains pending Developer Mode/symlink
support, and no binary artifacts are checked into the source tree.

## Commands

Run from the repository root:

```powershell
.\packaging\build-windows.ps1
.\packaging\build-android.ps1
```

The Windows command is intended to create a native Flutter release executable
inside staging and an Inno Setup installer at `dist\Waste-AI-Setup.exe`. The
installer exposes both the native `waste.exe` shortcut and a separate
companion-browser shortcut. The browser launcher serves the required
`client\web-preview\index.html` through the local companion. Only the three
runtime companion modules, `launch.py`, and the command launcher are packaged;
caches, tests, logs, secrets, and other Python files are excluded. `waste.exe`
and `Waste-AI-Setup.exe` are expected build outputs, not checked-in artifacts.

The Android command is intended to create `dist\Waste-android-debug.apk`.
This is an explicit debug APK for development/device testing and is **not
production signed**. The script does not claim or create a release-signed
artifact. Its staged manifest includes Internet and microphone permissions plus
Android speech-recognition and text-to-speech package-visibility queries. Voice
still depends on an installed device speech service and runtime permission;
the build script does not make Android voice or on-device AI available.

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

They do not build Flutter, install an APK, create an EXE, or verify a model.
The local Android artifact verification used `apksigner verify --verbose
--print-certs` and `aapt dump badging` after the build; it confirmed Android
debug signing and the Internet/microphone permissions.
