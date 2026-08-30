# Copyright and licensing

greeter-fprint is a fork of **slick-greeter**. Almost every file here is
upstream's work, under upstream's terms. This file records who holds what, so
that removing the Debian packaging (which is where the machine-readable
`debian/copyright` lived) does not lose the attribution those licences require.

## The fork as a whole

**GPL-3**, the licence slick-greeter is under. The full text is in
[COPYING](COPYING).

    Files: *
    Copyright: 2011-2013 Canonical Ltd
               2017 Clement Lefebvre <root@linuxmint.com>
               2026 soul-inferno <nofunction@gmx.net>
    License: GPL-3

Upstream's per-file copyright headers are untouched. The files added by this
fork carry their own headers naming the same licence:

    src/fingerprint-panel.vala
    src/fingerprint-messages.vala
    data/tux-fprint.svg

## Translations

    Files: po/*.po
    Copyright: 2012-2015 Rosetta Contributors and Canonical Ltd 2012
               2017 Clement Lefebvre <root@linuxmint.com>
               2026 soul-inferno <nofunction@gmx.net>
    License: GPL-3

## Session badges — attribution required

The 95 desktop-environment badges shipped under
`files/usr/share/greeter-fprint/badges/` are **CC-BY-3.0**, which requires that
credit travel with them:

    Files: files/usr/share/greeter-fprint/badges/*
    Copyright: 2013 zombifier
    License: CC-BY-3.0

    Files: files/usr/share/greeter-fprint/badges/budgie-desktop.svg
    Copyright: 2017 David Mohammed <fossfreedom@ubuntu.com>
    License: CC-BY-3.0

The directory is named after this fork rather than after slick-greeter, so the
two can be installed side by side. Renaming a directory changes nothing about
the licence of what is in it.

## Tux

`data/tux-fprint.svg` is an original drawing, not traced from or derived from
any existing file, and is GPL-3 like the rest of the fork. It depicts **Tux**,
the Linux mascot created by **Larry Ewing** with The GIMP in 1996 — credit to
him for the character.

## The Linux Mint logo

Not in this repository. The panel loads the system's own installed icon
(`linuxmint-logo-badge-symbolic`) at runtime and uses it as a Cairo mask, so no
Linux Mint trademark is redistributed here. On a machine without that icon the
panel simply draws the glow without it.

"Linux Mint" is a trademark of the Linux Mint project, registered through the
Linux Mark Institute. This fork is not affiliated with, endorsed by, or
supported by Linux Mint, and deliberately does not carry their name.
