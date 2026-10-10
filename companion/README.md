# Waste Python companion

This is the Windows companion gateway for Waste. It uses only Python's
standard library and serves the browser preview at `/` when the preview file
exists. Notes and conversation history remain in the client.

## Start locally

From `Waste`:

```powershell
python -m companion.server
```

The default listener is `http://127.0.0.1:8765`. On startup the process
prints one pairing token to its console. Keep that token private; the browser
preview retains it only in memory. To choose a stable token before startup:

```powershell
$env:WASTE_PAIRING_TOKEN = "use-a-long-random-private-token"
python -m companion.server
```

An environment token must be 24-256 printable ASCII characters. Tokens are
compared in constant time; malformed non-ASCII request headers are rejected
without exposing server details.

The server is loopback-only by default. A non-loopback bind must name a
concrete IP address and is accepted only with both a certificate and private
key; wildcard binds such as `0.0.0.0` are rejected:

```powershell
python -m companion.server --host 192.0.2.10 --port 8765 --cert C:\tls\waste.crt --key C:\tls\waste.key
```

Do not expose an insecure LAN port or forward this service publicly.

## Model configuration

Offline mode always posts to the local Ollama endpoint
`http://127.0.0.1:11434/api/chat`, with `stream: false`. The default model is
`qwen2.5:1.5b`; it can be changed with `WASTE_OFFLINE_MODEL`. Install Ollama,
start it, and pull the selected model before using offline chat:

```powershell
$env:WASTE_OFFLINE_MODEL = "qwen2.5:1.5b"
ollama pull qwen2.5:1.5b
python -m companion.server
```

Ollama was not available on PATH during the initial project prerequisite
check, so actual model generation remains unverified until it is installed and
exercised.

Online mode is disabled unless all three settings are present. The base URL
must be HTTPS and end exactly in `/v1`:

```powershell
$env:WASTE_ONLINE_BASE_URL = "https://api.example.invalid/v1"
$env:WASTE_ONLINE_MODEL = "your-model-name"
$env:WASTE_ONLINE_API_KEY = "your-private-key"
python -m companion.server
```

The key is read only by the companion and is never returned in API errors,
chat history, or startup output. Offline mode never falls back to online.
Provider calls have a bounded 90-second timeout for small-model cold starts.
Offline provider failures return a setup hint to start Ollama and pull the
configured model, without returning provider response bodies.

The companion disables environment proxy settings for provider requests, so
offline Ollama traffic remains on `127.0.0.1`. It also accepts only the exact
Host corresponding to the bound address and port, rejecting DNS-rebinding
Host headers.

## Guarded Windows actions

The only actions are `open_calculator` and `open_notepad`. The client must
show its own confirmation dialog after `/api/actions/prepare`; only a
short-lived, one-use confirmation from `/api/actions/confirm` starts the fixed
Windows executable. Arbitrary paths, commands, and shell execution are not
accepted.

## Checks

Run the standard-library unittest suite from `Waste`:

```powershell
python -m unittest companion.test_server -v
```
