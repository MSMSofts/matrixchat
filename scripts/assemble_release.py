# SPDX-FileCopyrightText: 2026 MatrixChat contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Validate seven existing build artifacts and create a draft RC payload."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys

TARGETS = {
    "android": ("android-universal", "matrixchat-android-candidate.apk", "Ephemeral debug signature; separate candidate application ID"),
    "windows-x64": ("windows-x64", "matrixchat-windows-x64-portable.zip", "Unsigned portable EXE bundle"),
    "linux-x64": ("linux-x64", "matrixchat-linux-x64.tar.gz", "Unsigned release bundle"),
    "linux-arm64": ("linux-arm64", "matrixchat-linux-arm64.tar.gz", "Unsigned release bundle"),
    "macos": ("macos", "matrixchat-macos-adhoc.zip", "Ad-hoc signed; not notarized"),
    "ios-unsigned": ("ios-device", "matrixchat-ios-unsigned.zip", "Unsigned device app; not directly installable"),
    "web": ("web", "matrixchat-web.tar.gz", "Unsigned web bundle; HTTPS deployment required"),
}

def require(condition, message):
    if not condition:
        raise ValueError(message)

def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def load(path):
    return json.loads(path.read_text(encoding="utf-8"))

def verify_run(run, run_id, commit, name, require_success=True):
    require(run["id"] == run_id and run["head_sha"] == commit, "Run/source mismatch")
    require(run["name"] == name, "Unexpected workflow")
    require(run["head_repository"]["full_name"] == "MSMSofts/matrixchat", "Unexpected repository")
    require(run["status"] == "completed", "Run not complete")
    if require_success:
        require(run["conclusion"] == "success", name + " did not pass")

def verify_artifact(folder, commit, target, binary):
    expected = {binary, "LICENSE", "BUILD.json", "SHA256SUMS"}
    require(folder.is_dir(), "Missing artifact: " + folder.name)
    files = list(folder.iterdir())
    require(all(p.is_file() and not p.is_symlink() for p in files), "Unexpected artifact entries")
    require({p.name for p in files} == expected, "Unexpected artifact contents")
    checks = {}
    for line in (folder / "SHA256SUMS").read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9._-]+)", line)
        require(match is not None, "Invalid checksum line")
        digest, name = match.groups()
        require(name not in checks, "Duplicate checksum")
        checks[name] = digest
    require(set(checks) == expected - {"SHA256SUMS"}, "Checksum coverage mismatch")
    for name, digest in checks.items():
        require(sha(folder / name) == digest, "Checksum mismatch: " + name)
    meta = load(folder / "BUILD.json")
    require(meta["commit"] == commit and meta["target"] == target, "Wrong artifact source or target")
    require(meta["production_approved"] is False, "Unexpected approval status")
    require(meta["source"] == "https://github.com/MSMSofts/matrixchat/tree/" + commit, "Wrong source URL")
    require((folder / binary).stat().st_size > 0, "Empty artifact")
    return meta

def main():
    plan = load(Path(sys.argv[1]))
    evidence = Path(sys.argv[2])
    incoming = Path(sys.argv[3])
    output = Path(sys.argv[4])
    commit = plan["source_commit"]
    version = plan["version"]
    require(re.fullmatch(r"[0-9a-f]{40}", commit) is not None, "Invalid commit")
    require(re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-rc\.[1-9][0-9]*", version) is not None, "Invalid RC version")
    require(plan["channel"] == "candidate", "Stable releases not supported by this workflow")
    build = load(evidence / "build.json")
    security = load(evidence / "security.json")
    pr = load(evidence / "pr.json")
    verify_run(build, plan["build_run"], commit, "MatrixChat Platform Candidates")
    verify_run(security, plan["security_run"], commit, "MatrixChat Security Checks")
    verify_run(pr, plan["pull_request_run"], commit, "Pull Request Workflow", False)
    expected = {"matrixchat-" + name + "-" + commit for name in TARGETS}
    require({p.name for p in incoming.iterdir()} == expected, "Missing or unexpected platform artifacts")
    output.mkdir(parents=True, exist_ok=False)
    inventory = []
    canonical_license = (evidence / "LICENSE").read_bytes()
    require(bool(canonical_license), "Missing source license")
    shutil.copyfile(evidence / "LICENSE", output / "LICENSE")
    normalized_license = canonical_license.replace(b"\r\n", b"\n")
    for name, (target, binary, signing) in TARGETS.items():
        folder = incoming / ("matrixchat-" + name + "-" + commit)
        meta = verify_artifact(folder, commit, target, binary)
        # Git checkout on Windows can convert LF to CRLF. Each original
        # artifact has already passed byte-exact SHA-256 verification.
        # Compare only newline-normalized license bytes to the source blob.
        require((folder / "LICENSE").read_bytes().replace(b"\r\n", b"\n") == normalized_license,
                "License text differs from source: " + name)
        # Give each package a stable, versioned filename without altering its bytes.
        filename = binary.replace("matrixchat-", "matrixchat-" + version + "-", 1)
        shutil.copyfile(folder / binary, output / filename)
        inventory.append({"target": target, "file": filename, "bytes": (output / filename).stat().st_size,
                          "sha256": sha(output / filename), "signing": signing, "build": meta})
    sbom = evidence / "sbom" / "matrixchat-dart.cdx.json"
    sbom_data = load(sbom)
    require(sbom_data.get("bomFormat") == "CycloneDX" and sbom_data.get("components"), "Missing Dart SBOM")
    shutil.copyfile(sbom, output / "matrixchat-dart.cdx.json")
    manifest = {"schema": 1, "project": "MatrixChat", "version": version,
                "app_version": plan["app_version"], "source_commit": commit,
                "production_approved": False, "channel": "candidate",
                "build_run": build["html_url"], "security_run": security["html_url"],
                "pull_request_run": pr["html_url"], "pull_request_result": pr["conclusion"],
                "artifacts": inventory, "sbom_scope": "Dart dependencies only"}
    (output / "RELEASE.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    notes = [
        "# MatrixChat " + version,
        "Release candidate for isolated testing only. Not a stable or security-certified release.",
        "", "## Highlights", "",
        "- Native SQLCipher media and draft vaults; non-destructive key recovery.",
        "- Verified identity continuity, strict message policy, protected local PIN and RTC key checks.",
        "- Web security controls, dependency and secret scans, Dart SBOM and seven platform builds.",
        "", "## Verification", "",
        "- Source: `" + commit + "`",
        "- Embedded application version: `" + plan["app_version"] + "` (release label is independent).",
        "- Seven platform builds: passed. Security checks: passed.",
        "- Full PR workflow: " + pr["conclusion"] + ". Visual regression review and integration testing remain outstanding.",
        "- Build and security run links: " + build["html_url"] + " ; " + security["html_url"],
        "", "## Downloads", "", "| Target | Package | Signing / limitations |", "| --- | --- | --- |",
    ]
    for item in inventory:
        notes.append("| " + item["target"] + " | `" + item["file"] + "` | " + item["signing"] + " |")
    notes += ["", "## Before installation", "", "Verify SHA256SUMS. Use disposable accounts and isolated profiles. "
              "Do not replace an existing FluffyChat installation or use production credentials. "
              "Some inherited identifiers and service endpoints remain. No Apple publisher signature or Windows Authenticode. "
              "Independent audit, native migration, device and RTC interoperability tests are not complete.",
              "", "Source code: https://github.com/MSMSofts/matrixchat/tree/" + commit,
              "License: AGPL-3.0-or-later; original attribution retained. Checksums are integrity records, not publisher signatures."]
    (output / "RELEASE_NOTES.md").write_text("\n".join(notes) + "\n", encoding="utf-8")
    with (output / "SHA256SUMS").open("w", encoding="utf-8", newline="\n") as stream:
        for path in sorted(output.iterdir()):
            if path.name != "SHA256SUMS":
                stream.write(sha(path) + "  " + path.name + "\n")

if __name__ == "__main__":
    main()
