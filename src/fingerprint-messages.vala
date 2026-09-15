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
 *    arrives, not an assumption about the user's language. What the user
 *    sees is produced here instead, from this project's own catalogue, with
 *    English as the base and fallback - so it is right whether or not a
 *    fprintd translation happens to be installed on the system.
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
    /* Finger names as pam_fprintd sends them. Longest first: "left index
     * finger" has to win over a bare "finger".
     *
     * These used to be paired with hard-wired German names, which were then
     * inserted into a *translated* sentence - so on any system that was not
     * German the panel said "Place your rechten Daumen on the reader". The
     * names are catalogue strings now, like every other word the panel
     * shows; see finger_label(). */
    private const string[] FINGERS = {
        "left index finger",
        "left middle finger",
        "left ring finger",
        "left little finger",
        "right index finger",
        "right middle finger",
        "right ring finger",
        "right little finger",
        "left thumb",
        "right thumb"
    };

    /* Spelled out one literal per case so that xgettext sees every msgid; a
     * _() around a variable would translate at runtime but never reach the
     * catalogue. Translators: the name is inserted into "Place your %s on the
     * reader" and "Swipe your %s across the reader", so use the form those
     * sentences need (German, for instance, needs the accusative). */
    private string finger_label (string finger)
    {
        switch (finger)
        {
        case "left index finger":   return _("left index finger");
        case "left middle finger":  return _("left middle finger");
        case "left ring finger":    return _("left ring finger");
        case "left little finger":  return _("left little finger");
        case "right index finger":  return _("right index finger");
        case "right middle finger": return _("right middle finger");
        case "right ring finger":   return _("right ring finger");
        case "right little finger": return _("right little finger");
        case "left thumb":          return _("left thumb");
        case "right thumb":         return _("right thumb");
        default:                    return finger;
        }
    }

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

            foreach (unowned string finger in FINGERS)
            {
                if (finger in text)
                {
                    display = placing
                        ? _("Place your %s on the reader").printf (finger_label (finger))
                        : _("Swipe your %s across the reader").printf (finger_label (finger));
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
