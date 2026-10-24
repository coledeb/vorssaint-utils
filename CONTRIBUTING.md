# Contributing to Vorssaint

Vorssaint aims to stay small, native and readable. Contributions are accepted
under GPL-3.0-or-later unless stated otherwise.

## Getting started

You need macOS 14 or newer, Apple Silicon, Xcode Command Line Tools and Python 3.
The project builds without an Xcode project or external package dependencies.
`Package.swift` supports editor indexing; it does not assemble or sign the app.

```sh
git clone https://github.com/coledeb/vorssaint-utils.git
cd vorssaint-utils
python3 Tools/build-local.py --dev
build/stage.noindex/Vorssaint.app/Contents/MacOS/Vorssaint --selftest
python3 Tools/build-local.py --test-suite=preferences
```

To install, use `python3 Tools/build-local.py --dev --install`, then
`open /Applications/Vorssaint.app`. The install command can replace the official
app at that path; it does not launch the app automatically. For a build without
installation, open `build/stage.noindex/Vorssaint.app`.

This fork keeps the app and executable named `Vorssaint`, with bundle ID
`com.coledeb.vorssaint.utils` in both debug and release builds. Its fan helper
uses `com.coledeb.vorssaint.utils.fan-control`. Upstream self-updates are disabled.
`--install` targets `/Applications/Vorssaint.app` and can replace this fork,
its former `com.vorssaint.utils.dev` build, or the official `com.vorssaint.utils`
app. Only the app bundle is replaced: upstream preferences, stored data, and
permissions are not deleted or imported. Process shutdown uses bundle IDs;
when replacing upstream, its running processes are stopped before replacement.
Other apps sharing the executable name are not stopped.

On first launch, portable settings are copied once from the old development
preference domain without removing it or overwriting existing fork settings.
macOS permissions belong to the new identity and need to be granted again.
Stored history, security-scoped folder grants, and system recovery state stay
with the old build.

### Signing and optimized builds

`Tools/build-local.py` uses ad-hoc signing without creating a keychain identity.
Ad-hoc signatures change with the binary and can invalidate permission grants.
The canonical `./build.sh --dev` and `./build.sh --dev --install` commands instead
try to create a stable local signing identity when none is available. You can
also run `./Tools/setup-signing.sh`. Keep that identity across rebuilds and check
the output for signing failures. For stale grants, see
[troubleshooting](docs/TROUBLESHOOTING.md#resetting-permissions).

`python3 Tools/build-local.py` builds the optimized fork variant without a
signing certificate; `./build.sh` is the canonical optimized build used by CI.
Both use `Vorssaint` as the executable name and the fork's bundle ID. Official
upstream releases use Developer ID signing and notarization; local builds do
not become official releases.

## Scope and implementation

Before a substantial feature, search existing PRs and discuss the direction
with the fork maintainer. This fork currently has no issue tracker; upstream
issues describe the original project. Explain the user need, required permissions,
dependencies and ongoing maintenance. Prefer existing macOS capabilities and repository code
over a new subsystem. Keep each PR focused on one independently useful change.

- App lifecycle lives in `Sources/Vorssaint/App`, shared catalogs and preferences
  in `Core`, behavior in `Services`, views in `UI`, and diagnostics in `Support`.
  Keep reusable decisions outside views where they can be tested.
- Check other callers and the upgrade path when fixing shared behavior.
- New features belong in the feature catalog, with availability and permission
  checks on every entry point. Optional background work should stop when disabled.
- User preferences must participate in settings backup. Machine-specific state
  and private content need an explicit exclusion.
- Update every locale in `AppLanguage.allCases`, including feature-specific
  string catalogs. A new language also needs its locale registration, localized
  permission prompts where applicable, and coverage tests.
- New source files retain the project's SPDX license and copyright headers.

Sensor changes should include a dump from `./build/Vorssaint --sensors` and the
Mac model. Selection logic lives in `TemperatureSensorSelector` and `SystemMonitor`.

## Validation

Documentation-only changes need a diff and link check. For code changes, run the
relevant tests; `python3 Tools/build-local.py --list-tests` lists suites and
`python3 Tools/build-local.py --test-suite=NAME` selects one.
Use `python3 Tools/build-local.py --test` for the full suite. The corresponding
`./build.sh` flags remain available with the canonical signing behavior.
Behavior tests should fail without the fix and preserve legitimate use, rather than pinning private implementation text.

The test executable compiles a selected set of sources, so passing tests does not
prove the app builds. Build the app and run its selftest for runtime, UI or bundled
resource changes. CI also checks the optimized build, selftest, tests and packaging.
Builds should finish without warnings.

For behavior involving windows, permissions or hardware, describe what you actually
verified and on which Mac and macOS version. Include display, Spaces or language
details when relevant, and state what remains untested. Compilation and static
inspection alone do not demonstrate an interaction on a real Mac.

## Pull requests

Explain the behavior before and after, the scope and validation. Use
`type(scope): lowercase imperative phrase` for the title and reuse an existing
scope where possible. Open unfinished work as a draft and name what is missing.
The [template](.github/PULL_REQUEST_TEMPLATE.md) is a prompt, not a form.

Leave version bumps and `CHANGELOG.md` to the maintainer. Describe the user-visible
effect in the PR so it can become a release note with your credit.

When an issue exists, include one reference per line:

```text
Refs #123
Refs #456
```

Avoid `Closes` or `Fixes`: those close the issue at merge, before users receive
the fix. The inherited fix-status workflow uses these references for issue and
release tracking when those services are configured; this fork currently has no issue
tracker or published releases. If the PR addresses only part of an issue,
say exactly which part.

For agent-assisted work, see [contributing with an agent](docs/AI-CONTRIBUTIONS.md).
For the original project, bug reports and feature requests use the [upstream issue forms](https://github.com/vorssaint/vorssaint-utils/issues/new/choose).
See the [security policy](SECURITY.md) for private reporting availability.

## Releases (maintainers)

This fork currently has no published app releases and no configured public
release pipeline. Pushing source to `main` does not publish an app or update
installed copies. Upstream updates arrive as reviewable PRs through
[Sync upstream](.github/UPSTREAM_SYNC.md); rebuild after merging them.

The inherited [release workflow](.github/workflows/release.yml) is gated to
`vorssaint/vorssaint-utils` and its upstream maintainer. Pushing a version tag to
this fork does not make that workflow sign, notarize or publish a fork release.
Its signing requirements still refer to the upstream Apple developer team.
Fork distribution needs its own explicit release setup and signing decisions.
Do not reuse upstream credentials or claim upstream signing or notarization for
local fork builds.

For upstream maintenance, the existing workflow requires an approved release
from a verified commit on `main`, matching app version, dated changelog entry,
and version tag. The protected `release-signing` environment holds upstream's
signing and notarization credentials. Those details describe upstream's release
process, not a distribution service configured for this fork.
