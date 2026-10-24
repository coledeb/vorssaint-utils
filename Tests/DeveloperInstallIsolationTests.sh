#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
set -euo pipefail
cd "$(dirname "$0")/.."
install_test_dir=$(mktemp -d)
trap 'command rm -rf "$install_test_dir"' EXIT
# Exercise the real install block against disposable apps; never stop real apps.
sed -n '/^if (( INSTALL )); then$/,$p' build.sh \
    | sed -e 's|/Applications|$install_test_dir/Applications|g' \
          -e 's|./Tools/stop-app.sh|stop_app|' > "$install_test_dir/install.zsh"
INSTALL=1
APP_NAME=Vorssaint
EXECUTABLE=Vorssaint
APP_BUNDLE_ID=com.coledeb.vorssaint.utils
STAGE="$install_test_dir/stage"
mkdir -p "$STAGE"
print new > "$STAGE/content"
stopped=()
signed=()
stop_app() { stopped+=("$1"); }
sign_installed_bundle() { signed+=("$1"); }
for DEV in 1 0; do
    stopped=(); signed=()
    for name in Vorss 'Vorssaint Utils' 'Vorssaint (Developer)'; do
        mkdir -p "$install_test_dir/Applications/$name.app"
        print original > "$install_test_dir/Applications/$name.app/content"
    done
    mkdir -p "$install_test_dir/Applications/Vorssaint.app/Contents"
    print original > "$install_test_dir/Applications/Vorssaint.app/content"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $APP_BUNDLE_ID" \
        "$install_test_dir/Applications/Vorssaint.app/Contents/Info.plist" >/dev/null
    source "$install_test_dir/install.zsh"
    [[ "$(cat "$install_test_dir/Applications/Vorssaint.app/content")" == new ]]
    [[ "${signed[*]}" == "$install_test_dir/Applications/Vorssaint.app" ]]
    [[ "${stopped[*]}" == "$APP_BUNDLE_ID" ]]
    for name in Vorss 'Vorssaint Utils' 'Vorssaint (Developer)'; do
        [[ "$(cat "$install_test_dir/Applications/$name.app/content")" == original ]]
    done
done
# Replacing upstream (or the old development build) replaces only its app bundle.
for installed_id in com.vorssaint.utils com.vorssaint.utils.dev; do
    stopped=(); signed=()
    mkdir -p "$install_test_dir/Applications/Vorssaint.app/Contents"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $installed_id" \
        "$install_test_dir/Applications/Vorssaint.app/Contents/Info.plist" >/dev/null
    mkdir -p "$install_test_dir/Library/Preferences" "$install_test_dir/Library/Application Support/$installed_id"
    print settings > "$install_test_dir/Library/Preferences/$installed_id.plist"
    print history > "$install_test_dir/Library/Application Support/$installed_id/history"
    source "$install_test_dir/install.zsh"
    [[ "$(cat "$install_test_dir/Applications/Vorssaint.app/content")" == new ]]
    [[ "${stopped[*]}" == "$APP_BUNDLE_ID $installed_id" ]]
    [[ "$(cat "$install_test_dir/Library/Preferences/$installed_id.plist")" == settings ]]
    [[ "$(cat "$install_test_dir/Library/Application Support/$installed_id/history")" == history ]]
done
# Refuse an unrelated app even if it occupies the standard path.
mkdir -p "$install_test_dir/Applications/Vorssaint.app/Contents"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string com.example.unrelated' \
    "$install_test_dir/Applications/Vorssaint.app/Contents/Info.plist" >/dev/null
print unrelated > "$install_test_dir/Applications/Vorssaint.app/content"
if ( source "$install_test_dir/install.zsh" ); then
    print -u2 'installer replaced an unrelated app'; exit 1
fi
[[ "$(cat "$install_test_dir/Applications/Vorssaint.app/content")" == unrelated ]]
print 'DEVELOPER INSTALL ISOLATION TESTS OK'
