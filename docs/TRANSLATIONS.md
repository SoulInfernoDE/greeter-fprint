# Translations

***English** · [Deutsch](TRANSLATIONS.de.md)*

Every text the panel shows comes from a gettext catalogue, with English as the
base and the fallback. Nothing is hard-wired.

Two sets of strings meet in the panel, and they are not equally well covered.

## Inherited from slick-greeter — complete

Everything upstream already translated, including the "Password:" on Tux's sign.
The fork kept upstream's whole `po/` directory and renamed the gettext domain, so
on a French system that sign reads "Mot de passe :" with nothing to configure:

    de  Passwort:        pl  Hasło:
    fr  Mot de passe :   nl  Wachtwoord:
    es  Contraseña:      ru  Пароль:

## Added by this fork — German only so far

25 strings: the panel's 15 sentences ("Fingerprint not recognised", "Place your
%s on the reader", …) and the 10 finger names inserted into two of them. They
sit at the bottom of `po/de.po` under a `greeter-fprint: fingerprint panel`
comment. In every other language they fall back to English — correct, but a
half-finished picture: on a French system the sign speaks French and the message
under Tux does not.

The finger names are inserted into "Place your %s on the reader" and "Swipe your
%s across the reader", so translate them in the form those sentences need.
German, for instance, uses the accusative: "rechten Daumen".

## Adding a language

Copy the fingerprint-panel block from `po/de.po` into `po/<language>.po` and
translate it. Machine translation would fill the gap in minutes and is
deliberately not what happened here: this text sits on a login screen, where
wrong-sounding wording is worse than plain English. Pull requests from people
who actually speak the language are welcome.

screensaver-fprint reads the same catalogue, so a translation added here covers
the lock screen too.
