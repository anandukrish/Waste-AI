# Waste — hybrid personal assistant

## First implementation
Original cross-platform assistant named Waste. Preserve sibling animation files.

- Flutter client source for Windows and Android: chat, explicit offline/online selection, local notes, local conversation storage, connection settings and guarded Windows actions.
- Python standard-library Windows companion: authenticated chat gateway to local Ollama or a configured HTTPS OpenAI-compatible endpoint, plus two-step allowlisted app launches.
- A lightweight browser client provides a runnable Windows interface while native build tools are not installed. It is a companion preview, not an Android APK or installed Windows app.
- No automatic upload/fallback from offline mode to online mode.
- No wake-word listener, arbitrary shell execution, file deletion, background surveillance, or on-device Android language model in this first release.

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

## Build prerequisites observed
Python 3.14 is available. Flutter, Dart, Android SDK tools, Git and Ollama were not on PATH during the initial check. Roughly 141 GiB free on C: was observed. Native builds and actual model generation must remain marked unverified until prerequisites are installed and exercised.
