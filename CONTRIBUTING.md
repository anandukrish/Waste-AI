# Contributing to WASTE

Thanks for helping make WASTE a useful private assistant.

## Principles

- Offline behavior must remain useful and must not silently upload data.
- Never commit API keys, pairing tokens, private logs, certificates or model files.
- Destructive or consequential computer actions need a clear confirmation step.
- Be honest about platform limitations and mark unfinished features as unfinished.
- Prefer small, reviewable pull requests with tests.

## Before opening a pull request

From the project root:

```powershell
python -m unittest discover -s companion -t . -v
cscript //nologo client\web-preview\chat_policy_test.js
python -m compileall -q companion launch.py
```

Flutter checks are required when Flutter is installed:

```powershell
flutter pub get
flutter analyze
flutter test
```

Explain any skipped check in the pull request. Do not include credentials in screenshots or issue reports.
