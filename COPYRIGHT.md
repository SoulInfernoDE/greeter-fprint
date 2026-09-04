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

## Additional grant to the Linux Mint project

Beyond the GPL, and specifically for the **Linux Mint project**: the parts of
this repository that are ours — the changes made in this fork, and
`data/tux-fprint.svg` — may be used, adapted, relicensed and shipped by Linux
Mint in any way they see fit, without permission and without attribution.

This is a one-way grant from the copyright holder of those parts
(soul-inferno <nofunction@gmx.net>) and cannot reach further than that. It does
not touch upstream slick-greeter's code, which stays with its own copyright
holders under GPL-3, and it does not lift the CC-BY-3.0 attribution requirement
on the session badges, which is not ours to waive.

Everyone else has the GPL-3, which is the licence of the fork as a whole.
