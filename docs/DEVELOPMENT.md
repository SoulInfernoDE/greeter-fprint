# Development

***English** · [Deutsch](DEVELOPMENT.de.md)*

## Demo mode

```bash
GREETER_FPRINT_DEMO=1 ./build/src/greeter-fprint --test-mode
```

Walks the panel through every state on a timer, feeding the real English
`pam_fprintd` strings through the real classifier — what you see is what a live
reader produces, translation included. Test mode shows slick-greeter's fixture
accounts ("No Password", "Two Factor", …), so it is for looking, not for
pictures.

`GREETER_FPRINT_TEST_SIZE=1000x1080` replaces test mode's hard-coded 800×600 and
640×480 monitors with a single one of the given size. At 800×600 Tux falls off
the bottom.

## The real greeter in a window

```bash
dm-tool add-nested-seat --screen 1280x900
```

A real LightDM seat, with real PAM and the real reader. A recognised finger
really logs you in there.

## Rendering the README images

```bash
# English, for README.md
LC_ALL=C.UTF-8 GREETER_FPRINT_RENDER=/tmp/frames-en GREETER_FPRINT_TEST_SIZE=1000x1080 \
  ./build/src/greeter-fprint --test-mode

# German, for README.de.md
LC_ALL=de_DE.UTF-8 GREETER_FPRINT_RENDER=/tmp/frames-de GREETER_FPRINT_TEST_SIZE=1000x1080 \
  ./build/src/greeter-fprint --test-mode
```

Writes one PNG per state (`1-waiting` … `4-password`) and quits. The window
paints itself onto an offscreen Cairo surface, so the frames are the greeter's
own widgets, CSS and glow code, at full sharpness.

- The accounts are the machine's real ones from `LightDM.UserList`, not test
  mode's fixtures. `GREETER_FPRINT_RENDER_USER` picks the selected name; the
  default is you.
- Test mode is needed only to get past the LightDM daemon connection, which a
  greeter started by hand cannot make. Outside test mode the variable is
  ignored, so a real login screen never writes pictures of itself or quits.
- Steps are spaced just past `FLASH_MS`. A flash owns the panel for its full
  duration and queues whatever arrives meanwhile, so a faster walk captures the
  same frame twice.
- The password row is requested with PAM's literal `"Password: "`, trailing
  space included — that exact string is what gets translated.

`docs/states.gif` (English) and `docs/states.de.gif` (German) are assembled
from those frames the same way: crop 420×550 at (290, 380),
scale to 380 px wide, one shared 256-colour palette with Floyd–Steinberg
dithering (without it the wallpaper posterises), and the durations from the
code — 2.4 s waiting, 1.5 s red, 1.6 s waiting, 1.5 s green, 1.6 s waiting,
1.8 s sign.
