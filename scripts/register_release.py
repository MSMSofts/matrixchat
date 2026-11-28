# SPDX-FileCopyrightText: 2026 MatrixChat contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Verify a candidate payload and optionally register an unpublished GitHub draft."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

REPO = "MSMSofts/matrixchat"
PACKAGES = {
    "android-universal": "android-candidate.apk",
    "windows-x64": "windows-x64-portable.zip",
    "linux-x64": "linux-x64.tar.gz",
    "linux-arm64": "linux-arm64.tar.gz",
    "macos": "macos-adhoc.zip",
    "ios-device": "ios-unsigned.zip",
    "web": "web.tar.gz",
}
METADATA = {"LICENSE", "RELEASE.json", "RELEASE_NOTES.md", "matrixchat-dart.cdx.json"}

def require(ok, message):
    if not ok:
        raise SystemExit(message)

def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def verify(root):
    require(root.is_dir(), "Payload directory not found")
    files = list(root.iterdir())
    require(all(p.is_file() and not p.is_symlink() for p in files), "Unexpected file or directory")
    manifest = json.loads((root / "RELEASE.json").read_text(encoding="utf-8"))
    version = manifest["version"]
    commit = manifest["source_commit"]
    require(re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-rc\.[1-9][0-9]*", version) is not None, "Not an RC version")
    require(re.fullmatch(r"[a-f0-9]{40}", commit) is not None, "Invalid source commit")
    require(manifest["project"] == "MatrixChat" and manifest["channel"] == "candidate" and manifest["production_approved"] is False, "Only non-production MatrixChat RCs are supported")
    expected = {target: "matrixchat-" + version + "-" + suffix for target, suffix in PACKAGES.items()}
    installer_enabled = manifest.get("windows_installer", False)
    require(type(installer_enabled) is bool, "Invalid installer flag")
    if installer_enabled:
        expected["windows-x64-installer"] = "matrixchat-" + version + "-windows-x64-setup.exe"
    names = set(expected.values()) | METADATA
    require({p.name for p in files} == names | {"SHA256SUMS"}, "Unexpected or missing payload files")
    checks = {}
    for line in (root / "SHA256SUMS").read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([a-f0-9]{64})  ([A-Za-z0-9._-]+)", line)
        require(match is not None, "Invalid checksum line")
        digest, name = match.groups()
        require(name not in checks, "Duplicate checksum")
        checks[name] = digest
    require(set(checks) == names, "Incomplete checksums")
    for name, digest in checks.items():
        require(sha(root / name) == digest, "Checksum mismatch: " + name)
    inventory = manifest["artifacts"]
    require(len(inventory) == len(expected), "Wrong platform count")
    for item in inventory:
        target = item["target"]
        require(target in expected and item["file"] == expected.pop(target), "Wrong or duplicate platform package")
        require(item["sha256"] == checks[item["file"]] and item["bytes"] == (root / item["file"]).stat().st_size, "Manifest mismatch")
        build_target = "windows-x64" if target == "windows-x64-installer" else target
        require(item["build"]["commit"] == commit and item["build"]["production_approved"] is False and item["build"]["target"] == build_target, "Wrong build source")
    require(not expected, "Missing platforms")
    print(f"Verified seven platforms, {len(inventory)} binaries, metadata and checksums for {version}")
    return manifest, sorted(files)

def gh(*args):
    return subprocess.check_output(["gh", *args], text=True).strip()

def register(root):
    manifest, files = verify(root)
    tag = "v" + manifest["version"]
    commit = manifest["source_commit"]
    # Authentication is supplied by the invoking owner or approved CI identity.
    # Do not request tokens, change permissions, or retry forbidden writes.
    require(gh("api", "repos/" + REPO + "/commits/" + commit, "--jq", ".sha") == commit, "Source commit mismatch")
    tags = gh("api", "repos/" + REPO + "/releases", "--paginate", "--jq", ".[].tag_name").splitlines()
    require(tag not in tags, "Release already exists; inspect it rather than overwrite")
    tags = gh("api", "repos/" + REPO + "/tags", "--paginate", "--jq", ".[].name").splitlines()
    require(tag not in tags, "Tag already exists; inspect it rather than overwrite")
    subprocess.run(["gh", "release", "create", tag, *[str(p.resolve()) for p in files],
                    "--repo", REPO, "--target", commit, "--title", "MatrixChat " + manifest["version"],
                    "--notes-file", str((root / "RELEASE_NOTES.md").resolve()),
                    "--draft", "--prerelease", "--latest=false"], check=True)
    print("Draft created; inspect its assets and status before any publication.")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("payload", type=Path)
    parser.add_argument("--create-draft", action="store_true", help="Explicitly create an unpublished prerelease using existing authorized gh credentials")
    args = parser.parse_args()
    if args.create_draft:
        register(args.payload)
    else:
        verify(args.payload)

if __name__ == "__main__":
    main()
