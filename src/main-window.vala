/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2011,2012 Canonical Ltd
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
 *
 * Authors: Robert Ancell <robert.ancell@canonical.com>
 *          Michael Terry <michael.terry@canonical.com>
 */

public class MainWindow : Gtk.Window
{
    public MenuBar menubar;

    private List<Monitor> monitors;
    private Monitor? primary_monitor;
    private Monitor active_monitor;
    private string only_on_monitor;
    private bool monitor_setting_ok;
    private Background background;
    private Gtk.Box login_box;
    private Gtk.Box hbox;
    private Gtk.Box content_box;
    private Gtk.Button back_button;
    private ShutdownDialog? shutdown_dialog = null;
    private bool do_resize;
    private FingerprintPanel fingerprint_panel;

    public ListStack stack;

    // Menubar is smaller, but with shadow, we reserve more space
    public const int MENUBAR_HEIGHT = 32;

    construct
    {
        events |= Gdk.EventMask.POINTER_MOTION_MASK;

        var accel_group = new Gtk.AccelGroup ();
        add_accel_group (accel_group);

        var bg_color = Gdk.RGBA ();
        bg_color.parse (UGSettings.get_string (UGSettings.KEY_BACKGROUND_COLOR));
        override_background_color (Gtk.StateFlags.NORMAL, bg_color);
        get_accessible ().set_name (_("Login Screen"));
        has_resize_grip = false;
        SlickGreeter.add_style_class (this);

        background = new Background ();
        add (background);
        SlickGreeter.add_style_class (background);

        login_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        login_box.show ();
        background.add (login_box);

        /* Box for menubar shadow */
        var menubox = new Gtk.EventBox ();
        var menualign = new Gtk.Alignment (0.0f, 0.0f, 1.0f, 0.0f);
        var shadow_path = Path.build_filename (Config.PKGDATADIR,
                                               "shadow.png", null);
        var shadow_style = "";
        if (FileUtils.test (shadow_path, FileTest.EXISTS))
        {
            shadow_style = "background-image: url('%s');background-repeat: repeat;".printf(shadow_path);
        }
        try
        {
            var style = new Gtk.CssProvider ();
            style.load_from_data ("* {background-color: transparent;%s}".printf(shadow_style), -1);
            var context = menubox.get_style_context ();
            context.add_provider (style,
                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading menubox style: %s", e.message);
        }
        menubox.set_size_request (-1, MENUBAR_HEIGHT);
        menubox.show ();
        menualign.show ();
        menubox.add (menualign);
        login_box.add (menubox);
        SlickGreeter.add_style_class (menualign);
        SlickGreeter.add_style_class (menubox);

        menubar = new MenuBar (background, accel_group, this);
        menubar.show ();
        menualign.add (menubar);
        SlickGreeter.add_style_class (menubar);

        content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        content_box.expand = true;
        content_box.show ();
        login_box.add (content_box);

        var content_align = UGSettings.get_string(UGSettings.KEY_CONTENT_ALIGN);
        var x_align = 0.5f;

        if (content_align == "left")
        {
            x_align = 0.0f;
        }
        else if (content_align == "right")
        {
            x_align = 1.0f;
        }

        var align = new Gtk.Alignment (x_align, 0.0f, 0.0f, 1.0f);

        if (content_align == "center")
        {
            // offset for back button
            align.margin_right = grid_size;
        }

        align.show ();
        content_box.add (align);

        hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        hbox.expand = true;
        hbox.show ();
        align.add (hbox);

        align = new Gtk.Alignment (0.5f, 0.5f, 0.0f, 0.0f);
        // Hack to avoid gtk 3.20's new allocate logic, which messes us up.
        align.resize_mode = Gtk.ResizeMode.QUEUE;
        align.set_size_request (grid_size, -1);
        align.margin_bottom = MENUBAR_HEIGHT; /* offset for menubar at top */
        align.show ();
        hbox.add (align);

        back_button = new FlatButton ();
        back_button.get_accessible ().set_name (_("Back"));
        Gtk.button_set_focus_on_click (back_button, false);
        var image = new Gtk.Image.from_file (Path.build_filename (Config.PKGDATADIR, "arrow_left.svg", null));
        image.show ();
        back_button.set_size_request (grid_size - GreeterList.BORDER * 2, grid_size - GreeterList.BORDER * 2);
        back_button.add (image);
        back_button.clicked.connect (pop_list);
        align.add (back_button);

        /* yscale 1, as upstream: GreeterList positions its own box from its
         * allocated height (see box_y there, which compensates for the
         * menubar), and the back-arrow button is centred in this same full
         * height. Take the height away from the list and the two stop lining
         * up - the arrow ends up above the box. The fingerprint panel is
         * therefore NOT stacked under the list here; GreeterList places it
         * itself, directly beneath the box it just positioned. */
        align = new Gtk.Alignment (0.0f, 0.5f, 0.0f, 1.0f);
        align.show ();
        hbox.add (align);

        stack = new ListStack ();
        stack.show ();

        fingerprint_panel = new FingerprintPanel ();
        FingerprintPanel.instance = fingerprint_panel;

        /* Visual check without a reader: GREETER_FPRINT_DEMO=1 walks the panel
         * through every state on a timer. Development aid only - it touches
         * nothing but the panel, and does nothing unless the variable is set. */
        if (Environment.get_variable ("GREETER_FPRINT_DEMO") != null)
            start_fingerprint_demo ();

        /* GREETER_FPRINT_RENDER=<dir> writes one PNG per fingerprint state and
         * quits. The frames are drawn by this window onto an offscreen Cairo
         * surface - the greeter's own widgets, its own CSS, its own glow code -
         * rather than grabbed off a screen and squeezed through a video codec,
         * which is what the README images used to cost in sharpness.
         *
         * It renders whatever greeter it is running in. Under LightDM that is
         * the real thing end to end; started by hand it needs --test-mode to
         * get past the daemon connection, and then the accounts still come from
         * the real LightDM.UserList rather than test mode's fixtures (see
         * UserList.render_fill_list). Only the sequence of states is scripted:
         * every pixel is drawn by the code that draws them at a real login. */
        var render_dir = Environment.get_variable ("GREETER_FPRINT_RENDER");
        if (render_dir != null)
            start_fingerprint_render (render_dir);

        align.add (stack);

        add_user_list ();

        primary_monitor = null;
        do_resize = false;

        only_on_monitor = UGSettings.get_string(UGSettings.KEY_ONLY_ON_MONITOR);
        monitor_setting_ok = only_on_monitor == "auto";

        if (SlickGreeter.singleton.test_mode)
        {
            /* Simulate an 800x600 monitor to the left of a 640x480 monitor.
             *
             * GREETER_FPRINT_TEST_SIZE=WIDTHxHEIGHT replaces that with a single
             * monitor of the given size. Upstream's pair is deliberate - it
             * tests multi-monitor placement - but 800x600 is smaller than this
             * greeter draws: with the fingerprint panel below the user list,
             * Tux falls off the bottom, which makes test mode useless for
             * looking at the whole thing at once. Unset, nothing changes. */
            monitors = new List<Monitor> ();

            var test_size = Environment.get_variable ("GREETER_FPRINT_TEST_SIZE");
            if (test_size != null)
            {
                var parts = test_size.split ("x");
                if (parts.length == 2)
                {
                    var w = int.parse (parts[0]);
                    var h = int.parse (parts[1]);
                    if (w > 320 && h > 240)
                        monitors.append (new Monitor (0, 0, w, h));
                }
            }

            if (monitors.length () == 0)
            {
                monitors.append (new Monitor (0, 0, 800, 600));
                monitors.append (new Monitor (800, 120, 640, 480));
            }
            background.set_monitors (monitors);
            move_to_monitor (monitors.nth_data (0));
            resize (background.width, background.height);
        }
        else
        {
            var screen = get_screen ();
            screen.monitors_changed.connect (monitors_changed_cb);
            monitors_changed_cb (screen);
        }

        /* Force a call on login_box.show()...
            This fixes the following issue:
            When the greeter starts, the login box looks too small, its entry isn't visible and
            its session button isn't sensitive/clickable.
            Pressing Escape fixes the box but not the session button..
            Scrolling up/down fixes both..
        */
        if (login_box.sensitive) {
            login_box.show();
        }
    }

    public void push_list (GreeterList widget)
    {
        stack.push (widget);

        if (stack.num_children > 1)
            back_button.show ();
    }

    public void pop_list ()
    {
        if (stack.num_children <= 2)
            back_button.hide ();

        stack.pop ();
    }

    public override void size_allocate (Gtk.Allocation allocation)
    {
        base.size_allocate (allocation);

        if (content_box != null)
        {
            var content_align = UGSettings.get_string(UGSettings.KEY_CONTENT_ALIGN);
            content_box.margin_left = get_grid_offset (get_allocated_width ()) + (content_align == "left" ? grid_size : 0);
            content_box.margin_right = get_grid_offset (get_allocated_width ()) + (content_align == "right" ? grid_size : 0);
            content_box.margin_top = get_grid_offset (get_allocated_height ());
            content_box.margin_bottom = get_grid_offset (get_allocated_height ());
        }
    }

    public override void realize ()
    {
        base.realize ();
        background.set_surface (Gdk.cairo_create (get_window ()).get_target ());
    }

    public void before_session_start()
    {
        debug ("Killing orca and onboard");
        menubar.cleanup();
    }

    /* Setup the size and position of the window */
    public void setup_window ()
    {
        resize (background.width, background.height);
        move (0, 0);
        move_to_monitor (primary_monitor);
    }

    private void monitors_changed_cb (Gdk.Screen screen)
    {
        Gdk.Display display = screen.get_display();
        Gdk.Monitor primary = display.get_primary_monitor();
        Gdk.Rectangle geometry;

        monitors = new List<Monitor> ();
        primary_monitor = null;

        for (var i = 0; i < display.get_n_monitors (); i++)
        {
            Gdk.Monitor monitor = display.get_monitor(i);
            geometry = monitor.get_geometry ();
            debug ("Monitor %d is %dx%d pixels at %d,%d", i, geometry.width, geometry.height, geometry.x, geometry.y);

            if (monitor_is_unique_position (display, i))
            {
                var greeter_monitor = new Monitor (geometry.x, geometry.y, geometry.width, geometry.height);
                var plug_name = monitor.get_model();
                monitors.append (greeter_monitor);

                if (plug_name == only_on_monitor)
                    monitor_setting_ok = true;

                if (plug_name == only_on_monitor || primary_monitor == null || primary == monitor)
                    primary_monitor = greeter_monitor;
            }
        }

        debug ("MainWindow is %dx%d pixels", background.width, background.height);

        background.set_monitors (monitors);

        if(do_resize)
        {
            setup_window ();
        }
        else
        {
            do_resize = true;
        }
    }

    /* Check if a monitor has a unique position */
    private bool monitor_is_unique_position (Gdk.Display display, int n)
    {
        Gdk.Rectangle g0;
        Gdk.Monitor mon0;
        mon0 = display.get_monitor(n);
        g0 = mon0.get_geometry ();

        for (var i = n + 1; i < display.get_n_monitors (); i++)
        {
            Gdk.Rectangle g1;
            Gdk.Monitor mon1;
            mon1 = display.get_monitor(i);
            g1 = mon1.get_geometry();

            if (g0.x == g1.x && g0.y == g1.y)
                return false;
        }

        return true;
    }

    public override bool motion_notify_event (Gdk.EventMotion event)
    {
        if (!monitor_setting_ok || only_on_monitor == "auto")
        {
            var x = (int) (event.x + 0.5);
            var y = (int) (event.y + 0.5);

            /* Get motion event relative to this widget */
            if (event.window != get_window ())
            {
                int w_x, w_y;
                get_window ().get_origin (out w_x, out w_y);
                x -= w_x;
                y -= w_y;
                event.window.get_origin (out w_x, out w_y);
                x += w_x;
                y += w_y;
            }

            foreach (var m in monitors)
            {
                if (x >= m.x && x <= m.x + m.width && y >= m.y && y <= m.y + m.height)
                {
                    move_to_monitor (m);
                    break;
                }
            }
        }

        return false;
    }

    private void move_to_monitor (Monitor monitor)
    {
        active_monitor = monitor;
        login_box.set_size_request (monitor.width, monitor.height);
        background.set_active_monitor (monitor);
        background.move (login_box, monitor.x, monitor.y);

        if (shutdown_dialog != null)
        {
            shutdown_dialog.set_active_monitor (monitor);
            background.move (shutdown_dialog, monitor.x, monitor.y);
        }
    }

    private void add_user_list ()
    {
        GreeterList greeter_list;
        greeter_list = new UserList (background, menubar);
        greeter_list.show ();
        SlickGreeter.add_style_class (greeter_list);
        
        // Connect Background to DashBox transitions for synchronized redraws
        background.connect_to_dashbox_transitions (greeter_list.greeter_box);
        
        push_list (greeter_list);
    }

    public override bool key_press_event (Gdk.EventKey event)
    {
        var top = stack.top ();

        if (stack.top () is UserList)
        {
            var user_list = stack.top () as UserList;
            var shift_mask = Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.MOD1_MASK;
            var control_mask = Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.MOD1_MASK;
            var alt_mask = Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK;
            if (((event.keyval == Gdk.Key.Shift_L || event.keyval == Gdk.Key.Shift_R) && (event.state & shift_mask) == shift_mask) ||
                ((event.keyval == Gdk.Key.Control_L || event.keyval == Gdk.Key.Control_R) && (event.state & control_mask) == control_mask) ||
                ((event.keyval == Gdk.Key.Alt_L || event.keyval == Gdk.Key.Alt_R) && (event.state & alt_mask) == alt_mask))
            {
                debug ("Hidden user key combination detected");
                user_list.show_hidden_users = ! user_list.show_hidden_users;
                return true;
            }
        }
        else if (stack.top () is SessionList) {
            // Session list is open
            switch (event.keyval) {
                case Gdk.Key.Escape:
                case Gdk.Key.Left:
                case Gdk.Key.KP_Left:
                    pop_list();
                    return true;
            }
        }

        switch (event.keyval)
        {
        case Gdk.Key.Escape:
            if (login_box.sensitive)
                top.cancel_authentication ();
            if (shutdown_dialog != null)
                shutdown_dialog.cancel ();
            return true;
        case Gdk.Key.Page_Up:
        case Gdk.Key.KP_Page_Up:
            if (login_box.sensitive)
                top.scroll (GreeterList.ScrollTarget.START);
            return true;
        case Gdk.Key.Page_Down:
        case Gdk.Key.KP_Page_Down:
            if (login_box.sensitive)
                top.scroll (GreeterList.ScrollTarget.END);
            return true;
        case Gdk.Key.Up:
        case Gdk.Key.KP_Up:
            if (login_box.sensitive)
                top.scroll (GreeterList.ScrollTarget.UP);
            return true;
        case Gdk.Key.Down:
        case Gdk.Key.KP_Down:
            if (login_box.sensitive)
                top.scroll (GreeterList.ScrollTarget.DOWN);
            return true;
        case Gdk.Key.F10:
            if (login_box.sensitive)
                menubar.select_first (false);
            return true;
        case Gdk.Key.PowerOff:
            show_shutdown_dialog (ShutdownDialogType.SHUTDOWN);
            return true;
        case Gdk.Key.Print:
            debug ("Taking screenshot");
            var root = Gdk.get_default_root_window ();
            var screenshot = Gdk.pixbuf_get_from_window (root, 0, 0, root.get_width (), root.get_height ());
            try
            {
                screenshot.save ("Screenshot.png", "png", null);
            }
            catch (Error e)
            {
                warning ("Failed to save screenshot: %s", e.message);
            }
            return true;
        case Gdk.Key.z:
            if (SlickGreeter.singleton.test_mode && (event.state & Gdk.ModifierType.MOD1_MASK) != 0)
            {
                show_shutdown_dialog (ShutdownDialogType.SHUTDOWN);
                return true;
            }
            break;
        case Gdk.Key.Z:
            if (SlickGreeter.singleton.test_mode && (event.state & Gdk.ModifierType.MOD1_MASK) != 0)
            {
                show_shutdown_dialog (ShutdownDialogType.RESTART);
                return true;
            }
            break;
        }

        return base.key_press_event (event);
    }

    public void set_keyboard_state ()
    {
        menubar.set_keyboard_state ();
    }

    public void show_shutdown_dialog (ShutdownDialogType type)
    {
        if (shutdown_dialog != null)
            shutdown_dialog.destroy ();

        /* Stop input to login box */
        login_box.sensitive = false;

        shutdown_dialog = new ShutdownDialog (type, background);
        shutdown_dialog.closed.connect (close_shutdown_dialog);
        background.add (shutdown_dialog);
        move_to_monitor (active_monitor);
        shutdown_dialog.visible = true;
    }

    public void close_shutdown_dialog ()
    {
        if (shutdown_dialog == null)
            return;

        shutdown_dialog.destroy ();
        shutdown_dialog = null;

        login_box.sensitive = true;
    }

    /* see GREETER_FPRINT_DEMO above.
     *
     * The demo deliberately feeds the *real* English strings pam_fprintd
     * sends through the *real* classifier, so what it shows on screen is what
     * a live reader produces - translation included - and not a hand-written
     * imitation of it. */
    private void start_fingerprint_demo ()
    {
        string[] script = {
            "Place your right thumb on the fingerprint reader",
            "Failed to match fingerprint",
            "Swipe was too short, try again",
            "__password__",
            "__success__"
        };

        var step = 0;
        Timeout.add (2200, () => {
            var line = script[step];
            step = (step + 1) % script.length;

            if (line == "__password__")
            {
                fingerprint_panel.show_password_fallback (
                    _("Please use your password"));
                return Source.CONTINUE;
            }

            if (line == "__success__")
            {
                fingerprint_panel.show_success (_("Fingerprint recognised"));
                return Source.CONTINUE;
            }

            FingerprintMessageKind kind;
            string display;
            if (FingerprintMessages.classify (line, out kind, out display))
            {
                if (kind == FingerprintMessageKind.FAILURE)
                {
                    fingerprint_panel.show_failure (display);

                    /* Reproduce what the reader really does: the retry message
                     * follows the failure almost immediately. It must not eat
                     * the red flash. */
                    Timeout.add (120, () => {
                        FingerprintMessageKind k2;
                        string d2;
                        if (FingerprintMessages.classify (
                                "Place your finger on the reader again", out k2, out d2))
                            fingerprint_panel.show_waiting (d2);
                        return Source.REMOVE;
                    });
                }
                else
                {
                    fingerprint_panel.show_waiting (display);
                }
            }

            return Source.CONTINUE;
        });
    }

    /* see GREETER_FPRINT_RENDER above. */
    private void render_frame (string dir, string name)
    {
        /* Let the state change reach the widgets first: the glow travels from
         * the panel to the selected name through a signal and a CSS provider,
         * and a prompt adds a row to the box. None of that has happened yet at
         * the moment the state is set. */
        while (Gtk.events_pending ())
            Gtk.main_iteration_do (false);

        var w = get_allocated_width ();
        var h = get_allocated_height ();
        if (w < 1 || h < 1)
        {
            warning ("render: window not allocated yet, skipping %s", name);
            return;
        }

        var surface = new Cairo.ImageSurface (Cairo.Format.RGB24, w, h);
        var cr = new Cairo.Context (surface);

        /* Emitting "draw" with a plain Cairo context rather than calling
         * gtk_widget_draw: gtk_cairo_should_draw_window() lets every child
         * through when the context did not come from GDK, which is exactly
         * what an offscreen snapshot of the whole hierarchy needs. */
        draw (cr);

        var path = Path.build_filename (dir, name + ".png");
        if (surface.write_to_png (path) != Cairo.Status.SUCCESS)
            warning ("render: could not write %s", path);
        else
            debug ("render: wrote %s (%dx%d)", path, w, h);
    }

    private string classified (string pam_line)
    {
        FingerprintMessageKind kind;
        string display;
        if (FingerprintMessages.classify (pam_line, out kind, out display))
            return display;
        return pam_line;
    }

    private void start_fingerprint_render (string dir)
    {
        if (DirUtils.create_with_parents (dir, 0755) != 0)
        {
            warning ("render: cannot create %s", dir);
            return;
        }

        /* One step per state, spaced just past FLASH_MS. set_state() gives a
         * flash the panel for its full duration and queues whatever arrives
         * meanwhile, so a faster walk silently rendered the red frame twice:
         * the green was still sitting in that queue. Each state is captured
         * immediately after it is set, while its own flash is lit. The GIF
         * takes its durations from the code, not from this timer. */
        var step = 0;
        Timeout.add (FingerprintPanel.FLASH_MS + 200, () => {
            switch (step)
            {
            case 0:
                /* Skipped: the first tick only gives the window its size. */
                break;

            case 1:
                fingerprint_panel.show_waiting (
                    classified ("Place your finger on the reader"));
                render_frame (dir, "1-waiting");
                break;

            case 2:
                fingerprint_panel.show_failure (
                    classified ("Failed to match fingerprint"));
                render_frame (dir, "2-failed");
                break;

            case 3:
                fingerprint_panel.show_success (_("Fingerprint recognised"));
                render_frame (dir, "3-success");
                break;

            case 4:
                /* The password row is not ours to fake: emit the prompt on the
                 * same signal LightDM uses, so the box grows its row exactly as
                 * it does when pam_fprintd has run out of tries. The trailing
                 * space matters - GreeterList.show_prompt_cb() matches PAM's
                 * literal "Password: " to know what to translate, and without
                 * it the field keeps the untranslated English.
                 *
                 * That handler also raises the sign itself, but only when
                 * fingerprint_active is set, and that flag belongs to the
                 * message routing this walk bypasses by driving the panel
                 * directly. Hence the explicit call below. */
                SlickGreeter.singleton.show_prompt ("Password: ", LightDM.PromptType.SECRET);
                fingerprint_panel.show_password_fallback (
                    _("Please use your password"));
                render_frame (dir, "4-password");
                break;

            default:
                Gtk.main_quit ();
                return Source.REMOVE;
            }

            step++;
            return Source.CONTINUE;
        });
    }

}
