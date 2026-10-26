#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

"""Portable local build: use an ad-hoc signature without modifying a keychain.

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
    for name, code in [("developer_id_identity", "return 0"), ("legacy_identity_installed", "return 1")]:
        script, count = re.subn(rf"{name}\(\) \{{.*?\n\}}", f"{name}() {{ {code};\n}}",
                                script, count=1, flags=re.S)
        if count != 1:
            raise RuntimeError(f"Missing upstream signing function: {name}")
    start = script.index("if (( DEV || INSTALL ))")
    end = script.index("\ncodesign_with_timestamp_retry()", start)
    script = script[:start] + script[end:]
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
