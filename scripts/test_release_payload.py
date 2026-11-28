# SPDX-FileCopyrightText: 2026 MatrixChat contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Offline regression tests for candidate payload verification."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest

from register_release import METADATA, PACKAGES, sha, verify

class PayloadTests(unittest.TestCase):
    def make_payload(self, root, installer=False):
        version = "2.11.6-rc.2"
        commit = "a" * 40
        packages = dict(PACKAGES)
        if installer:
            packages["windows-x64-installer"] = "windows-x64-setup.exe"
        items = []
        for target, suffix in packages.items():
            name = "matrixchat-" + version + "-" + suffix
            path = root / name
            path.write_bytes(target.encode())
            build_target = "windows-x64" if target == "windows-x64-installer" else target
            items.append({"target": target, "file": name, "bytes": path.stat().st_size,
                          "sha256": sha(path), "build": {"commit": commit, "production_approved": False,
                                                        "target": build_target}})
        for name in METADATA - {"RELEASE.json"}:
            (root / name).write_text(name, encoding="utf-8")
        manifest = {"project": "MatrixChat", "version": version, "channel": "candidate",
                    "source_commit": commit, "production_approved": False, "artifacts": items}
        if installer:
            manifest["windows_installer"] = True
        (root / "RELEASE.json").write_text(json.dumps(manifest), encoding="utf-8")
        (root / "SHA256SUMS").write_text("".join(
            sha(p) + "  " + p.name + "\n" for p in sorted(root.iterdir())), encoding="utf-8")

    def test_existing_and_installer_payloads(self):
        for installer in (False, True):
            with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
                root = Path(tmp)
                self.make_payload(root, installer)
                manifest, files = verify(root)
                self.assertEqual(len(manifest["artifacts"]), 8 if installer else 7)
                self.assertEqual(len(files), 13 if installer else 12)

    def test_tampered_package_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.make_payload(root, True)
            (root / "matrixchat-2.11.6-rc.2-windows-x64-setup.exe").write_bytes(b"tampered")
            with self.assertRaises(SystemExit):
                verify(root)

    def test_missing_installer_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.make_payload(root, True)
            (root / "matrixchat-2.11.6-rc.2-windows-x64-setup.exe").unlink()
            with self.assertRaises(SystemExit):
                verify(root)

if __name__ == "__main__":
    unittest.main()
