# greeter-fprint

*[English](README.md) · **Deutsch***

Anmeldung per Fingerabdruck am LightDM-Anmeldebildschirm, die sagt, was sie
gerade tut – und dich danach auch wirklich anmeldet.

Ein Fork von [slick-greeter](https://github.com/linuxmint/slick-greeter), dem
Anmeldebildschirm von Linux Mint. Inoffiziell: nicht mit Linux Mint verbunden
und weder von Linux Mint unterstützt noch empfohlen.

![Der Anmeldebildschirm in seinen Zuständen: Mint-Logo und der Name des
gewählten Benutzers leuchten gelb, solange der Leser wartet, rot bei einem
abgelehnten Finger, grün bei einem erkannten, danach tauscht Tux das Logo gegen
das Schild „Passwort:“](docs/states.de.gif)

## Warum

Mit dem normalen Anmeldebildschirm funktioniert die Anmeldung per
Fingerabdruck, aber schlecht:

- **Meldungen stapeln sich**, eine Zeile pro Versuch.
- **Sie sind immer englisch**, egal welche Sprache das System hat.
- **Ein erkannter Finger meldet dich nicht an** – du musst trotzdem noch auf
  „Anmelden“ klicken.

greeter-fprint gibt dem Leser eine eigene Anzeige unter der Benutzerliste:

| | |
| --- | --- |
| **Gelb** | der Leser wartet |
| **Rot** | Finger nicht erkannt – nach 1,5 s wieder gelb |
| **Grün** | Finger erkannt – die Sitzung startet |
| **Passwort-Schild** | der Leser hat aufgegeben; gib dein Passwort ein |

Der Name des gewählten Benutzers leuchtet in derselben Farbe mit, und jedes
Ergebnis hat einen kurzen Ton im Stil von Cinnamon – der dann auch bei `sudo` im
Terminal und bei Legitimierungsdialogen in deiner Sitzung erklingt. Immer nur eine
Meldung, übersetzt: Deutsch ist vollständig, in anderen Sprachen fallen die
Meldungen des Lesers auf Englisch zurück.

## Voraussetzungen

- LightDM und eine funktionierende Fingerabdruck-Einrichtung: `fprintd`,
  `libpam-fprintd`, ein eingelesener Finger
- Zum Bauen:

```bash
sudo apt install valac meson libgtk-3-dev liblightdm-gobject-1-dev libcanberra-dev libpixman-1-dev
```

> **Unter Linux Mint** ist die Anmeldung per Fingerabdruck am
> Anmeldebildschirm ab Werk abgeschaltet, und der Schalter dafür hat keine
> Oberfläche. Wie du ihn umlegst, steht in
> [`docs/LINUX-MINT.de.md`](docs/LINUX-MINT.de.md) – ein Befehl.

## Installation

```bash
git clone https://github.com/SoulInfernoDE/greeter-fprint.git
cd greeter-fprint
meson setup build --prefix=/usr
ninja -C build
sudo ninja -C build install
printf '[Seat:*]\ngreeter-session=greeter-fprint\n' | sudo tee /etc/lightdm/lightdm.conf.d/80-greeter-fprint.conf
```

Wirksam wird das nach einem Neustart. slick-greeter bleibt als Rückfallebene
installiert: Startet greeter-fprint einmal nicht, lösche diese Datei auf einer
Textkonsole (Strg+Alt+F2) und starte `lightdm` neu.

Deine bisherigen slick-greeter-Einstellungen – Hintergrund, Design, Schriften –
gelten unverändert weiter.

## Empfohlen: auch den Schlüsselbund entsperren

Nach einer Anmeldung per Fingerabdruck bleibt der GNOME-Schlüsselbund gesperrt,
weil er normalerweise mit dem eingetippten Passwort entsperrt wird.
[tpm-keyring-unlock](https://github.com/SoulInfernoDE/tpm-keyring-unlock)
entsperrt ihn stattdessen über den TPM-Chip; unter Linux Mint nimm diesen Fork,
er enthält eine Korrektur, die Mint braucht. Er schützt gegen eine ausgebaute
Festplatte, nicht gegen einen gestohlenen Laptop, der von einem Live-USB-Stick
startet – lies [`docs/LINUX-MINT.de.md`](docs/LINUX-MINT.de.md), bevor du dich
darauf verlässt.

## Ausprobieren, ohne dich abzumelden

```bash
GREETER_FPRINT_DEMO=1 greeter-fprint --test-mode
```

Zeigt alle Zustände nacheinander in einem Fenster. Mehr dazu in
[`docs/DEVELOPMENT.de.md`](docs/DEVELOPMENT.de.md).

## Wie es funktioniert

| | |
| --- | --- |
| [`docs/HOW-IT-WORKS.de.md`](docs/HOW-IT-WORKS.de.md) | warum der normale Anmeldebildschirm es falsch macht und was die Anzeige stattdessen tut |
| [`docs/LINUX-MINT.de.md`](docs/LINUX-MINT.de.md) | der Fingwit-Schalter, warum der Leser englisch bleibt, längere Wartezeit, der Schlüsselbund |
| [`docs/TRANSLATIONS.de.md`](docs/TRANSLATIONS.de.md) | was übersetzt ist und wie eine Sprache dazukommt |
| [`docs/DEVELOPMENT.de.md`](docs/DEVELOPMENT.de.md) | Demomodus, der echte Anmeldebildschirm im Fenster, die README-Bilder rendern |

Alle gibt es auch auf Englisch; der Link steht jeweils oben.

## Verwandt

- [screensaver-fprint](https://github.com/SoulInfernoDE/screensaver-fprint) –
  dieselbe Anzeige für den Cinnamon-Sperrbildschirm
- [cinnamon-extension-fprint](https://github.com/SoulInfernoDE/cinnamon-extension-fprint)
  – dieselben Farben für Cinnamons Legitimierungsdialog (`pkexec`, polkit)

## Für Linux Mint

Alles, was in diesem Fork neu ist, darf Linux Mint frei verwenden, anpassen und
neu lizenzieren – ohne zu fragen und ohne Namensnennung. Den genauen Umfang
beschreibt [COPYRIGHT.md](COPYRIGHT.md) (englisch).

## Lizenz

GPL-3 wie slick-greeter – siehe [COPYING](COPYING) und
[COPYRIGHT.md](COPYRIGHT.md). Tux ist das Linux-Maskottchen von Larry Ewing; das
Linux-Mint-Logo liegt nicht in diesem Repository, sondern wird zur Laufzeit vom
System geladen. Die ursprüngliche README von slick-greeter:
[README.slick-greeter.md](README.slick-greeter.md).
