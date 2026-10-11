"""Small, authenticated HTTP companion for the Waste client.

The module deliberately has no third-party dependencies.  Run it from the
Waste directory with ``python -m companion.server``.
"""

from __future__ import annotations

import argparse
import hmac
import ipaddress
import json
import os
import secrets
import socket
import ssl
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Callable, Optional

from . import __version__
from .local_tools import local_reply


DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765
OLLAMA_URL = "http://127.0.0.1:11434/api/chat"
OLLAMA_TAGS_URL = "http://127.0.0.1:11434/api/tags"
DEFAULT_OFFLINE_MODEL = "qwen2.5:1.5b"
ACTION_TTL_SECONDS = 60
MAX_BODY_BYTES = 64 * 1024
MAX_MESSAGE_CHARS = 8_000
MAX_HISTORY_ITEMS = 30
MAX_HISTORY_CHARS = 32_000
MAX_REPLY_CHARS = 64_000
MAX_PROVIDER_RESPONSE_BYTES = 1 * 1024 * 1024
MAX_PENDING_ACTIONS = 128
REQUEST_TIMEOUT_SECONDS = 5
PROVIDER_TIMEOUT_SECONDS = 90
SECURITY_CSP = (
    "default-src 'self'; script-src 'self' 'unsafe-inline'; "
    "style-src 'self' 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'"
)

PREVIEW_PATH = Path(__file__).resolve().parent.parent / "client" / "web-preview" / "index.html"
CALCULATOR_PATH = r"C:\Windows\System32\calc.exe"
NOTEPAD_PATH = r"C:\Windows\System32\notepad.exe"
ACTION_PATHS = {
    "open_calculator": ("Open Calculator", CALCULATOR_PATH),
    "open_notepad": ("Open Notepad", NOTEPAD_PATH),
}


class CompanionError(Exception):
    """An expected error with a safe public message and HTTP status."""

    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status
        self.message = message


class ProviderError(Exception):
    """Provider failures never carry provider response bodies to clients."""


class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    """Do not follow redirects, especially when an API key is in a request."""

    def redirect_request(self, req: Any, fp: Any, code: int, msg: str, headers: Any, newurl: str) -> Any:
        raise ProviderError("provider redirect rejected")


def _default_provider_transport(request: urllib.request.Request, timeout: float) -> bytes:
    """POST a provider request while refusing redirects and bounding the body."""

    # Do not inherit HTTP_PROXY/HTTPS_PROXY for either provider.  In
    # particular, offline chat must stay on the loopback Ollama endpoint.
    opener = urllib.request.build_opener(
        NoRedirectHandler(), urllib.request.ProxyHandler({})
    )
    try:
        with opener.open(request, timeout=timeout) as response:
            body = response.read(MAX_PROVIDER_RESPONSE_BYTES + 1)
            if len(body) > MAX_PROVIDER_RESPONSE_BYTES:
                raise ProviderError("provider response too large")
            return body
    except ProviderError:
        raise
    except (urllib.error.URLError, OSError, TimeoutError, ValueError) as exc:
        # Keep exception details (which can contain URLs or response bodies) private.
        raise ProviderError("provider unavailable") from exc


def _json_bytes(value: Any) -> bytes:
    return json.dumps(value, separators=(",", ":"), ensure_ascii=True).encode("utf-8")


def _origin_for(scheme: str, host: str, port: int) -> str:
    display_host = _display_host(host)
    return f"{scheme}://{display_host}:{port}"


def _display_host(host: str) -> str:
    if ":" in host and not host.startswith("["):
        return f"[{host}]"
    return host


def _constant_time_text_equal(left: str, right: str) -> bool:
    """Compare header text without str/str compare_digest Unicode failures."""

    try:
        left_bytes = left.encode("utf-8")
    except UnicodeEncodeError:
        left_bytes = b"\x00"
    try:
        right_bytes = right.encode("utf-8")
    except UnicodeEncodeError:
        right_bytes = b"\x00"
    return hmac.compare_digest(left_bytes, right_bytes)


def _new_pairing_token() -> str:
    configured = os.environ.get("WASTE_PAIRING_TOKEN")
    if configured:
        # A bounded token prevents pathological Authorization headers and keeps
        # comparison work predictable.  Do not print it here.
        if (
            len(configured) < 24
            or len(configured) > 256
            or any(ord(ch) < 33 or ord(ch) > 126 for ch in configured)
        ):
            raise ValueError("WASTE_PAIRING_TOKEN must be printable and 24-256 characters")
        return configured
    return secrets.token_urlsafe(32)


class CompanionApplication:
    """Application state and provider/action operations, independent of HTTP."""

    def __init__(
        self,
        token: Optional[str] = None,
        provider_transport: Optional[Callable[[urllib.request.Request, float], bytes]] = None,
        clock: Callable[[], float] = time.monotonic,
        popen: Callable[..., Any] = subprocess.Popen,
    ) -> None:
        self.token = token if token is not None else _new_pairing_token()
        if not self.token:
            raise ValueError("pairing token cannot be empty")
        self.provider_transport = provider_transport or _default_provider_transport
        self.clock = clock
        self.popen = popen
        self._pending: dict[str, tuple[str, float]] = {}
        self._pending_lock = threading.Lock()

    def authenticate(self, authorization: Optional[str]) -> bool:
        supplied = ""
        if authorization and authorization.startswith("Bearer "):
            supplied = authorization[7:]
        # Always compare a value to the configured token, including malformed
        # or missing headers, to avoid an early-exit token comparison.
        matches = _constant_time_text_equal(supplied, self.token)
        return bool(supplied) & matches

    def chat(self, message: str, mode: str, history: list[dict[str, str]]) -> str:
        if mode == "offline":
            built_in = local_reply(message)
            if built_in is not None:
                return built_in
        system = (
            "You are Waste, a helpful personal assistant. Be honest about what you "
            "can and cannot do. Never claim that an external action was completed "
            "unless the client reports it explicitly."
        )
        messages: list[dict[str, str]] = [{"role": "system", "content": system}]
        messages.extend(history)
        messages.append({"role": "user", "content": message})

        if mode == "offline":
            model = os.environ.get("WASTE_OFFLINE_MODEL", DEFAULT_OFFLINE_MODEL).strip()
            if not model or len(model) > 200:
                raise CompanionError(503, "offline model is not configured")
            payload = {"model": model, "messages": messages, "stream": False}
            request = urllib.request.Request(
                OLLAMA_URL,
                data=_json_bytes(payload),
                headers={"Content-Type": "application/json", "Accept": "application/json"},
                method="POST",
            )
            expected_mode = "offline"
        elif mode == "online":
            base = os.environ.get("WASTE_ONLINE_BASE_URL", "").strip()
            model = os.environ.get("WASTE_ONLINE_MODEL", "").strip()
            key = os.environ.get("WASTE_ONLINE_API_KEY", "")
            try:
                parsed = urllib.parse.urlparse(base)
                hostname = parsed.hostname
            except ValueError:
                raise CompanionError(503, "online provider is not configured")
            if (
                not base
                or parsed.scheme != "https"
                or not hostname
                or parsed.query
                or parsed.fragment
                or parsed.username
                or parsed.password
                or not parsed.path.endswith("/v1")
                or not model
                or len(model) > 200
                or not key
            ):
                raise CompanionError(503, "online provider is not configured")
            request = urllib.request.Request(
                base + "/chat/completions",
                data=_json_bytes({"model": model, "messages": messages, "stream": False}),
                headers={
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                    "Authorization": f"Bearer {key}",
                },
                method="POST",
            )
            expected_mode = "online"
        else:
            raise CompanionError(400, "mode must be offline or online")

        try:
            raw = self.provider_transport(request, PROVIDER_TIMEOUT_SECONDS)
            response = json.loads(raw.decode("utf-8"))
            if expected_mode == "offline":
                reply = response["message"]["content"]
            else:
                reply = response["choices"][0]["message"]["content"]
            if not isinstance(reply, str) or not reply or len(reply) > MAX_REPLY_CHARS:
                raise ValueError("invalid reply")
            return reply
        except CompanionError:
            raise
        except Exception as exc:
            # This includes malformed provider JSON, schema errors and transport
            # errors.  Never return provider bodies or exception text.
            if isinstance(exc, ProviderError):
                if expected_mode == "offline":
                    raise CompanionError(
                        502,
                        "offline provider unavailable; start Ollama and pull the configured model",
                    ) from exc
                raise CompanionError(502, "provider request failed") from exc
            raise CompanionError(502, "provider returned an invalid response") from exc

    def check_offline_model(self) -> tuple[bool, str]:
        """Check local Ollama and the configured model without contacting online services."""

        model = os.environ.get("WASTE_OFFLINE_MODEL", DEFAULT_OFFLINE_MODEL).strip()
        if not model or len(model) > 200 or any(ord(char) < 32 for char in model):
            return False, "Offline model is not configured. Set WASTE_OFFLINE_MODEL to a model name."

        request = urllib.request.Request(
            OLLAMA_TAGS_URL,
            headers={"Accept": "application/json"},
            method="GET",
        )
        try:
            raw = self.provider_transport(request, REQUEST_TIMEOUT_SECONDS)
        except (ProviderError, OSError, TimeoutError, ValueError):
            return (
                False,
                "Ollama is not reachable at 127.0.0.1:11434. Start Ollama, then run "
                "this check again.",
            )

        try:
            response = json.loads(raw.decode("utf-8"))
            installed = {
                item["name"]
                for item in response["models"]
                if isinstance(item, dict) and isinstance(item.get("name"), str)
            }
        except (KeyError, TypeError, UnicodeDecodeError, json.JSONDecodeError):
            return False, "Ollama returned an invalid model list; offline setup could not be verified."

        if model not in installed:
            return (
                False,
                f"Offline model '{model}' is not installed. Run: ollama pull {model}",
            )
        return True, f"Ollama is ready for offline mode with model '{model}'."

    def prepare_action(self, action: str) -> tuple[str, str, int]:
        if action not in ACTION_PATHS:
            raise CompanionError(400, "unsupported action")
        if os.name != "nt":
            raise CompanionError(501, "actions are supported on Windows only")
        now = self.clock()
        with self._pending_lock:
            self._purge_expired_locked(now)
            if len(self._pending) >= MAX_PENDING_ACTIONS:
                raise CompanionError(429, "too many pending confirmations")
            confirmation_id = secrets.token_urlsafe(24)
            description, path = ACTION_PATHS[action]
            self._pending[confirmation_id] = (path, now + ACTION_TTL_SECONDS)
        return confirmation_id, description, ACTION_TTL_SECONDS

    def confirm_action(self, confirmation_id: str) -> None:
        if os.name != "nt":
            raise CompanionError(501, "actions are supported on Windows only")
        now = self.clock()
        with self._pending_lock:
            self._purge_expired_locked(now)
            item = self._pending.pop(confirmation_id, None)
        if item is None:
            raise CompanionError(400, "invalid or expired confirmation")
        path, _expires_at = item
        try:
            self.popen([path], shell=False)
        except (OSError, ValueError) as exc:
            # The one-use confirmation has already been consumed, even if the
            # fixed executable could not be started.
            raise CompanionError(502, "action could not be launched") from exc

    def _purge_expired_locked(self, now: float) -> None:
        expired = [key for key, (_path, expiry) in self._pending.items() if expiry <= now]
        for key in expired:
            del self._pending[key]


class CompanionHandler(BaseHTTPRequestHandler):
    """HTTP surface.  It intentionally exposes only the contract routes."""

    protocol_version = "HTTP/1.1"
    server_version = "WasteCompanion/0.1"
    sys_version = ""

    def setup(self) -> None:
        super().setup()
        self.connection.settimeout(REQUEST_TIMEOUT_SECONDS)

    def log_message(self, format: str, *args: Any) -> None:
        # Avoid logging Authorization headers, paths containing user data, or
        # provider details.  Startup information is printed by main().
        return

    @property
    def app(self) -> CompanionApplication:
        return self.server.app  # type: ignore[attr-defined]

    def _origin_allowed(self) -> bool:
        origin = self.headers.get("Origin")
        if origin is None:
            return True
        return _constant_time_text_equal(origin, self.server.allowed_origin)  # type: ignore[attr-defined]

    def _host_allowed(self) -> bool:
        values = self.headers.get_all("Host") or []
        if len(values) != 1:
            return False
        return _constant_time_text_equal(values[0], self.server.allowed_host)  # type: ignore[attr-defined]

    def _send(self, status: int, payload: Any, content_type: str = "application/json") -> None:
        body = _json_bytes(payload) if content_type == "application/json" else payload
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Content-Security-Policy", SECURITY_CSP)
        origin = self.headers.get("Origin")
        if origin is not None and _constant_time_text_equal(origin, self.server.allowed_origin):  # type: ignore[attr-defined]
            self.send_header("Access-Control-Allow-Origin", self.server.allowed_origin)  # type: ignore[attr-defined]
            self.send_header("Vary", "Origin")
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)
        self.close_connection = True

    def _error(self, status: int, message: str) -> None:
        try:
            self._send(status, {"error": message})
        except (BrokenPipeError, ConnectionResetError):
            self.close_connection = True

    def _require_api_origin(self) -> bool:
        if not self._origin_allowed():
            self._error(403, "origin is not allowed")
            return False
        return True

    def _require_host(self) -> bool:
        if not self._host_allowed():
            self._error(HTTPStatus.MISDIRECTED_REQUEST, "host is not allowed")
            return False
        return True

    def _require_auth(self) -> bool:
        if not self.app.authenticate(self.headers.get("Authorization")):
            self._error(401, "authentication required")
            return False
        return True

    @staticmethod
    def _is_api_path(path: str) -> bool:
        return path == "/api" or path.startswith("/api/")

    def _read_json(self) -> Any:
        if self.headers.get("Transfer-Encoding"):
            raise CompanionError(400, "transfer encoding is not supported")
        content_length = self.headers.get("Content-Length")
        if content_length is None or "," in content_length:
            raise CompanionError(411, "content length is required")
        try:
            length = int(content_length)
        except ValueError as exc:
            raise CompanionError(400, "invalid content length") from exc
        if length < 0:
            raise CompanionError(400, "invalid content length")
        if length > MAX_BODY_BYTES:
            raise CompanionError(413, "request body is too large")
        if not (self.headers.get("Content-Type") or "").lower().startswith("application/json"):
            raise CompanionError(415, "application/json is required")
        raw = self.rfile.read(length)
        if len(raw) != length:
            raise CompanionError(400, "incomplete request body")
        try:
            return json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise CompanionError(400, "malformed JSON") from exc

    @staticmethod
    def _chat_input(data: Any) -> tuple[str, str, list[dict[str, str]]]:
        if not isinstance(data, dict):
            raise CompanionError(400, "request must be an object")
        message = data.get("message")
        mode = data.get("mode")
        history = data.get("history")
        if not isinstance(message, str) or not message.strip() or len(message) > MAX_MESSAGE_CHARS:
            raise CompanionError(422, "message is invalid")
        if mode not in ("offline", "online"):
            raise CompanionError(422, "mode must be offline or online")
        if not isinstance(history, list) or len(history) > MAX_HISTORY_ITEMS:
            raise CompanionError(422, "history is invalid")
        clean_history: list[dict[str, str]] = []
        total = len(message)
        for item in history:
            if not isinstance(item, dict) or item.get("role") not in ("user", "assistant"):
                raise CompanionError(422, "history is invalid")
            content = item.get("content")
            if not isinstance(content, str) or not content or len(content) > MAX_MESSAGE_CHARS:
                raise CompanionError(422, "history is invalid")
            total += len(content)
            if total > MAX_HISTORY_CHARS:
                raise CompanionError(413, "history is too large")
            clean_history.append({"role": item["role"], "content": content})
        return message, mode, clean_history

    def do_GET(self) -> None:  # noqa: N802 (BaseHTTPRequestHandler API)
        if not self._require_host():
            return
        parsed = urllib.parse.urlsplit(self.path)
        if self._is_api_path(parsed.path):
            if not self._require_api_origin():
                return
            if parsed.path != "/api/health":
                if not self._require_auth():
                    return
                self._error(404, "not found")
                return
            self._send(200, {"name": "Waste", "version": __version__})
            return
        if parsed.path == "/":
            try:
                preview = PREVIEW_PATH.read_bytes()
                if len(preview) > 2 * 1024 * 1024:
                    raise OSError
            except OSError:
                self._error(404, "preview unavailable")
                return
            self._send(200, preview, "text/html; charset=utf-8")
            return
        self._error(404, "not found")

    def do_POST(self) -> None:  # noqa: N802 (BaseHTTPRequestHandler API)
        if not self._require_host():
            return
        parsed = urllib.parse.urlsplit(self.path)
        if not self._is_api_path(parsed.path):
            self._error(404, "not found")
            return
        if not self._require_api_origin() or not self._require_auth():
            return
        if parsed.path not in ("/api/chat", "/api/actions/prepare", "/api/actions/confirm"):
            self._error(404, "not found")
            return
        try:
            data = self._read_json()
            if parsed.path == "/api/chat":
                message, mode, history = self._chat_input(data)
                reply = self.app.chat(message, mode, history)
                self._send(200, {"reply": reply, "mode": mode})
            elif parsed.path == "/api/actions/prepare":
                if not isinstance(data, dict) or not isinstance(data.get("action"), str):
                    raise CompanionError(422, "action is invalid")
                confirmation_id, description, expires_in = self.app.prepare_action(data["action"])
                self._send(
                    200,
                    {
                        "confirmation_id": confirmation_id,
                        "description": description,
                        "expires_in": expires_in,
                    },
                )
            else:
                if not isinstance(data, dict) or not isinstance(data.get("confirmation_id"), str):
                    raise CompanionError(422, "confirmation_id is invalid")
                self.app.confirm_action(data["confirmation_id"])
                self._send(200, {"status": "launched"})
        except CompanionError as exc:
            self._error(exc.status, exc.message)
        except (BrokenPipeError, ConnectionResetError):
            self.close_connection = True
        except Exception:
            self._error(500, "request failed")

    def do_HEAD(self) -> None:  # noqa: N802
        if not self._require_host():
            return
        parsed = urllib.parse.urlsplit(self.path)
        if self._is_api_path(parsed.path):
            if not self._require_api_origin():
                return
            if parsed.path != "/api/health" and not self._require_auth():
                return
        self._error(405, "method not allowed")

    def do_OPTIONS(self) -> None:  # noqa: N802
        if not self._require_host():
            return
        parsed = urllib.parse.urlsplit(self.path)
        if not self._is_api_path(parsed.path):
            self._error(404, "not found")
            return
        # Do not provide a wildcard or permissive preflight.  An exact-origin
        # preflight is enough for the browser preview and does not authenticate.
        if not self._require_api_origin():
            return
        self.send_response(HTTPStatus.NO_CONTENT)
        self.send_header("Content-Length", "0")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Content-Security-Policy", SECURITY_CSP)
        self.send_header("Access-Control-Allow-Origin", self.server.allowed_origin)  # type: ignore[attr-defined]
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        self.send_header("Access-Control-Max-Age", "300")
        self.send_header("Vary", "Origin")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True


class WasteHTTPServer(ThreadingHTTPServer):
    allow_reuse_address = True
    daemon_threads = True

    def __init__(self, address: tuple[str, int], app: CompanionApplication, *, tls: bool) -> None:
        self.app = app
        if ":" in address[0]:
            self.address_family = socket.AF_INET6
        super().__init__(address, CompanionHandler)
        self.socket.settimeout(REQUEST_TIMEOUT_SECONDS)
        scheme = "https" if tls else "http"
        bound_host, bound_port = self.server_address[0], self.server_address[1]
        self.allowed_origin = _origin_for(scheme, bound_host, bound_port)
        self.allowed_host = f"{_display_host(bound_host)}:{bound_port}"


def create_server(
    host: str = DEFAULT_HOST,
    port: int = DEFAULT_PORT,
    *,
    certfile: Optional[str] = None,
    keyfile: Optional[str] = None,
    app: Optional[CompanionApplication] = None,
) -> WasteHTTPServer:
    """Create a server, refusing insecure non-loopback operation."""

    normalized_host = host.strip().lower()
    if normalized_host == "localhost":
        loopback = True
    else:
        try:
            parsed_host = normalized_host[1:-1] if normalized_host.startswith("[") and normalized_host.endswith("]") else normalized_host
            host_ip = ipaddress.ip_address(parsed_host)
        except ValueError as exc:
            raise ValueError("binding host must be localhost or a concrete IP address") from exc
        if host_ip.is_unspecified:
            raise ValueError("wildcard binding is not allowed; use a concrete local IP")
        loopback = host_ip.is_loopback
    if not loopback and not (certfile and keyfile):
        raise ValueError("non-loopback binding requires --cert and --key for HTTPS")
    if (certfile and not keyfile) or (keyfile and not certfile):
        raise ValueError("--cert and --key must be supplied together")
    server = WasteHTTPServer((host, port), app or CompanionApplication(), tls=bool(certfile and keyfile))
    if certfile and keyfile:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(certfile=certfile, keyfile=keyfile)
        server.socket = context.wrap_socket(server.socket, server_side=True)
    return server


def _parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Waste local assistant companion")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", default=DEFAULT_PORT, type=int)
    parser.add_argument("--cert", dest="certfile")
    parser.add_argument("--key", dest="keyfile")
    parser.add_argument(
        "--check-ollama",
        action="store_true",
        help="check local Ollama and the configured offline model, then exit",
    )
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    args = _parse_args(argv)
    if args.check_ollama:
        # A check-only run must not create a listener or expose a pairing token.
        ready, message = CompanionApplication(token="check-only").check_offline_model()
        print(message, flush=True)
        return 0 if ready else 1
    try:
        server = create_server(
            args.host,
            args.port,
            certfile=args.certfile,
            keyfile=args.keyfile,
        )
    except (OSError, ValueError) as exc:
        print(f"Waste companion could not start: {exc}", flush=True)
        return 2
    try:
        print(f"Waste companion listening on {server.allowed_origin}", flush=True)
        print(f"Pairing token: {server.app.token}", flush=True)
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
