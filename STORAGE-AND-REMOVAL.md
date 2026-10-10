# Waste storage and safe removal

## Current files

Project root: `C:\Users\ADMIN\omnirush.ai\Waste`

- `companion/`: Python companion source and tests.
- `client/`: Flutter source and browser preview.
- `launch.py`, `Start-Waste.cmd`: local startup helpers.
- `__pycache__/` folders: disposable Python bytecode created by running tests/app.

No Flutter SDK, Android SDK, Ollama installation, downloaded AI model, paid service, scheduled task, firewall rule or Windows startup entry was created by this project work. Python was already installed and is shared; do not uninstall it just to remove Waste.

## Data outside the project

**Browser preview:** notes and chat history are plain localStorage data for `http://127.0.0.1:8765` in the browser profile you use. Deleting the project directory does not erase that browser data. Use Waste Settings → Clear chats / Clear notes first, or remove this origin's site data through your browser settings. The pairing token is in page memory only, and is lost when the page closes; the server's generated token lasts for that server process.

**Native app, after you build/install it:** notes, history and nonsecret settings use app preferences. The pairing token uses flutter_secure_storage. Use the native app's clear-data and disconnect controls before uninstalling. Android's App info → Storage → Clear storage is another option; uninstalling may not remove backups made by the OS. Native app data folders are not created until the app runs.

**Future models/tools:** installing Ollama, Flutter or Android tooling later introduces separate storage locations. Record those actual locations at installation time. Removing this source folder does not uninstall shared tooling or downloaded models. For Ollama use its model list/removal commands rather than deleting unrelated directories.

## Remove Waste safely

1. Export or copy any notes you want to keep.
2. Use Clear chats / Clear notes / Forget token in the clients as applicable.
3. Press Ctrl+C in the Waste terminal, or close that terminal. This stops the local companion.
4. Move only `C:\Users\ADMIN\omnirush.ai\Waste` to the Recycle Bin.
5. Leave sibling files such as `kerala-robot-short.mp4` untouched.

There is deliberately no one-click recursive uninstall command in this prototype. If you ask the assistant to remove it, specify what to preserve and confirm the exact target before deletion.
