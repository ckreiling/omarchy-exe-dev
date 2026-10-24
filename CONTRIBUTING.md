# Contributing

Use synthetic VM names and descriptions in tests, screenshots, and bug reports.
Never commit account responses, SSH keys, credentials, or private logs.

## Local checks

There are no npm dependencies or build step. Use Node.js 22 or newer:

```sh
node --test tests/*.test.cjs
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Widget.qml VmService.qml VmNavigation.qml VmDetail.qml ShortcutHint.qml
git diff --check
```

The contract tests supplement the official Omarchy validator; they do not replace
it. QML linting needs the matching Omarchy/Quickshell import environment. Tests
load the pure model without starting SSH or launching a browser/terminal.

Make changes on a branch and open a pull request. Keep the default branch
installable: Omarchy updates users from default-branch HEAD, not release tags.
Do not introduce install hooks, privilege escalation, shell-evaluated VM
metadata, or runtime package downloads.

## Manual desktop tests

On a supported Omarchy session, test:

- Fresh Git-based install, discovery, enabling, and bar placement.
- Open by click and IPC; Escape closes; close/reopen and shell restart work.
- Grouping when empty; flat relevance order when filtering; case-insensitive
  subsequences; no matches; replacement query and whitespace-only query.
- Slash focuses the finder without inserting slash; typing list shortcut
  letters does not activate them; Enter returns to the list without launching.
- Arrow navigation, scrolling, browser/SSH selection, and hover selection
  target the same displayed VM, including after a refresh or filter change.
- S/B launch from both list and details; list Enter opens details; details Enter
  launches the selected action. Escape returns to the same query and selection.
- Row click defaults to SSH; test browser/details click settings, including
  access-denied actions. There must be no action buttons on list rows.
- Detail refresh tracks the same VM by name; removal returns to the list safely.
- SSH/browser buttons, access-disabled buttons, refresh, and middle-click.
- Creation age boundaries (just now/minutes/hours/days), live age updates, and
  missing/invalid timestamps; the exact date should only appear on hover.
- E opens a new floating terminal in the exe.dev REPL from the list, including
  an empty account. While filtering, E must type normally.
- Management actions require explicit admin access and named confirmation.
  Escape cancels; Enter confirms once; no S/B shortcut may bypass confirmation.
  Check success/error/timeout messages and the refreshed list afterward.
  Exercise restart, pause/resume, and copy only on a disposable VM with the
  account owner's permission; copy can consume additional capacity.
- Empty account, failed authentication, unavailable network, malformed response,
  and recovery; stale results remain visible after a failed refresh.
- Disable/re-enable, Git-based update, and removal. Do not remove a checkout
  containing unsaved work.
- At least a small screen and an alternate bar position/theme.

Do destructive installation/removal testing in a disposable account or VM, not
by deleting the maintainer's live plugin. Never use another person's account.

## Release checklist

1. Run all local checks and the desktop matrix on the supported Omarchy version.
2. Update CHANGELOG.md and manifest.json together.
3. Review the diff for credentials, real VM metadata, and unexpected artifacts.
4. Merge via a pull request with passing CI. Workflow actions must stay pinned to
   full commit SHAs; review Dependabot updates before merging.
5. Create the version tag at the tested main commit and prepare release notes.
   Published version tags must not be moved or deleted.
6. Publish the release only when the documented compatibility and tests are true.
7. If listed on the marketplace, request verification of the exact new commit;
   verification of an older commit does not cover a later update.

The plugin ID `cmk.exe-dev` is stable; do not rename it as routine cleanup.

## Licensing

Contributions are under the repository's MIT license. Retain applicable notices
when copying code; do not assume a marketplace listing transfers asset rights.
