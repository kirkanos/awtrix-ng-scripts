# urlaub

Ein Berry-App fürs AWTRIX NG Panel: zeigt vor Urlaubsbeginn die Tage bis zum Start, während des
Urlaubs die verbleibenden Tage bis zum Ende — danach blendet sich die App automatisch aus der
Rotation aus.

- Vor dem Urlaub: standardmäßig ein animiertes, von Hand gezeichnetes Laptop-Icon mit blinkendem
  Terminal-Text ("noch am Arbeiten") — lässt sich per Icon-ID durch ein LaMetric-Icon ersetzen.
- Im Urlaub: LaMetric-Icon (Standard-ID `15644`), konfigurierbar.

## Install

1. Open the AWTRIX web interface (device IP, or `http://awtrixng-xxxxxx.local`).
2. Go to the **Scripts** tab → create a new script, e.g. name it `urlaub`.
3. Paste in the contents of `urlaub.ax`, press **Save**.

Or via curl, from a machine that can reach the device:

```sh
curl -sX PUT "http://$AWTRIX/api/v1/apps/script/urlaub" \
  -H 'Content-Type: text/plain' --data-binary @urlaub.ax
```

## Configure

**Apps** tab → the `⋯` menu on the `urlaub` row → **Settings**:

| Setting | Meaning | Default |
| --- | --- | --- |
| Urlaubsbeginn | Startdatum, Format `JJJJ-MM-TT` (z. B. `2026-09-15`) | leer |
| Urlaubsende | Enddatum, Format `JJJJ-MM-TT` | leer |
| Farbe davor | Textfarbe für den Countdown vor dem Urlaub | Blau `#3399FF` |
| Farbe im Urlaub | Textfarbe für die verbleibenden Urlaubstage | Grün `#00CC44` |
| Icon (im Urlaub) | LaMetric-Icon-ID für die Urlaubszeit | `15644` |
| Icon (davor) | LaMetric-Icon-ID für die Countdown-Phase; leer = gezeichneter Laptop | leer |

Solange kein Datum eingetragen ist, bleibt die App aus der Rotation ausgeblendet. Speichern startet
die App neu und liest die Werte neu ein.

Icon-IDs müssen auf dem Gerät installiert sein (Icons-Bereich der AWTRIX-Weboberfläche). Schlägt das
Dekodieren fehl (Icon fehlt oder kurzzeitiger Speicherengpass), zeigt die App bei "im Urlaub" ein
dunkelgraues Platzhalter-Quadrat, bei "davor" fällt sie automatisch auf den gezeichneten Laptop
zurück — genau wie wenn "Icon (davor)" gar nicht gesetzt ist.

## Hinweis: `num()` und führende Nullen

Die Firmware-Funktion `num()` interpretiert Strings mit führender Null (z. B. Monat `"09"`) als
Oktalzahl und liefert für ungültige Oktalziffern (`8`, `9`) `nil` statt der erwarteten Zahl. Das
Script parst Datumswerte deshalb selbst Ziffer für Ziffer (`parse_int()`), statt sich auf `num()`
zu verlassen.
