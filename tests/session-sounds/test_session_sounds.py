#!/usr/bin/python3
"""Replays a recording of fprintd's signals through the session sounds' rules.

fprintd-trace.txt was recorded on a Mint 22.3 machine while doing, in order:
sudo with a wrong and then the right finger, sudo left to time out, pkexec
with a finger, pkexec left to time out; plus an early match and a cancelled
sudo. pam_fprintd's effective timeout there was the default 30 s.
"""

import ast
import os
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "src"))
import session_sounds as ss  # noqa: E402

LINE = re.compile(r"^\S+ \+\s*([0-9.]+)s\s+(\S+) (.*)$")


def replay(path, timeout):
    events = []
    for line in open(path, encoding="utf-8"):
        m = LINE.match(line.strip())
        if m and m.group(2) != "recording":
            events.append((float(m.group(1)), m.group(2), ast.literal_eval(m.group(3))))
    clock = [0.0]
    played = []
    tracker = ss.Tracker(lambda name: played.append((round(clock[0], 2), name)), timeout, lambda: clock[0])
    for t, name, args in events:
        if tracker.gave_up_at is not None and t >= tracker.gave_up_at:
            clock[0] = tracker.gave_up_at
            tracker.tick()
        clock[0] = t
        if name == "Device.VerifyFingerSelected":
            tracker.verify_started()
        elif name == "Device.VerifyStatus":
            tracker.verify_status(*args)
        elif name == "Properties.PropertiesChanged" and "finger-present" in args[1]:
            tracker.finger_present(args[1]["finger-present"])
    if tracker.gave_up_at is not None:
        clock[0] = tracker.gave_up_at
        tracker.tick()
    return played


def test_trace():
    played = [name.replace("fingerprint-", "").replace(".oga", "")
              for _, name in replay(os.path.join(HERE, "fprintd-trace.txt"), 30)]
    expect = ["success",               # a match already under way when recording began
              "password",              # 30 s without a finger: timed out
                                       # (11 s without a finger: cancelled - silent)
              "failure",               # wrong finger, sudo restarts at once
              "success",               # right finger
              "password",              # sudo left to time out
              "success",               # pkexec with a finger
              "password"]              # pkexec left to time out
    assert played == expect, played


def test_gave_up_after_last_try():
    clock = [0.0]
    played = []
    t = ss.Tracker(played.append, 30, lambda: clock[0])
    t.verify_started(); clock[0] = 2; t.finger_present(True)
    t.verify_status("verify-no-match", True)
    clock[0] = 3.1; t.tick()                       # nobody restarted
    assert played == [ss.FAILURE, ss.PASSWORD], played


def test_pam_timeout_parsing():
    cases = {
        "auth [success=2 default=ignore] pam_fprintd.so timeout=120 # debug max-tries=3 timeout=900\n": 30,
        "auth [success=2 default=ignore] pam_fprintd.so max-tries=3 timeout=15\n": 15,
        "auth [success=2 default=ignore] pam_fprintd.so timeout=99\n": 99,
        "auth [success=2 default=ignore] pam_fprintd.so timeout=5\n": 10,
        "auth sufficient /lib/security/pam_fprintd.so\n": 30,
        "# auth pam_fprintd.so timeout=20\nauth required pam_unix.so\n": 30,
    }
    for text, expect in cases.items():
        with tempfile.NamedTemporaryFile("w", delete=False) as f:
            f.write(text)
        try:
            got = ss.pam_fprintd_timeout(f.name)
        finally:
            os.unlink(f.name)
        assert got == expect, (text, got, expect)


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn()
            print(f"  {name}: ok")
