# Entwicklung

*[English](DEVELOPMENT.md) · **Deutsch***

## Demomodus

```bash
GREETER_FPRINT_DEMO=1 ./build/src/greeter-fprint --test-mode
```

Schickt die Anzeige zeitgesteuert durch alle Zustände und füttert dabei die
echten englischen Texte von `pam_fprintd` durch den echten Classifier – was du
siehst, ist also das, was ein echter Leser erzeugt, Übersetzung eingeschlossen.
Der Testmodus zeigt die Beispielkonten von slick-greeter („No Password“, „Two
Factor“, …); er ist zum Anschauen da, nicht für Bilder.

`GREETER_FPRINT_TEST_SIZE=1000x1080` ersetzt die fest eingebauten Monitore des
Testmodus (800×600 und 640×480) durch einen einzigen in der angegebenen Größe.
Bei 800×600 fällt Tux unten aus dem Bild.

## Der echte Anmeldebildschirm im Fenster

```bash
dm-tool add-nested-seat --screen 1280x900
```

Eine echte LightDM-Sitzung mit echtem PAM und echtem Leser. Ein erkannter Finger
meldet dich dort wirklich an.

## Die README-Bilder rendern

```bash
# Englisch, für README.md
LC_ALL=C.UTF-8 GREETER_FPRINT_RENDER=/tmp/frames-en GREETER_FPRINT_TEST_SIZE=1000x1080 \
  ./build/src/greeter-fprint --test-mode

# Deutsch, für README.de.md
LC_ALL=de_DE.UTF-8 GREETER_FPRINT_RENDER=/tmp/frames-de GREETER_FPRINT_TEST_SIZE=1000x1080 \
  ./build/src/greeter-fprint --test-mode
```

Schreibt pro Zustand ein PNG (`1-waiting` … `4-password`) und beendet sich. Das
Fenster zeichnet sich selbst auf eine Cairo-Fläche außerhalb des Bildschirms; die
Bilder sind also die eigenen Widgets, das CSS und der Leuchtcode des
Anmeldebildschirms, in voller Schärfe.

- Die Konten sind die echten des Rechners aus `LightDM.UserList`, nicht die
  Beispielkonten des Testmodus. `GREETER_FPRINT_RENDER_USER` wählt den
  markierten Namen; ohne Angabe bist du es.
- Der Testmodus wird nur gebraucht, um an der Verbindung zum LightDM-Dienst
  vorbeizukommen, die ein von Hand gestarteter Anmeldebildschirm nicht aufbauen
  kann. Außerhalb des Testmodus wird die Variable ignoriert; ein echter
  Anmeldebildschirm schreibt also nie Bilder von sich und beendet sich nie
  deswegen.
- Die Schritte liegen knapp über `FLASH_MS` auseinander. Ein Aufblitzen gehört
  der Anzeige für seine volle Dauer und stellt alles zurück, was in der Zeit
  eintrifft – ein schnellerer Durchlauf nimmt deshalb zweimal dasselbe Bild auf.
- Die Passwortzeile wird mit dem wörtlichen PAM-Text `"Password: "` angefordert,
  mit Leerzeichen am Ende – genau diese Zeichenkette wird übersetzt.

`docs/states.gif` (englisch) und `docs/states.de.gif` (deutsch) entstehen auf
dieselbe Weise aus diesen Bildern: Ausschnitt 420×550 bei
(290, 380), auf 380 px Breite skaliert, eine gemeinsame Palette mit 256 Farben
und Floyd-Steinberg-Dithering (ohne das bekommt das Hintergrundbild harte
Farbstufen), und die Dauern aus dem Code – 2,4 s Warten, 1,5 s Rot, 1,6 s
Warten, 1,5 s Grün, 1,6 s Warten, 1,8 s Schild.

## Die Töne

```bash
tools/derive-fingerprint-sounds.py
```

Baut `data/sounds/` aus Cinnamons eigenem Tonsatz unter
`/usr/share/mint-artwork/sounds` neu: `plug` plus ein dritter Ton für
„erkannt", `unplug` mit fallender Terz statt Quinte für „nicht erkannt" und
`notification`, auf einen neutralen Doppelton abgesenkt, für das Passwort. Jedes
Ergebnis wird auf die Spitze von `plug.oga` gebracht, und jeder Abschnitt, der
mitten in einem Klang beginnt, bekommt 6 ms Einblenden, damit keine Übergänge
knacken. Braucht ffmpeg mit dem Filter `rubberband` und `python3-numpy`.

Es schreibt zwei Sätze: `data/sounds/` in Cinnamons Lautstärke für den
Sperrbildschirm und `data/sounds/login-screen/` 14 dB lauter für den
Anmeldebildschirm, dessen Audiositzung mit WirePlumbers niedriger
Grundlautstärke beginnt.

Um den Anmeldebildschirm die Töne ohne echte Anmeldung spielen zu hören, starte
die Demo mit dem frisch gebauten Schema, denn dem installierten fehlen die
Schlüssel noch:

```bash
mkdir -p /tmp/schema && cp data/x.dm.slick-greeter.gschema.xml /tmp/schema/
glib-compile-schemas /tmp/schema
GSETTINGS_SCHEMA_DIR=/tmp/schema GREETER_FPRINT_DEMO=1 ./build/src/greeter-fprint --test-mode
```

## Töne in der Sitzung

```bash
python3 tests/session-sounds/test_session_sounds.py
```

Spielt `tests/session-sounds/fprintd-trace.txt` – die Signale von `fprintd`,
aufgezeichnet bei echten `sudo`- und `pkexec`-Abfragen – durch die Regeln in
`src/session_sounds.py` und prüft das Auslesen der Wartezeit gegen die Regeln
von `pam_fprintd`. Für eine neue Aufzeichnung alles abonnieren, was
`net.reactivated.Fprint` auf dem Systembus sendet, und mit Zeitstempeln
mitschreiben; das Zeilenformat des Tests ist das von `fprintd-trace.txt`.
