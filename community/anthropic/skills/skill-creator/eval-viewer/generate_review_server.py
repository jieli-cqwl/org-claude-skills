"""HTTP helpers for the eval review viewer."""

from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
import time
from http.server import BaseHTTPRequestHandler
from pathlib import Path
from typing import Callable


def kill_port(port: int) -> None:
    try:
        result = subprocess.run(
            ["lsof", "-ti", f":{port}"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        for pid_str in result.stdout.strip().split("\n"):
            if pid_str.strip():
                try:
                    os.kill(int(pid_str.strip()), signal.SIGTERM)
                except (ProcessLookupError, ValueError):
                    pass
        if result.stdout.strip():
            time.sleep(0.5)
    except subprocess.TimeoutExpired:
        pass
    except FileNotFoundError:
        print("Note: lsof not found, cannot check if port is in use", file=sys.stderr)


def build_review_handler(
    workspace: Path,
    skill_name: str,
    feedback_path: Path,
    previous: dict[str, dict],
    benchmark_path: Path | None,
    find_runs: Callable[[Path], list[dict]],
    generate_html: Callable[[list[dict], str, dict[str, dict], dict | None], str],
) -> type[BaseHTTPRequestHandler]:
    class ReviewHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            if self.path == "/" or self.path == "/index.html":
                runs = find_runs(workspace)
                benchmark = None
                if benchmark_path and benchmark_path.exists():
                    try:
                        benchmark = json.loads(benchmark_path.read_text())
                    except (json.JSONDecodeError, OSError):
                        pass
                html = generate_html(runs, skill_name, previous, benchmark)
                content = html.encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(content)))
                self.end_headers()
                self.wfile.write(content)
            elif self.path == "/api/feedback":
                data = b"{}"
                if feedback_path.exists():
                    data = feedback_path.read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            else:
                self.send_error(404)

        def do_POST(self) -> None:
            if self.path != "/api/feedback":
                self.send_error(404)
                return
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            try:
                data = json.loads(body)
                if not isinstance(data, dict) or "reviews" not in data:
                    raise ValueError("Expected JSON object with 'reviews' key")
                feedback_path.write_text(json.dumps(data, indent=2) + "\n")
                resp = b'{"ok":true}'
                self.send_response(200)
            except (json.JSONDecodeError, OSError, ValueError) as e:
                resp = json.dumps({"error": str(e)}).encode()
                self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)

        def log_message(self, format: str, *args: object) -> None:
            pass

    return ReviewHandler
