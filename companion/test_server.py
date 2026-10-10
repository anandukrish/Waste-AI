"""HTTP-level tests for the Waste companion; no live provider is contacted."""

from __future__ import annotations

import http.client
import json
import os
import threading
import unittest
from unittest import mock

from . import server


class FakeClock:
    def __init__(self) -> None:
        self.value = 100.0

    def __call__(self) -> float:
        return self.value


class CompanionHTTPTests(unittest.TestCase):
    TOKEN = "test-pairing-token"

    def setUp(self) -> None:
        self.old_env = os.environ.copy()
        for key in ("WASTE_ONLINE_BASE_URL", "WASTE_ONLINE_MODEL", "WASTE_ONLINE_API_KEY", "WASTE_OFFLINE_MODEL"):
            os.environ.pop(key, None)
        self.calls: list[tuple[str, dict, float]] = []
        self.clock = FakeClock()

        def transport(request, timeout):
            payload = json.loads(request.data.decode("utf-8"))
            self.calls.append((request.full_url, payload, timeout))
            if "chat/completions" in request.full_url:
                return b'{"choices":[{"message":{"content":"online reply"}}]}'
            return b'{"message":{"content":"offline reply"}}'

        self.transport = transport
        self.app = server.CompanionApplication(
            token=self.TOKEN,
            provider_transport=self.transport,
            clock=self.clock,
        )
        self.httpd = server.create_server("127.0.0.1", 0, app=self.app)
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.thread.start()
        self.host, self.port = self.httpd.server_address[:2]
        self.origin = self.httpd.allowed_origin

    def tearDown(self) -> None:
        self.httpd.shutdown()
        self.httpd.server_close()
        self.thread.join(timeout=2)
        os.environ.clear()
        os.environ.update(self.old_env)

    def request(self, method, path, payload=None, *, token=True, origin=None, raw_body=None, headers=None):
        connection = http.client.HTTPConnection(self.host, self.port, timeout=3)
        request_headers = {"Origin": origin or self.origin}
        if token:
            request_headers["Authorization"] = f"Bearer {self.TOKEN}"
        if headers:
            request_headers.update(headers)
        if raw_body is not None:
            body = raw_body
        elif payload is not None:
            body = json.dumps(payload).encode()
        else:
            body = None
        if body is not None:
            request_headers.setdefault("Content-Type", "application/json")
            request_headers.setdefault("Content-Length", str(len(body)))
        connection.request(method, path, body=body, headers=request_headers)
        response = connection.getresponse()
        data = response.read()
        connection.close()
        return response.status, json.loads(data.decode()) if data else None

    def test_builtin_skills_work_over_authenticated_http_without_provider(self):
        for message, expected in (("/help", "I'm Waste"), ("/calculate 7*6", "Result: 42"), ("/time", "local time:")):
            status, body = self.request("POST", "/api/chat", {"message": message, "mode": "offline", "history": []})
            self.assertEqual(status, 200)
            self.assertIn(expected, body["reply"])
            self.assertEqual(body["mode"], "offline")
        self.assertEqual(self.calls, [])

    def test_public_health_is_minimal_and_foreign_origin_is_rejected(self):
        status, body = self.request("GET", "/api/health", token=False)
        self.assertEqual((status, body), (200, {"name": "Waste", "version": "0.1.0"}))
        status, body = self.request("GET", "/api/health", token=False, origin="http://localhost:8765")
        self.assertEqual(status, 403)
        self.assertNotIn("token", json.dumps(body).lower())

    def test_non_ascii_auth_and_origin_headers_are_rejected_safely(self):
        status, _ = self.request(
            "GET",
            "/api/not-a-route",
            token=False,
            headers={"Authorization": "Bearer token-with-é"},
        )
        self.assertEqual(status, 401)
        status, _ = self.request(
            "GET",
            "/api/health",
            token=False,
            origin="http://localhost:8765/é",
        )
        self.assertEqual(status, 403)

    def test_exact_host_and_security_headers(self):
        connection = http.client.HTTPConnection(self.host, self.port, timeout=3)
        connection.request(
            "GET",
            "/api/health",
            headers={"Host": self.httpd.allowed_host, "Origin": self.origin},
        )
        response = connection.getresponse()
        response.read()
        connection.close()
        self.assertEqual(response.status, 200)
        self.assertEqual(response.getheader("X-Content-Type-Options"), "nosniff")
        self.assertEqual(response.getheader("Referrer-Policy"), "no-referrer")
        csp = response.getheader("Content-Security-Policy")
        self.assertIn("default-src 'self'", csp)
        self.assertIn("base-uri 'none'", csp)
        self.assertIn("frame-ancestors 'none'", csp)
        self.assertIn("script-src 'self' 'unsafe-inline'", csp)
        self.assertIn("style-src 'self' 'unsafe-inline'", csp)

        status, _ = self.request(
            "GET",
            "/api/health",
            token=False,
            headers={"Host": f"localhost:{self.port}"},
        )
        self.assertEqual(status, 421)

    def test_preflight_allows_only_the_exact_bound_origin(self):
        status, body = self.request("OPTIONS", "/api/chat", token=False)
        self.assertEqual((status, body), (204, None))
        connection = http.client.HTTPConnection(self.host, self.port, timeout=3)
        connection.request("OPTIONS", "/api/chat", headers={"Origin": "http://localhost:8765"})
        response = connection.getresponse()
        response.read()
        connection.close()
        self.assertEqual(response.status, 403)

    def test_private_auth_and_missing_content_are_rejected(self):
        status, _ = self.request("POST", "/api/actions/prepare", token=False, payload={"action": "open_notepad"})
        self.assertEqual(status, 401)
        status, _ = self.request("POST", "/api/actions/prepare", payload=None)
        self.assertEqual(status, 415)
        status, _ = self.request("POST", "/api/actions/prepare", raw_body=b"{", headers={"Content-Type": "application/json"})
        self.assertEqual(status, 400)

    def test_oversized_body_and_history_are_bounded(self):
        huge = b"{" + b"a" * server.MAX_BODY_BYTES
        status, _ = self.request(
            "POST", "/api/chat", raw_body=huge,
            headers={"Content-Type": "application/json", "Content-Length": str(len(huge))},
        )
        self.assertEqual(status, 413)
        status, _ = self.request(
            "POST", "/api/chat",
            payload={"message": "hi", "mode": "offline", "history": [{"role": "user", "content": "x"}] * 31},
        )
        self.assertEqual(status, 422)

    def test_offline_and_online_routes_are_explicit(self):
        status, body = self.request("POST", "/api/chat", payload={"message": "hello", "mode": "offline", "history": []})
        self.assertEqual((status, body), (200, {"reply": "offline reply", "mode": "offline"}))
        self.assertEqual(self.calls[-1][0], server.OLLAMA_URL)
        self.assertEqual(self.calls[-1][2], server.PROVIDER_TIMEOUT_SECONDS)

        os.environ.update({
            "WASTE_ONLINE_BASE_URL": "https://provider.example/v1",
            "WASTE_ONLINE_MODEL": "online-model",
            "WASTE_ONLINE_API_KEY": "secret-key",
        })
        status, body = self.request("POST", "/api/chat", payload={"message": "hello", "mode": "online", "history": []})
        self.assertEqual((status, body), (200, {"reply": "online reply", "mode": "online"}))
        self.assertEqual(self.calls[-1][0], "https://provider.example/v1/chat/completions")

    def test_online_missing_config_and_provider_error_are_safe(self):
        status, body = self.request("POST", "/api/chat", payload={"message": "hello", "mode": "online", "history": []})
        self.assertEqual(status, 503)
        self.assertEqual(body, {"error": "online provider is not configured"})
        os.environ.update({
            "WASTE_ONLINE_BASE_URL": "https://[invalid/v1",
            "WASTE_ONLINE_MODEL": "online-model",
            "WASTE_ONLINE_API_KEY": "secret-key",
        })
        status, body = self.request("POST", "/api/chat", payload={"message": "hello", "mode": "online", "history": []})
        self.assertEqual((status, body), (503, {"error": "online provider is not configured"}))
        self.app.provider_transport = mock.Mock(side_effect=server.ProviderError("provider body: secret-key"))
        status, body = self.request("POST", "/api/chat", payload={"message": "hello", "mode": "offline", "history": []})
        self.assertEqual(status, 502)
        self.assertEqual(
            body,
            {"error": "offline provider unavailable; start Ollama and pull the configured model"},
        )
        self.assertNotIn("secret-key", json.dumps(body))

    def test_default_transport_disables_environment_proxies(self):
        class Response:
            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc_value, traceback):
                return False

            def read(self, _limit):
                return b"{}"

        opener = mock.Mock()
        opener.open.return_value = Response()
        request = server.urllib.request.Request(server.OLLAMA_URL, method="POST")
        with mock.patch.object(server.urllib.request, "build_opener", return_value=opener) as build_opener:
            self.assertEqual(server._default_provider_transport(request, 90), b"{}")
        handlers = build_opener.call_args.args
        proxy_handlers = [handler for handler in handlers if isinstance(handler, server.urllib.request.ProxyHandler)]
        self.assertEqual(len(proxy_handlers), 1)
        self.assertEqual(proxy_handlers[0].proxies, {})
        opener.open.assert_called_once_with(request, timeout=90)

    def test_invalid_action_expired_and_reused_confirmation(self):
        with mock.patch.object(server.os, "name", "nt"), mock.patch.object(server.secrets, "token_urlsafe", return_value="nonce"):
            status, _ = self.request("POST", "/api/actions/prepare", payload={"action": "run_cmd"})
            self.assertEqual(status, 400)
            status, body = self.request("POST", "/api/actions/prepare", payload={"action": "open_calculator"})
            self.assertEqual(status, 200)
            self.assertEqual(body["expires_in"], 60)
            self.clock.value += 61
            status, _ = self.request("POST", "/api/actions/confirm", payload={"confirmation_id": "nonce"})
            self.assertEqual(status, 400)

            self.clock.value = 100
            status, _ = self.request("POST", "/api/actions/prepare", payload={"action": "open_notepad"})
            self.assertEqual(status, 200)
            with mock.patch.object(self.app, "popen") as popen:
                status, body = self.request("POST", "/api/actions/confirm", payload={"confirmation_id": "nonce"})
            self.assertEqual((status, body), (200, {"status": "launched"}))
            popen.assert_called_once_with([server.NOTEPAD_PATH], shell=False)
            status, _ = self.request("POST", "/api/actions/confirm", payload={"confirmation_id": "nonce"})
            self.assertEqual(status, 400)

    def test_preview_is_fixed_and_no_traversal(self):
        status, _ = self.request("GET", "/../PROJECT.md", token=False, origin=None)
        self.assertEqual(status, 404)


class ServerPolicyTests(unittest.TestCase):
    def test_non_loopback_requires_tls_pair(self):
        with self.assertRaises(ValueError):
            server.create_server("0.0.0.0", 0)
        with self.assertRaises(ValueError):
            server.create_server("0.0.0.0", 0, certfile="certificate.pem")
        with self.assertRaises(ValueError):
            server.create_server("example.invalid", 0, certfile="certificate.pem", keyfile="key.pem")

    def test_environment_pairing_token_has_minimum_length(self):
        with mock.patch.dict(os.environ, {"WASTE_PAIRING_TOKEN": "too-short"}, clear=False):
            with self.assertRaisesRegex(ValueError, "24-256"):
                server.CompanionApplication()


if __name__ == "__main__":
    unittest.main()
