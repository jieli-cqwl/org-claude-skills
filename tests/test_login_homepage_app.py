"""Real HTTP acceptance tests for the login and homepage pilot app.

The tests own the observable user contract: redirects, cookies, login
errors, authenticated homepage content, and logout invalidation.
"""

from __future__ import annotations

import contextlib
import http.client
import io
import os
import threading
import unittest
from http import HTTPStatus
from http.server import ThreadingHTTPServer
from urllib.parse import urlencode

from examples.login_homepage_app.app import create_handler


class LoginHomepageAcceptanceTests(unittest.TestCase):
    """Exercise the app through a real local HTTP server."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.previous_username = os.environ.get("LOGIN_HOMEPAGE_USERNAME")
        cls.previous_password = os.environ.get("LOGIN_HOMEPAGE_PASSWORD")
        os.environ["LOGIN_HOMEPAGE_USERNAME"] = "demo@example.com"
        os.environ["LOGIN_HOMEPAGE_PASSWORD"] = "correct-horse-battery-staple"
        handler = create_handler()
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base_host, cls.base_port = cls.server.server_address

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=3)
        cls._restore_env("LOGIN_HOMEPAGE_USERNAME", cls.previous_username)
        cls._restore_env("LOGIN_HOMEPAGE_PASSWORD", cls.previous_password)

    @staticmethod
    def _restore_env(name: str, value: str | None) -> None:
        """Restore one environment value without leaking test credentials."""
        if value is None:
            os.environ.pop(name, None)
            return
        os.environ[name] = value

    def request(
        self,
        method: str,
        path: str,
        body: str = "",
        headers: dict[str, str] | None = None,
    ) -> tuple[int, dict[str, str], str]:
        """Send one HTTP request and return status, headers, and decoded body."""
        conn = http.client.HTTPConnection(self.base_host, self.base_port, timeout=3)
        try:
            conn.request(method, path, body=body, headers=headers or {})
            response = conn.getresponse()
            payload = response.read().decode("utf-8")
            return response.status, dict(response.getheaders()), payload
        finally:
            conn.close()

    def login(self, password: str = "correct-horse-battery-staple") -> str:
        """Log in and return the cookie header value expected by later requests."""
        body = urlencode({"username": "demo@example.com", "password": password})
        status, headers, _ = self.request(
            "POST",
            "/login",
            body=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        self.assertEqual(HTTPStatus.SEE_OTHER, status)
        self.assertEqual("/", headers["Location"])
        cookie = headers["Set-Cookie"]
        self.assertIn("session=", cookie)
        self.assertIn("HttpOnly", cookie)
        self.assertIn("SameSite=Lax", cookie)
        return cookie.split(";", 1)[0]

    def test_anonymous_home_redirects_to_login(self) -> None:
        status, headers, payload = self.request("GET", "/")

        self.assertEqual(HTTPStatus.SEE_OTHER, status)
        self.assertEqual("/login", headers["Location"])
        self.assertEqual("", payload)

    def test_login_page_exposes_required_form_fields(self) -> None:
        status, _, payload = self.request("GET", "/login")

        self.assertEqual(HTTPStatus.OK, status)
        self.assertIn("<form", payload)
        self.assertIn('method="post"', payload)
        self.assertIn('name="username"', payload)
        self.assertIn('name="password"', payload)

    def test_valid_login_sets_session_and_shows_homepage(self) -> None:
        cookie = self.login()

        status, _, payload = self.request("GET", "/", headers={"Cookie": cookie})

        self.assertEqual(HTTPStatus.OK, status)
        self.assertIn("Welcome, demo@example.com", payload)
        self.assertIn("Today overview", payload)
        self.assertIn("Logout", payload)

    def test_invalid_login_returns_readable_error_on_login_page(self) -> None:
        body = urlencode({"username": "demo@example.com", "password": "wrong"})

        status, _, payload = self.request(
            "POST",
            "/login",
            body=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )

        self.assertEqual(HTTPStatus.UNAUTHORIZED, status)
        self.assertIn("Invalid username or password", payload)
        self.assertIn('name="username"', payload)
        self.assertIn('name="password"', payload)

    def test_invalid_login_emits_access_log(self) -> None:
        body = urlencode({"username": "demo@example.com", "password": "wrong"})
        captured = io.StringIO()

        with contextlib.redirect_stderr(captured):
            self.request(
                "POST",
                "/login",
                body=body,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )

        log_output = captured.getvalue()
        self.assertIn("POST /login", log_output)
        self.assertIn("401", log_output)

    def test_logout_clears_session_and_rejects_old_cookie(self) -> None:
        cookie = self.login()

        status, headers, _ = self.request("POST", "/logout", headers={"Cookie": cookie})
        self.assertEqual(HTTPStatus.SEE_OTHER, status)
        self.assertEqual("/login", headers["Location"])
        self.assertIn("session=;", headers["Set-Cookie"])
        self.assertIn("Max-Age=0", headers["Set-Cookie"])

        status, headers, _ = self.request("GET", "/", headers={"Cookie": cookie})
        self.assertEqual(HTTPStatus.SEE_OTHER, status)
        self.assertEqual("/login", headers["Location"])


if __name__ == "__main__":
    unittest.main()
