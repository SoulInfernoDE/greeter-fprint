# Anmeldung per Fingerabdruck unter Linux Mint

*[English](LINUX-MINT.md) · **Deutsch***

Notizen aus der Einrichtung unter Mint 22.3 (Cinnamon, LightDM, Basis Ubuntu
24.04). Nichts davon verursacht dieser Fork; alles davon trifft jeden, der am
Mint-Anmeldebildschirm einen Fingerabdruckleser benutzen will.

## Fingwit sperrt den Anmeldebildschirm und liest die Einstellung als root

Mint liefert `libpam-fingwit` aus, dessen `pam-auth-update`-Profil eine Sperre
vor `pam_fprintd` setzt:

```
auth  [authinfo_unavail=1 default=ignore]  pam_fingwit.so
auth  [success=2 default=ignore]           pam_fprintd.so max-tries=3 timeout=15
auth  [success=1 default=ignore]           pam_unix.so nullok try_first_pass
```

`pam_fingwit.so` ist eine dünne Hülle um `/usr/lib/*/fingwit/pam_fingwit.py`,
und das entscheidet:

```python
if user_has_session(user):
    return PAM.PAM_IGNORE                    # Abkürzung, Sperre übersprungen
if is_login_session():                       # PAM_SERVICE in lightdm/gdm/login/...
    if not settings.get_boolean("login-enabled"):
        return PAM.PAM_AUTHINFO_UNAVAIL      # authinfo_unavail=1 springt über pam_fprintd
    if has_encrypted_home(user):
        return PAM.PAM_AUTHINFO_UNAVAIL
```

`org.x.fingwit login-enabled` steht ab Werk auf false, und die Oberfläche von
Fingwit hat keinen Schalter dafür – das ganze System erwähnt dieses Schema an
drei Stellen (`gschema.xml`, `pam_fingwit.py`, `/usr/bin/fingwit`), und keine
davon schreibt den Schlüssel. Mints Grund für die Voreinstellung: Eine Anmeldung
per Fingerabdruck lässt den Schlüsselbund gesperrt – siehe
[den letzten Abschnitt](#auch-den-schlüsselbund-entsperren).

**Zwei Fallen beim Testen.**

*Ab- und wieder anmelden ist kein Test.* `user_has_session()` greift vor der
Sperre, und nach einer Abmeldung hat logind oft noch eine Sitzung für den
Benutzer – also wird der Fingerabdruck angeboten. Nach einem echten Neustart gibt
es keine Sitzung, die Sperre greift, und die Passwortabfrage ist zurück. Nur ein
Neustart testet den echten Weg.

*Den Schlüssel als du selbst zu setzen, bewirkt nichts.* Das Modul läuft als
**root** im PAM-Prozess des Displaymanagers, also löst `Gio.Settings` das Backend
von root auf, nicht deins. Auf dem Rechner, auf dem das auffiel, lagen die
GSettings des Benutzers in einer Schlüsseldatei
(`~/.config/glib-2.0/settings/keyfile`, die GLib bevorzugt, sobald sie existiert),
die von root in dconf. Nur derselbe Codeweg, als root ausgeführt, prüft das
zuverlässig:

```bash
sudo -H python3 -c "import gi; gi.require_version('Gio','2.0'); \
  from gi.repository import Gio; \
  print(Gio.Settings(schema_id='org.x.fingwit').get_boolean('login-enabled'))"
```

Die Lösung, über einen Neustart hinweg bestätigt:

```bash
sudo -H dconf write /org/x/fingwit/login-enabled true
```

Die Alternative ist `sudo pam-auth-update` mit einem Wechsel vom Profil
`fingwit` zum einfachen `fprintd`-Profil; das nimmt die Sperre ganz aus
`common-auth`. Auf Dauer sauberer, aber es ändert eine Datei, von der die
Anmeldung abhängt.

## Die Meldung des Lesers bleibt am Anmeldebildschirm englisch

`nm -D … | grep -c setlocale`:

| Programm | setlocale | Folge |
| --- | --- | --- |
| `pam_fprintd.so` | 0 | verlässt sich auf seinen Wirtsprozess |
| `lightdm` | 0 | hier läuft der PAM-Stapel, der Text kommt also unübersetzt durch |
| `sudo` | 1 | dieselbe Meldung *ist* im Terminal deutsch |
| der Anmeldebildschirm | 1 | egal: er zeigt nur den fertigen Text an |

Der Text entsteht in `lightdm`, und das setzt nie eine Sprache. Weder ein
fprintd-Sprachkatalog noch ein `LANG`-Eintrag für `lightdm.service` kann daran
etwas ändern. Dieser Fork übersetzt die Meldungen selbst, deshalb funktioniert
es.

## Länger auf den Finger warten

`timeout=` von `pam_fprintd` ist die Wartezeit, bevor PAM zur Passwortabfrage
weitergeht. Voreingestellt sind 30 Sekunden, das Minimum sind 10 – und das
Maximum **99**: pam_fprintd nimmt nur Werte mit höchstens zwei Ziffern an und
*ignoriert* längere stillschweigend; `timeout=120` lässt dich also unbemerkt bei
30. Alles hinter einem `#` in der Zeile ist für PAM ein Kommentar, Argumente dort
wirken also ebenfalls nicht.

```bash
sudo cp /etc/pam.d/common-auth /etc/pam.d/common-auth.bak-$(date +%Y%m%d%H%M%S)
sudo sed -i '/pam_fprintd\.so/ s/timeout=[0-9]*/timeout=99/' /etc/pam.d/common-auth
sudo sed -i '/pam_fprintd\.so/ s/timeout=[0-9]*/timeout=99/' /usr/share/pam-configs/fingwit
```

Die zweite Zeile verhindert, dass ein späteres `pam-auth-update` die erste
rückgängig macht.

Bedenke den Preis: PAM arbeitet der Reihe nach – laut Handbuchseite von
`pam_fprintd` können Fingerabdruck und Passwort nicht gleichzeitig aktiv sein –,
eine lange Wartezeit heißt also auch, so lange zu warten, bevor du stattdessen
tippen kannst. Escape bricht ab und startet die Abfrage neu.

## Auch den Schlüsselbund entsperren

Nach einer Anmeldung per Fingerabdruck bleibt der GNOME-Schlüsselbund gesperrt.
`pam_gnome_keyring` entsperrt ihn mit dem Passwort, das du eintippst, und eine
Anmeldung per Fingerabdruck erzeugt keins – WLAN-Passwörter, gespeicherte
Anmeldungen und alles andere darin fragen also nach dem Passwort, das du dir
gerade gespart hast.

[tpm-keyring-unlock](https://github.com/dmitriitimoshenko/tpm-keyring-unlock)
schließt diese Lücke: Das Schlüsselbund-Passwort wird im TPM-Chip versiegelt,
gebunden an eine PCR7-Richtlinie, nur freigegeben, wenn der Rechner im selben
Secure-Boot-Zustand startet, und von einem PAM-Modul an `pam_gnome_keyring`
übergeben.

**Unter Linux Mint nimm [diesen Fork davon](https://github.com/SoulInfernoDE/tpm-keyring-unlock).**
Mints `/etc/pam.d/lightdm` schreibt seine Schlüsselbund-Zeile mit dem
`pam.conf`-Präfix „-“, also als `-auth`, und das ursprüngliche
Installationsskript hat das nicht erkannt: Es fand nichts zu ändern, meldete das,
und der Schlüsselbund fragte weiter. Die Korrektur liegt upstream als
[PR #6](https://github.com/dmitriitimoshenko/tpm-keyring-unlock/pull/6); bis sie
übernommen ist, funktioniert unter Mint der Fork.

**Wisse, wogegen es schützt.** Das Werkzeug ist für Festplatten gedacht, die
nicht vollständig verschlüsselt sind. Dort hält ein reines PCR7-Siegel jemanden
auf, der die Festplatte ausbaut und in einem anderen Rechner ausliest – nicht
aber jemanden, der den ganzen Laptop mitnimmt und ihn von einem signierten
Live-System startet: Das erreicht denselben PCR7-Wert und kann das
Schlüsselbund-Passwort entsiegeln, ohne dass irgendwo ein Passwort abgefragt
wird. Einzelheiten in
[Issue #8](https://github.com/dmitriitimoshenko/tpm-keyring-unlock/issues/8).
