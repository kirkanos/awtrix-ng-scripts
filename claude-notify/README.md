# claude-notify

Global Claude Code hooks that flash a status notification on an AWTRIX NG panel: an icon on
the left (LaMetric icon `71832`), "DONE `<project>`" (green, with a sound) when Claude finishes a
task, "HELP `<project>`" (amber, with a different sound) when Claude needs your input. Fires for
every Claude Code session on this machine, across all projects — `<project>` is the working
directory's folder name, so you can tell sessions apart.

This is a copy of what's actually installed at `~/.claude/hooks/` and `~/.claude/settings.json`,
kept here for reference/backup and so it can be reinstalled or copied to another machine.

## Files

- **`awtrix-notify.sh`** — the hook script. Reads `cwd` from the hook-event JSON on stdin, builds
  the AWTRIX notification (`POST /api/v1/notifications`) with icon, scrolling text and an RTTTL
  sound, and posts it. Non-blocking (`curl -m 3 ... || true; exit 0`) so a network hiccup or an
  offline panel never blocks Claude Code.
- **`.env.example`** — template for the `.env` holding the panel's address. Copy it next to the
  installed script (`~/.claude/hooks/.env`); `.env` is gitignored so the address stays out of the
  repo.
- **`claude-icon.gif`** — an 8x8 hand-generated asterisk icon in Claude's brand orange (`#DA7756`).
  Not the Anthropic logo — a generic asterisk motif. No longer used by default (see below), kept
  here in case you want to switch back to it.
- **`hooks-settings-snippet.json`** — the `hooks` block to merge into `~/.claude/settings.json`
  (global, user-level — applies to every project). The `Notification` entry is restricted with
  `"matcher": "permission_prompt|agent_needs_input"` — without it, Claude Code's periodic
  `idle_prompt` reminder (sent while a finished session just sits unanswered) also fires the HELP
  notification, which looks like a spurious second alert shortly after a DONE ping.

## Install on a (new) machine

1. Copy the script and make it executable:

   ```sh
   mkdir -p ~/.claude/hooks
   cp awtrix-notify.sh ~/.claude/hooks/awtrix-notify.sh
   chmod +x ~/.claude/hooks/awtrix-notify.sh
   ```

2. Make sure LaMetric icon `71832` is installed on the device (Icons area of the AWTRIX web UI) —
   otherwise the notification still fires, just without an icon. To use the bundled
   `claude-icon.gif` instead, upload it once and change `"icon":"71832"` in `awtrix-notify.sh` back
   to `"icon":"claude"`:

   ```sh
   curl -X POST "http://<AWTRIX_HOST>/api/v1/files?dir=/ICONS" -F "file=@claude-icon.gif;filename=claude.gif"
   ```

3. Point the script at the panel — without an address it exits quietly and nothing fires:

   ```sh
   cp .env.example ~/.claude/hooks/.env
   # then edit AWTRIX_NOTIFY_HOST in that file
   ```

   Alternatively export `AWTRIX_NOTIFY_HOST` in your shell profile (it wins over the `.env`), or
   point `AWTRIX_NOTIFY_ENV_FILE` at an env file elsewhere.

4. Merge the `hooks` block from `hooks-settings-snippet.json` into `~/.claude/settings.json` —
   **merge, don't overwrite**; keep any existing keys (permissions, model, etc.) in that file.

5. Run `/hooks` in any already-running Claude Code session to pick up the change (new sessions
   pick it up automatically on startup).

## Test

```sh
echo '{"cwd":"'"$PWD"'"}' | ~/.claude/hooks/awtrix-notify.sh done
echo '{"cwd":"'"$PWD"'"}' | ~/.claude/hooks/awtrix-notify.sh input
```

Each should flash the icon + "DONE `<folder>`" / "HELP `<folder>`" on the panel with a sound.
