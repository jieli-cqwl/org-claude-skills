"""Real HTTP acceptance tests for the feedback form and thanks page pilot.

The tests define the observable contract for form rendering, validation,
submission redirects, stored feedback display, HTML escaping, and access logs.
"""

from __future__ import annotations

import contextlib
import http.client
import io
import socket
import threading
import unittest
from http import HTTPStatus
from http.server import ThreadingHTTPServer
from urllib.parse import urlencode

from examples.feedback_thanks_app.app import MAX_FORM_BYTES, create_handler


class FeedbackThanksAcceptanceTests(unittest.TestCase):
    """Exercise the feedback pilot through a real local HTTP server."""

    @classmethod
    def setUpClass(cls) -> None:
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

    def submit_feedback(self, name: str = "Ada", message: str = "Ship it") -> str:
        """Submit valid feedback and return the redirected thanks page path."""
        body = urlencode({"name": name, "message": message})
        status, headers, payload = self.request(
            "POST",
            "/feedback",
            body=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        self.assertEqual("", payload)
        self.assertEqual(HTTPStatus.SEE_OTHER, status)
        self.assertIn("Location", headers)
        self.assertRegex(headers["Location"], r"^/thanks\?id=[A-Za-z0-9_-]+$")
        return headers["Location"]

    def assert_invalid_submission_log_evidence(self, log_output: str) -> None:
        self.assertIn("POST /feedback", log_output)
        self.assertIn("400", log_output)

    def submission_count(self) -> int:
        for cell in self.server.RequestHandlerClass._store_submission.__closure__ or ():
            if isinstance(cell.cell_contents, dict):
                return len(cell.cell_contents)
        self.fail("feedback submission store closure is not inspectable")

    def raw_http_request(self, payload: bytes) -> str:
        """Send a raw HTTP payload for malformed-header boundary coverage."""
        with socket.create_connection((self.base_host, self.base_port), timeout=3) as sock:
            sock.sendall(payload)
            sock.shutdown(socket.SHUT_WR)
            chunks = []
            while True:
                chunk = sock.recv(4096)
                if not chunk:
                    break
                chunks.append(chunk)
        return b"".join(chunks).decode("utf-8", errors="replace")

    def test_root_redirects_to_feedback_form(self) -> None:
        status, headers, payload = self.request("GET", "/")

        self.assertEqual(HTTPStatus.SEE_OTHER, status)
        self.assertEqual("/feedback", headers["Location"])
        self.assertEqual("", payload)

        status, _, payload = self.request("GET", "/feedback")

        self.assertEqual(HTTPStatus.OK, status)
        self.assertIn("<form", payload)
        self.assertIn('method="post"', payload)
        self.assertIn('name="name"', payload)
        self.assertIn('name="message"', payload)

    def test_minimum_blank_field_request_fails_closed_without_creating_feedback(self) -> None:
        body = "name=&message="
        before_count = self.submission_count()

        status, headers, payload = self.request(
            "POST",
            "/feedback",
            body=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )

        self.assertEqual(HTTPStatus.BAD_REQUEST, status)
        self.assertNotIn("Location", headers)
        self.assertIn("Name and message are required.", payload)
        self.assertEqual(before_count, self.submission_count())

    def test_blank_submission_returns_readable_validation_error(self) -> None:
        body = urlencode({"name": "  ", "message": ""})

        status, _, payload = self.request(
            "POST",
            "/feedback",
            body=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )

        self.assertEqual(HTTPStatus.BAD_REQUEST, status)
        self.assertIn("Name and message are required.", payload)
        self.assertIn('name="name"', payload)
        self.assertIn('name="message"', payload)

    def test_negative_content_length_is_rejected_before_body_read(self) -> None:
        oversized_body = urlencode({"name": "Ada", "message": "x" * 9000}).encode()
        raw_response = self.raw_http_request(
            b"POST /feedback HTTP/1.1\r\n"
            b"Host: localhost\r\n"
            b"Content-Type: application/x-www-form-urlencoded\r\n"
            b"Content-Length: -1\r\n"
            b"Connection: close\r\n"
            b"\r\n"
            + oversized_body
        )

        self.assertIn("400 Bad Request", raw_response)
        self.assertIn("Invalid form submission.", raw_response)
        self.assertNotIn("/thanks?id=", raw_response)

    def test_oversized_submission_returns_readable_error(self) -> None:
        body = urlencode({"name": "Ada", "message": "x" * 9000})

        status, _, payload = self.request(
            "POST",
            "/feedback",
            body=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )

        self.assertEqual(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, status)
        self.assertIn("Form submission is too large.", payload)

    def test_maximum_body_boundary_submission_redirects_to_thanks_page(self) -> None:
        prefix = urlencode({"name": "Ada", "message": ""})
        message = "x" * (MAX_FORM_BYTES - len(prefix.encode("utf-8")))
        body = urlencode({"name": "Ada", "message": message})
        self.assertEqual(MAX_FORM_BYTES, len(body.encode("utf-8")))

        status, headers, payload = self.request(
            "POST",
            "/feedback",
            body=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )

        self.assertEqual("", payload)
        self.assertEqual(HTTPStatus.SEE_OTHER, status)
        self.assertRegex(headers["Location"], r"^/thanks\?id=[A-Za-z0-9_-]+$")

    def test_valid_submission_redirects_to_thanks_page(self) -> None:
        location = self.submit_feedback()

        status, _, payload = self.request("GET", location)

        self.assertEqual(HTTPStatus.OK, status)
        self.assertIn("Thanks, Ada", payload)
        self.assertIn("Ship it", payload)

    def test_thanks_page_escapes_submitted_feedback(self) -> None:
        location = self.submit_feedback(
            name="<script>alert(1)</script>",
            message="<strong>hello</strong>",
        )

        status, _, payload = self.request("GET", location)

        self.assertEqual(HTTPStatus.OK, status)
        self.assertIn("&lt;script&gt;alert(1)&lt;/script&gt;", payload)
        self.assertIn("&lt;strong&gt;hello&lt;/strong&gt;", payload)
        self.assertNotIn("<script>alert(1)</script>", payload)
        self.assertNotIn("<strong>hello</strong>", payload)

    def test_missing_feedback_id_returns_readable_not_found(self) -> None:
        status, _, payload = self.request("GET", "/thanks?id=missing")

        self.assertEqual(HTTPStatus.NOT_FOUND, status)
        self.assertIn("Feedback was not found.", payload)

    def test_invalid_submission_emits_access_log(self) -> None:
        body = urlencode({"name": "", "message": ""})
        captured = io.StringIO()

        with contextlib.redirect_stderr(captured):
            self.request(
                "POST",
                "/feedback",
                body=body,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )

        log_output = captured.getvalue()
        self.assert_invalid_submission_log_evidence(log_output)

    def test_observability_guard_rejects_missing_invalid_submission_log_evidence(self) -> None:
        with self.assertRaises(AssertionError):
            self.assert_invalid_submission_log_evidence("")

    def test_single_invalid_submission_produces_one_auditable_status_trace(self) -> None:
        body = urlencode({"name": "", "message": ""})
        captured = io.StringIO()

        with contextlib.redirect_stderr(captured):
            self.request(
                "POST",
                "/feedback",
                body=body,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )

        log_lines = [line for line in captured.getvalue().splitlines() if "POST /feedback" in line]
        self.assertEqual(1, len(log_lines))
        self.assertIn("400", log_lines[0])


if __name__ == "__main__":
    unittest.main()
