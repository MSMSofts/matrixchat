# SPDX-FileCopyrightText: 2026 MatrixChat contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Record the exact source and checksums for a non-production candidate."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

dist = Path("dist")
target, build_mode = sys.argv[1:]
commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
files = sorted(p for p in dist.iterdir() if p.is_file())
if not files:
    raise SystemExit("No build artifacts")
shutil.copyfile("LICENSE", dist / "LICENSE")
(dist / "BUILD.json").write_text(json.dumps({
    "project": "MatrixChat",
    "source": "https://github.com/MSMSofts/matrixchat/tree/" + commit,
    "commit": commit,
    "target": target,
    "build_mode": build_mode,
    "production_approved": False,
    "notice": "Test only with disposable accounts in isolated profiles. Inherited FluffyChat identifiers and services may remain."
}, indent=2) + "\n", encoding="utf-8")
files = sorted(p for p in dist.iterdir() if p.is_file() and p.name != "SHA256SUMS")
with (dist / "SHA256SUMS").open("w", encoding="utf-8", newline="\n") as out:
    for path in files:
        with path.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        out.write(f"{digest}  {path.name}\n")
