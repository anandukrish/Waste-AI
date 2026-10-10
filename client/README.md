# WASTE client

WASTE is a local-first Flutter client for the Windows companion described in
the parent `PROJECT.md`. The same directory also contains a standalone browser
preview in `web-preview/index.html`.

## Flutter scaffold

The Flutter SDK was not available while this source was prepared, so platform
folders and compiled artifacts are intentionally not included. On a machine
with Flutter installed:

```text
cd C:\Users\ADMIN\omnirush.ai\Waste\client
flutter create --platforms=windows,android --project-name waste .
flutter pub get
flutter run -d windows
# or: flutter run -d <android-device>
```

Run the scaffold command from this `client` directory. It generates the
platform folders and project plumbing; retain the existing `lib/`, `test/`,
`web-preview/`, and `pubspec.yaml` source while reviewing generated metadata.
Then run `flutter pub get` so the dependencies are `http`,
`shared_preferences`, and `flutter_secure_storage`.

For Android release networking, verify the generated
`android/app/src/main/AndroidManifest.xml` contains this permission outside
the `<application>` element:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

For a non-loopback HTTPS companion, Android and Windows must trust the server
certificate. A self-signed certificate is not silently accepted; install it
through the platform's trusted-certificate mechanism or use a certificate
chaining to a trusted CA.

## Data and connection behavior

- The default origin is `http://127.0.0.1:8765`.
- Loopback allows HTTP. Non-loopback origins require HTTPS, and origins with
  user info, query strings, fragments, or paths are rejected.
- The native pairing token is stored only through `flutter_secure_storage`.
  Notes, bounded chat history, host, and mode are stored in
  `shared_preferences`.
- Offline and online are explicit modes sent as the API `mode` field. The
  client never silently changes mode or creates an answer when the companion
  fails.
- Chat sends only history matching the mode captured when the request began,
  with at most 30 items, 24,000 total characters, and 8,000 characters per
  item. Messages are limited to 8,000 characters. Local history remains capped
  at 40 messages.
- Chat requests allow up to 100 seconds for provider cold starts. Health and
  action requests remain bounded at 15 seconds.
- Chat history is capped at 40 messages and retains `role`, `content`, and
  `mode`. Notes can be added and deleted locally without a running backend.
- Windows actions are allowlisted Calculator/Notepad operations and always use
  prepare, a visible confirmation dialog, then confirm. Android does not expose
  computer-companion actions.
- Speech input and TTS are marked planned; there are no fake microphone or
  speaker controls.

## Browser preview

The companion serves this file at `/` and the preview uses fixed same-origin
`/api/...` paths. It has no external dependencies, third-party web APIs, or
service worker. The browser pairing token lives in JavaScript memory only; it
is never written to `localStorage`. Entering a token is labeled **TOKEN SET**,
not authenticated; the API remains the authority. Notes and history do use
plain `localStorage` and the settings screen labels that privacy boundary.
Dynamic model and note content is inserted with `textContent`.
`chat_policy.js` exports the pure history/message bound logic for a Node or
Windows Script Host smoke test; the same policy is embedded in `index.html`
because the companion serves only `/`.

## Checks

With Flutter installed, run:

```text
flutter test
flutter analyze
# optional browser policy smoke test:
node web-preview/chat_policy_test.js
# or on Windows without Node:
cscript //nologo web-preview/chat_policy_test.js
```

Those checks could not be executed in the preparation environment because
Flutter/Dart/Node were not on PATH. No APK, Windows executable, or generated
platform directory is claimed by this source-only deliverable.
