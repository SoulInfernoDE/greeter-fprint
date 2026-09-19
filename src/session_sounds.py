#!/usr/bin/python3
# Copyright (C) 2026 soul-inferno <nofunction@gmx.net>
#
# This file is part of greeter-fprint, a fork of slick-greeter.
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3 as published by
# the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

"""
greeter-fprint-session-sounds - the fingerprint panel's sounds for every
fingerprint prompt in the desktop session: sudo, su and pkexec in a terminal,
and Cinnamon's authentication dialogs.

None of those programs knows about sounds, and none of them is changed. They
all verify through fprintd, and fprintd broadcasts every step on the system
bus, so a listener in the session hears all of them:

  VerifyFingerSelected               a verification has started
  PropertiesChanged finger-present   a finger is on the sensor
  VerifyStatus(result, done)         the verdict

A recording on a real machine (tests/session-sounds/fprintd-trace.txt) shows
the one rule that matters: a real verdict always follows finger-present.
fprintd reports a *stopped* verification as "verify-no-match" as well - a
cancelled sudo, or pam_fprintd running out of time - and the rejection sound
would be wrong for those. So:

  match                                 recognised
  no-match after a finger               not recognised; and if no new
                                        verification starts within a second,
                                        the reader has used up its tries and
                                        the password comes next
  no-match without a finger, once       the password comes next: pam_fprintd
  pam_fprintd's timeout has run out     timed out and PAM moves on
  no-match without a finger, earlier    cancelled - silent

Silent while the screen is locked (cinnamon-screensaver plays these sounds
itself), while this session is not the one in front (the login screen and
other users' sessions verify through the same fprintd), and when Cinnamon's
"Showing notifications" sound is off - the rule the lock screen follows too.
"""

import os
import sys
import time
import traceback

SUCCESS = "fingerprint-success.oga"
FAILURE = "fingerprint-failure.oga"
PASSWORD = "fingerprint-password.oga"

SOUND_DIR = "/usr/share/greeter-fprint/sounds"
PAM_CONFIG = "/etc/pam.d/common-auth"

# pam_fprintd 1.94's own values (pam/pam_fprintd.c).
DEFAULT_TIMEOUT = 30
MIN_TIMEOUT = 10

# How close to the timeout a finger-less stop has to come to count as one.
TIMEOUT_SLACK = 0.5
# After a rejection pam_fprintd restarts at once if it has tries left - the
# recording shows no measurable gap. A second without a restart means it gave up.
RESTART_WINDOW = 1.0
# Retry hints can arrive in quick succession; one sound per flash is enough,
# the same 1.5 s the panel holds its red for.
RETRY_DEBOUNCE = 1.5

RETRY_RESULTS = ("verify-retry-scan", "verify-swipe-too-short",
                 "verify-finger-not-centered", "verify-remove-and-retry")


def pam_fprintd_timeout(path=PAM_CONFIG):
    """pam_fprintd's effective timeout, parsed the way PAM and pam_fprintd do.

    PAM ends a line at '#'. pam_fprintd accepts "timeout=" only with at most
    two digits - "timeout=120" is silently ignored and the default of 30
    applies - and raises anything below 10 to 10. A negative value means it
    never times out.
    """
    timeout = DEFAULT_TIMEOUT
    try:
        with open(path, encoding="utf-8", errors="replace") as config:
            lines = config.readlines()
    except OSError:
        return timeout
    for line in lines:
        words = line.split("#", 1)[0].split()
        modules = [i for i, w in enumerate(words) if os.path.basename(w) == "pam_fprintd.so"]
        if not modules:
            continue
        for arg in words[modules[0] + 1:]:
            if arg.startswith("timeout=") and len(arg) <= len("timeout=") + 2:
                digits = arg[len("timeout="):]
                try:
                    value = int(digits)
                except ValueError:
                    value = 0                       # atoi() of garbage
                if value < 0:
                    timeout = float("inf")
                else:
                    timeout = max(value, MIN_TIMEOUT)
    return timeout


class Tracker:
    """Turns fprintd's signals into sounds. Clock and player are injected, so
    the rules can be replayed against a recording without a bus or a speaker."""

    def __init__(self, play, timeout, now=time.monotonic):
        self.play = play
        self.timeout = timeout
        self.now = now
        self.started = None
        self.finger_seen = False
        self.gave_up_at = None          # deadline for "no new verification"
        self.last_retry_sound = None

    def verify_started(self):
        self.started = self.now()
        self.finger_seen = False
        self.gave_up_at = None          # it restarted: tries are left

    def finger_present(self, present):
        if present:
            self.finger_seen = True

    def verify_status(self, result, done):
        now = self.now()
        if result == "verify-match":
            self.play(SUCCESS)
        elif result == "verify-no-match":
            if self.finger_seen:
                self.play(FAILURE)
                self.gave_up_at = now + RESTART_WINDOW
            elif self.started is not None and now - self.started >= self.timeout - TIMEOUT_SLACK:
                self.play(PASSWORD)
        elif result in RETRY_RESULTS:
            if self.last_retry_sound is None or now - self.last_retry_sound >= RETRY_DEBOUNCE:
                self.play(FAILURE)
                self.last_retry_sound = now
            if not done:
                self.finger_seen = False
                return
        if done:
            self.started = None
            self.finger_seen = False

    def tick(self):
        """Call RESTART_WINDOW after a rejection; plays the password sound if
        no new verification started in the meantime."""
        if self.gave_up_at is not None and self.now() >= self.gave_up_at:
            self.gave_up_at = None
            self.play(PASSWORD)


class SessionPlayer:
    """Plays a sound only when it belongs to this session, right now."""

    def __init__(self):
        from gi.repository import Gio
        self.Gio = Gio
        self.system = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.session = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.context = None

    def _session_active(self):
        try:
            reply = self.system.call_sync(
                "org.freedesktop.login1", "/org/freedesktop/login1/session/auto",
                "org.freedesktop.DBus.Properties", "Get",
                self._variant("(ss)", ("org.freedesktop.login1.Session", "Active")),
                None, self.Gio.DBusCallFlags.NONE, 1000, None)
            return bool(reply.unpack()[0])
        except Exception:
            return True                     # no logind: assume we are in front

    def _screen_locked(self):
        try:
            reply = self.session.call_sync(
                "org.cinnamon.ScreenSaver", "/org/cinnamon/ScreenSaver",
                "org.cinnamon.ScreenSaver", "GetActive", None, None,
                self.Gio.DBusCallFlags.NO_AUTO_START, 1000, None)
            return bool(reply.unpack()[0])
        except Exception:
            return False

    def _sounds_enabled(self):
        source = self.Gio.SettingsSchemaSource.get_default()
        if source is None or source.lookup("org.cinnamon.sounds", True) is None:
            return True                     # not Cinnamon: nothing says no
        return self.Gio.Settings(schema_id="org.cinnamon.sounds").get_boolean("notification-enabled")

    @staticmethod
    def _variant(fmt, value):
        from gi.repository import GLib
        return GLib.Variant(fmt, value)

    def __call__(self, name):
        try:
            if not self._sounds_enabled() or self._screen_locked() or not self._session_active():
                return
            path = os.path.join(SOUND_DIR, name)
            if not os.path.exists(path):
                return
            if self.context is None:
                import gi
                gi.require_version("GSound", "1.0")
                from gi.repository import GSound
                context = GSound.Context()
                context.init(None)
                self.context = context
            self.context.play_simple({"media.filename": path}, None)
        except Exception:
            sys.stderr.write(traceback.format_exc())


def main():
    from gi.repository import Gio, GLib

    tracker = Tracker(SessionPlayer(), pam_fprintd_timeout())
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)

    def on_signal(conn, sender, path, iface, name, params):
        try:
            if iface == "net.reactivated.Fprint.Device" and name == "VerifyFingerSelected":
                tracker.verify_started()
            elif iface == "net.reactivated.Fprint.Device" and name == "VerifyStatus":
                result, done = params.unpack()
                tracker.verify_status(result, done)
                if tracker.gave_up_at is not None:
                    GLib.timeout_add(int(RESTART_WINDOW * 1000) + 50,
                                     lambda: (tracker.tick(), False)[1])
            elif name == "PropertiesChanged":
                changed = params.unpack()[1]
                if "finger-present" in changed:
                    tracker.finger_present(changed["finger-present"])
        except Exception:
            sys.stderr.write(traceback.format_exc())

    bus.signal_subscribe("net.reactivated.Fprint", None, None, None, None,
                         Gio.DBusSignalFlags.NONE, on_signal)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
