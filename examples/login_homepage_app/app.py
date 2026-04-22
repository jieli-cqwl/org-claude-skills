"""Minimal HTTP login and homepage app for the standard-chain pilot.

This module owns only the example app runtime. It stores sessions in memory,
loads credentials from environment variables, and exposes a handler factory for
tests or local servers to run through a real HTTP path.
"""

from __future__ import annotations

import html
import os
import secrets
import threading
from dataclasses import dataclass
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler
from urllib.parse import parse_qs


USERNAME_ENV = "LOGIN_HOMEPAGE_USERNAME"
PASSWORD_ENV = "LOGIN_HOMEPAGE_PASSWORD"
MAX_FORM_BYTES = 8192

LOGIN_PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Login</title>
</head>
<body>
  <main>
    <h1>Login</h1>
    {error_block}
    <form method="post" action="/login">
      <label>Email <input name="username" autocomplete="username"></label>
      <label>Password <input name="password" type="password" autocomplete="current-password"></label>
      <button type="submit">Sign in</button>
    </form>
  </main>
</body>
</html>
"""

HOME_PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Home</title>
</head>
<body>
  <main>
    <h1>Welcome, {username}</h1>
    <section aria-labelledby="today-overview">
      <h2 id="today-overview">Today overview</h2>
      <p>Your workspace is ready.</p>
    </section>
    <form method="post" action="/logout">
      <button type="submit">Logout</button>
    </form>
  </main>
</body>
</html>
"""


@dataclass(frozen=True)
class LoginConfig:
    """Credential contract loaded from deployment-owned environment values."""

    username: str  # Login identifier; non-empty string.
    password: str  # Secret password; loaded from environment and non-empty.


def load_config() -> LoginConfig:
    """Read login credentials and fail fast when deployment omitted them."""
    username = os.environ.get(USERNAME_ENV, "").strip()
    password = os.environ.get(PASSWORD_ENV, "")
    if not username or not password:
        raise RuntimeError("Login credentials are not configured.")
    return LoginConfig(username=username, password=password)


def create_handler(config: LoginConfig | None = None) -> type[BaseHTTPRequestHandler]:
    """Build a request handler class with isolated session state."""
    app_config = config or load_config()
    sessions: dict[str, str] = {}
    session_lock = threading.Lock()

    class LoginHomepageHandler(BaseHTTPRequestHandler):
        """Serve login, homepage, and logout routes for one app instance."""

        server_version = "LoginHomepagePilot/1.0"

        def do_GET(self) -> None:
            """Route safe page requests without exposing internal failures."""
            if self.path == "/login":
                self._render_login()
                return
            if self.path == "/":
                username = self._current_username()
                if username is None:
                    self._redirect("/login")
                    return
                self._send_html(HTTPStatus.OK, HOME_PAGE.format(username=html.escape(username)))
                return
            self._send_html(HTTPStatus.NOT_FOUND, "Page not found.")

        def do_POST(self) -> None:
            """Route form submissions for login and logout."""
            if self.path == "/login":
                self._handle_login()
                return
            if self.path == "/logout":
                self._handle_logout()
                return
            self._send_html(HTTPStatus.NOT_FOUND, "Page not found.")

        def _handle_login(self) -> None:
            """Authenticate submitted credentials and create a server session."""
            form = self._read_form()
            if form is None:
                return
            username = form.get("username", "")
            password = form.get("password", "")
            if not self._credentials_match(username, password):
                self._render_login(
                    status=HTTPStatus.UNAUTHORIZED,
                    error="Invalid username or password.",
                )
                return
            token = secrets.token_urlsafe(32)
            with session_lock:
                sessions[token] = app_config.username
            self._redirect("/", headers=[("Set-Cookie", self._session_cookie(token))])

        def _handle_logout(self) -> None:
            """Invalidate the current session token and clear the browser cookie."""
            token = self._session_token()
            if token is not None:
                with session_lock:
                    sessions.pop(token, None)
            self._redirect("/login", headers=[("Set-Cookie", self._expired_cookie())])

        def _credentials_match(self, username: str, password: str) -> bool:
            """Compare credentials in constant time for the configured account."""
            username_match = secrets.compare_digest(username, app_config.username)
            password_match = secrets.compare_digest(password, app_config.password)
            return username_match and password_match

        def _current_username(self) -> str | None:
            """Resolve the current cookie to a known session owner."""
            token = self._session_token()
            if token is None:
                return None
            with session_lock:
                return sessions.get(token)

        def _session_token(self) -> str | None:
            """Extract the session token from the Cookie header."""
            cookie_header = self.headers.get("Cookie", "")
            for item in cookie_header.split(";"):
                name, _, value = item.strip().partition("=")
                if name == "session" and value:
                    return value
            return None

        def _read_form(self) -> dict[str, str] | None:
            """Parse a small URL-encoded form body or send a safe error page."""
            length_header = self.headers.get("Content-Length", "0")
            try:
                length = int(length_header)
            except ValueError:
                self._send_html(HTTPStatus.BAD_REQUEST, "Invalid form submission.")
                return None
            if length > MAX_FORM_BYTES:
                self._send_html(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, "Form submission is too large.")
                return None
            raw_body = self.rfile.read(length).decode("utf-8", errors="replace")
            parsed = parse_qs(raw_body, keep_blank_values=True)
            return {key: values[0] if values else "" for key, values in parsed.items()}

        def _render_login(self, status: HTTPStatus = HTTPStatus.OK, error: str = "") -> None:
            """Render the login form with an optional user-readable error."""
            if error:
                error_block = f'<p role="alert">{html.escape(error)}</p>'
            else:
                error_block = ""
            self._send_html(status, LOGIN_PAGE.format(error_block=error_block))

        def _redirect(self, location: str, headers: list[tuple[str, str]] | None = None) -> None:
            """Send a See Other redirect with optional response headers."""
            self.send_response(HTTPStatus.SEE_OTHER)
            self.send_header("Location", location)
            for name, value in headers or []:
                self.send_header(name, value)
            self.send_header("Content-Length", "0")
            self.end_headers()

        def _send_html(self, status: HTTPStatus, content: str) -> None:
            """Send an HTML response with deterministic encoding headers."""
            body = content.encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        @staticmethod
        def _session_cookie(token: str) -> str:
            """Build the secure-by-default session cookie attributes."""
            return f"session={token}; Path=/; HttpOnly; SameSite=Lax"

        @staticmethod
        def _expired_cookie() -> str:
            """Build a cookie header that removes the browser session."""
            return "session=; Path=/; Max-Age=0; HttpOnly; SameSite=Lax"

    return LoginHomepageHandler
