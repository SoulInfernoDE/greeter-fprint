/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2026 soul-inferno <nofunction@gmx.net>
 *
 * This file is part of greeter-fprint, a fork of slick-greeter.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * greeter-fprint - classification of pam_fprintd's messages
 *
 * PAM messages arrive as plain strings with no marker saying where they came
 * from, so the only way to tell a fingerprint message from any other one is
 * to recognise its text. Two things make that less fragile than it sounds:
 *
 *  - The set of strings is small, fixed, and lives in pam_fprintd's source
 *    (its "fprintd" gettext domain). They are matched here case-folded and by
 *    substring, so wording changes around the edges don't break detection.
 *  - They arrive in English regardless of the system locale: lightdm never
 *    calls setlocale(), so pam_fprintd's gettext() returns the msgid
 *    untranslated. Matching English is therefore matching what actually
 *    arrives, not an assumption about the user's language. The German the
 *    user sees is produced here instead - which also means it stays correct
 *    whether or not a fprintd translation is installed on the system.
 *
 * If a string is not recognised as fingerprint-related, classify() returns
 * false and the greeter handles the message exactly as it always did.
 */

public enum FingerprintMessageKind
{
    WAITING,     /* reader is armed and wants a finger */
    RETRY,       /* the scan didn't take; try again, still armed */
    FAILURE      /* this attempt is over and failed */
}

namespace FingerprintMessages
{
    private struct FingerName
    {
        public unowned string english;
        public unowned string german;
    }

    /* Longest first: "left index finger" has to win over a bare "finger". */
    private const FingerName[] FINGERS = {
        { "left index finger",   "linken Zeigefinger" },
        { "left middle finger",  "linken Mittelfinger" },
        { "left ring finger",    "linken Ringfinger" },
        { "left little finger",  "linken kleinen Finger" },
        { "right index finger",  "rechten Zeigefinger" },
        { "right middle finger", "rechten Mittelfinger" },
        { "right ring finger",   "rechten Ringfinger" },
        { "right little finger", "rechten kleinen Finger" },
        { "left thumb",          "linken Daumen" },
        { "right thumb",         "rechten Daumen" }
    };

    public bool classify (string raw,
                          out FingerprintMessageKind kind,
                          out string display)
    {
        kind = FingerprintMessageKind.WAITING;
        display = "";

        var text = raw.down ();

        /* --- failures ------------------------------------------------- */
        if ("failed to match" in text || "no match" in text)
        {
            kind = FingerprintMessageKind.FAILURE;
            display = _("Fingerprint not recognised");
            return true;
        }

        if ("timed out" in text && ("verification" in text || "finger" in text))
        {
            kind = FingerprintMessageKind.FAILURE;
            display = _("The reader timed out");
            return true;
        }

        /* --- retry hints ---------------------------------------------- */
        if ("too short" in text)
        {
            kind = FingerprintMessageKind.RETRY;
            display = _("Swiped too fast - once more, please");
            return true;
        }

        if ("not centered" in text || "not centred" in text)
        {
            kind = FingerprintMessageKind.RETRY;
            display = _("Not centred - once more, please");
            return true;
        }

        if ("remove your finger" in text)
        {
            kind = FingerprintMessageKind.RETRY;
            display = _("Lift your finger and try again");
            return true;
        }

        if (("place your finger" in text || "swipe your finger" in text)
            && "again" in text)
        {
            kind = FingerprintMessageKind.RETRY;
            display = _("Once more, please");
            return true;
        }

        /* --- the ordinary "reader is waiting" messages ---------------- */
        var placing = "place your" in text;
        var swiping = "swipe your" in text;

        if (placing || swiping)
        {
            kind = FingerprintMessageKind.WAITING;

            foreach (var finger in FINGERS)
            {
                if (finger.english in text)
                {
                    display = placing
                        ? _("Place your %s on the reader").printf (finger.german)
                        : _("Swipe your %s across the reader").printf (finger.german);
                    return true;
                }
            }

            display = placing
                ? _("Place your finger on the reader")
                : _("Swipe your finger across the reader");
            return true;
        }

        /* Anything else that is unmistakably about the reader: keep it in the
         * panel rather than letting it stack up in the entry, but say
         * something generic rather than showing raw English. */
        if ("fingerprint" in text)
        {
            kind = FingerprintMessageKind.WAITING;
            display = _("Waiting for the fingerprint reader");
            return true;
        }

        return false;
    }
}
