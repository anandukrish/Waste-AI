# Waste — hybrid personal assistant

## First implementation
Original cross-platform assistant named Waste. Preserve sibling animation files.

- Flutter client source for Windows and Android: chat, explicit offline/online selection, local notes, local conversation storage, connection settings and guarded Windows actions.
- Python standard-library Windows companion: authenticated chat gateway to local Ollama or a configured HTTPS OpenAI-compatible endpoint, plus two-step allowlisted app launches.
- A lightweight browser client provides a runnable Windows interface while native build tools are not installed. It is a companion preview, not an Android APK or installed Windows app.
- No automatic upload/fallback from offline mode to online mode.
- No wake-word listener, arbitrary shell execution, file deletion, background surveillance, or on-device Android language model in this first release.
- Voice is client-side: native Flutter uses device TTS/speech recognition and the browser preview uses browser speech APIs. Malayalam (`ml-IN`) is preferred, English India (`en-IN`) is selectable, and push-to-talk only fills the composer; there is no wake-word listener or automatic voice submission.

## Acceptance checks
1. Save notes locally and retain them after reopening the client.
2. An unconfigured model returns an honest setup error, never a fabricated AI response.
3. Offline requests cannot invoke the online provider.
4. All private companion routes require a pairing token; browser requests from unrelated origins are rejected.
5. App launches are fixed allowlisted operations and require a short-lived, one-use confirmation.
6. No API keys are embedded in source or chat history.

## Shared API contract
Default origin: http://127.0.0.1:8765. Companion serves browser preview at `/` from `client/web-preview/index.html`.

- GET `/api/health` is public: `{name:"Waste",version:"0.1.0"}`. No secrets or filesystem paths.
- All other `/api/*` routes use `Authorization: Bearer <pairing token>`.
- POST `/api/chat`: `{message:string,mode:"offline"|"online",history:[{role:"user"|"assistant",content:string}]}` -> `{reply:string,mode:string}`.
- POST `/api/actions/prepare`: `{action:"open_calculator"|"open_notepad"}` -> `{confirmation_id:string,description:string,expires_in:60}`.
- POST `/api/actions/confirm`: `{confirmation_id:string}` -> `{status:"launched"}`.
- Errors: `{error:string}` with meaningful non-2xx status.

Notes and conversation history live on the client, not the companion. Native client stores pairing token in secure storage; browser preview keeps it in memory only. Online API key is configured only on the companion through an environment variable. The server binds to loopback by default. Cross-device operation needs explicitly configured TLS; do not recommend public port forwarding.

Browser notes, chat history, and voice preferences use plain browser
`localStorage`; native notes, history, and ordinary settings use app
preferences. WASTE does not persist microphone audio or recognition
transcripts. Offline mode never falls back to online mode, and only history
from the selected mode is sent. The online key is not returned in API errors,
chat history, or startup output.

## Build and verification status

Python 3.14, Git, Windows Script Host, Flutter 3.47.7, Android SDK command-line
tools, and Inno Setup are available in the verified build environment. The
Android debug build was produced and its signature and manifest were checked
locally; it is not a production-signed release. The Windows build remains
blocked by Flutter's Developer Mode/symlink requirement, and Ollama model
generation remains unverified until Ollama and a model are installed.

The offline model can be checked without starting the companion listener or
printing a token with `python -m companion.server --check-ollama`. The check
uses only Ollama's loopback model-list endpoint, waits at most five seconds,
and exits non-zero when Ollama or the configured model is unavailable.

## Remaining limitations

- There is no wake-word/background listener, autonomous file management, web
  search, cross-device sync, or Android on-device language model.
- Android and non-loopback clients still depend on a reachable companion; a
  non-loopback companion requires HTTPS and a trusted certificate.
- Voice availability depends on OS/browser engines and permissions. WASTE does
  not provide a hosted speech service or guarantee Malayalam/English voices.
- Flutter platform folders and compiled artifacts are generated only in a
  staging/build environment; the source checkout does not track an EXE or
  installer. A debug APK can be regenerated with `packaging\build-android.ps1`.
