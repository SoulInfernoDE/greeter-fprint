# How it works

***English** · [Deutsch](HOW-IT-WORKS.de.md)*

## What goes wrong in the stock greeter

Fingerprint login works in slick-greeter, but three things go wrong, all from
one cause: `pam_fprintd`'s messages are routed into the user entry's message
list, which was built for something else.

- **They stack up**, one line per attempt and per hint.
- **They arrive in English**, whatever the system locale says. `lightdm` never
  calls `setlocale()`, so `pam_fprintd`'s own `gettext()` returns the
  untranslated text, and no locale setting fixes that from the outside.
  [`LINUX-MINT.md`](LINUX-MINT.md) has the measurements.
- **They block the login.** Every message sets `unacknowledged_messages`, and
  that flag is exactly what stops `authentication_complete_cb()` from starting
  the session — so a successful scan left you looking at a Log In button.

## The panel

Fingerprint messages go to a panel of their own, centred under the user list,
showing exactly one message at a time:

| State | What you see |
| --- | --- |
| Waiting | Mint logo glows yellow, breathing |
| Rejected | Logo flashes red for 1.5 s, then back to waiting |
| Recognised | Logo glows green for 1.5 s, then the session starts |
| Reader gave up | Tux swaps the logo for a "Password:" sign |

The name of the user being authenticated glows in the same colour, so the two
read as one signal.

A flash owns the panel for its full 1.5 s, and a message arriving meanwhile is
shown when the flash ends. Without that the red was never visible:
`pam_fprintd` sends "Failed to match fingerprint" and the next "Place your
finger" in the same breath.

The password state is driven by PAM, not by counting attempts. A password prompt
arriving after the reader has been talking means `pam_fprintd` used up its
`max-tries`; the box then grows its password row, exactly as PAM asks for it.

## Sounds

Each result of a scan has a short sound in the style of Cinnamon's own: a
rising three-note chime when the finger is recognised, a gentle falling third
when it is not, and a neutral double tone when the password is needed. A wrong
password typed at the sign gets the same sound as a rejected finger. Waiting
stays silent. Sounds follow what is shown, so a state queued behind a flash is
heard together with its colour.

They are ordinary slick-greeter settings, like `play-ready-sound`: one sound
file per state, on by default, silent when empty. To switch one off, add it
empty to `/etc/lightdm/slick-greeter.conf`:

```ini
[Greeter]
play-fingerprint-failure-sound=
```

| Key | Plays when |
| --- | --- |
| `play-fingerprint-success-sound` | the finger is recognised |
| `play-fingerprint-failure-sound` | the finger is not recognised, or the password typed at the sign is wrong |
| `play-fingerprint-password-sound` | the reader gave up and the password is needed |

The login screen uses its own copies, 14 dB louder, in
`/usr/share/greeter-fprint/sounds/login-screen/`. The greeter runs as the
`lightdm` user, whose audio session has no saved volume, so WirePlumber opens
the device at its default of about −24 dB — with the ordinary files the sounds
came out roughly 18 dB quieter than on the lock screen. The gain sits in the
files rather than in the playback volume on purpose: WirePlumber remembers a
stream's volume per media role, and every event sound shares one role, so a
single boosted stream would leave all later event sounds boosted too. 14 dB is
as far as it goes without clipping, so the login screen stays a few dB quieter
than your own session.

The files are derived from Cinnamon's `plug`, `unplug` and `notification`
sounds; [`DEVELOPMENT.md`](DEVELOPMENT.md) shows how, and
[COPYRIGHT.md](../COPYRIGHT.md) carries their attribution.

## In the terminal and in dialogs

The same sounds play for every fingerprint prompt in your own session: `sudo`,
`su` and `pkexec` in a terminal, and Cinnamon's authentication dialogs. None of
them is changed. They all verify through `fprintd`, and `fprintd` announces
every step on the system bus, so a small companion started with the session -
`greeter-fprint-session-sounds`, listed under Startup Applications as
"Fingerprint sounds" - hears all of them.

One detail decides what it plays. `fprintd` reports a *stopped* verification as
"no match" too - a cancelled `sudo`, or the reader running out of time - so a
rejection only counts if a finger was actually on the sensor first. A stop
without a finger after `pam_fprintd`'s timeout means the password is next; an
earlier one is a cancel and stays silent. A recording of real prompts,
replayed by `tests/session-sounds/`, keeps those rules honest.

It stays silent while the screen is locked (the lock screen plays these itself),
while another session is in front, and when Cinnamon's **Sound → Showing
notifications** is off. A wrong *password* has no sound here: that verdict comes
from `pam_unix`, which announces nothing.

## Messages

PAM messages carry no marker saying where they came from, so the panel
recognises `pam_fprintd`'s by their text — matched in English, because that is
what arrives at the login screen. What is shown comes from this project's own
gettext catalogue, with English as the base and fallback, so it does not depend
on a fprintd translation being installed. See [`TRANSLATIONS.md`](TRANSLATIONS.md).

Anything that is not about the reader reaches the greeter's message list as
before.

## Smaller fixes in upstream layout code

- User names are centred in their entry rather than pinned to its top-left
  corner.
- The active-session marker is centred on the whole box instead of its first
  row, which stops being the middle once the box grows a password row.

## Configuration

greeter-fprint reads exactly what slick-greeter reads — the `x.dm.slick-greeter`
schema and `/etc/lightdm/slick-greeter.conf` — so an existing setup applies
unchanged.

## The whole screen

The animation in the README is cropped to the user list and the panel. This is
a screenshot of the real thing — LightDM, PAM and the reader — in a nested
LightDM seat:

![greeter-fprint running in a nested LightDM session](panel.png)
