# exe.dev for Omarchy

[![CI](https://github.com/ckreiling/omarchy-exe-dev/actions/workflows/ci.yml/badge.svg)](https://github.com/ckreiling/omarchy-exe-dev/actions/workflows/ci.yml)

Browse and fuzzy-find your [exe.dev](https://exe.dev/) virtual machines from the
Omarchy bar. Open a VM in your browser or SSH into it without leaving the desktop.

An independent community plugin, not an official exe.dev or Omarchy product.

## Features

- Lists VMs grouped by their first tag, sorted by name within each group.
- Press `/` to fuzzy-find by VM name, with a flat, best-match-first result list.
- Shows emoji, description, tags, status, and public-web visibility.
- Minimal VM details on Enter, with browser/SSH buttons and full connection info.
- Always-visible B/S shortcut guide; quick-launch actions respect API access restrictions.
- Click a VM to SSH by default, configurable to browser or details.
- Relative creation age beside the VM name; restart, pause/resume, and copy actions
  with explicit confirmation and administration-access checks.
- E opens the exe.dev REPL in a new floating terminal.
- Keyboard navigation, scrolling, and theme-aware styling.
- Refreshes on open and periodically while open; retains the last successful list
  in memory when a query fails.
- No build step, extra daemon, account tokens, or Node/Python runtime required.

## Requirements

- **Omarchy Quattro** with the Quickshell shell/plugin system and `qs.Ui` helpers.
  Tested on Omarchy **4.0.6-1**; older Waybar-based releases are not supported.
- OpenSSH (`ssh`) and GNU coreutils (`timeout`).
- Omarchy's `omarchy-launch-browser` and `omarchy-launch-terminal` commands, and
  your configured browser and terminal. The REPL shortcut uses
  `--app-id=org.omarchy.terminal`, which Omarchy's stock window rules float.
- An exe.dev account and SSH authentication usable by the desktop shell.

These desktop tools ship with the supported Omarchy environment. Node.js is only
needed to run development tests.

### Authenticate first

In a terminal, run:

```sh
ssh exe.dev
ssh exe.dev ls --json
```

Complete registration if needed. Before accepting a new SSH host key, verify it
against [exe.dev's host-key documentation](https://exe.dev/docs/faq/host-key.md).
Do not disable host-key checking to make the plugin connect.

Background queries use batch mode: they cannot display a password or passphrase
prompt. If your key is encrypted, unlock it in the SSH agent available to your
Omarchy session. Your existing SSH configuration and agent are respected; the
plugin does not edit keys, SSH config, or known-hosts files.

## Install

Review the source before enabling: Omarchy plugins run unsandboxed as your user.

```sh
omarchy plugin add https://github.com/ckreiling/omarchy-exe-dev.git --enable
```

The plugin ID is **`cmk.exe-dev`**. Omarchy validates the manifest and installs the
Git checkout under `~/.config/omarchy/plugins/cmk.exe-dev/`. The default bar
section is right; the interactive installer can ask where you want it.
No custom installer, install hook, package installation, or privileged operation
is required.

For a staged installation, omit `--enable`, decline enabling if prompted, review
the installed files, then run:

```sh
omarchy plugin enable cmk.exe-dev
```

Move it later with:

```sh
omarchy bar move cmk.exe-dev --section right
```

## Usage

Click the bar's server icon to open the list. The header globe opens the exe.dev
dashboard; the refresh button reloads the VMs. Middle-click the bar icon to
refresh without opening the panel.

Hover or use ↑/↓ to select a VM. **S opens SSH; B opens the browser**, directly
from either the list or details. The footer displays these shortcuts without
adding buttons to every row.

**Enter opens details**: the VM's name, emoji and human-readable creation age
become the panel title (for example, "Created just now" or "Created 3 days ago").
The age updates while details are open; hover for the exact timestamp.
Hostname, status, web port, sharing, and egress policy are grouped together
directly below, followed by the description and tags. A dense metadata grid
shows CPU/RAM/disk, region, email receiving and image, when returned by the API. Full image references and clipped values are available on hover.
SSH and Browser buttons retain their full destinations in tooltips.
In details, use the arrow keys to select an action and Enter to activate it,
or use S/B directly for SSH/browser.
Escape or the back arrow returns to the same filtered list and selection.

**Clicking a VM opens SSH by default.** You can change this to browser or details
in the plugin settings; the setting affects mouse clicks only.

The browser action opens `https://<vm-name>.exe.xyz/`. The terminal action runs
SSH using the API's validated `ssh_dest`, including username-routed destinations.
Neither action changes a VM's web-sharing or access settings.

### VM management

Details also provide **Copy**, **Restart**, and **Pause** (or **Resume** for a
paused VM). These controls require the API's administration permission and ask
for confirmation naming the target VM. Enter confirms; Escape cancels without
executing a command.

Copy uses exe.dev's auto-generated name and consumes additional VM capacity.
Restart interrupts running work and connections; pause suspends the VM until
resumed. Commands run in the background, display their outcome, and refresh the
list afterward. Only one management command runs at a time. Requests have a
120-second deadline; a timeout can leave the outcome unknown, so refresh and
check the account before retrying, especially before making another copy.

On the main list, **E** opens a new floating terminal running `ssh exe.dev`.
It does not act on the selected VM. While typing a filter, E is ordinary text.

### Keyboard

| Key | Action |
| --- | --- |
| `/` | Focus the VM-name fuzzy finder; select any existing query |
| Enter while filtering | Return focus to the filtered list without opening a VM |
| Escape while filtering | Clear the filter and return focus to the list |
| ↑ / ↓ or K / J | Select VM |
| Enter / Space in the list | Open details for the selected VM |
| Arrows or H / J / K / L in details | Select a launch or management action |
| Enter / Space in details | Launch the selected action |
| Escape in details | Return to the list, keeping the query and selection |
| B / S | Open the selected VM in browser / SSH |
| E in the list | Open the exe.dev REPL in a floating terminal |
| Enter / Escape at a management confirmation | Confirm / cancel the named operation |
| R | Refresh |
| Escape in the list | Close the popout |
| Tab / Shift+Tab in the list | Switch to an adjacent Omarchy panel |

While the finder has focus, letters type normally rather than triggering list
shortcuts. Matching is case-insensitive and uses VM names only, not tags or
comments. Characters must appear in order: `mdb` matches `my-dev-box`.

Exact matches rank above prefixes, then contiguous substrings, then scattered
matches. Scattered matches favor consecutive characters and the start of a name
or hyphen-separated segment, penalizing gaps and late starts. Ties sort by name.
An empty or whitespace-only query restores tag grouping. Reopening clears the
query. Navigation and actions always refer to the displayed results.

## Settings

Choose what happens when you click a VM:

```sh
omarchy bar set cmk.exe-dev clickAction ssh       # default
omarchy bar set cmk.exe-dev clickAction browser
omarchy bar set cmk.exe-dev clickAction details
```

Enter in the list always opens details, regardless of this setting. S and B
always launch SSH and browser respectively. If the API denies the chosen action,
the plugin does not launch it or silently substitute another action.

Configure periodic refresh:

```sh
omarchy bar set cmk.exe-dev refreshIntervalSec 120
```

The default is 60 seconds; periodic refresh is clamped to at least 15 seconds and
only runs while the popout is open. There is also an initial query when the
widget loads and a refresh on opening. Overlapping refresh requests are coalesced.

Queries have an 8-second connection timeout and a 20-second total deadline, with
forced termination after a further 2 seconds if needed. A successful response
replaces the list. Failure leaves the previous list visible with a warning.
VM metadata is not cached to disk by the plugin.

## Update

```sh
omarchy plugin update cmk.exe-dev
```

Omarchy fetches upstream HEAD, shows the diff, and fast-forwards the checkout.
**Updates follow the repository's default branch, not release tags or the
manifest version.** Review updates before accepting them. Keep local edits on a
separate branch; they can prevent a fast-forward update.

Release tags identify snapshots, but the standard install command is not pinned
to a release or marketplace-reviewed commit. See [SECURITY.md](SECURITY.md).

## Disable or remove

```sh
omarchy plugin disable cmk.exe-dev
omarchy plugin remove cmk.exe-dev
```

Removal disables the plugin and deletes its Git checkout. Save any local changes
first. It does not delete VMs or change your exe.dev account or SSH configuration.

## Troubleshooting

- **Authentication/host-key error:** run `ssh exe.dev ls --json` in a terminal.
  Check the host key and that the desktop shell can use your SSH agent.
- **Connection failure:** the last successful list remains usable; press R to
  retry. The plugin never creates a VM automatically.
- **Plugin missing:** run `omarchy plugin list`, then
  `omarchy plugin enable cmk.exe-dev` if needed.
- **Edits not appearing:** try `omarchy-shell shell rescanPlugins`. If QML is
  still cached, use `omarchy restart shell` when convenient; this restarts the
  desktop shell, not your session.

Diagnostics are available through `omarchy-shell cmk.exe-dev status`. Its output
can include VM names, your search text, and SSH error details. Redact those before
sharing logs or filing an issue.

## Development

```sh
node --test tests/*.test.cjs
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Widget.qml VmService.qml VmNavigation.qml VmDetail.qml ShortcutHint.qml
```

CI runs the dependency-free Node tests, manifest/repository contract checks, and
whitespace checks. It does not run the plugin against a live desktop or account.
Local QML linting requires the supported Omarchy/Quickshell imports; manifest
validation alone cannot prove runtime compatibility.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the manual desktop test matrix and
release checklist, and [CHANGELOG.md](CHANGELOG.md) for release notes.

## Security and scope

The plugin lists VMs, launches browser/SSH sessions and the lobby REPL, and can
restart, pause/resume, or copy a VM after explicit confirmation. It does not
delete, resize, unlock, or change sharing on VMs. Management requires current
administration permission and uses a fixed allowlist of commands. Commands use
argument arrays, not a local shell or the API's `ssh_command` string. VM names and SSH destinations are
validated before launch, and server metadata is rendered as plain text.

Plugins are **not sandboxed**. These boundaries are implementation choices, not
an isolation guarantee. See [SECURITY.md](SECURITY.md) for the threat model and
private vulnerability reporting.

## License

[MIT](LICENSE), copyright Christian Kreiling. Omarchy and exe.dev names belong to
their respective owners.

API references: [SSH API](https://exe.dev/docs/api.md) ·
[SSH destinations](https://exe.dev/docs/faq/ssh-destination.md)
