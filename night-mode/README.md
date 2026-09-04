# night-mode

Two ways to silence an AWTRIX NG panel during the night and bring it back in the morning. Pick
whichever fits your setup, or run both — they don't conflict since they touch the same settings.

- **`night-mode.sh`** — an external shell script, scheduled by cron (or launchd) on another
  machine. Uses the real panel-power endpoint, so the display fully switches off.
- **`night-mode.ax`** — a Berry app that runs **on the panel itself**. No external machine or
  cron needed, but it can only dim the panel to a configurable brightness (down to 0) and mute
  sound — the on-device scripting API has no access to the actual power-off endpoint.

## Option A: external script (`night-mode.sh`)

Calls the device's REST API (`PATCH /api/v1/display` for real power off, `PATCH /api/v1/settings`
for sound) from a machine on the same network. Requires only `curl`.

### Setup

```sh
cp .env.example .env
# edit .env: set AWTRIX_HOST (and AWTRIX_USER/AWTRIX_PASS if the device has auth enabled)
```

### Usage

```sh
./night-mode.sh off      # blank the display, mute sound
./night-mode.sh on        # restore display, unmute sound
./night-mode.sh status    # print current display/power state
```

### Scheduling with cron

```sh
crontab -e
```

```cron
# Silence AWTRIX at 22:00 every night
0 22 * * * /full/path/to/night-mode/night-mode.sh off >> /full/path/to/night-mode/night-mode.log 2>&1

# Wake it back up at 07:00 every morning
0 7  * * * /full/path/to/night-mode/night-mode.sh on  >> /full/path/to/night-mode/night-mode.log 2>&1
```

Use absolute paths — cron does not run your shell profile, so relative paths and `~` will not
resolve.

### Scheduling with launchd (macOS alternative)

If this runs on a Mac that sleeps overnight, cron jobs may be skipped. Two `launchd` agents using
`StartCalendarInterval` behave the same way and are more reliable across sleep/wake. Ask if you'd
like these generated.

## Option B: on-device Berry app (`night-mode.ax`)

Runs entirely on the AWTRIX itself — no computer, cron job, or network access from outside needed
once installed. It checks the time once a second and, during the configured window, mutes sound
and dims the panel; it restores whatever brightness/sound/auto-brightness settings were active
before, so it doesn't clobber a value you set some other way.

### Install

1. Open the AWTRIX web interface (device IP, or `http://awtrixng-xxxxxx.local`).
2. Go to the **Scripts** tab → create a new script, e.g. name it `night-mode`.
3. Paste in the contents of `night-mode.ax`, press **Save**.

Or via curl, from a machine that can reach the device:

```sh
curl -sX PUT "http://$AWTRIX/api/v1/apps/script/night-mode" \
  -H 'Content-Type: text/plain' --data-binary @night-mode.ax
```

### Configure

**Apps** tab → the `⋯` menu on the `night-mode` row → **Settings**:

| Setting | Meaning | Default |
| --- | --- | --- |
| Night start (HH:MM) | when quiet hours begin | `22:00` |
| Night end (HH:MM) | when quiet hours end | `07:00` |
| Night brightness | panel brightness during quiet hours (`0` = effectively off) | `0` |

Saving restarts the app and re-reads these values.

### Limitation vs. Option A

The Berry scripting API only exposes `PATCH /api/v1/settings` (brightness, sound), not
`PATCH /api/v1/display` (the real panel-power toggle with its off animation). So this app dims the
panel to black rather than truly powering it off — visually near-identical, but `matrixPower`
stays `true` internally. If you want the panel *actually* off (e.g. for power saving), use Option A.
