# Fingerprint login on Linux Mint

Notes from getting this working on Mint 22.3 (Cinnamon, LightDM, Ubuntu 24.04
base). None of it is caused by this fork; all of it will bite anyone trying to
use a fingerprint reader at the Mint login screen.

## Fingwit gates the login screen, and reads the setting as root

Mint ships `libpam-fingwit`, whose `pam-auth-update` profile puts a gate in
front of `pam_fprintd`:

```
auth  [authinfo_unavail=1 default=ignore]  pam_fingwit.so
auth  [success=2 default=ignore]           pam_fprintd.so max-tries=3 timeout=15
auth  [success=1 default=ignore]           pam_unix.so nullok try_first_pass
```

`pam_fingwit.so` is a thin wrapper around `/usr/lib/*/fingwit/pam_fingwit.py`,
which decides:

```python
if user_has_session(user):
    return PAM.PAM_IGNORE                    # short-circuits, gate skipped
if is_login_session():                       # PAM_SERVICE in lightdm/gdm/login/...
    if not settings.get_boolean("login-enabled"):
        return PAM.PAM_AUTHINFO_UNAVAIL      # authinfo_unavail=1 jumps over pam_fprintd
    if has_encrypted_home(user):
        return PAM.PAM_AUTHINFO_UNAVAIL
```

`org.x.fingwit login-enabled` defaults to false, and Fingwit's own GUI has no
toggle for it — the whole system references that schema in three places
(`gschema.xml`, `pam_fingwit.py`, `/usr/bin/fingwit`) and none of them writes
the key. Mint's reason for the default is the problem this fork exists to solve:
a fingerprint login leaves the keyring locked.

**Two traps when testing this.**

*Logging out and back in is not a test.* `user_has_session()` short-circuits
ahead of the gate, and after a logout logind regularly still has a session for
the user, so fingerprint is offered. After a real reboot there is no session,
the gate applies, and the password prompt is back. Only a reboot tests the real
path.

*Setting the key as yourself does nothing.* The module runs as **root** inside
the display manager's PAM process, so `Gio.Settings` resolves root's backend,
not yours. On the machine this was found on, the user's GSettings were
keyfile-backed (`~/.config/glib-2.0/settings/keyfile`, which GLib prefers once
it exists) while root's were dconf-backed. The exact code path, run as root, is
the only reliable check:

```bash
sudo -H python3 -c "import gi; gi.require_version('Gio','2.0'); \
  from gi.repository import Gio; \
  print(Gio.Settings(schema_id='org.x.fingwit').get_boolean('login-enabled'))"
```

Fix, verified across a reboot:

```bash
sudo -H dconf write /org/x/fingwit/login-enabled true
```

The alternative is `sudo pam-auth-update`, switching from the `fingwit` profile
to the plain `fprintd` one, which removes the gate from `common-auth` entirely.
Cleaner in the long run, but it edits a login-critical file.

## The reader's prompt stays English at the login screen

`nm -D … | grep -c setlocale`:

| Binary | setlocale | Consequence |
|---|---|---|
| `pam_fprintd.so` | 0 | relies on its host process |
| `lightdm` | 0 | the PAM stack runs here, so the msgid comes through untranslated |
| `sudo` | 1 | the same prompt *is* German in a terminal |
| the greeter | 1 | irrelevant: it only displays the finished string |

The text is produced in `lightdm`, which never sets a locale. Neither an
`fprintd` message catalogue nor a `LANG` drop-in for `lightdm.service` can
change that. This fork translates the messages itself, which is why it works.

## Waiting longer for a finger

`pam_fprintd`'s `timeout=` is the wait before PAM falls through to the password.
Its minimum is 10 seconds; there is no documented maximum.

```bash
sudo cp /etc/pam.d/common-auth /etc/pam.d/common-auth.bak-$(date +%Y%m%d%H%M%S)
sudo sed -i '/pam_fprintd\.so/ s/timeout=[0-9]*/timeout=120/' /etc/pam.d/common-auth
sudo sed -i '/pam_fprintd\.so/ s/timeout=[0-9]*/timeout=120/' /usr/share/pam-configs/fingwit
```

The second line keeps a future `pam-auth-update` from reverting the first.

Note the trade-off: PAM is serial — `pam_fprintd`'s own man page says
fingerprint and password cannot both be live at once — so a long timeout also
means waiting that long before you can type instead. Escape cancels and
restarts the conversation.
