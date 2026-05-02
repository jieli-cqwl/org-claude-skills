"""File embedding helpers for the eval review viewer."""

from __future__ import annotations

import base64
import mimetypes
from pathlib import Path

TEXT_EXTENSIONS = {
    ".txt",
    ".md",
    ".json",
    ".csv",
    ".py",
    ".js",
    ".ts",
    ".tsx",
    ".jsx",
    ".yaml",
    ".yml",
    ".xml",
    ".html",
    ".css",
    ".sh",
    ".rb",
    ".go",
    ".rs",
    ".java",
    ".c",
    ".cpp",
    ".h",
    ".hpp",
    ".sql",
    ".r",
    ".toml",
}
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp"}
MIME_OVERRIDES = {
    ".svg": "image/svg+xml",
    ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
}


def get_mime_type(path: Path) -> str:
    ext = path.suffix.lower()
    if ext in MIME_OVERRIDES:
        return MIME_OVERRIDES[ext]
    mime, _ = mimetypes.guess_type(str(path))
    return mime or "application/octet-stream"


def read_base64(path: Path) -> str | None:
    try:
        return base64.b64encode(path.read_bytes()).decode("ascii")
    except OSError:
        return None


def embed_file(path: Path) -> dict:
    ext = path.suffix.lower()
    mime = get_mime_type(path)
    if ext in TEXT_EXTENSIONS:
        try:
            content = path.read_text(errors="replace")
        except OSError:
            content = "(Error reading file)"
        return {"name": path.name, "type": "text", "content": content}

    b64 = read_base64(path)
    if b64 is None:
        return {"name": path.name, "type": "error", "content": "(Error reading file)"}
    if ext in IMAGE_EXTENSIONS:
        return {
            "name": path.name,
            "type": "image",
            "mime": mime,
            "data_uri": f"data:{mime};base64,{b64}",
        }
    if ext == ".pdf":
        return {
            "name": path.name,
            "type": "pdf",
            "data_uri": f"data:{mime};base64,{b64}",
        }
    if ext == ".xlsx":
        return {"name": path.name, "type": "xlsx", "data_b64": b64}
    return {
        "name": path.name,
        "type": "binary",
        "mime": mime,
        "data_uri": f"data:{mime};base64,{b64}",
    }
