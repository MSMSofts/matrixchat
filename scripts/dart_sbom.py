#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 MatrixChat contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Deterministic CycloneDX 1.6 inventory of the resolved Dart graph only."""
import json
import sys
from pathlib import Path
from urllib.parse import quote


def convert(graph):
    packages = graph["packages"]
    by_name = {}
    for package in packages:
        name = package["name"]
        version = package["version"]
        if not isinstance(name, str) or not name or not isinstance(version, str) or not version:
            raise ValueError("Invalid package identity")
        if name in by_name:
            raise ValueError("Duplicate package identity")
        by_name[name] = package
    roots = [p for p in packages if p.get("kind") == "root"]
    if len(roots) != 1:
        raise ValueError("Expected one root Dart package")
    root = roots[0]["name"]

    def component(name):
        p = by_name[name]
        ref = "dart:" + name + "@" + p["version"]
        value = {
            "type": "application" if name == root else "library",
            "bom-ref": ref,
            "name": name,
            "version": p["version"],
        }
        if p.get("source") == "hosted":
            value["purl"] = "pkg:pub/" + quote(name, safe="") + "@" + quote(p["version"], safe="")
        return value

    components = {name: component(name) for name in sorted(by_name)}
    edges = []
    for name in sorted(by_name):
        deps = by_name[name].get("dependencies", [])
        if not isinstance(deps, list) or not all(isinstance(d, str) and d in components for d in deps):
            raise ValueError("Dependency graph contains an unresolved edge")
        edges.append({
            "ref": components[name]["bom-ref"],
            "dependsOn": sorted({components[d]["bom-ref"] for d in deps}),
        })
    return {
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        "version": 1,
        "metadata": {"component": components[root]},
        "components": [components[n] for n in sorted(components) if n != root],
        "dependencies": edges,
    }


def self_test():
    app = {"name": "app", "version": "1.0.0", "kind": "root",
           "source": "root", "dependencies": ["lib"]}
    lib = {"name": "lib", "version": "2.0.0", "kind": "direct",
           "source": "hosted", "dependencies": []}
    first = convert({"packages": [app, lib]})
    assert first == convert({"packages": [lib, app]})
    assert first["metadata"]["component"]["name"] == "app"
    assert first["components"][0]["purl"] == "pkg:pub/lib@2.0.0"
    assert first["dependencies"][0]["dependsOn"] == ["dart:lib@2.0.0"]
    try:
        convert({"packages": [app]})
    except ValueError:
        pass
    else:
        raise AssertionError("Missing dependency not rejected")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    elif len(sys.argv) == 3:
        graph = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
        Path(sys.argv[2]).write_text(
            json.dumps(convert(graph), ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
    else:
        raise SystemExit("usage: dart_sbom.py input.json output.cdx.json | --self-test")
