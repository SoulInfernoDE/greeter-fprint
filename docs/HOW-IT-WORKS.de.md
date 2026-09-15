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
