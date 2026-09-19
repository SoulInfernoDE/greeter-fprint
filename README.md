# greeter-fprint

***English** · [Deutsch](README.de.md)*

Fingerprint login for the LightDM login screen that says what it is doing — and
then actually logs you in.

A fork of [slick-greeter](https://github.com/linuxmint/slick-greeter), the login
screen of Linux Mint. Unofficial: not affiliated with, endorsed by, or supported
by Linux Mint.

![The login screen cycling through its states: the Mint logo and the selected
user's name glow yellow while the reader waits, red for a rejected finger, green
for a recognised one, then Tux swaps the logo for the "Password:"
sign](docs/states.gif)

## Why

Fingerprint login works with the stock greeter, but badly:

- **Messages pile up**, one line per attempt.
- **They are always in English**, whatever language the system uses.
- **A recognised finger does not log you in** — you still have to click Log In.

greeter-fprint gives the reader a panel of its own under the user list:

| | |
| --- | --- |
| **Yellow** | the reader is waiting |
| **Red** | finger not recognised — back to yellow after 1.5 s |
| **Green** | finger recognised — the session starts |
| **Password sign** | the reader gave up; type your password |

The selected user's name glows in the same colour, and each result has a short
sound in Cinnamon's style. One message at a time,
translated: German is complete, and in other languages the reader's messages
fall back to English.

## Requirements

- LightDM and a working fingerprint setup: `fprintd`, `libpam-fprintd`, an
  enrolled finger
- To build:

```bash
sudo apt install valac meson libgtk-3-dev liblightdm-gobject-1-dev libcanberra-dev libpixman-1-dev
```

> **On Linux Mint**, fingerprint login at the login screen is switched off by
> default, and the switch has no GUI. [`docs/LINUX-MINT.md`](docs/LINUX-MINT.md)
> shows how to turn it on — one command.

## Install

```bash
git clone https://github.com/SoulInfernoDE/greeter-fprint.git
cd greeter-fprint
meson setup build
ninja -C build
sudo ninja -C build install
printf '[Seat:*]\ngreeter-session=greeter-fprint\n' | sudo tee /etc/lightdm/lightdm.conf.d/80-greeter-fprint.conf
```

It takes effect after a reboot. slick-greeter stays installed as a fallback: if
greeter-fprint ever fails to start, delete that file from a text console
(Ctrl+Alt+F2) and restart `lightdm`.

Your existing slick-greeter settings — background, theme, fonts — apply
unchanged.

## Recommended: unlock the keyring too

After a fingerprint login the GNOME keyring stays locked, because it is normally
unlocked with the password you typed.
[tpm-keyring-unlock](https://github.com/SoulInfernoDE/tpm-keyring-unlock)
unlocks it from the TPM instead; on Linux Mint use this fork of it, which
carries a fix Mint needs. It protects against a removed disk, not against a
stolen laptop booted from a live USB stick — read
[`docs/LINUX-MINT.md`](docs/LINUX-MINT.md) before relying on it.

## Trying it without logging out

```bash
GREETER_FPRINT_DEMO=1 greeter-fprint --test-mode
```

Walks the panel through every state in a window. More in
[`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

## How it works

| | |
| --- | --- |
| [`docs/HOW-IT-WORKS.md`](docs/HOW-IT-WORKS.md) | why the stock greeter gets it wrong, and what the panel does instead |
| [`docs/LINUX-MINT.md`](docs/LINUX-MINT.md) | the Fingwit switch, why the reader stays English, longer timeouts, the keyring |
| [`docs/TRANSLATIONS.md`](docs/TRANSLATIONS.md) | what is translated, and how to add a language |
| [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) | demo mode, the real greeter in a window, rendering the README images |

Each of them is also available in German; the link sits at the top of each.

## Related

[screensaver-fprint](https://github.com/SoulInfernoDE/screensaver-fprint) — the
same panel for the Cinnamon lock screen.

## For Linux Mint

Everything new in this fork may be used, adapted and relicensed by Linux Mint
freely, without asking and without attribution. The exact scope is in
[COPYRIGHT.md](COPYRIGHT.md).

## License

GPL-3, like slick-greeter — see [COPYING](COPYING) and
[COPYRIGHT.md](COPYRIGHT.md). Tux is the Linux mascot created by Larry Ewing; the
Linux Mint logo is not in this repository but loaded from the system at
runtime. Upstream's own README: [README.slick-greeter.md](README.slick-greeter.md).
