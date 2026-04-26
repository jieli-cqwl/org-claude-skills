#!/usr/bin/env python3
"""Query arxiv for deep-research and emit structured paper metadata."""
from __future__ import annotations

import argparse
import json
import sys
import urllib.parse
import urllib.request
from defusedxml import ElementTree as ET

API_URL = "https://export.arxiv.org/api/query"
ATOM_NS = {"atom": "http://www.w3.org/2005/Atom"}
DEFAULT_TIMEOUT_SECONDS = 20


def build_query_url(query: str, max_results: int) -> str:
    """Build an arxiv API URL with deterministic query encoding."""
    params = {
        "search_query": f"all:{query}",
        "start": "0",
        "max_results": str(max_results),
        "sortBy": "relevance",
        "sortOrder": "descending",
    }
    return f"{API_URL}?{urllib.parse.urlencode(params, quote_via=urllib.parse.quote)}"


def _validated_arxiv_url(url: str) -> str:
    """Require the fixed arxiv HTTPS endpoint before opening a URL."""
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.netloc != "export.arxiv.org" or parsed.path != "/api/query":
        raise ValueError("unexpected arxiv API URL")
    return url


def parse_feed(feed_text: str) -> list[dict[str, object]]:
    """Parse an arxiv Atom feed into the fields consumed by deep-research."""
    root = ET.fromstring(feed_text)
    papers: list[dict[str, object]] = []
    for entry in root.findall("atom:entry", ATOM_NS):
        authors = [
            name.text.strip()
            for name in entry.findall("atom:author/atom:name", ATOM_NS)
            if name.text and name.text.strip()
        ]
        papers.append(
            {
                "id": _text(entry, "atom:id"),
                "title": " ".join(_text(entry, "atom:title").split()),
                "summary": " ".join(_text(entry, "atom:summary").split()),
                "published": _text(entry, "atom:published"),
                "authors": authors,
            }
        )
    return papers


def fetch(query: str, max_results: int, timeout: int) -> list[dict[str, object]]:
    """Fetch and parse arxiv results with a caller-controlled timeout."""
    url = _validated_arxiv_url(build_query_url(query, max_results))
    with urllib.request.urlopen(url, timeout=timeout) as response:  # nosec B310
        return parse_feed(response.read().decode("utf-8"))


def _text(entry: ET.Element, path: str) -> str:
    node = entry.find(path, ATOM_NS)
    return node.text.strip() if node is not None and node.text else ""


def main() -> int:
    parser = argparse.ArgumentParser(description="Search arxiv and return JSON metadata.")
    parser.add_argument("--query", required=True)
    parser.add_argument("--max-results", type=int, default=5)
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_SECONDS)
    args = parser.parse_args()
    if args.max_results < 1 or args.max_results > 25:
        print("max-results must be between 1 and 25", file=sys.stderr)
        return 2
    try:
        papers = fetch(args.query, args.max_results, args.timeout)
    except Exception as exc:
        print(f"arxiv query failed: {exc}", file=sys.stderr)
        return 1
    payload = {"query": args.query, "papers": papers}
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
