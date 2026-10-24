# Security policy

## Supported versions

Security fixes target the latest default-branch code and the latest release.
Review updates before accepting them; older snapshots are not maintained.

## Report vulnerabilities privately

Use [GitHub private vulnerability reporting](https://github.com/ckreiling/omarchy-exe-dev/security/advisories/new).
Do not include private keys, tokens, SSH agent material, VM inventories, or
personal logs in public issues. Supply a minimal reproduction with synthetic
names and identify the affected commit.

If the reporting form is unavailable, do not post exploit details publicly;
open an issue asking for a private reporting channel without sensitive details.

## Runtime trust boundary

Omarchy plugins execute as unsandboxed code in the long-running desktop shell
with your user permissions. Review this repository and its updates before
enabling it. This is not a sandbox or a security audit.

The plugin:

- Runs a bounded, batch-mode `ssh exe.dev ls --json` query using strict host-key
  checking. OpenSSH still honors your SSH configuration and SSH agent.
- Keeps VM metadata in process memory, not in a plugin-managed disk cache.
- Constructs browser URLs from validated VM names in the `exe.xyz` domain.
- Accepts direct and username-routed SSH destinations only within that domain.
- Uses argument arrays and an SSH option terminator instead of shell-evaluated
  VM metadata; it never evaluates the API's `ssh_command`.
- Renders API-provided metadata as plain text.
- Offers restart, pause/resume, and copy only after a confirmation naming the
  target VM, and only when the latest API record explicitly grants admin access.
  These commands use the fixed exe.dev host and allowlisted verbs; names are
  validated before remote SSH command serialization. Copy creates a VM and may
  consume additional capacity; restart/pause can interrupt running work.
- Serializes management requests and bounds them to 120 seconds plus a 2-second
  forced-termination grace period. A timeout or SSH disconnect does not prove
  the remote operation failed: management remains disabled until an inventory
  query started afterward succeeds. Check that inventory before retrying,
  particularly before copying. Confirmation rejects held-key autorepeat.
- Opens the lobby REPL on E using a new terminal with Omarchy's stock floating
  app-id. Commands typed by the user in that REPL are outside the plugin's
  allowlist and confirmation UI.
- Does not install packages, request elevated privileges, or change SSH config,
  keys, known-hosts entries, VM access, or sharing settings. No delete action is
  exposed.

Opening SSH intentionally gives you an interactive session on the selected VM.
Opening a website exposes the browser to that VM's content. SSH forwarding,
ProxyCommand, and other behavior configured by the user remain OpenSSH's
responsibility, not something this plugin isolates.

The diagnostic IPC status includes selected VM names, filter text, and error
details. Other software in the same desktop session may be able to query it.
Redact diagnostics and screenshots before sharing them.

## Supply-chain and update behavior

The official `omarchy plugin add` and `update` commands follow mutable upstream
HEAD. A release tag or marketplace verification does not pin those commands.
To inspect a particular snapshot, use normal Git in the installed checkout and
verify the full commit before enabling it; a detached checkout is not an
automatic security-update channel.

CI has read-only repository permissions, does not receive application secrets,
does not authenticate to exe.dev, and uses full-commit-pinned actions. Checkout
credentials are not retained. Fork contributions run with GitHub's restricted
pull-request context, never `pull_request_target`.

GitHub branch/tag protections, secret scanning, and push protection are
repository settings, not guarantees provided by a clone of these files.
No automated check proves that the plugin or a dependency is safe.
