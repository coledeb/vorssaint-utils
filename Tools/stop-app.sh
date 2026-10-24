#!/bin/zsh
# Stop only processes registered under the requested bundle identity.
set -euo pipefail
bundle_id="${1:?bundle identifier required}"
app_pids() {
    /usr/bin/osascript -l JavaScript - "$bundle_id" <<'JXA'
ObjC.import('AppKit');
function run(argv) {
    const apps = $.NSRunningApplication.runningApplicationsWithBundleIdentifier(argv[0]);
    const pids = [];
    for (let i = 0; i < apps.count; i++) pids.push(apps.objectAtIndex(i).processIdentifier);
    return pids.join('\n');
}
JXA
}
pids="$(app_pids)" || exit 1
for app_pid in ${(f)pids}; do
    [[ "$app_pid" == <-> ]] || exit 1
    kill -TERM "$app_pid" 2>/dev/null || true
done
for attempt in {1..50}; do
    pids="$(app_pids)" || exit 1
    [[ -z "$pids" ]] && exit 0
    sleep 0.1
done
print -u2 "✗ $bundle_id is still running — quit it and retry"
exit 1
