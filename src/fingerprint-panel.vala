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
 * greeter-fprint - fingerprint panel
 *
 * A single, centred panel that owns everything the fingerprint reader has to
 * say. It exists because the stock greeter routes PAM messages into the user
 * entry's message list, where they stack up under each other, arrive in
 * English (lightdm never calls setlocale(), so pam_fprintd's gettext is a
 * no-op in that process), and - worst of all - each one sets
 * unacknowledged_messages, which is what stops the greeter from logging you
 * in automatically after a successful scan.
 *
 * So GreeterList hands fingerprint messages here instead. This panel keeps
 * exactly one message on screen at a time, in German, and drives Tux:
 *
 *   WAITING   Mint logo glows yellow, breathing, while the reader waits.
 *   FAILED    Mint logo flashes red for FLASH_MS, then back to WAITING.
 *   SUCCESS   Mint logo glows green for FLASH_MS, then success_finished().
 *   PASSWORD  Tux swaps the logo for a "Passwort:" sign - the reader has
 *             given up (pam_fprintd's max-tries) and PAM fell through to the
 *             password.
 */

public enum FingerprintState
{
    HIDDEN,
    WAITING,
    FAILED,
    SUCCESS,
    PASSWORD
}

public class FingerprintPanel : Gtk.Box
{
    /* Set by MainWindow; GreeterList reaches the panel through this rather
     * than being handed a reference down three constructors. */
    public static FingerprintPanel? instance = null;

    /* How long the red/green states hold before resolving. The spec is 1.5s
     * for both; SUCCESS spends it before the session actually starts, so it
     * is a real (deliberate) delay on login. */
    public const uint FLASH_MS = 1500;

    /* Where the logo hangs, as a fraction of tux-fprint.svg's viewBox: just
     * beyond the raised flipper's tip, above and to the left of the head.
     * Keep in sync with the artwork. */
    private const double HAND_X = 0.105;
    private const double HAND_Y = 0.085;

    private const int TUX_WIDTH = 180;

    /* Kept proportional to TUX_WIDTH: at a fixed pixel size the logo swamped
     * the drawing and covered Tux's face. */
    private const int LOGO_SIZE = (int) (TUX_WIDTH * 0.26);

    /* Room for the glow, which now sits above and outside Tux's own outline
     * and would otherwise be clipped by the drawing area. */
    private const int TOP_PAD = (int) (LOGO_SIZE * 0.9);
    private const int SIDE_PAD = (int) (LOGO_SIZE * 1.6);

    public signal void success_finished ();

    private Gtk.DrawingArea canvas;
    private Gtk.Label message_label;
    private Gtk.CssProvider label_style;

    private Gdk.Pixbuf? tux = null;
    private Gdk.Pixbuf? logo = null;

    private FingerprintState state = FingerprintState.HIDDEN;
    private double pulse = 0.0;
    private uint pulse_timer = 0;
    private uint flash_timer = 0;

    /* A state change that arrived while a flash was on screen, to be applied
     * when the flash is done. HIDDEN here means "nothing queued" - reset()
     * clears the queue instead of going through it. */
    private FingerprintState pending_state = FingerprintState.HIDDEN;
    private string pending_text = "";

    public FingerprintPanel ()
    {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        halign = Gtk.Align.CENTER;
        valign = Gtk.Align.CENTER;
        no_show_all = true;

        try
        {
            tux = new Gdk.Pixbuf.from_file_at_scale (
                Path.build_filename (Config.PKGDATADIR, "tux-fprint.svg"),
                TUX_WIDTH, -1, true);
        }
        catch (Error e)
        {
            warning ("greeter-fprint: could not load tux-fprint.svg: %s", e.message);
        }

        /* The symbolic Mint logo is a single-colour silhouette, which is
         * exactly what we need: it is used as a Cairo mask, so the state
         * colour comes from us and no recolouring of the file is required. */
        try
        {
            logo = new Gdk.Pixbuf.from_file_at_scale (
                "/usr/share/icons/hicolor/scalable/apps/linuxmint-logo-badge-symbolic.svg",
                LOGO_SIZE, LOGO_SIZE, true);
        }
        catch (Error e)
        {
            warning ("greeter-fprint: could not load the Mint logo: %s", e.message);
        }

        canvas = new Gtk.DrawingArea ();
        canvas.set_size_request (TUX_WIDTH + 2 * SIDE_PAD,
                                 (tux != null ? tux.get_height () : 200)
                                 + TOP_PAD + 12);
        canvas.draw.connect (on_draw);
        canvas.show ();
        add (canvas);

        message_label = new Gtk.Label ("");
        message_label.set_line_wrap (false);
        message_label.set_ellipsize (Pango.EllipsizeMode.END);
        message_label.set_max_width_chars (42);
        message_label.justify = Gtk.Justification.CENTER;
        message_label.halign = Gtk.Align.CENTER;

        /* The greeter has no stylesheet of its own - every widget that needs
         * styling ships its own provider (see dash-entry.vala, toggle-box.vala),
         * so this one does too. The colour follows the state, same as the logo:
         * the sentence and the glow are one signal, not two. The shadow is
         * there because this is drawn over whatever wallpaper the user picked. */
        label_style = new Gtk.CssProvider ();
        message_label.get_style_context ().add_provider (
            label_style, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        apply_label_colour ();

        message_label.show ();
        add (message_label);

        SlickGreeter.add_style_class (this);
    }

    /* --- state transitions ------------------------------------------- */

    public void show_waiting (string text)
    {
        set_state (FingerprintState.WAITING, text);
    }

    public void show_failure (string text)
    {
        set_state (FingerprintState.FAILED, text);
    }

    /* A retry hint means the previous attempt failed. Whether that is news
     * depends on the channel: here PAM's own "Failed to match fingerprint"
     * normally arrives first, so the hint is just the reader re-arming - but
     * on the lock screen that message is dropped before it reaches the UI
     * (cinnamon-screensaver's PAM helper discards PAM_ERROR_MSG), and there
     * the hint is the only evidence the user gets. The same rule serves both:
     * say it failed unless we just said so. */
    public void show_retry (string text)
    {
        if (state == FingerprintState.FAILED || flash_timer != 0)
            set_state (FingerprintState.WAITING, text);
        else
            set_state (FingerprintState.FAILED, text);
    }

    public void show_success (string text)
    {
        set_state (FingerprintState.SUCCESS, text);
    }

    public void show_password_fallback (string text)
    {
        set_state (FingerprintState.PASSWORD, text);
    }

    public void reset ()
    {
        set_state (FingerprintState.HIDDEN, "");
    }

    public bool is_active ()
    {
        return state != FingerprintState.HIDDEN;
    }

    private void set_state (FingerprintState new_state, string text)
    {
        /* A flash owns the panel for its full FLASH_MS. Without this, the red
         * one was never actually visible: pam_fprintd sends "Failed to match
         * fingerprint" and, in the same breath, "Place your finger on the
         * reader again" for the next try - and that second message used to
         * put the panel straight back to yellow, milliseconds later.
         *
         * Anything arriving mid-flash is queued and applied when the flash
         * ends. Two exceptions: another failure restarts the flash (the user
         * did something new and deserves the feedback), and reset() is a hard
         * stop that clears the queue. */
        if (flash_timer != 0 && new_state != FingerprintState.HIDDEN
            && new_state != FingerprintState.FAILED)
        {
            pending_state = new_state;
            pending_text = text;
            return;
        }

        if (flash_timer != 0)
        {
            Source.remove (flash_timer);
            flash_timer = 0;
        }

        if (new_state == FingerprintState.HIDDEN)
        {
            pending_state = FingerprintState.HIDDEN;
            pending_text = "";
        }

        state = new_state;
        message_label.set_text (text);

        if (state == FingerprintState.HIDDEN)
        {
            stop_pulse ();
            hide ();
            return;
        }

        show ();
        message_label.visible = text != "";

        if (state == FingerprintState.WAITING)
            start_pulse ();
        else
            stop_pulse ();

        if (state == FingerprintState.FAILED || state == FingerprintState.SUCCESS)
        {
            var finished_state = state;
            flash_timer = Timeout.add (FLASH_MS, () => {
                flash_timer = 0;
                if (finished_state == FingerprintState.SUCCESS)
                {
                    success_finished ();
                }
                else if (state == FingerprintState.FAILED)
                {
                    if (pending_state != FingerprintState.HIDDEN)
                    {
                        /* Whatever the reader said during the flash - almost
                         * always "place your finger again", sometimes the
                         * password fallback - now gets its turn. */
                        var next_state = pending_state;
                        var next_text = pending_text;
                        pending_state = FingerprintState.HIDDEN;
                        pending_text = "";
                        set_state (next_state, next_text);
                    }
                    else
                    {
                        /* Nothing queued: back to waiting, because
                         * pam_fprintd retries on its own. */
                        state = FingerprintState.WAITING;
                        start_pulse ();
                        apply_label_colour ();
                        queue_draw_canvas ();
                    }
                }
                return Source.REMOVE;
            });
        }

        queue_draw_canvas ();
    }

    /* The message takes the same colour the logo has right now; PASSWORD is
     * the one state with no signal colour, so it stays white. */
    private void apply_label_colour ()
    {
        string colour;

        switch (state)
        {
        case FingerprintState.FAILED:
            colour = "#e63836";
            break;
        case FingerprintState.SUCCESS:
            colour = "#3db857";
            break;
        case FingerprintState.PASSWORD:
            colour = "#ffffff";
            break;
        default:
            colour = "#ffcc1a";
            break;
        }

        try
        {
            var css = "label { color: %s; font-size: 17px; font-weight: 500; text-shadow: 0 1px 4px rgba(0, 0, 0, 0.75); }".printf (colour);
            label_style.load_from_data (css, -1);
        }
        catch (Error e)
        {
            warning ("greeter-fprint: could not style the message label: %s", e.message);
        }
    }

    private void queue_draw_canvas ()
    {
        canvas.queue_draw ();
    }

    private void start_pulse ()
    {
        if (pulse_timer != 0)
            return;

        pulse_timer = Timeout.add (40, () => {
            pulse += 0.09;
            if (pulse > 2 * Math.PI)
                pulse -= 2 * Math.PI;
            canvas.queue_draw ();
            return Source.CONTINUE;
        });
    }

    private void stop_pulse ()
    {
        if (pulse_timer != 0)
        {
            Source.remove (pulse_timer);
            pulse_timer = 0;
        }
    }

    /* --- drawing ------------------------------------------------------ */

    private void state_colour (out double r, out double g, out double b)
    {
        switch (state)
        {
        case FingerprintState.FAILED:
            r = 0.90; g = 0.22; b = 0.21;   /* red */
            break;
        case FingerprintState.SUCCESS:
            r = 0.24; g = 0.72; b = 0.34;   /* green */
            break;
        default:
            r = 1.00; g = 0.80; b = 0.10;   /* Mint-ish yellow */
            break;
        }
    }

    private bool on_draw (Cairo.Context cr)
    {
        if (state == FingerprintState.HIDDEN || tux == null)
            return false;

        Gtk.Allocation alloc;
        canvas.get_allocation (out alloc);

        var tux_x = (alloc.width - tux.get_width ()) / 2.0;
        var tux_y = (double) TOP_PAD;

        Gdk.cairo_set_source_pixbuf (cr, tux, tux_x, tux_y);
        cr.paint ();

        var hx = tux_x + tux.get_width () * HAND_X;
        var hy = tux_y + tux.get_height () * HAND_Y;

        double r, g, b;
        state_colour (out r, out g, out b);

        /* Breathing only while waiting; the red/green flashes stay steady so
         * they read as a verdict rather than as more waiting. */
        var intensity = (state == FingerprintState.WAITING)
            ? 0.55 + 0.30 * Math.sin (pulse)
            : 1.0;

        if (state == FingerprintState.PASSWORD)
            draw_password_sign (cr, hx, hy);
        else
            draw_logo (cr, hx, hy, r, g, b, intensity);

        return false;
    }

    private void draw_logo (Cairo.Context cr, double hx, double hy,
                            double r, double g, double b, double intensity)
    {
        var radius = LOGO_SIZE * 0.95;

        var glow = new Cairo.Pattern.radial (hx, hy, 2, hx, hy, radius);
        glow.add_color_stop_rgba (0.0, r, g, b, 0.80 * intensity);
        glow.add_color_stop_rgba (0.55, r, g, b, 0.35 * intensity);
        glow.add_color_stop_rgba (1.0, r, g, b, 0.0);
        cr.set_source (glow);
        cr.arc (hx, hy, radius, 0, 2 * Math.PI);
        cr.fill ();

        if (logo == null)
            return;

        /* The logo itself: the pixbuf is used purely as an alpha mask so the
         * silhouette takes the state colour. */
        Gdk.cairo_set_source_pixbuf (cr, logo,
                                     hx - logo.get_width () / 2.0,
                                     hy - logo.get_height () / 2.0);
        var mask = cr.get_source ();
        cr.set_source_rgba (r, g, b, 0.55 + 0.45 * intensity);
        cr.mask (mask);
    }

    private void draw_password_sign (Cairo.Context cr, double hx, double hy)
    {
        const double W = 104;
        const double H = 46;
        const double RADIUS = 9;

        var x = hx - W / 2;
        var y = hy - H / 2;


        /* rounded card */
        cr.new_sub_path ();
        cr.arc (x + W - RADIUS, y + RADIUS, RADIUS, -Math.PI / 2, 0);
        cr.arc (x + W - RADIUS, y + H - RADIUS, RADIUS, 0, Math.PI / 2);
        cr.arc (x + RADIUS, y + H - RADIUS, RADIUS, Math.PI / 2, Math.PI);
        cr.arc (x + RADIUS, y + RADIUS, RADIUS, Math.PI, 1.5 * Math.PI);
        cr.close_path ();

        cr.set_source_rgba (0.99, 0.99, 0.99, 0.97);
        cr.fill_preserve ();
        cr.set_source_rgba (0.55, 0.68, 0.29, 1.0);   /* Mint green edge */
        cr.set_line_width (2.5);
        cr.stroke ();

        var layout = Pango.cairo_create_layout (cr);
        layout.set_text (_("Password:"), -1);
        layout.set_font_description (Pango.FontDescription.from_string ("Ubuntu Bold 12"));

        int tw, th;
        layout.get_pixel_size (out tw, out th);
        cr.move_to (x + (W - tw) / 2, y + (H - th) / 2);
        cr.set_source_rgba (0.15, 0.16, 0.17, 1.0);
        Pango.cairo_show_layout (cr, layout);
    }
}
