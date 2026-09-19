# Wie es funktioniert

*[English](HOW-IT-WORKS.md) · **Deutsch***

## Was beim normalen Anmeldebildschirm schiefgeht

Die Anmeldung per Fingerabdruck funktioniert mit slick-greeter, aber drei Dinge
gehen schief, alle aus einem Grund: Die Meldungen von `pam_fprintd` landen in
der Meldungsliste des Benutzereintrags, und die war für etwas anderes gebaut.

- **Sie stapeln sich**, eine Zeile pro Versuch und pro Hinweis.
- **Sie kommen auf Englisch an**, egal was die Systemsprache sagt. `lightdm` ruft
  nie `setlocale()` auf, also liefert das `gettext()` von `pam_fprintd` den
  unübersetzten Text, und keine Spracheinstellung ändert das von außen.
  [`LINUX-MINT.de.md`](LINUX-MINT.de.md) enthält die Messungen dazu.
- **Sie blockieren die Anmeldung.** Jede Meldung setzt
  `unacknowledged_messages`, und genau dieses Flag hält
  `authentication_complete_cb()` davon ab, die Sitzung zu starten – nach einem
  erfolgreichen Scan stand man also vor einem „Anmelden“-Knopf.

## Die Anzeige

Die Meldungen des Lesers bekommen eine eigene Anzeige, mittig unter der
Benutzerliste, mit immer genau einer Meldung:

| Zustand | Was du siehst |
| --- | --- |
| Wartet | Mint-Logo leuchtet gelb und pulsiert |
| Abgelehnt | Logo blitzt 1,5 s rot, dann wieder wartend |
| Erkannt | Logo leuchtet 1,5 s grün, dann startet die Sitzung |
| Leser gibt auf | Tux tauscht das Logo gegen ein Schild „Passwort:“ |

Der Name des Benutzers, der sich gerade anmeldet, leuchtet in derselben Farbe
mit – beides wirkt so wie ein einziges Signal.

Ein Aufblitzen gehört der Anzeige für die vollen 1,5 s; eine Meldung, die in der
Zeit eintrifft, erscheint, sobald es vorbei ist. Ohne das war das Rot nie zu
sehen: `pam_fprintd` schickt „Failed to match fingerprint“ und direkt danach das
nächste „Place your finger“.

Der Passwort-Zustand wird von PAM gesteuert, nicht durch Zählen von Versuchen.
Kommt eine Passwortabfrage, nachdem der Leser gesprochen hat, hat `pam_fprintd`
seine `max-tries` aufgebraucht; die Box bekommt dann ihre Passwortzeile, genau
so, wie PAM danach fragt.

## Töne

Jedes Ergebnis eines Scans hat einen kurzen Ton im Stil von Cinnamons eigenen:
ein steigender Dreiklang, wenn der Finger erkannt wird, eine sanft fallende
Terz, wenn nicht, und ein neutraler Doppelton, wenn das Passwort gebraucht
wird. Ein falsches Passwort am Schild bekommt denselben Ton wie ein abgelehnter
Finger. Das Warten bleibt still. Die Töne folgen dem, was angezeigt wird; ein
Zustand, der hinter einem Aufblitzen wartet, ist also zusammen mit seiner Farbe
zu hören.

Es sind gewöhnliche slick-greeter-Einstellungen wie `play-ready-sound`: eine
Tondatei pro Zustand, ab Werk an, still wenn leer. Um einen abzuschalten, trage
ihn leer in `/etc/lightdm/slick-greeter.conf` ein:

```ini
[Greeter]
play-fingerprint-failure-sound=
```

| Schlüssel | Spielt, wenn |
| --- | --- |
| `play-fingerprint-success-sound` | der Finger erkannt wird |
| `play-fingerprint-failure-sound` | der Finger nicht erkannt wird oder das Passwort am Schild falsch ist |
| `play-fingerprint-password-sound` | der Leser aufgegeben hat und das Passwort gebraucht wird |

Der Anmeldebildschirm nutzt eigene Kopien, 14 dB lauter, unter
`/usr/share/greeter-fprint/sounds/login-screen/`. Er läuft als Benutzer
`lightdm`, dessen Audiositzung keine gespeicherte Lautstärke hat; WirePlumber
öffnet das Gerät deshalb mit seiner Voreinstellung von etwa −24 dB – mit den
gewöhnlichen Dateien waren die Töne rund 18 dB leiser als im Sperrbildschirm.
Die Verstärkung steckt bewusst in den Dateien und nicht in der
Wiedergabelautstärke: WirePlumber merkt sich die Lautstärke eines Streams pro
Medienrolle, und alle Ereignistöne teilen sich eine Rolle – ein einziger
verstärkter Stream hätte also alle späteren Ereignistöne mit verstärkt. Mehr als
14 dB gehen nicht, ohne dass es verzerrt; der Anmeldebildschirm bleibt deshalb
ein paar dB leiser als deine eigene Sitzung.

Die Dateien sind aus Cinnamons Tönen `plug`, `unplug` und `notification`
abgeleitet; wie, zeigt [`DEVELOPMENT.de.md`](DEVELOPMENT.de.md), die
Namensnennung steht in [COPYRIGHT.md](../COPYRIGHT.md) (englisch).

## Im Terminal und in Dialogen

Dieselben Töne spielen bei jeder Fingerabdruck-Abfrage in deiner eigenen
Sitzung: `sudo`, `su` und `pkexec` im Terminal und Cinnamons
Legitimierungsdialoge. Keines dieser Programme wird verändert. Sie prüfen alle
über `fprintd`, und `fprintd` meldet jeden Schritt auf dem Systembus – ein kleiner
Begleiter, der mit der Sitzung startet, hört sie also alle mit:
`greeter-fprint-session-sounds`, unter „Startprogramme“ als „Fingerabdruck-Töne“.

Ein Detail entscheidet, was er spielt. `fprintd` meldet auch eine *gestoppte*
Prüfung als „kein Treffer“ – ein abgebrochenes `sudo` oder einen Leser, dem die
Zeit ausgegangen ist. Eine Ablehnung zählt deshalb nur, wenn vorher wirklich ein
Finger auf dem Sensor lag. Ein Stopp ohne Finger nach Ablauf von `pam_fprintd`s
Wartezeit heißt: Jetzt kommt das Passwort. Ein früherer ist ein Abbruch und
bleibt still. Eine Aufzeichnung echter Abfragen, die `tests/session-sounds/`
abspielt, hält diese Regeln ehrlich.

Er bleibt still, solange der Bildschirm gesperrt ist (der Sperrbildschirm spielt
die Töne selbst), solange eine andere Sitzung vorne ist und wenn in Cinnamon
**Klang → Benachrichtigungen anzeigen** aus ist. Ein falsches *Passwort* hat hier
keinen Ton: Das Urteil fällt `pam_unix`, und das meldet nichts.

## Meldungen

PAM-Meldungen tragen keine Kennung, woher sie stammen. Die Anzeige erkennt die
von `pam_fprintd` deshalb an ihrem Text – auf Englisch, weil sie so am
Anmeldebildschirm ankommen. Was angezeigt wird, stammt aus dem eigenen
gettext-Katalog dieses Projekts, mit Englisch als Basis und Rückfall, und hängt
damit nicht davon ab, ob eine fprintd-Übersetzung installiert ist. Siehe
[`TRANSLATIONS.de.md`](TRANSLATIONS.de.md).

Alles, was nicht den Leser betrifft, landet wie bisher in der Meldungsliste des
Anmeldebildschirms.

## Kleinere Korrekturen am Layout-Code von upstream

- Benutzernamen stehen mittig in ihrem Eintrag statt oben links angeheftet.
- Die Markierung für eine aktive Sitzung sitzt mittig an der ganzen Box statt an
  ihrer ersten Zeile – die ist nicht mehr die Mitte, sobald die Box eine
  Passwortzeile bekommt.

## Konfiguration

greeter-fprint liest genau das, was slick-greeter liest – das Schema
`x.dm.slick-greeter` und `/etc/lightdm/slick-greeter.conf` –, eine bestehende
Einrichtung gilt also unverändert.

## Der ganze Bildschirm

Die Animation in der README ist auf Benutzerliste und Anzeige zugeschnitten. Das
hier ist ein Bildschirmfoto des Echtbetriebs – LightDM, PAM und Leser – in einer
verschachtelten LightDM-Sitzung:

![greeter-fprint in einer verschachtelten LightDM-Sitzung](panel.png)
