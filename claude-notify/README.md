# claude-notify

Global Claude Code hooks that flash a status notification on an AWTRIX NG panel: a Claude icon on
the left, "DONE `<project>`" (green, with a sound) when Claude finishes a task, "HELP `<project>`"
(amber, with a different sound) when Claude needs your input. Fires for every Claude Code session
on this machine, across all projects — `<project>` is the working directory's folder name, so you
can tell sessions apart.

This is a copy of what's actually installed at `~/.claude/hooks/` and `~/.claude/settings.json`,
kept here for reference/backup and so it can be reinstalled or copied to another machine.

## Files

- **`awtrix-notify.sh`** — the hook script. Reads `cwd` from the hook-event JSON on stdin, builds
  the AWTRIX notification (`POST /api/v1/notifications`) with icon, scrolling text and an RTTTL
  sound, and posts it. Non-blocking (`curl -m 3 ... || true; exit 0`) so a network hiccup or an
  offline panel never blocks Claude Code.
- **`claude-icon.gif`** — an 8x8 hand-generated asterisk icon in Claude's brand orange (`#DA7756`).
  Not the Anthropic logo — a generic asterisk motif. Must be uploaded to the device once as
  `/ICONS/claude.gif` so AWTRIX can reserve the icon column and auto-scroll the text next to it
  (a `draw`-command icon doesn't scroll — text drawn that way is static and gets clipped instead).
- **`hooks-settings-snippet.json`** — the `hooks` block to merge into `~/.claude/settings.json`
  (global, user-level — applies to every project).

## Install on a (new) machine

1. Copy the script and make it executable:

   ```sh
   mkdir -p ~/.claude/hooks
   cp awtrix-notify.sh ~/.claude/hooks/awtrix-notify.sh
   chmod +x ~/.claude/hooks/awtrix-notify.sh
   ```

2. Upload the icon to the AWTRIX device once:

   ```sh
   curl -X POST "http://<AWTRIX_HOST>/api/v1/files?dir=/ICONS" -F "file=@claude-icon.gif;filename=claude.gif"
   ```

3. If the device's IP differs from `192.168.1.42`, edit the `AWTRIX_HOST` default near the top of
   `awtrix-notify.sh`, or export `AWTRIX_NOTIFY_HOST` in your shell profile.

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
