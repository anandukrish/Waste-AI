# Venom Antivirus

Venom is a standalone, local-first file inspection dashboard. It is separate
from the WASTE assistant.

## Run it

From this folder:

```powershell
python venom_server.py
```

Open <http://127.0.0.1:8787/>. The dashboard lets you choose files or a folder,
calculate SHA-256 locally, run bounded explainable heuristics, and keep a local
inspection history.

## Optional Ollama review

Local inspection does not need Ollama. If Ollama is already installed and you
want an AI explanation of the scan metadata:

```powershell
ollama pull qwen2.5:1.5b
```

Then use the opt-in **AI Review** action in the dashboard. Venom sends only
metadata such as the filename, size, hash, risk label, and heuristic findings
to Ollama at `127.0.0.1:11434`. It does not send file bytes by default. Set a
different local model with `VENOM_AI_MODEL` before starting the server.

## Important scope

This release is an inspection/triage layer, not a complete endpoint antivirus:

- no real-time filesystem monitor;
- no maintained malware-definition database;
- no cloud reputation lookup;
- no process termination, quarantine, or deletion;
- no claim that a file is clean or virus-free.

The EICAR test string is supported as a harmless scanner-validation pattern.
Keep Microsoft Defender or another trusted antivirus enabled. A production
antivirus needs a maintained engine such as Microsoft Defender/AMSI, ClamAV,
or a separately licensed commercial engine before it can make reliable malware
verdicts.

On Windows, the dashboard can optionally call the installed `MpCmdRun.exe`
bridge for one explicitly entered file path. The scan uses a non-remediating
flag and does not delete or quarantine files. A non-zero command result is
shown as an attention state, not silently converted into a malware verdict.

## Checks

```powershell
python -m unittest -v
python -m py_compile venom_server.py test_venom_server.py
cscript //nologo web\venom_policy_test.js
```
