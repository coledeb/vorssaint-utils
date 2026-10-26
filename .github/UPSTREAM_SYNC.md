# Upstream updates

**Sync upstream** runs twice daily at 6 AM and 6 PM Central time
(`America/Chicago`), automatically adjusting for daylight saving time. You can also run it from the
repository's **Actions → Sync upstream → Run workflow** page on `main`.

It fast-forwards this fork's `upstream` branch to `vorssaint/vorssaint-utils:main`
and opens a PR into our customized `main` when upstream commits are missing.
An existing open PR from `upstream` is reused and receives new commits as the
branch advances. No PR is created when there is nothing to merge.

Review the PR, approve CI workflows if GitHub requests it, and test the app
before merging. Use **Create a merge commit**, so future comparisons recognize
the original upstream commits. Keep the `upstream` branch after merging.
The **Upstream merge check** commit status reports whether the PR merges cleanly
into `main`; a failure requires manual conflict resolution. Nothing is
automatically merged into `main`.
If someone adds custom commits to `upstream` or the original repo rewrites its
history, the workflow fails rather than overwriting that branch.

The workflow uses the built-in `GITHUB_TOKEN` with contents, pull request
and commit-status write access. **Settings → Actions → General → Workflow permissions → Allow
GitHub Actions to create and approve pull requests** must be enabled. The
automation only creates PRs; it never approves them. No personal access token
or additional repository secret is required.

GitHub may delay scheduled jobs and disables schedules in public repositories
after 60 days without repository activity. If checks stop arriving, open the
Actions page and re-enable the workflow. A failed run appears there as well.

This updates GitHub only. After merging an update, pull `fork/main` on your Mac
and rebuild the app using `python3 Tools/build-local.py --dev`. To update an
installed copy at `/Applications/Vorssaint.app`, use
`python3 Tools/build-local.py --dev --install` instead. Quit the running copy
before opening the rebuilt app. The fork does not install upstream releases
through its in-app updater.

Local verification:

```sh
python3 -m unittest discover -s .github/scripts -p 'test_*.py' -v
python3 .github/scripts/sync_upstream.py --dry-run
```
