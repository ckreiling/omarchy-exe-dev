# exe.dev for Omarchy

A native Omarchy/Quickshell bar dropdown for your exe.dev virtual machines.

- Lists all VMs, grouped by their first tag, sorted by name within each group.
- Fuzzy-finds VM names with a flat, best-match-first result list while searching.
- Shows emoji, description, tags, status, and public-web visibility.
- **Globe** opens `https://<vm-name>.exe.xyz/` in your default browser.
- **Terminal** opens your default Omarchy terminal, SSH'd into that VM.
- Uses the API's `ssh_dest`, including username-routed destinations.
- Refreshes on open, with a refresh button and periodic updates while open.
- Keeps the last successful list in memory when offline and shows an error.
- Adapts to Omarchy's theme, bar position, screen size, and popup coordination.
- No account tokens, additional daemon, or Python/Node runtime required.

## Requirements

- Omarchy with the Quickshell plugin system (`omarchy plugin --help`).
- OpenSSH and GNU coreutils (`timeout`), included in Omarchy.
- An exe.dev account already accessible via `ssh exe.dev ls --json`.

The background query uses batch mode and strict host-key checking. If setup is
needed, run `ssh exe.dev` in a terminal first, verify the host key against
[exe.dev's documentation](https://exe.dev/docs/faq/host-key.md), and complete
registration. SSH configuration and your existing SSH agent are respected.
No SSH config or known-hosts files are modified by this plugin.

## Install locally

From this directory, in your running Omarchy session:

```bash
bash install.sh
```

The installer validates the manifest, backs up your existing shell config,
copies the plugin to `~/.config/omarchy/plugins/cmk.exe-dev/`, and enables it
in the **right bar section after Tailscale**. If you don't use Tailscale, omit
the final positioning step in the installer and use
`omarchy bar move cmk.exe-dev --section right --index 0` instead.
It does not change packaged Omarchy files or require sudo.

The bar's server icon opens the dropdown. The header globe opens exe.dev;
the header refresh button reloads the list. Each VM has separate web and SSH
buttons, with hover tooltips. Access explicitly denied by the API disables
the corresponding button.

## Keyboard

With the dropdown open:

| Key | Action |
| --- | --- |
| / | Focus the VM-name fuzzy finder (case-insensitive) |
| Enter while filtering | Return focus to the filtered list without opening a VM |
| Escape while filtering | Clear the filter and return focus to the list |
| ↑ / ↓ (or K / J) | Select VM |
| ← / → (or H / L) | Select browser / SSH |
| Enter / Space | Open selected action (defaults to SSH) |
| B / S | Open selected VM in browser / SSH |
| R | Refresh |
| Escape | Close |
| Tab / Shift+Tab | Switch to adjacent Omarchy panel |

The filter updates as you type and only matches VM names, not tags or descriptions.
Query characters must appear in order: `mdb` matches `my-dev-box`. Matching is
case-insensitive. Exact matches rank above prefixes, then contiguous substrings,
then scattered matches. Scattered matches favor consecutive characters and the
start of a name or hyphen-separated segment, penalizing gaps and late starts.
Equal scores sort by VM name.

Searching shows a flat, best-match-first list. An empty or whitespace-only query
restores the tag-grouped list. Press `/` again to select and replace the current
query. Reopening the dropdown clears the filter. All VM actions and navigation
use the filtered list.

Middle-click the bar icon to refresh without opening the panel.

## Settings

Settings are inline on this plugin's entry in
`~/.config/omarchy/shell.json`:

```json
{ "id": "cmk.exe-dev", "refreshIntervalSec": 60 }
```

Or use:

```bash
omarchy bar set cmk.exe-dev refreshIntervalSec 120
```

The interval is clamped to at least 15 seconds, and periodic queries only run
while the dropdown is open. A query also runs when the widget first loads.
Queries have an 8-second connection timeout and a 20-second total deadline.
Overlapping queries are skipped. Successful responses replace the whole list;
failed queries leave the previous list in memory and show a warning.
There is no disk cache of account metadata.

## Disable / remove

```bash
omarchy plugin disable cmk.exe-dev
omarchy plugin remove cmk.exe-dev --yes
```

Installation backups are in `~/.config/omarchy/backups/`.

## Development and checks

```bash
node tests/model.test.cjs
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell Widget.qml VmService.qml
```

Node is only used by the tests. To exercise the live widget:

```bash
omarchy-shell cmk.exe-dev status
omarchy-shell cmk.exe-dev open
omarchy-shell cmk.exe-dev refresh
omarchy-shell cmk.exe-dev close
```

Edit the installed QML/JS files to hot-reload, or rerun `bash install.sh`
from this source directory. No shell restart is needed.

## Security and scope

Omarchy plugins run as unsandboxed code in the desktop shell. This plugin
only lists VMs and launches the two requested actions. It does not create,
delete, stop, resize, unlock, or change sharing on VMs.

Commands use argument arrays, never shell-evaluated metadata or the API's
`ssh_command` string. VM names and SSH destinations are validated before
launch. Web links are constructed from validated names. Server metadata is
rendered as plain text, not rich HTML.

API references:
[SSH API](https://exe.dev/docs/api.md) ·
[SSH destinations](https://exe.dev/docs/faq/ssh-destination.md)
