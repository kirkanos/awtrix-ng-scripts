# arbeitszeit

Ein Berry-App fürs AWTRIX NG Panel: zeigt die heute geleistete Arbeitszeit (Sollstunden minus
Pausen). Links im 8×8-Icon-Bereich (wie bei den anderen Apps in diesem Repo) erscheint ein
LaMetric-Icon, das zwischen "unter Sollzeit" und "Überstunden" wechselt. Rechts daneben steht die
geleistete Zeit als `H:MM` mit blinkendem Doppelpunkt, farblich passend zum Icon-Zustand.

Unten läuft ein Fortschrittsbalken (gleicher Stil wie die mitgelieferte `Year-Progress`-App): er
füllt sich in der normalen Farbe bis zur Sollzeit; sobald Überstunden anfallen, werden hinten
zusätzliche Felder in der Überstunden-Farbe angehängt.

Der Arbeitsbeginn lässt sich entweder in den Einstellungen eintragen oder per Knopfdruck setzen:
solange kein Arbeitsbeginn gesetzt ist, erscheint die App ab 8 Uhr morgens als Erinnerung mit der
Anzeige `0:00`. Ein Druck auf den mittleren Knopf (select) am Panel übernimmt dann die aktuelle
Uhrzeit als Arbeitsbeginn — die Zeiterfassung startet sofort.

Bei Erreichen der maximalen Arbeitszeit ertönt einmalig eine Fanfare samt Benachrichtigung
"Feierabend!". Nachts um 0 Uhr wird der Arbeitsbeginn automatisch zurückgesetzt (leer), damit am
nächsten Morgen wieder neu gestartet werden kann (per Knopf oder Einstellung).

## Pausenregel

- Ab 6 Stunden Bruttozeit werden 30 Minuten Pause von der geleisteten Zeit abgezogen.
- Ab 8 Stunden Bruttozeit werden zusätzlich 15 Minuten abgezogen (45 Minuten insgesamt).

## Install

1. Open the AWTRIX web interface (device IP, or `http://awtrixng-xxxxxx.local`).
2. Go to the **Scripts** tab → create a new script, e.g. name it `arbeitszeit`.
3. Paste in the contents of `arbeitszeit.ax`, press **Save**.

Or via curl, from a machine that can reach the device:

```sh
curl -sX PUT "http://$AWTRIX/api/v1/apps/script/arbeitszeit" \
  -H 'Content-Type: text/plain' --data-binary @arbeitszeit.ax
```

## Configure

**Apps** tab → the `⋯` menu on the `arbeitszeit` row → **Settings**:

| Setting | Meaning | Default |
| --- | --- | --- |
| Arbeitsbeginn | Startzeit, Format `SS:MM` (z. B. `08:30`) | leer |
| Sollstunden | Regelarbeitszeit in Stunden | `8` |
| Farbe | Textfarbe, solange keine Überstunden anfallen | Grün `#00CC44` |
| Farbe Ueberstunden | Textfarbe für Überstunden | Orange `#FF8800` |
| Icon (unter Sollzeit) | LaMetric-Icon-ID, solange die Sollzeit noch nicht erreicht ist | `5582` |
| Icon (Ueberstunden) | LaMetric-Icon-ID ab Erreichen der Sollzeit | `24443` |
| Ueberstunden-Skala | Wie viele Überstunden der Balken zusätzlich fasst, bevor er ganz voll ist | `2` h |
| Maximale Arbeitszeit | Ab dieser geleisteten Zeit ertönt einmalig die Fanfare | `10` h |

Solange kein Arbeitsbeginn gesetzt ist, bleibt die App vor 8 Uhr aus der Rotation ausgeblendet; ab
8 Uhr erscheint sie mit `0:00` als Erinnerung. Der mittlere Knopf (select) am Panel setzt den
Arbeitsbeginn jederzeit auf die aktuelle Uhrzeit — praktisch für den täglichen "Einstempeln"-Moment,
ersetzt aber jedes Mal den vorherigen Wert.

Die beiden Icon-IDs müssen auf dem Gerät installiert sein (Icons-Bereich der AWTRIX-Weboberfläche).
Fehlt ein Icon oder schlägt das Dekodieren kurzzeitig fehl (Speicherengpass bei vielen aktiven
Scripts), zeigt die App stattdessen ein dunkelgraues Platzhalter-Quadrat statt eines Lochs.

## Hinweis: `num()` und führende Nullen

Wie bei [`urlaub/`](../urlaub/) beschrieben, scheitert `num()` an Strings mit führender Null (z. B.
`"08"` Uhr). Das Script parst die Uhrzeit deshalb selbst Ziffer für Ziffer (`parse_int()`).
