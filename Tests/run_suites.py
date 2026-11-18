#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

"""Run every test suite of the compiled runner, several at a time.

Each suite runs in its own process: a selected suite already runs alone with
`--suite=`. Every worker slot has its own copy of the runner, so the processes
never share a standard defaults domain (one per executable name). Output is
printed in suite order once all suites finish, followed by the same summary
line as an unfiltered run. A suite that crashes or prints no summary fails.

VORSSAINT_TEST_JOBS sets the number of concurrent suites; 1 runs the runner
once, unfiltered, exactly as before.
"""
import concurrent.futures
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

# The runner skips notch-music in an unfiltered run because notch already
# executes it (see MetricsTests.swift). Keep the same set of suites here.
SKIPPED = {"notch-music"}
# Slowest first, so they never start last and stretch the run. Measured
# serially; anything unlisted is short and keeps runner order.
SLOWEST = ["recorder", "notch", "agents", "screenshots", "feature-hub-layout",
           "settings", "dock-autohide", "switcher", "repository", "utilities"]
SUITE_TIMEOUT = 900
# "TESTS OK (n checks)" or "TESTS FAILED (k of n):", as TestSuite.finish prints.
SUMMARY = re.compile(r"^TESTS (?:(OK) \((\d+) checks\)|(FAILED) \((\d+) of (\d+)\):)", re.M)


def main():
    runner = Path(sys.argv[1])
    jobs = int(os.environ.get("VORSSAINT_TEST_JOBS", "0") or 0) or min(6, os.cpu_count() or 1)
    if jobs <= 1:
        os.execv(str(runner), [str(runner)])

    listed = subprocess.run([str(runner), "--list"], capture_output=True, text=True, check=True).stdout.split()
    suites = [name for name in listed if name not in SKIPPED]
    order = sorted(suites, key=lambda name: (SLOWEST.index(name) if name in SLOWEST else len(SLOWEST)))
    jobs = min(jobs, len(order))

    copies = []
    for slot in range(jobs):
        copy = runner.with_name(f"{runner.name}-{slot + 1}")
        copy.unlink(missing_ok=True)
        # An APFS clone costs nothing; fall back to a plain copy elsewhere.
        if subprocess.run(["cp", "-c", str(runner), str(copy)], capture_output=True).returncode != 0:
            shutil.copy2(runner, copy)
        copies.append(copy)
    free = list(copies)
    lock = threading.Lock()

    def run(name):
        with lock:
            binary = free.pop()
        started = time.monotonic()
        try:
            result = subprocess.run([str(binary), f"--suite={name}"], capture_output=True, text=True,
                                    timeout=SUITE_TIMEOUT)
            output, code = result.stdout + result.stderr, result.returncode
        except subprocess.TimeoutExpired as error:
            output = (error.stdout or b"").decode(errors="replace") if isinstance(error.stdout, bytes) else (error.stdout or "")
            output += f"\n{name}: timed out after {SUITE_TIMEOUT}s\n"
            code = -1
        finally:
            with lock:
                free.append(binary)
        return name, code, output, time.monotonic() - started

    started = time.monotonic()
    print(f"▸ Running {len(order)} suites, {jobs} at a time…", flush=True)
    results = {}
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
            for name, code, output, elapsed in pool.map(run, order):
                results[name] = (code, output, elapsed)
    finally:
        for copy in copies:
            copy.unlink(missing_ok=True)

    checks, failures, broken = 0, [], []
    for name in suites:
        code, output, elapsed = results[name]
        summary = SUMMARY.search(output)
        # Keep each suite's own output, minus its per-process summary block.
        body = output[:summary.start()] if summary else output
        sys.stdout.write(body if body.endswith("\n") or not body else body + "\n")
        if summary is None:
            broken.append(f"{name}: exited {code} without a test summary")
            continue
        passed = summary.group(1) == "OK"
        checks += int(summary.group(2) if passed else summary.group(5))
        if not passed or code != 0:
            listed_failures = [line[4:] for line in output[summary.end():].splitlines() if line.startswith("  - ")]
            failures += listed_failures or [f"{name}: exited {code}"]

    print(f"▸ {len(suites)} suites in {time.monotonic() - started:.1f}s", flush=True)
    failures += broken
    if failures:
        print(f"TESTS FAILED ({len(failures)} of {checks}):")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print(f"TESTS OK ({checks} checks)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
