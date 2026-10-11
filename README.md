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

The source tree now includes reproducible PowerShell build scripts. They do not
download tools or change machine-wide settings:

```powershell
.\packaging\build-windows.ps1
.\packaging\build-android.ps1
```

The Windows build requires Flutter plugin symlink support. Enable Windows
Developer Mode yourself (or run the build from an approved elevated shell); the
script will not change that system setting automatically.

The Windows script builds an isolated staging copy and packages the release
with Inno Setup into `dist\Waste-AI-Setup.exe`, without modifying `client/`.
The Android script similarly builds an isolated debug APK, ensures Internet and
microphone permissions are present, and copies it to
`dist\Waste-android-debug.apk`. It is not production-signed.

Both installed clients still use the local companion flow. The Windows preview
installer expects Python to be available because the companion is intentionally
not replaced with an opaque background service. Read `packaging\README.md` for
the prerequisites and the security boundaries.

## What is implemented

- Local notes and chat history storage, with clear/delete controls.
- Explicit local/online chat routing; no automatic online fallback.
- Offline history is excluded from online requests, even after switching modes.
- Local arithmetic, help and time commands without a language model.
- An Ollama adapter for open-ended offline conversation.
- An HTTPS OpenAI-compatible adapter for optional online conversation.
- Authenticated Windows companion with short-lived, one-use action confirmations.
- Flutter client source for Windows and Android, with secure token storage.

## What is NOT finished or installed

- **No APK or Windows native installer artifact is checked in yet.** The build scripts are ready, but Flutter/Dart, Android SDK, and Inno Setup must be installed locally before producing artifacts.
- **No AI model has been downloaded.** Open-ended offline chat requires Ollama plus a model.
- **No cloud provider is connected.** Online chat requires an endpoint, model and API key configured on the companion.
- **Voice interaction is available on supported clients.** Native TTS and push-to-talk speech recognition are explicit, permission-gated controls; no wake-word listener is enabled.
- **No autonomous file management, web search, cross-device sync or Android on-device AI yet.**
- Browser interactions and native builds have not been end-to-end UI tested. API, arithmetic and JavaScript routing checks have been run.

## Add offline AI later

Install Ollama separately, then download the default small model using `ollama pull qwen2.5:1.5b`. This is an additional download, not something this project has done. Model license and system suitability should be reviewed before use. Your 8 GB RAM PC should start with a small model and measured performance.

Start Ollama before Waste. Waste talks only to `http://127.0.0.1:11434/api/chat` in local model mode; environment proxies are disabled for this transport. Cold-start model requests are bounded at 90 seconds.

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
python -m compileall -q companion launch.py
```

Native checks pending prerequisite installation: `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build windows`, and `flutter build apk` from the scaffolded client directory. Do not treat them as passed.

## Storage and removal

See `STORAGE-AND-REMOVAL.md`. Your existing animation files outside `Waste` are unrelated and should not be deleted when removing this assistant.
