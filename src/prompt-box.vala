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

public class PromptBox : FadableBox
{
    public signal void respond (string[] response);
    public signal void login ();
    public signal void show_options ();
    public signal void name_clicked ();

    public bool has_errors { get; set; default = false; }
    public string id { get; construct; }

    public string label
    {
        get { return name_label.label; }
        set
        {
            name_label.label = value;
            small_name_label.label = value;
        }
    }

    public double position { get; set; default = 0; }

    private Gtk.Fixed fixed;
    private Gtk.Widget zone; /* when overlapping zone we are fully expanded */

    /* Expanded widgets */
    protected Gtk.Grid box_grid;
    protected Gtk.Grid name_grid;
    private ActiveIndicator active_indicator;
    protected FadingLabel name_label;
    private Gtk.CssProvider? name_style = null;

    /* The wide part of the glow is painted, not shadowed: GTK clips a label's
     * text-shadow to the label, and the clip lands around 30px out - measured,
     * a hard cut to zero rather than a falloff. Padding the label does not
     * move it. So the bloom is drawn into the box behind the name instead,
     * where nothing clips it until the box edge, and the CSS shadow is left to
     * do what it is good at: the tight core right at the glyphs. */
    private bool glow_on = false;
    private double glow_r = 0.0;
    private double glow_g = 0.0;
    private double glow_b = 0.0;

    private void parse_glow (string channels)
    {
        glow_on = false;

        if (channels == "")
            return;

        var parts = channels.split (",");
        if (parts.length != 3)
            return;

        glow_r = int.parse (parts[0].strip ()) / 255.0;
        glow_g = int.parse (parts[1].strip ()) / 255.0;
        glow_b = int.parse (parts[2].strip ()) / 255.0;
        glow_on = true;
    }

    /* Reach of the painted bloom. 36px is one centimetre on a 96dpi screen,
     * which is what was asked for; the box is 112px tall, so it fits. */
    private const double GLOW_REACH = 36.0;

    protected FlatButton option_button;
    private CachedImage option_image;
    private CachedImage message_image;
    private UserAvatar avatar_image;

    /* Condensed widgets */
    protected Gtk.Widget small_box_widget;
    private ActiveIndicator small_active_indicator;
    protected FadingLabel small_name_label;
    private CachedImage small_message_image;
    private UserAvatar small_avatar_image;

    private const string CHIP_CSS =
        "grid { background-color: rgba(0, 0, 0, 0.42);"
                + " border: 1px solid rgba(255, 255, 255, 0.13);"
                + " border-radius: 9px; margin: 3px 0px; padding: 0px 12px; }";
    private const string NAME_SHADOW_CSS =
        "label { text-shadow: 0px 1px 3px rgba(0, 0, 0, 0.85); }";

    protected const int COL_ACTIVE        = 0;
    protected const int COL_CONTENT       = 1;
    protected const int COL_SPACER        = 2;

    protected const int ROW_NAME          = 0;
    protected const int COL_AVATAR        = 0;
    protected const int COL_NAME_LABEL    = 1;
    protected const int COL_NAME_MESSAGE  = 2;
    protected const int COL_NAME_OPTIONS  = 3;

    protected const int COL_ENTRIES_START = 1;
    protected const int COL_ENTRIES_END   = 1;
    protected const int COL_ENTRIES_WIDTH = 1;

    protected int start_row;
    protected int last_row;

    private enum PromptVisibility
    {
        HIDDEN,
        FADING,
        SHOWN,
    }
    private PromptVisibility prompt_visibility = PromptVisibility.HIDDEN;

    public PromptBox (string id)
    {
        Object (id: id);
    }

    construct
    {
        // Hack to avoid gtk 3.20's new allocate logic, which messes us up.
        resize_mode = Gtk.ResizeMode.QUEUE;

        set_start_row ();
        reset_last_row ();
        expand = true;

        fixed = new Gtk.Fixed ();
        fixed.show ();
        add (fixed);

        box_grid = new Gtk.Grid ();
        box_grid.column_spacing = 4;
        box_grid.row_spacing = 3;
        box_grid.margin_top = GreeterList.BORDER;
        box_grid.margin_bottom = 4;
        box_grid.expand = true;

        /** Grid layout:
          0 1     2      3 4
          > [A]   M      S <
            Name........
            Message.....
            Entry.......
            
          Where:
          > = Active indicator
          [A] = Avatar
          M = Message icon
          S = Session options
          < = Spacing indicator
         */

        active_indicator = new ActiveIndicator ();
        /* Centred on the whole box, not on its first row. Upstream pinned it
         * to the top of the name row with a margin that centres it within one
         * grid row - fine when the box was one row tall, but the box grows a
         * row for the password prompt and the marker then sat up at the
         * corner. It spans every row instead now; see update_active_span,
         * which re-attaches it whenever a row is added or cleared. */
        active_indicator.valign = Gtk.Align.CENTER;
        active_indicator.show ();
        box_grid.attach (active_indicator, COL_ACTIVE, last_row, 1, 1);

        /* Add a second one on right just for equal-spacing purposes */
        var dummy_indicator = new ActiveIndicator ();
        dummy_indicator.show ();
        box_grid.attach (dummy_indicator, COL_SPACER, last_row, 1, 1);

        box_grid.show ();

        /* Create fully expanded version of ourselves */
        name_grid = create_name_grid ();
        box_grid.attach (name_grid, COL_CONTENT, last_row, 1, 1);

        /* Now prep small versions of the above normal widgets.  These are
         * used when scrolling outside of the main dash box. */
        var small_box_grid = new Gtk.Grid ();
        small_box_grid.column_spacing = 4;
        small_box_grid.row_spacing = 6;
        small_box_grid.hexpand = true;
        small_box_grid.show ();

        small_active_indicator = new ActiveIndicator ();
        small_active_indicator.valign = Gtk.Align.START;
        small_active_indicator.margin_top = (grid_size - ActiveIndicator.HEIGHT) / 2;
        small_active_indicator.show ();
        small_box_grid.attach (small_active_indicator, 0, 0, 1, 1);

        var small_name_grid = create_small_name_grid ();
        small_box_grid.attach (small_name_grid, 1, 0, 1, 1);

        /* Add a second indicator on right just for equal-spacing purposes */
        var small_dummy_indicator = new ActiveIndicator ();
        small_dummy_indicator.show ();
        small_box_grid.attach (small_dummy_indicator, 3, 0, 1, 1);

        var small_box_eventbox = new Gtk.EventBox ();
        small_box_eventbox.visible_window = false;
        small_box_eventbox.button_release_event.connect (() =>
        {
            name_clicked ();
            return true;
        });
        small_box_eventbox.add (small_box_grid);
        small_box_eventbox.show ();
        small_box_widget = small_box_eventbox;

        fixed.add (small_box_widget);
        fixed.add (box_grid);

        // Connect the notify::position signal to handle visibility
        notify["position"].connect(update_visibility);
    }

    private void update_visibility()
    {
        // If we are in the main zone (position close to 0)
        if (position >= -0.1 && position <= 0.1) {
            box_grid.opacity = 1.0;
            small_box_widget.opacity = 0.0;
            box_grid.visible = true;
            small_box_widget.visible = false;
        }
        // If we are outside the main zone
        else {
            box_grid.opacity = 0.0;
            small_box_widget.opacity = 1.0;
            box_grid.visible = false;
            small_box_widget.visible = true;
        }
    }

    protected virtual Gtk.Grid create_name_grid ()
    {
        var name_grid = new Gtk.Grid ();
        name_grid.column_spacing = 4;
        name_grid.hexpand = true;

        avatar_image = new UserAvatar();
        avatar_image.valign = Gtk.Align.START;
        avatar_image.halign = Gtk.Align.START;
        avatar_image.margin_top = (ActiveIndicator.WIDTH + box_grid.column_spacing) - ActiveIndicator.MARGIN;
        avatar_image.show();
        name_grid.attach (avatar_image, COL_AVATAR, ROW_NAME, 1, 1);

        name_label = new FadingLabel ("");
        name_label.override_font (Pango.FontDescription.from_string ("Ubuntu Medium 13"));
        name_label.override_color (Gtk.StateFlags.NORMAL, { 1.0f, 1.0f, 1.0f, 1.0f });
        style_name_shadow (name_label);
        /* Centred in its own column rather than pinned left: the name is the
         * label of the box the user is picking, so it belongs in the middle of
         * it. hexpand makes the column take the space left over by the avatar
         * and the option button, xalign then centres the text inside it. */
        name_label.halign = Gtk.Align.FILL;
        name_label.hexpand = true;
        name_label.xalign = 0.5f;
        /* Centred on both axes, not just horizontally. The avatar sets this
         * row's height, and with valign START (plus a top margin) the name sat
         * against the avatar's top edge - centred left-to-right but visibly
         * "up there". yalign matters as well as valign: the label is stretched
         * to the row height by FILL, so the text needs centring inside it. */
        name_label.valign = Gtk.Align.FILL;
        name_label.yalign = 0.5f;
        name_label.vexpand = false;
        name_label.margin_left = 2;
        name_label.set_size_request (-1, grid_size);
        name_label.show ();
        name_grid.attach (name_label, COL_NAME_LABEL, ROW_NAME, 1, 1);

        message_image = new CachedImage (null);
        message_image.set_from_icon_name("mail-unread", Gtk.IconSize.BUTTON);
        message_image.valign = Gtk.Align.CENTER;
        message_image.halign = Gtk.Align.CENTER;

        var align = new Gtk.Alignment (0.5f, 0.5f, 0.0f, 0.0f);
        align.valign = Gtk.Align.START;
        align.set_size_request (-1, grid_size);
        align.add (message_image);
        align.show ();
        name_grid.attach (align, COL_NAME_MESSAGE, ROW_NAME, 1, 1);

        option_button = new FlatButton ();
        option_button.get_style_context ().add_class ("option-button");
        /* Not hexpand: the free space in this row belongs to the name column,
         * so the name can sit in the middle of the box. With both columns
         * expanding, GTK split the slack between them and the name centred
         * inside a half-width column - which looked left-aligned. The button
         * still ends up hard right, because the name column now pushes it
         * there. */
        option_button.hexpand = false;
        option_button.vexpand = true;
        option_button.halign = Gtk.Align.END;
        option_button.valign = Gtk.Align.START;
        // Keep as much space on top as on the right
        option_button.margin_top = (ActiveIndicator.WIDTH + box_grid.column_spacing) - ActiveIndicator.MARGIN;
        Gtk.button_set_focus_on_click (option_button, false);
        option_button.relief = Gtk.ReliefStyle.NONE;
        option_button.get_accessible ().set_name (_("Session Options"));
        option_button.clicked.connect (option_button_clicked_cb);
        option_image = new CachedImage (null);
        option_image.show ();

        option_button.add (option_image);
        name_grid.attach (option_button, COL_NAME_OPTIONS, ROW_NAME, 1, 1);

        name_grid.show ();

        return name_grid;
    }

    /* The collapsed entries are bare text over whatever wallpaper the user
     * picked, which makes them exactly as readable as that wallpaper allows.
     * They get a chip instead: the same rounded, dark, translucent language the
     * selected entry already speaks through its DashBox, only quieter - so the
     * list reads as "one of these is open, the others are waiting" rather than
     * as text floating on a photo. */
    private void style_as_chip (Gtk.Widget widget)
    {
        try
        {
            var css = new Gtk.CssProvider ();
            css.load_from_data (CHIP_CSS, -1);
            widget.get_style_context ().add_provider (
                css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            warning ("greeter-fprint: could not style the entry chip: %s", e.message);
        }
    }

    /* A soft shadow under the name, for the same reason the chip exists: white
     * on a bright photograph is not white enough. On the label rather than the
     * chip, so it also helps the selected entry, which has no chip.
     *
     * One provider per label, not one per effect: the glow below writes into
     * the same text-shadow property, and two providers at the same priority
     * would just fight over it. */
    private void style_name_shadow (Gtk.Widget widget)
    {
        var css = new Gtk.CssProvider ();
        widget.get_style_context ().add_provider (
            css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        if (widget == name_label)
            name_style = css;

        apply_name_shadow (css, "");
    }

    private void apply_name_shadow (Gtk.CssProvider css, string glow_rgba)
    {
        /* Four layers: the dark shadow that keeps the glyphs legible, a tight
         * core, a mid bloom, and a wide one at a third of the opacity. The
         * spread is what makes it read as light coming off the name rather
         * than an outline around it, and the falling alpha is what keeps the
         * wide layer from turning into a smudge.
         *
         * Sized against a real background, not a test one: a single 11px
         * shadow moved the warmth beside the glyphs by 0.1 units on Mint's
         * default wallpaper, which is to say not at all. */
        var shadow = glow_rgba == ""
            ? NAME_SHADOW_CSS
            : ("label { text-shadow: 0px 1px 3px rgba(0, 0, 0, 0.85),"
               + " 0px 0px 7px rgba(%s, 0.95),"
               + " 0px 0px 16px rgba(%s, 0.60); }").printf (glow_rgba, glow_rgba);

        try
        {
            css.load_from_data (shadow, -1);
        }
        catch (Error e)
        {
            warning ("greeter-fprint: could not style the name label: %s", e.message);
        }
    }

    /* Called by GreeterList when the fingerprint panel changes state: the
     * selected user's name takes the same colour the logo is glowing in. An
     * empty string clears it, leaving the plain shadow. */
    public void set_name_glow (string glow_rgba)
    {
        parse_glow (glow_rgba);
        queue_draw ();

        if (name_style == null)
            return;

        apply_name_shadow (name_style, glow_rgba);
        name_label.invalidate_cache ();
    }

    protected virtual Gtk.Grid create_small_name_grid ()
    {
        var small_name_grid = new Gtk.Grid ();
        small_name_grid.column_spacing = 4;
        style_as_chip (small_name_grid);

        small_avatar_image = new UserAvatar();
        small_avatar_image.is_small = true;
        small_avatar_image.valign = Gtk.Align.CENTER;
        small_avatar_image.show();
        small_name_grid.attach (small_avatar_image, 0, 0, 1, 1);

        small_name_label = new FadingLabel ("");
        small_name_label.override_font (Pango.FontDescription.from_string ("Ubuntu Medium 13"));
        small_name_label.override_color (Gtk.StateFlags.NORMAL, { 1.0f, 1.0f, 1.0f, 1.0f });
        style_name_shadow (small_name_label);
        small_name_label.valign = Gtk.Align.CENTER;
        small_name_label.yalign = 0.5f;
        small_name_label.xalign = 0.5f;
        small_name_label.hexpand = true;
        small_name_label.margin_left = 2;
        small_name_label.set_size_request (-1, grid_size);
        small_name_label.show ();
        small_name_grid.attach (small_name_label, 1, 0, 1, 1);

        small_message_image = new CachedImage (null);
        small_message_image.set_from_icon_name("mail-unread", Gtk.IconSize.BUTTON);

        var align = new Gtk.Alignment (0.5f, 0.5f, 0.0f, 0.0f);
        align.set_size_request (-1, grid_size);
        align.add (small_message_image);
        align.show ();
        small_name_grid.attach (align, 2, 0, 1, 1);

        small_name_grid.show ();
        return small_name_grid;
    }

    protected virtual void set_start_row ()
    {
        start_row = 0;
    }

    protected virtual void reset_last_row ()
    {
        last_row = start_row;
    }

#if HAVE_GTK_3_20_0
    private int round_to_grid (int size)
    {
        var num_grids = size / grid_size;
        var remainder = size % grid_size;
        if (remainder > 0)
            num_grids += 1;
        num_grids = int.max (num_grids, 3);
        return num_grids * grid_size;
    }

    public override void get_preferred_height (out int min, out int nat)
    {
        base.get_preferred_height (out min, out nat);
        min = round_to_grid (min + GreeterList.BORDER * 2) - GreeterList.BORDER * 2;
        nat = round_to_grid (nat + GreeterList.BORDER * 2) - GreeterList.BORDER * 2;

        if (position <= -1 || position >= 1)
            min = nat = grid_size;
    }
#endif

    public void set_zone (Gtk.Widget zone)
    {
        this.zone = zone;
        queue_draw ();
    }

    public void set_options_image (Gdk.Pixbuf? image, string? tooltip)
    {
        if (option_button == null)
            return;

        option_image.set_pixbuf (image);

        if (tooltip == null)
            option_image.set_tooltip_text("");
        else
            option_image.set_tooltip_text(tooltip);

        if (image == null)
            option_button.hide ();
        else
            option_button.show ();
    }

    private void option_button_clicked_cb (Gtk.Button button)
    {
        show_options ();
    }

    public void set_show_message_icon (bool show)
    {
        message_image.visible = show;
        small_message_image.visible = show;
    }

    public void set_is_active (bool active)
    {
        active_indicator.active = active;
        small_active_indicator.active = active;
    }

    protected void foreach_prompt_widget (Gtk.Callback cb)
    {
        var prompt_widgets = new List<Gtk.Widget> ();

        var i = start_row + 1;
        while (i <= last_row)
        {
            var c = box_grid.get_child_at (COL_ENTRIES_START, i);
            if (c != null) /* c might have been deleted from selective clear */
                prompt_widgets.append (c);
            i++;
        }

        foreach (var w in prompt_widgets)
            cb (w);
    }

    public void clear ()
    {
        prompt_visibility = PromptVisibility.HIDDEN;

        /* Hold a ref while removing the prompt widgets -
         * if we just do w.destroy() we get this warning:
         * CRITICAL: pango_layout_get_cursor_pos: assertion 'index >= 0 && index <= layout->length' failed
         * by GtkWidget's screen-changed signal being called on
         * widget when we destroy it.
         */
        foreach_prompt_widget ((w) => {
#if HAVE_GTK_3_20_0
            w.ref ();
            w.get_parent().remove(w);
            w.unref ();
#else
            w.destroy ();
#endif
        });

        reset_last_row ();
        update_active_span ();
        has_errors = false;
    }

    /* Clears error messages */
    public void reset_messages ()
    {
        has_errors = false;
        foreach_prompt_widget ((w) =>
        {
            var is_error = w.get_data<bool> ("prompt-box-is-error");
            if (is_error)
                w.destroy ();
        });
    }

    /* Stops spinners */
    public void reset_spinners ()
    {
        foreach_prompt_widget ((w) =>
        {
            if (w is DashEntry)
            {
                var e = w as DashEntry;
                e.did_respond = false;
            }
        });
    }

    /* Clears error messages and stops spinners.  Basically gets the box back to a filled-by-user-but-no-status state. */
    public void reset_state ()
    {
        reset_messages ();
        reset_spinners ();
    }

    public virtual void add_static_prompts ()
    {
        /* Subclasses may want to add prompts that are always present here */
    }

    private void update_prompt_visibility (Gtk.Widget w)
    {
        switch (prompt_visibility)
        {
        case PromptVisibility.HIDDEN:
            w.hide ();
            break;
        case PromptVisibility.FADING:
            var f = w as Fadable;
            w.sensitive = true;
            if (f != null)
                f.fade_in ();
            else
                w.show ();
            break;
        case PromptVisibility.SHOWN:
            w.show ();
            w.sensitive = true;
            break;
        }
    }

    public void fade_in_prompts ()
    {
        prompt_visibility = PromptVisibility.FADING;
        show ();
        foreach_prompt_widget ((w) => { update_prompt_visibility (w); });
    }

    public void show_prompts ()
    {
        prompt_visibility = PromptVisibility.SHOWN;
        show ();
        foreach_prompt_widget ((w) => { update_prompt_visibility (w); });
    }

    /* Keeps the active marker spanning the full height of the box, so it stays
     * centred on it as rows come and go. */
    protected void update_active_span ()
    {
        if (active_indicator == null || active_indicator.get_parent () != box_grid)
            return;

        var rows = last_row - start_row + 1;
        if (rows < 1)
            rows = 1;

        box_grid.remove (active_indicator);
        box_grid.attach (active_indicator, COL_ACTIVE, start_row, 1, rows);
    }

    protected void attach_item (Gtk.Widget w, bool add_style_class = true)
    {
        w.set_data ("prompt-box-widget", this);
        if (add_style_class)
            SlickGreeter.add_style_class (w);

        last_row += 1;
        box_grid.attach (w, COL_ENTRIES_START, last_row, COL_ENTRIES_WIDTH, 1);
        update_active_span ();

        update_prompt_visibility (w);
        queue_resize ();
    }

    public void add_message (string text, bool is_error)
    {
        var label = new FadingLabel (text);

        label.override_font (Pango.FontDescription.from_string ("Ubuntu Bold 10"));

        Gdk.RGBA color = { 1.0f, 1.0f, 1.0f, 1.0f };
        if (is_error)
            color.parse ("#ffd64d");
        label.override_color (Gtk.StateFlags.NORMAL, color);

        label.xalign = 0.0f;
        label.set_data<bool> ("prompt-box-is-error", is_error);

        attach_item (label);

        if (is_error)
            has_errors = true;
    }

    public DashEntry add_prompt (string text, string? accessible_text, bool is_secret)
    {
        /* Stop other entry's arrows/spinners from showing */
        foreach_prompt_widget ((w) =>
        {
            if (w is DashEntry)
            {
                var e = w as DashEntry;
                if (e != null)
                    e.can_respond = false;
            }
        });

        var entry = new DashEntry ();
        entry.sensitive = false;

        if (text.contains ("\n"))
        {
            add_message (text, false);
            entry.constant_placeholder_text = "";
        }
        else
        {
            /* Strip trailing colon if present (also handle CJK version) */
            var placeholder = text;
            if (placeholder.has_suffix (":") || placeholder.has_suffix ("："))
            {
                var len = placeholder.char_count ();
                placeholder = placeholder.substring (0, placeholder.index_of_nth_char (len - 1));
            }
            entry.constant_placeholder_text = placeholder;
        }

        var accessible = entry.get_accessible ();
        if (accessible_text != null)
            accessible.set_name (accessible_text);
        else
            accessible.set_name (text);

        if (is_secret)
        {
            entry.visibility = false;
            entry.caps_lock_warning = true;
            entry.button_release_event.connect ((widget, event) => {
                if (event.button == 1)
                    show_toggle_visibility_icon (entry);
                return false;
            });
            entry.key_press_event.connect ((widget, event) => {
                switch (event.keyval) {
                    case Gdk.Key.Left:
                    case Gdk.Key.KP_Left:
                    case Gdk.Key.Right:
                    case Gdk.Key.KP_Right:
                        show_toggle_visibility_icon (entry);
                        return false;
                    case Gdk.Key.F8:
                        if (Gdk.ModifierType.MOD1_MASK in event.state) {
                            entry.set_visibility (!entry.get_visibility ());
                            show_toggle_visibility_icon (entry);
                            return true;
                        }
                        break;
                }
                return base.key_press_event (event);
            });
            entry.icon_press.connect(entry_icon_press_cb);
        }

        entry.respond.connect (entry_activate_cb);

        attach_item (entry);

        return entry;
    }

    public void show_toggle_visibility_icon (Gtk.Entry entry)
    {
        if (entry.get_visibility ()) {
            entry.set_icon_from_icon_name(Gtk.EntryIconPosition.PRIMARY, "xsi-view-conceal-symbolic");
        }
        else {
            entry.set_icon_from_icon_name(Gtk.EntryIconPosition.PRIMARY, "xsi-view-reveal-symbolic");
        }
    }

    public void entry_icon_press_cb (Gtk.Entry entry, Gtk.EntryIconPosition position, Gdk.Event event)
    {
        entry.set_visibility (!entry.get_visibility ());
        show_toggle_visibility_icon (entry);
    }

    public Gtk.ComboBox add_combo (GenericArray<string> texts, bool read_only)
    {
        Gtk.ComboBoxText combo;
        if (read_only)
            combo = new Gtk.ComboBoxText ();
        else
            combo = new Gtk.ComboBoxText.with_entry ();

        combo.get_style_context ().add_class ("lightdm-combo");
        combo.get_child ().get_style_context ().add_class ("lightdm-combo");
        combo.get_child ().override_font (Pango.FontDescription.from_string (DashEntry.font));

        attach_item (combo, false);

        texts.foreach ((text) => { combo.append_text (text); });

        if (texts.length > 0)
            combo.active = 0;

        return combo;
    }

    protected void entry_activate_cb ()
    {
        var response = new string[0];

        foreach_prompt_widget ((w) =>
        {
            if (w is Gtk.Entry)
            {
                var e = w as Gtk.Entry;
                if (e != null)
                    response += e.text;
            }
        });
        respond (response);
    }

    public void add_button (string text, string? accessible_text)
    {
        var button = new DashButton (text);

        var accessible = button.get_accessible ();
        accessible.set_name (accessible_text);

        button.clicked.connect (button_clicked_cb);

        attach_item (button);
    }

    private void button_clicked_cb (Gtk.Button button)
    {
        login ();
    }

    public override void grab_focus ()
    {
        var done = false;
        Gtk.Widget best = null;
        foreach_prompt_widget ((w) =>
        {
            if (done)
                return;
            best = w; /* last entry wins, all else considered */
            var e = w as Gtk.Entry;
            var b = w as Gtk.Button;
            var c = w as Gtk.ComboBox;

            /* We've found ideal entry (first empty one), so stop looking */
            if ((e != null && e.text == "") || b != null || c != null)
                done = true;
        });
        if (best != null)
            best.grab_focus ();
    }

    public override void size_allocate (Gtk.Allocation allocation)
    {
        base.size_allocate (allocation);
        box_grid.size_allocate (allocation);

        int small_height;
        small_box_widget.get_preferred_height (null, out small_height);
        allocation.height = small_height;
        small_box_widget.size_allocate (allocation);

        update_visibility();
    }

    public override void draw_full_alpha (Cairo.Context c)
    {
        /* Draw either small or normal version of ourselves, depending on where
           our allocation put us relative to our zone */
        int x, y;
        zone.translate_coordinates (this, 0, 0, out x, out y);

        Gtk.Allocation alloc, zone_alloc;
        this.get_allocation (out alloc);
        zone.get_allocation (out zone_alloc);

        /* Draw main grid only in that area */
        c.save ();
        c.rectangle (x, y, zone_alloc.width, zone_alloc.height);
        c.clip ();
        fixed.propagate_draw (box_grid, c);
        c.restore ();

        /* Do actual drawing */
        c.save ();
        if (y > 0)
            c.rectangle (x, 0, zone_alloc.width, y);
        else
            c.rectangle (x, y + zone_alloc.height, zone_alloc.width, -y);
        c.clip ();
        fixed.propagate_draw (small_box_widget, c);
        c.restore ();
    }

    public void set_avatar_path(string? path)
    {
        if (avatar_image != null)
            avatar_image.avatar_path = path;
        if (small_avatar_image != null)
            small_avatar_image.avatar_path = path;
    }

    public void hide_avatar ()
    {
        avatar_image.hide ();
    }

    /* The wide half of the name's glow. It is painted rather than shadowed
     * because GTK clips a label's text-shadow: measured, the falloff stops
     * dead about 30px out, and padding the label does not move that edge. In
     * here nothing clips until the box itself, which is 112px tall - room
     * enough for the centimetre that was asked for. The CSS shadow keeps the
     * tight core right at the glyphs, where it belongs. */
    private void draw_name_glow (Cairo.Context c)
    {
        if (!glow_on || name_label == null || !name_label.get_mapped ())
            return;

        Gtk.Allocation mine, label;
        get_allocation (out mine);
        name_label.get_allocation (out label);

        var cx = label.x - mine.x + label.width / 2.0;
        var cy = label.y - mine.y + label.height / 2.0;

        /* Wider than tall: a name is a line of text, and a circular bloom
         * around it reads as a sun behind the word rather than the word
         * itself glowing. */
        var half_h = label.height / 2.0 + GLOW_REACH;
        var half_w = half_h * 1.45;

        c.save ();
        c.translate (cx, cy);
        c.scale (half_w / half_h, 1.0);

        var glow = new Cairo.Pattern.radial (0, 0, label.height * 0.2, 0, 0, half_h);
        glow.add_color_stop_rgba (0.0, glow_r, glow_g, glow_b, 0.50);
        glow.add_color_stop_rgba (0.45, glow_r, glow_g, glow_b, 0.20);
        glow.add_color_stop_rgba (1.0, glow_r, glow_g, glow_b, 0.0);

        c.set_source (glow);
        c.arc (0, 0, half_h, 0, 2 * Math.PI);
        c.fill ();
        c.restore ();
    }

    public override bool draw (Cairo.Context c)
    {
        draw_name_glow (c);
        return base.draw (c);
    }
}

private class ActiveIndicator : Gtk.Image
{
    public bool active { get; set; }
    public const int WIDTH = 8;
    public const int HEIGHT = 7;
    public const int MARGIN = 4;

    construct
    {
        var filename = Path.build_filename (Config.PKGDATADIR, "active.png");
        try
        {
            pixbuf = new Gdk.Pixbuf.from_file (filename);
        }
        catch (Error e)
        {
            debug ("Could not load active image: %s", e.message);
        }
        notify["active"].connect (() => { queue_draw (); });
        xalign = 0.0f;
    }

    public override void get_preferred_width (out int min, out int nat)
    {
        min = WIDTH;
        nat = min;
    }

    public override void get_preferred_height (out int min, out int nat)
    {
        min = HEIGHT;
        nat = min;
    }

    public override bool draw (Cairo.Context c)
    {
        if (!active)
            return false;
        return base.draw (c);
    }
}
