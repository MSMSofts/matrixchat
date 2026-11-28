# SPDX-FileCopyrightText: 2026 MatrixChat contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Read-only validation of published RC metadata and all downloaded bytes."""
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from register_release import REPO, require, sha, verify

def gh_json(endpoint):
    return json.loads(subprocess.check_output(["gh", "api", endpoint], text=True))

def main():
    evidence = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    tag = evidence["tag"]
    commit = evidence["source_commit"]
    require(evidence["project"] == "MatrixChat", "Wrong project")
    require(re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+-rc\.[1-9][0-9]*", tag) is not None, "Not an RC tag")
    require(re.fullmatch(r"[a-f0-9]{40}", commit) is not None, "Invalid source commit")
    release = gh_json(f"repos/{REPO}/releases/tags/{tag}")
    require(release["id"] == evidence["release_id"], "Wrong release identity")
    require(release["tag_name"] == tag and release["draft"] is False and release["prerelease"] is True, "Not a published prerelease")
    require(gh_json(f"repos/{REPO}/commits/{tag}")["sha"] == commit, "Tag/source mismatch")
    expected = evidence["assets"]
    actual = {}
    for asset in release["assets"]:
        require(asset["name"] not in actual and asset["state"] == "uploaded", "Invalid remote asset")
        actual[asset["name"]] = asset["digest"]
    require(actual == {name: "sha256:" + digest for name, digest in expected.items()}, "Remote asset digest or filename mismatch")
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["gh", "release", "download", tag, "--repo", REPO, "--dir", tmp], check=True)
        root = Path(tmp)
        manifest, files = verify(root)
        require(manifest["source_commit"] == commit and "v" + manifest["version"] == tag, "Manifest/tag mismatch")
        require({p.name: sha(p) for p in files} == expected, "Downloaded asset differs from original assembly")
    print(f"PASS: {tag}; {len(expected)} assets, exact bytes and source commit verified")

if __name__ == "__main__":
    main()
