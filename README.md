# greeter-fprint

A fork of [slick-greeter](https://github.com/linuxmint/slick-greeter) that makes
fingerprint login say what it is doing — and then actually log you in.

Unofficial. Not affiliated with, endorsed by, or supported by Linux Mint.
Upstream's own README is kept as
[README.slick-greeter.md](README.slick-greeter.md).

![The greeter cycling through its states: the Mint logo and the selected user's
name glow yellow while the reader waits, red for a rejected finger, green for a
recognised one, then Tux swaps the logo for the "Passwort:" sign](doc/states.gif)

Drawn by the greeter itself. `GREETER_FPRINT_RENDER` has it paint its own
window onto an offscreen Cairo surface and write one PNG per state, so these are
the fork's widgets, its CSS and its glow code - not a screen grab put through a
video codec. The accounts come from the same `LightDM.UserList` a real login
reads, the wallpaper is the configured one, and the messages travel through the
real classifier and catalogue; only the order of the states is scripted. Each is
held for the duration the code gives it, 1.5 s per flash.

The name of the user being authenticated glows along with the logo, so the two
read as one signal rather than two, and the box grows its password row only once
the reader has given up.

## What it changes

Three things go wrong with fingerprint login in the stock greeter, all from one
cause: `pam_fprintd`'s messages are routed into the user entry's message list,
which was built for something else.

- **They stack up**, one line per attempt and per hint.
- **They arrive in English**, whatever the system locale says: `lightdm` never
  calls `setlocale()`, so `pam_fprintd`'s own `gettext()` hands back the
  untranslated msgid. No locale setting fixes this from the outside.
- **They block the login.** Every message sets `unacknowledged_messages`, and
  that flag is precisely what stops `authentication_complete_cb()` from starting
  the session — so a successful scan left you looking at a "Log In" button you
  had to click by hand.

Fingerprint messages go to a panel of their own instead, centred under the user
list, showing exactly one message at a time:

| State | What you see |
|---|---|
| Waiting | Mint logo glows yellow, breathing |
| Rejected | Logo flashes red for 1.5 s, then back to waiting |
| Recognised | Logo glows green for 1.5 s, then the session starts |
| Reader gave up | Tux swaps the logo for a "Passwort:" sign |

The password state is driven by PAM itself — a prompt arriving after the reader
has been talking means `pam_fprintd` used up its `max-tries` — rather than by
guessing the retry count.

The German comes from this project's own catalogue, so it is right whether or
not an `fprintd` translation happens to be installed.

Two smaller fixes came along the way, both in upstream layout code: user names
are centred in their entry rather than pinned to its top-left corner, and the
active-session marker is centred on the box instead of on its first row — it was
pinned to the top of the name row, which stops being the middle as soon as the
box grows a row for the password prompt.

## In the real greeter

The animation above is rendered, and cropped to the user list and the panel.
This is a screenshot of the whole thing actually working - LightDM, PAM and the
reader, in a nested seat:

![greeter-fprint running in a nested LightDM session](doc/panel.png)

## Requirements

- LightDM, and a fingerprint setup that already works: `fprintd`,
  `libpam-fprintd`, an enrolled finger, `pam_fprintd.so` in your auth stack.
- slick-greeter's build dependencies: `valac`, `meson`, `libgtk-3-dev`,
  `liblightdm-gobject-1-dev`, `libcanberra-dev`, `libpixman-1-dev`.

On Linux Mint there is one more hurdle that has nothing to do with this fork:
`libpam-fingwit` gates fingerprint auth at the login screen behind the GSettings
key `org.x.fingwit login-enabled`, which defaults to false and has no GUI. The
module reads it as **root**, so setting it as your own user changes nothing.
[`doc/linux-mint.md`](doc/linux-mint.md) has the details and the one-line fix.

## Build and install

```bash
meson setup build
ninja -C build
sudo ninja -C build install
```

Then point LightDM at it:

```bash
printf '[Seat:*]\ngreeter-session=greeter-fprint\n' | sudo tee /etc/lightdm/lightdm.conf.d/80-greeter-fprint.conf
```

LightDM reads `conf.d` when *it* starts, not per greeter launch, so this takes
effect on the next reboot.

The installed slick-greeter is deliberately left untouched and stays available
as a fallback: if this greeter ever fails to start, delete that file from a TTY
(Ctrl+Alt+F2) and restart `lightdm`.

## Unlocking the keyring as well

Recommended alongside this fork, because logging in with a finger has one
consequence the greeter cannot solve: the GNOME keyring stays locked.
`pam_gnome_keyring` unlocks it with the password you type, and a fingerprint
login never produces one - so Wi-Fi passwords, saved logins and everything else
in there start asking for the password you just avoided typing. That is Linux
Mint's own stated reason for shipping fingerprint login disabled at the login
screen in the first place.

Sealing the keyring password to the TPM closes the gap: it is stored encrypted
against a PCR7 policy, released only when the machine boots into the same
Secure Boot state, and handed to `pam_gnome_keyring` by a PAM module.
[tpm-keyring-unlock](https://github.com/dmitriitimoshenko/tpm-keyring-unlock)
does exactly that.

On Linux Mint, use this fork of it:

    https://github.com/SoulInfernoDE/tpm-keyring-unlock

It carries a fix the original needs here. Mint's `/etc/pam.d/lightdm` writes
its keyring line with the `pam.conf` "-" prefix, as `-auth`, and the
installer's detection did not match that - so it found nothing to patch, said
so cheerfully, and the keyring went on asking. Sent upstream as
[PR #6](https://github.com/dmitriitimoshenko/tpm-keyring-unlock/pull/6); until
that lands, the fork is the one that works. Its `JOURNAL.md` also carries the
rest of the Mint specifics, `pam_fingwit` included.

## Looking at it without logging out

`GREETER_FPRINT_DEMO=1 greeter-fprint --test-mode` walks the panel through every
state, feeding the real English `pam_fprintd` strings through the real
classifier — so what you see is what a live reader produces, translation
included.

For the real greeter, PAM and reader included, in a window:

```bash
dm-tool add-nested-seat --screen 1280x900
```

`GREETER_FPRINT_RENDER=<dir> greeter-fprint --test-mode` writes one PNG per
fingerprint state and quits; `doc/states.gif` is assembled from those. The list
it draws holds the machine's real accounts, not test mode's fixtures - test mode
is there only to get past the LightDM daemon connection, which a greeter started
by hand cannot make. `GREETER_FPRINT_RENDER_USER` picks which name is selected,
and defaults to the invoking user.

## Configuration

It reads exactly what slick-greeter reads — the `x.dm.slick-greeter` schema and
`/etc/lightdm/slick-greeter.conf` — on purpose, so an existing greeter
configuration (background, per-user backgrounds, theme, fonts) applies
unchanged.

## Translations

Two sets of strings meet in this panel, and they are not equally well covered.

**Inherited from slick-greeter**, and complete: everything upstream already
translated, including the "Password:" on Tux's sign. The fork kept upstream's
whole `po/` directory and renamed the gettext domain, so on a French system
that sign reads "Mot de passe :" with nothing to configure. Verified against
the installed catalogues:

    de  Passwort:        pl  Hasło:
    fr  Mot de passe :   nl  Wachtwoord:
    es  Contraseña:      ru  Пароль:

**Added by this fork**, and German only: the fifteen strings the panel itself
produces - "Fingerprint not recognised", "Place your %s on the reader" and so
on, at the bottom of each `po/*.po` under a `greeter-fprint: fingerprint panel`
comment. Everywhere else they fall back to their English msgid, which is
correct behaviour and still a half-finished picture: on a French system the
sign speaks French and the message under Tux does not.

Adding a language means translating those fifteen strings into
`po/<language>.po`. Machine translation would fill the gap in minutes and is
deliberately not what happened here - this text sits on a login screen, and
wrong-sounding German or French there is worse than plain English. Pull
requests from people who actually speak the language are welcome.

## For Linux Mint

Everything original to this fork - the code, the artwork, the ideas behind them
- is offered to the Linux Mint project to use, adapt, relicense and ship in
whatever way suits them. No need to ask, no attribution required, no strings.
A change that lands in slick-greeter itself helps more people than this
repository ever will, so please take anything that is useful.

That grant covers what is actually ours to give: the changes made in this
repository and `data/tux-fprint.svg`. Code inherited from slick-greeter keeps
its own licence and its own copyright holders, and the session badges keep the
CC-BY-3.0 attribution requirement described in
[COPYRIGHT.md](COPYRIGHT.md).

## Licence

GPL-3, like slick-greeter. See [COPYING](COPYING), and [COPYRIGHT.md](COPYRIGHT.md)
for who holds what — including the session badges, which are CC-BY-3.0 and carry
their own attribution requirement.

Tux is the Linux mascot created by Larry Ewing; `data/tux-fprint.svg` is an
original drawing of him. The Linux Mint logo is **not** in this repository: the
panel loads the system's installed icon at runtime and uses it as a mask.

## Related

[screensaver-fprint](https://github.com/SoulInfernoDE/screensaver-fprint) does
the same for the Cinnamon lock screen, and shares this project's artwork and
translation catalogue.
