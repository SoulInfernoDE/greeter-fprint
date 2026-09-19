# Übersetzungen

*[English](TRANSLATIONS.md) · **Deutsch***

Jeder Text, den die Anzeige zeigt, stammt aus einem gettext-Katalog, mit
Englisch als Basis und Rückfall. Nichts ist fest verdrahtet.

In der Anzeige treffen zwei Gruppen von Texten zusammen, und sie sind
unterschiedlich gut abgedeckt.

## Von slick-greeter geerbt – vollständig

Alles, was upstream schon übersetzt hatte, auch das „Passwort:“ auf dem Schild
von Tux. Der Fork hat das ganze `po/`-Verzeichnis von upstream behalten und nur
die gettext-Domäne umbenannt; auf einem französischen System steht auf dem
Schild also „Mot de passe :“, ohne dass etwas einzustellen wäre:

    de  Passwort:        pl  Hasło:
    fr  Mot de passe :   nl  Wachtwoord:
    es  Contraseña:      ru  Пароль:

## Von diesem Fork hinzugefügt – bisher nur Deutsch

28 Texte: die 16 Sätze der Anzeige („Fingerprint not recognised“, „Place your %s
on the reader“, …), die 10 Fingernamen, die in zwei davon eingesetzt werden, und
die 2 Zeilen des Autostart-Eintrags für die Töne in der Sitzung.
Sie stehen am Ende von `po/de.po` unter dem Kommentar
`greeter-fprint: fingerprint panel`. In allen anderen Sprachen fallen sie auf
Englisch zurück – korrekt, aber ein halbfertiges Bild: Auf einem französischen
System spricht das Schild Französisch, die Meldung unter Tux nicht.

Die Fingernamen werden in „Place your %s on the reader“ und „Swipe your %s
across the reader“ eingesetzt; übersetze sie also in der Form, die diese Sätze
brauchen. Im Deutschen ist das der Akkusativ: „rechten Daumen“.

## Eine Sprache hinzufügen

Kopiere den Block der Fingerabdruck-Anzeige aus `po/de.po` nach
`po/<sprache>.po` und übersetze ihn. Maschinelle Übersetzung hätte die Lücke in
Minuten gefüllt und ist bewusst nicht der Weg, der hier gegangen wurde: Dieser
Text steht auf einem Anmeldebildschirm, und falsch klingende Formulierungen sind
dort schlimmer als schlichtes Englisch. Pull Requests von Leuten, die die Sprache
wirklich sprechen, sind willkommen.

screensaver-fprint liest denselben Katalog; eine hier ergänzte Übersetzung gilt
also auch für den Sperrbildschirm.
