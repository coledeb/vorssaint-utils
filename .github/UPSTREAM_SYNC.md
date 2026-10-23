# Upstream updates

**Sync upstream** runs every day at 14:23 UTC (9:23 AM Central during daylight
saving time, 8:23 AM during standard time). You can also run it from the
repository's **Actions → Sync upstream → Run workflow** page on `main`.

It fast-forwards this fork's `upstream` branch to `vorssaint/vorssaint-utils:main`
and opens a PR into our customized `main` when upstream commits are missing.
An existing open PR from `upstream` is reused and receives new commits as the
branch advances. No PR is created when there is nothing to merge.

Review the PR, approve CI workflows if GitHub requests it, and test the app
before merging. Use **Create a merge commit**, so future comparisons recognize
the original upstream commits. Keep the `upstream` branch after merging.
Conflicts need manual resolution; nothing is automatically merged into `main`.
If someone adds custom commits to `upstream` or the original repo rewrites its
history, the workflow fails rather than overwriting that branch.

The workflow uses the built-in `GITHUB_TOKEN` with contents and pull request
write access. **Settings → Actions → General → Workflow permissions → Allow
GitHub Actions to create and approve pull requests** must be enabled. The
automation only creates PRs; it never approves them. No personal access token
or additional repository secret is required.

GitHub may delay scheduled jobs and disables schedules in public repositories
after 60 days without repository activity. If checks stop arriving, open the
Actions page and re-enable the workflow. A failed run appears there as well.

This updates GitHub only. After merging an update, pull `fork/main` on your Mac
and rebuild the app using `python3 Tools/build-local.py --dev`.

Local verification:

```sh
python3 -m unittest discover -s .github/scripts -p 'test_*.py' -v
python3 .github/scripts/sync_upstream.py --dry-run
```
