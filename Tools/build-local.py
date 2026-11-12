#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

"""Portable local build: sign with the stable local identity, never Developer ID.

Developer and install builds use the self-signed "Vorssaint Utils Signing"
identity that Tools/setup-signing.sh creates in its own keychain, as build.sh
does. A stable certificate lets fan control's app and helper authenticate each
other over XPC, and keeps macOS permissions granted across rebuilds. If the
identity cannot be created, build.sh warns and falls back to ad-hoc signing.

Usage: python3 Tools/build-local.py --dev
       python3 Tools/build-local.py --test-suite=volume-indicator --test-suite=localization
The upstream build.sh remains the canonical build and packaging implementation.
"""

from pathlib import Path
import os
import re
import shlex
import subprocess
import sys
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    script = (root / "build.sh").read_text()

    def replace_once(old, new):
        nonlocal script
        if script.count(old) != 1:
            raise RuntimeError(f"Upstream build script changed; review the local wrapper: {old!r}")
        script = script.replace(old, new, 1)

    replace_once('cd "$(dirname "$0")"', "cd " + shlex.quote(str(root)))
    # Never pick up a Developer ID certificate: this fork is not released, and
    # local builds should match each other whichever certificates are present.
    script, count = re.subn(r"developer_id_identity\(\) \{.*?\n\}", "developer_id_identity() { return 0;\n}",
                            script, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError("Missing upstream signing function: developer_id_identity")
    for marker in ("legacy_identity_installed() {", "./Tools/setup-signing.sh"):
        if marker not in script:
            raise RuntimeError(f"Upstream build script changed; review the local wrapper: {marker!r}")
    # sysctl is unavailable in the agent sandbox. Four compiler jobs worked
    # well on this machine and avoid exhausting memory on a clean build.
    script = script.replace("$(sysctl -n hw.logicalcpu)", str(min(os.cpu_count() or 4, 4)))
    cache = shlex.quote(str(root / "build/module-cache"))
    script = script.replace("swiftc ", f"swiftc -module-cache-path {cache} ")
    script = script.replace("swift Tools/MakeIcon.swift", f"swift -module-cache-path {cache} Tools/MakeIcon.swift")
    with tempfile.TemporaryDirectory(prefix="vorssaint-local-build-") as directory:
        driver = Path(directory) / "build.zsh"
        driver.write_text(script)
        driver.chmod(0o700)
        return subprocess.call(["/bin/zsh", str(driver), *sys.argv[1:]], cwd=root)


if __name__ == "__main__":
    raise SystemExit(main())
