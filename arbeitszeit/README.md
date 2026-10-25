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
Uhrzeit als Arbeitsbeginn — die Zeiterfassung startet sofort ("einstempeln").

Ein erneuter Druck auf den Knopf, während die Zeiterfassung läuft, pausiert sie ("ausstempeln"): die
angezeigte Zeit friert an Ort und Stelle ein — die App bleibt dabei weiter in der Rotation sichtbar,
zählt aber nicht mehr weiter. Ein dritter Druck setzt die Zeiterfassung fort ("weiter"): die
Pausendauer wird herausgerechnet, die Anzeige macht also genau dort weiter, wo sie eingefroren war,
statt bei 0 neu zu beginnen. Beliebig oft wiederholbar (z. B. für die Mittagspause).

Gedrückte Pausen werden dabei **gegen die gesetzliche Pause gerechnet**, nicht zusätzlich abgezogen
— siehe unten.

Bei Erreichen der maximalen Arbeitszeit ertönt einmalig eine Fanfare samt Benachrichtigung
"Feierabend!". Nachts um 0 Uhr wird der Arbeitsbeginn automatisch zurückgesetzt (leer), damit am
nächsten Morgen wieder neu gestartet werden kann (per Knopf oder Einstellung).

## MQTT (Stream Deck)

Optional, standardmäßig eingeschaltet, ohne konfigurierten MQTT-Broker wirkungslos (die
Berry-Aufrufe `mqtt.publish`/`mqtt.subscribe` sind dann No-ops). Damit spiegelt das
[Worktime-Plugin](https://github.com/kirkanos/Streamdeck-Arbeitszeit) fürs Stream Deck die Anzeige
und kann ein-, aus- und weiterstempeln; das Panel bleibt die Wahrheit, der Knopf am Gerät
funktioniert unverändert.

- `<Topic>/state` (Standard `awtrix/arbeitszeit/state`): JSON
  `{"start_min":452,"paused":false,"paused_at":0,"pause_min":0,"net_min":123}` — `start_min` ist
  der Arbeitsbeginn als Minute des Tages (`null` ohne Arbeitsbeginn), `paused` ob die Zeit
  eingefroren ist, `paused_at` die Minute des Tages, in der die laufende Pause begann (`0` sonst),
  `pause_min` die **Summe** der heute gedrückten Pausenminuten, `net_min` die angezeigte
  Nettozeit. Gesendet bei jeder Änderung, einmal pro Minute und auf den Befehl `state`.
- `<Topic>/cmd`: Klartext-Befehle `clock_in`, `pause`, `resume`, `reset`, `state` — genau wie der
  Select-Knopf; unpassende Befehle (z. B. `pause` ohne laufende Zeit) werden ignoriert.

Prüfen, sobald der Broker in den AWTRIX-Systemeinstellungen eingetragen ist:

```sh
mosquitto_sub -h <broker> -t 'awtrix/arbeitszeit/state' -v
mosquitto_pub -h <broker> -t 'awtrix/arbeitszeit/cmd' -m state
```

## Panelgröße

Die App bringt **zwei eigene Layouts** mit und wählt nach `height()` aus — keine skalierte Fassung
desselben Entwurfs, sondern zwei Entwürfe für zwei sehr verschiedene Flächen:

- **32×8** (Ulanzi TC001) — `draw_klein()`: Icon links, Zeit in der kleinen Schrift auf Grundlinie 6,
  einzeiliger Balken in der untersten Zeile. Hier zählt jeder Pixel.
- **52×16** (Ulanzi TC002) — `draw_gross()`: 16×16-Icon links, Textspalte ab x=17, dreizeiliger
  Balken. Die Zeit steht in einer 3×5-Pixelschrift, pixelweise verdoppelt (6×10 je Zeichen).

Das Panel-Aufteilung und die Schrifttabelle sind von den mitgelieferten TC002-Apps übernommen,
damit die App sich zwischen ihnen nicht fremd anfühlt. Die `large`-Schrift der API wäre nur
7 der 16 Zeilen hoch, und die Icons der TC002 sind 16×16 statt 8×8 — auf dem neuen Panel liegen
deshalb andere Icon-Dateien unter denselben IDs.

Die Logik — Pausenregel, MQTT, Einstellungen — ist davon unberührt und existiert nur einmal. Ein
Fix an der Pausenrechnung gilt damit automatisch für beide Uhren.

## Pausenregel

Grundlage ist die **Anwesenheit** — die Zeit seit dem Einstempeln, gedrückte Pausen eingeschlossen.
Davon abgezogen wird die kürzeste Dauer, die zweierlei erfüllt: sie deckt die selbst gedrückte
Pause ab, *und* sie genügt der gesetzlichen Pflicht für die Arbeitszeit, die dabei herauskommt
(über 6 Stunden: 30 Minuten, über 9 Stunden: 45 Minuten).

Gedrückte Pausen zählen damit **auf die gesetzliche an, statt zusätzlich zu kosten**. Wer 35
Minuten Pause drückt, verliert nicht 35 Minuten *obendrauf* — die 35 decken die geschuldeten 30
ab, nur die 5 Minuten Differenz kosten Zeit. Erst eine Pause über der gesetzlichen Dauer kostet
die Zeit darüber.

Liegt die Anwesenheit nur knapp über einer Schwelle, reicht weniger als die volle Pause: die
Arbeitszeit wird dann auf die Schwelle gedeckelt, statt darunter zu fallen. 6:30 Anwesenheit ohne
gedrückte Pause ergeben also 6:00, nicht 6:00 minus weitere 30 Minuten.

| Anwesenheit | gedrückt | Abzug | Arbeitszeit |
| --- | --- | --- | --- |
| 6:00 | 0 | 0 | 6:00 |
| 6:30 | 0 | 30 | 6:00 |
| 9:00 | 0 | 30 | 8:30 |
| 9:00 | 35 | 35 | 8:25 |
| 10:00 | 0 | 45 | 9:15 |
| 10:00 | 35 | 45 | 9:15 |
| 10:00 | 60 | 60 | 9:00 |

So formuliert ist das Ergebnis immer zulässig, immer die größtmögliche zulässige Arbeitszeit, und
eine längere Pause ergibt nie mehr Arbeitszeit als eine kürzere.

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
| Gedrückte Pause | Summe der heute gedrückten Pausen in Minuten; wird gegen die gesetzliche gerechnet. Steht hier, damit sie einen Neustart übersteht und das Stream Deck auch ohne MQTT drankommt — von Hand korrigierbar | `0` |
| Farbe | Textfarbe, solange keine Überstunden anfallen | Grün `#00CC44` |
| Farbe Ueberstunden | Textfarbe für Überstunden | Orange `#FF8800` |
| Icon (unter Sollzeit) | LaMetric-Icon-ID, solange die Sollzeit noch nicht erreicht ist | `5582` |
| Icon (Ueberstunden) | LaMetric-Icon-ID ab Erreichen der Sollzeit | `24443` |
| Ueberstunden-Skala | Wie viele Überstunden der Balken zusätzlich fasst, bevor er ganz voll ist | `2` h |
| Maximale Arbeitszeit | Ab dieser geleisteten Zeit ertönt einmalig die Fanfare | `10` h |
| MQTT (Stream Deck) | Zustand per MQTT melden und Befehle annehmen (siehe oben) | an |
| MQTT-Topic | Basis-Topic für `state` und `cmd` | `awtrix/arbeitszeit` |

Solange kein Arbeitsbeginn gesetzt ist, bleibt die App vor 8 Uhr aus der Rotation ausgeblendet; ab
8 Uhr erscheint sie mit `0:00` als Erinnerung. Der mittlere Knopf (select) am Panel wechselt
zwischen Einstempeln, Pausieren (Zeit einfrieren) und Fortsetzen (Pausendauer wird herausgerechnet).

Die beiden Icon-IDs müssen auf dem Gerät installiert sein (Icons-Bereich der AWTRIX-Weboberfläche).
Fehlt ein Icon oder schlägt das Dekodieren kurzzeitig fehl (Speicherengpass bei vielen aktiven
Scripts), zeigt die App stattdessen ein dunkelgraues Platzhalter-Quadrat statt eines Lochs.

## Test ohne Gerät

`test_arbeitszeit.be` stubbt die AWTRIX-Laufzeit (store, mqtt, Uhr, Zeichnen) und prüft Knopf,
MQTT-Befehle, Pausenregeln und Mitternachts-Reset. Braucht ein Standalone-Berry
([berry-lang/berry](https://github.com/berry-lang/berry), `make`), dann im Ordner `arbeitszeit/`:
`berry test_arbeitszeit.be`.

## Hinweis: Speicher

Das Panel kompiliert jedes Script in den gemeinsamen Berry-Heap; jede Methode kostet dauerhaft
Speicher. Die App ist deshalb auf wenige Methoden gehalten (alle Befehle laufen durch `apply()`).
Meldet die Weboberfläche beim Speichern „out of memory“, hilft ein Neustart des Panels (der Heap
wird dabei defragmentiert) und ein erneutes Speichern.

## Hinweis: `num()` und führende Nullen

Wie bei [`urlaub/`](../urlaub/) beschrieben, scheitert `num()` an Strings mit führender Null (z. B.
`"08"` Uhr). Das Script parst die Uhrzeit deshalb selbst Ziffer für Ziffer (`parse_int()`).
