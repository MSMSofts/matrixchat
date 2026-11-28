#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 MatrixChat contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Static regression checks for web security configuration, not browser tests."""
from html.parser import HTMLParser
from pathlib import Path


class ScriptPolicy(HTMLParser):
    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag == "script":
            src = attributes.get("src")
            if not src or ":" in src or src.startswith("//"):
                raise ValueError("Script must be a local external file")
        for key, value in attrs:
            if key.lower().startswith("on"):
                raise ValueError("Inline event handler")
            if value and value.lstrip().lower().startswith("javascript:"):
                raise ValueError("Javascript URL")


root = Path(__file__).resolve().parents[1]
for html in ("index.html", "auth.html"):
    ScriptPolicy().feed((root / "web" / html).read_text(encoding="utf-8"))
assert (root / "web" / "flutter_bootstrap.js").is_file()
assert (root / "web" / "auth.js").is_file()
conf = (root / "deploy/nginx/matrixchat.conf").read_text(encoding="utf-8")
for header in (
    "X-Content-Type-Options nosniff",
    "X-Frame-Options DENY",
    "Referrer-Policy no-referrer",
    "Content-Security-Policy",
    "frame-ancestors 'none'",
    "object-src 'none'",
    "Content-Security-Policy-Report-Only",
):
    if header not in conf:
        raise ValueError("Missing web protection: " + header)
assert "--source-maps" not in (root / "Dockerfile").read_text(encoding="utf-8")
print("Web source security checks passed (browser tests remain required).")
