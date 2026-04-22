"""Minimal HTTP feedback form and thanks page app for chain validation.

This module owns only the example app runtime. It keeps submissions in memory,
renders a feedback form, validates URL-encoded form submissions, and exposes a
handler factory so tests can exercise the feature through a real HTTP server.
"""

from __future__ import annotations

import html
import secrets
import threading
from dataclasses import dataclass
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse


MAX_FORM_BYTES = 8192

FEEDBACK_PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Feedback</title>
</head>
<body>
  <main>
    <h1>Feedback</h1>
    {error_block}
    <form method="post" action="/feedback">
      <label>Name <input name="name" autocomplete="name"></label>
      <label>Message <textarea name="message"></textarea></label>
      <button type="submit">Send feedback</button>
    </form>
  </main>
</body>
</html>
"""

THANKS_PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Thanks</title>
</head>
<body>
  <main>
    <h1>Thanks, {name}</h1>
    <section aria-labelledby="submitted-feedback">
      <h2 id="submitted-feedback">Submitted feedback</h2>
      <p>{message}</p>
    </section>
    <p><a href="/feedback">Send another response</a></p>
  </main>
</body>
</html>
"""


@dataclass(frozen=True)
class FeedbackSubmission:
    """User-submitted feedback stored for the current in-memory app instance."""

    name: str  # Submitter display name; non-empty after trimming whitespace.
    message: str  # Feedback body text; non-empty after trimming whitespace.


def create_handler() -> type[BaseHTTPRequestHandler]:
    """Build a request handler class with isolated feedback state."""
    submissions: dict[str, FeedbackSubmission] = {}
    submissions_lock = threading.Lock()

    class FeedbackThanksHandler(BaseHTTPRequestHandler):
        """Serve feedback form, validation, submission, and thanks routes."""

        server_version = "FeedbackThanksPilot/1.0"

        def do_GET(self) -> None:
            """Route page requests without exposing internal failure details."""
            parsed = urlparse(self.path)
            if parsed.path == "/":
                self._redirect("/feedback")
                return
            if parsed.path == "/feedback":
                self._render_feedback()
                return
            if parsed.path == "/thanks":
                self._render_thanks(parsed.query)
                return
            self._send_html(HTTPStatus.NOT_FOUND, "Page not found.")

        def do_POST(self) -> None:
            """Route form submissions for the feedback flow."""
            if self.path == "/feedback":
                self._handle_feedback_submission()
                return
            self._send_html(HTTPStatus.NOT_FOUND, "Page not found.")

        def _handle_feedback_submission(self) -> None:
            """Validate required fields, store feedback, and redirect to thanks."""
            form = self._read_form()
            if form is None:
                return
            name = form.get("name", "").strip()
            message = form.get("message", "").strip()
            if not name or not message:
                self._render_feedback(
                    status=HTTPStatus.BAD_REQUEST,
                    error="Name and message are required.",
                )
                return
            submission_id = self._store_submission(
                FeedbackSubmission(name=name, message=message)
            )
            self._redirect(f"/thanks?id={submission_id}")

        def _render_thanks(self, query: str) -> None:
            """Render one stored feedback submission by id or a safe not-found page."""
            submission_id = parse_qs(query).get("id", [""])[0]
            with submissions_lock:
                submission = submissions.get(submission_id)
            if submission is None:
                self._send_html(HTTPStatus.NOT_FOUND, "Feedback was not found.")
                return
            self._send_html(
                HTTPStatus.OK,
                THANKS_PAGE.format(
                    name=html.escape(submission.name),
                    message=html.escape(submission.message),
                ),
            )

        def _store_submission(self, submission: FeedbackSubmission) -> str:
            """Persist one submission in memory and return its page-safe id."""
            while True:
                submission_id = secrets.token_urlsafe(8)
                with submissions_lock:
                    if submission_id not in submissions:
                        submissions[submission_id] = submission
                        return submission_id

        def _read_form(self) -> dict[str, str] | None:
            """Parse a small URL-encoded form body or send a safe error page."""
            length_header = self.headers.get("Content-Length", "0")
            try:
                length = int(length_header)
            except ValueError:
                self._send_html(HTTPStatus.BAD_REQUEST, "Invalid form submission.")
                return None
            if length < 0:
                self._send_html(HTTPStatus.BAD_REQUEST, "Invalid form submission.")
                return None
            if length > MAX_FORM_BYTES:
                self._send_html(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, "Form submission is too large.")
                return None
            raw_body = self.rfile.read(length).decode("utf-8", errors="replace")
            parsed = parse_qs(raw_body, keep_blank_values=True)
            return {key: values[0] if values else "" for key, values in parsed.items()}

        def _render_feedback(self, status: HTTPStatus = HTTPStatus.OK, error: str = "") -> None:
            """Render the feedback form with an optional user-readable error."""
            if error:
                error_block = f'<p role="alert">{html.escape(error)}</p>'
            else:
                error_block = ""
            self._send_html(status, FEEDBACK_PAGE.format(error_block=error_block))

        def _redirect(self, location: str) -> None:
            """Send a See Other redirect to the next feedback page."""
            self.send_response(HTTPStatus.SEE_OTHER)
            self.send_header("Location", location)
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

    return FeedbackThanksHandler
