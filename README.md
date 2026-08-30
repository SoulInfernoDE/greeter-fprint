# greeter-fprint

A fork of [slick-greeter](https://github.com/linuxmint/slick-greeter) that makes
fingerprint login say what it is doing — and then actually log you in.

Unofficial. Not affiliated with, endorsed by, or supported by Linux Mint.
Upstream's own README is kept as
[README.slick-greeter.md](README.slick-greeter.md).

![The panel cycling through its states: yellow while the reader waits, red for
a rejected finger, green for a recognised one, then the "Passwort:" sign](doc/states.gif)

Rendered with the panel's own drawing code, so the timings are the real ones:
each flash holds for 1.5 s, and the yellow breathes while the reader waits.

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

Not a mockup - LightDM, PAM and the reader, in a nested seat:

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

## Looking at it without logging out

`GREETER_FPRINT_DEMO=1 greeter-fprint --test-mode` walks the panel through every
state, feeding the real English `pam_fprintd` strings through the real
classifier — so what you see is what a live reader produces, translation
included.

For the real greeter, PAM and reader included, in a window:

```bash
dm-tool add-nested-seat --screen 1280x900
```

## Configuration

It reads exactly what slick-greeter reads — the `x.dm.slick-greeter` schema and
`/etc/lightdm/slick-greeter.conf` — on purpose, so an existing greeter
configuration (background, per-user backgrounds, theme, fonts) applies
unchanged.

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
