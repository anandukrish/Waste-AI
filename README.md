# WASTE AI — private offline-first Jarvis assistant for Windows and Android

> Malayalam + English • local-first • optional online AI • safe computer actions • open source

WASTE is a privacy-first personal AI assistant project inspired by the idea of a helpful Jarvis: it can run local commands without a model, connect to an optional local model, and use an explicitly configured online provider when you choose. **WASTE is the assistant's name.**

[![Status: early preview](https://img.shields.io/badge/status-early%20preview-7c5cff)](PROJECT.md)
[![Offline first](https://img.shields.io/badge/privacy-offline--first-20c997)](STORAGE-AND-REMOVAL.md)
[![Windows + Android source](https://img.shields.io/badge/platform-Windows%20%7C%20Android-4285f4)](client/README.md)

**Search keywords:** offline AI assistant, private Jarvis assistant, Malayalam AI, English AI assistant, Windows AI companion, Android AI assistant, Ollama assistant, local-first AI, safe computer automation.

An early working foundation, not a finished Jarvis replacement. Built for a Windows companion with Flutter Windows/Android client source and a runnable browser interface. Contributions and feedback are welcome.

## Start the working Windows preview

1. Double-click `Start-Waste.cmd` in this folder, or run `python launch.py` here.
2. The companion opens **http://127.0.0.1:8765/** in your default browser.
3. Copy the pairing token from the new terminal into Waste's welcome screen. Do not paste it into an AI chat or share it. The token changes after restarting unless explicitly configured.
4. Keep the terminal open. Close it or press Ctrl+C to stop Waste. No Windows service, scheduled task or startup entry is installed.

In **Local** mode, these work immediately without Ollama, an API key or internet:

```text
/help
/time
/calculate 12 * (3 + 4)
```

The browser Notes screen stores notes locally without a pairing token. Windows Settings actions can open Calculator or Notepad after a separate confirmation. These are fixed buttons, not arbitrary AI-controlled commands.

## Build Windows and Android artifacts

The source tree includes PowerShell build scripts for producing local artifacts.
They do not download tools, change machine-wide settings, or imply that an
artifact is already present. They stage a copy of `client/`, so generated
platform files and build output do not overwrite the checked-in client source:

```powershell
.\packaging\build-windows.ps1
.\packaging\build-android.ps1
```

Before building, install Flutter and make `flutter` available on `PATH`. The
Windows toolchain also needs Visual Studio's Desktop development with C++
workload and a Windows SDK. Flutter plugin builds may need Windows Developer
Mode (or an approved elevated shell) for symlinks; the script will not change
that system setting automatically. Android builds need a configured Android
SDK/toolchain with accepted licenses and a valid device or emulator. Windows
packaging additionally needs Inno Setup 6 (`ISCC.exe`) and both build paths
need Python 3 for the companion launcher included with the installer.

The Windows script is intended to build an isolated native release and package
it with Inno Setup as `dist\Waste-AI-Setup.exe`, without modifying `client/`.
That installer contains the native `waste.exe` and a separate companion-browser
launcher. The Android script is intended to build an isolated debug APK,
ensures Internet and microphone permissions are present, and copies it to
`dist\Waste-android-debug.apk`. It is not production-signed. These are expected
outputs after a successful local build, not checked-in artifacts. The Android
debug APK was built and independently verified locally in the current
development session. The Windows installer remains unbuilt because Flutter
requires Windows Developer Mode (or an approved elevated build shell) for
plugin symlinks.

Both installed clients still use the local companion flow. The Windows preview
installer expects Python to be available because the companion is intentionally
not replaced with an opaque background service. Read `packaging\README.md` for
the prerequisites and the security boundaries.

## Preview download

The verified Android development build is available from the
[v0.1.0-preview GitHub release](https://github.com/anandukrish/Waste-AI/releases/tag/v0.1.0-preview).
`Waste-android-debug.apk` is debug-signed for development/device testing; it is
not a production release and should only be installed when you trust the
download source. SHA-256:

```text
AF614F63AC0D2EAF4395D8DEE503F78F6CD1C174D10EDC45DE26D896B4700501
```

## What is implemented

- Local notes and chat history storage, with clear/delete controls.
- Explicit local/online chat routing; no automatic online fallback.
- Offline history is excluded from online requests, even after switching modes.
- Local arithmetic, help and time commands without a language model.
- An Ollama adapter for open-ended offline conversation.
- Malayalam-aware prompt guidance for open-ended replies, with explicit limits
  against invented actions and secret disclosure.
- An HTTPS OpenAI-compatible adapter for optional online conversation.
- Authenticated Windows companion with short-lived, one-use action confirmations.
- Flutter client source for Windows and Android, with secure token storage.
- Browser Security Center preview for local-only file inspection: SHA-256 hashing,
  transparent extension/header heuristics, local history, and explicit engine
  limitations. It is not a replacement for Microsoft Defender, ClamAV, or a
  commercial malware engine.

## What is NOT finished or installed

- **No Windows native installer artifact is checked in or verified.** The Windows build script is ready, but Flutter plugin symlink support requires Windows Developer Mode or an approved elevated shell.
- **Android debug APK:** built and verified locally as `dist\Waste-android-debug.apk`; it is a development artifact signed with the standard Android debug key, not a production release.
- **No AI model has been downloaded.** Open-ended offline chat requires Ollama plus a model.
- **No cloud provider is connected.** Online chat requires an endpoint, model and API key configured on the companion.
- **Voice interaction is available when the client platform exposes it.** Flutter uses native TTS and speech-recognition plugins, while the browser preview uses browser-native speech APIs. Malayalam (`ml-IN`) is preferred, with English India (`en-IN`) selectable. Voice is explicit push-to-talk/speak or auto-speak; no wake-word listener is enabled. Availability, permissions, and speech processing remain controlled by the OS/browser.
- **No autonomous file management, web search, cross-device sync or Android on-device AI yet.**
- **Security Center limitation:** the browser preview only inspects files the
  user explicitly selects. It does not execute, upload, quarantine, delete, or
  claim files are clean; real-time protection and malware definitions are not
  connected.
- Browser interactions and native builds have not been end-to-end UI tested. API, arithmetic, JavaScript policy, Python compile, Flutter analysis/tests, Android APK metadata, and packaging failure-propagation checks are available; Windows installer and real device checks remain pending.

## Privacy and data boundaries

- Local mode is explicit. Built-in commands run without a model; open-ended
  offline requests use only Ollama at `127.0.0.1:11434`. Offline mode never
  falls back to the online provider, and only history from the selected mode is
  sent with a request.
- Notes, chat history, and ordinary settings stay on the client. The native
  client uses app preferences and secure storage for the pairing token. The
  browser preview keeps the token in page memory but stores notes, history, and
  voice preferences in that browser's plain `localStorage`; treat browser
  profile access as access to that data.
- The companion does not persist notes or chat history. An online API key is
  read from the companion process environment only and is not returned in
  responses or startup output. Voice input/output is handled by native or
  browser facilities; WASTE does not store microphone audio or transcripts,
  and recognized text is placed in the composer without automatic sending.
- The companion binds to loopback by default. Cross-device use requires a
  concrete address with HTTPS and a trusted certificate; do not use public
  port forwarding.

## Add offline AI later

Install Ollama separately, then download the default small model using `ollama pull qwen2.5:1.5b`. This is an additional download, not something this project has done. Model license and system suitability should be reviewed before use. Your 8 GB RAM PC should start with a small model and measured performance.

Start Ollama before Waste. To check setup without starting Waste or printing a
pairing token, run:

```powershell
python -m companion.server --check-ollama
```

The check contacts only Ollama's loopback model-list endpoint, has a bounded
five-second request, reports whether Ollama is unreachable or the configured
model is missing, and exits with status 1 when not ready. Waste talks only to
`http://127.0.0.1:11434/api/chat` in local model mode; environment proxies are
disabled for this transport. Cold-start model requests are bounded at 90
seconds.

For another local model set `WASTE_OFFLINE_MODEL` in your terminal before starting Waste. See `companion/README.md` for online configuration. Never commit API keys or put them into client source.

## Android connectivity

Flutter Android source is included but cannot run until platform files are generated and the APK built. On a phone, `127.0.0.1` means the phone, not your PC. To connect to your Windows companion, configure a concrete private PC IP and a trusted TLS certificate; the app requires HTTPS for non-loopback connections. See `client/README.md` and `companion/README.md`.

Android notes are designed to work locally. Both online and PC-model chat currently require the companion to be on and reachable. Internet-independent PC model chat can work over a local network after pairing/TLS setup, but this is not standalone offline AI on Android. Do not expose this development companion through public port forwarding.

## Checks

Run from this folder:

```powershell
python -m unittest discover -s companion -t . -v
cscript //nologo client\web-preview\chat_policy_test.js
cscript //nologo client\web-preview\voice_policy_test.js
cscript //nologo client\web-preview\security_policy_test.js
python -m compileall -q companion launch.py
powershell.exe -NoProfile -ExecutionPolicy Bypass -File packaging\test-packaging.ps1
```

Native verification in the current environment: Flutter `analyze --no-pub` and
`test --no-pub` pass, and the Android debug APK metadata/signature was verified.
The Windows installer and a real Android device/emulator flow remain pending.
The source checkout does not track generated Flutter platform directories or the
Windows installer; use `packaging\build-android.ps1` and
`packaging\build-windows.ps1` for reproducible builds.

## Storage and removal

See `STORAGE-AND-REMOVAL.md`. Your existing animation files outside `Waste` are unrelated and should not be deleted when removing this assistant.
