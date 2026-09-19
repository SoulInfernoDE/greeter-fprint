icon_files = [
    'a11y.svg',
    'active.png',
    'arrow_left.svg',
    'arrow_right.svg',
    'battery.svg',
    'battery_10.svg',
    'battery_25.svg',
    'battery_50.svg',
    'dialog_close.svg',
    'dialog_close_highlight.svg',
    'dialog_close_press.svg',
    'hibernate_highlight.svg',
    'hibernate.svg',
    'keyboard.svg',
    'message.png',
    'remote_login_help.png',
    'restart_highlight.svg',
    'restart.svg',
    'shadow.png',
    'shutdown_highlight.svg',
    'shutdown_dialog.svg',
    'shutdown.svg',
    'suspend_highlight.svg',
    'suspend.svg',
    'tux-fprint.svg',
    'switcher_corner.png',
    'switcher_left.png',
    'switcher_top.png',
]

install_data(
    icon_files,
    install_dir: pkgdatadir,
)

install_data(
    [
        'sounds/fingerprint-success.oga',
        'sounds/fingerprint-failure.oga',
        'sounds/fingerprint-password.oga',
    ],
    install_dir: pkgdatadir / 'sounds',
)

install_data(
    [
        'sounds/login-screen/fingerprint-success.oga',
        'sounds/login-screen/fingerprint-failure.oga',
        'sounds/login-screen/fingerprint-password.oga',
    ],
    install_dir: pkgdatadir / 'sounds' / 'login-screen',
)

install_data(
    'x.dm.slick-greeter.gschema.xml',
    install_dir: datadir / 'glib-2.0' / 'schemas',
)

# The greeter's own session file is files/usr/share/xgreeters/greeter-fprint.desktop.
# slick-greeter.desktop is deliberately NOT installed: it belongs to the
# upstream package, and that package is the fallback greeter if this one ever
# fails to start. A fork has no business overwriting its own escape hatch.

man_files = [
    'slick-greeter-set-keyboard-layout.1',
    'slick-greeter-check-hidpi.1',
    'slick-greeter-enable-tap-to-click.1',
    'greeter-fprint.8',
]

install_man(man_files)

# The session companion: plays the panel's sounds for fingerprint prompts in
# the user's own session - sudo in a terminal, authentication dialogs - by
# listening to fprintd on the system bus. See src/session_sounds.py.
session_sounds_desktop = configure_file(
    input: 'greeter-fprint-session-sounds.desktop.in.in',
    output: 'greeter-fprint-session-sounds.desktop.in',
    configuration: {'LIBEXECDIR': prefix / get_option('libexecdir')},
)

i18n.merge_file(
    input: session_sounds_desktop,
    output: 'greeter-fprint-session-sounds.desktop',
    type: 'desktop',
    po_dir: meson.source_root() / 'po',
    install: true,
    install_dir: get_option('sysconfdir') / 'xdg' / 'autostart',
)

