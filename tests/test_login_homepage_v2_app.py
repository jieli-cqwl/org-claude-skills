"""Real HTTP acceptance tests for the fresh login/homepage v2 pilot.

The tests define the observable contract for the new v2 app only. They use a
real local HTTP server, configured credentials, cookie assertions, protected
homepage behavior, and logout invalidation without importing the old pilot app.
"""

from __future__ import annotations

import http.client
import os
import threading
import unittest
from http import HTTPStatus
from http.server import ThreadingHTTPServer
from urllib.parse import urlencode

from examples.login_homepage_v2_app.app import LoginConfig, create_handler, load_config


class LoginHomepageV2AcceptanceTests(unittest.TestCase):
    """Exercise login-homepage-v2 through real HTTP requests."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.previous_username = os.environ.get("LOGIN_HOMEPAGE_V2_USERNAME")
        cls.previous_password = os.environ.get("LOGIN_HOMEPAGE_V2_PASSWORD")
        os.environ["LOGIN_HOMEPAGE_V2_USERNAME"] = "fresh@example.com"
        os.environ["LOGIN_HOMEPAGE_V2_PASSWORD"] = "fresh-correct-password"
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), create_handler())
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.host, cls.port = cls.server.server_address

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=3)
        cls._restore_env("LOGIN_HOMEPAGE_V2_USERNAME", cls.previous_username)
        cls._restore_env("LOGIN_HOMEPAGE_V2_PASSWORD", cls.previous_password)

    @staticmethod
    def _restore_env(name: str, value: str | None) -> None:
        """Restore one environment variable without leaking test credentials."""
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
        conn = http.client.HTTPConnection(self.host, self.port, timeout=3)
        try:
            conn.request(method, path, body=body, headers=headers or {})
            response = conn.getresponse()
            payload = response.read().decode("utf-8")
            return response.status, dict(response.getheaders()), payload
        finally:
            conn.close()

    def login(self, password: str = "fresh-correct-password") -> str:
        """Log in and return the raw cookie pair used by protected requests."""
        body = urlencode({"username": "fresh@example.com", "password": password})
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

    def test_login_page_exposes_required_form_fields(self) -> None:
        status, _, payload = self.request("GET", "/login")

        self.assertEqual(HTTPStatus.OK, status)
        self.assertIn("<form", payload)
        self.assertIn('method="post"', payload)
        self.assertIn('name="username"', payload)
        self.assertIn('name="password"', payload)

    def test_valid_login_sets_safe_session_cookie_and_redirects_home(self) -> None:
        cookie = self.login()

        self.assertTrue(cookie.startswith("session="))

    def test_invalid_login_shows_readable_error_without_session_cookie(self) -> None:
        body = urlencode({"username": "fresh@example.com", "password": "wrong"})

        status, headers, payload = self.request(
            "POST",
            "/login",
            body=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )

        self.assertEqual(HTTPStatus.UNAUTHORIZED, status)
        self.assertNotIn("Set-Cookie", headers)
        self.assertIn("Invalid username or password", payload)
        self.assertIn('name="username"', payload)
        self.assertIn('name="password"', payload)

    def test_invalid_content_length_is_rejected_safely(self) -> None:
        status, _, payload = self.request(
            "POST",
            "/login",
            body="username=fresh%40example.com",
            headers={"Content-Length": "not-a-number"},
        )

        self.assertEqual(HTTPStatus.BAD_REQUEST, status)
        self.assertIn("Invalid form submission", payload)

    def test_missing_configuration_fails_fast(self) -> None:
        self._restore_env("LOGIN_HOMEPAGE_V2_USERNAME", None)
        self._restore_env("LOGIN_HOMEPAGE_V2_PASSWORD", None)
        try:
            with self.assertRaisesRegex(RuntimeError, "Login credentials are not configured"):
                load_config()
        finally:
            os.environ["LOGIN_HOMEPAGE_V2_USERNAME"] = "fresh@example.com"
            os.environ["LOGIN_HOMEPAGE_V2_PASSWORD"] = "fresh-correct-password"

    def test_anonymous_home_redirects_to_login(self) -> None:
        status, headers, payload = self.request("GET", "/")

        self.assertEqual(HTTPStatus.SEE_OTHER, status)
        self.assertEqual("/login", headers["Location"])
        self.assertEqual("", payload)

    def test_authenticated_homepage_shows_identity_and_logout_action(self) -> None:
        cookie = self.login()

        status, _, payload = self.request("GET", "/", headers={"Cookie": cookie})

        self.assertEqual(HTTPStatus.OK, status)
        self.assertIn("Welcome, fresh@example.com", payload)
        self.assertIn("Fresh workspace", payload)
        self.assertIn("Logout", payload)

    def test_repeated_login_replaces_previous_session(self) -> None:
        first_cookie = self.login()
        second_cookie = self.login()

        status, headers, _ = self.request("GET", "/", headers={"Cookie": first_cookie})
        self.assertEqual(HTTPStatus.SEE_OTHER, status)
        self.assertEqual("/login", headers["Location"])

        status, _, payload = self.request("GET", "/", headers={"Cookie": second_cookie})
        self.assertEqual(HTTPStatus.OK, status)
        self.assertIn("Welcome, fresh@example.com", payload)

    def test_authentication_events_are_logged_without_secrets(self) -> None:
        wrong_body = urlencode({"username": "fresh@example.com", "password": "wrong"})

        with self.assertLogs("examples.login_homepage_v2_app.app", level="INFO") as logs:
            self.request(
                "POST",
                "/login",
                body=wrong_body,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )
            cookie = self.login()
            self.request("POST", "/logout", headers={"Cookie": cookie})

        output = "\n".join(logs.output)
        self.assertIn("login_failed", output)
        self.assertIn("login_success", output)
        self.assertIn("logout", output)
        self.assertNotIn("fresh-correct-password", output)
        self.assertNotIn("session=", output)

    def test_homepage_escapes_configured_identity(self) -> None:
        handler = create_handler(LoginConfig(username="<script>alert(1)</script>", password="pw"))
        server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        host, port = server.server_address
        try:
            body = urlencode({"username": "<script>alert(1)</script>", "password": "pw"})
            conn = http.client.HTTPConnection(host, port, timeout=3)
            conn.request("POST", "/login", body=body)
            response = conn.getresponse()
            cookie = dict(response.getheaders())["Set-Cookie"].split(";", 1)[0]
            response.read()
            conn.close()

            conn = http.client.HTTPConnection(host, port, timeout=3)
            conn.request("GET", "/", headers={"Cookie": cookie})
            response = conn.getresponse()
            payload = response.read().decode("utf-8")
            conn.close()

            self.assertEqual(HTTPStatus.OK, response.status)
            self.assertIn("&lt;script&gt;alert(1)&lt;/script&gt;", payload)
            self.assertNotIn("<script>alert(1)</script>", payload)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)

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

    def test_excluded_routes_are_not_implemented(self) -> None:
        for path in ("/register", "/password-reset", "/dashboard"):
            status, _, payload = self.request("GET", path)
            self.assertEqual(HTTPStatus.NOT_FOUND, status)
            self.assertIn("Page not found", payload)


if __name__ == "__main__":
    unittest.main()
