# Forum post (Fedora Discussion, Reddit r/Fedora, GNOME Discourse)

**Title:** Fedora 44: Google Drive "Files" missing from Online Accounts – why, and a workaround

After upgrading to Fedora 44, the Google account in **Settings → Online Accounts** only offers
Mail, Calendar and Contacts – the **Files** switch is gone (while Microsoft 365 still has it). On
Debian 13 or Fedora 43 it may still be there.

**It's not your setup.** GNOME 50 dropped Google Drive from gvfs because it depended on `libgdata`,
which has been unmaintained for ~4 years and is now archived. Fedora followed on 2026-02-18 (`gvfs`
changelog: *"Drop support for unmaintained libgdata"*); Ubuntu 26.04 is affected too. Quick check:
`/usr/libexec/gvfsd-onedrive` exists, `gvfsd-google` doesn't.

**Will it come back?** Likely: [GNOME/gvfs!323 "Re-implement Google Drive support"](https://gitlab.gnome.org/GNOME/gvfs/-/merge_requests/323)
is under review, milestone **GNOME 52** – so not Fedora 45 (GNOME 51), maybe Fedora 46 (spring 2027).

**Meanwhile** I wrote a small tool, [gdrive-fedora-mount](https://github.com/olosip/gdrive-fedora-mount),
based on **rclone** (in the official Fedora repos), which doesn't replace any system package:

- mounts Google Drive at `~/GoogleDrive`, shown as a volume in Files (Nautilus);
- follows your Google account in Online Accounts: mounts only while the account exists, unmounts
  and clears the cache when you remove it;
- uninstalls cleanly (`gdrive-fedora-mount uninstall`).

```bash
sudo dnf install rclone
git clone https://github.com/olosip/gdrive-fedora-mount.git && cd gdrive-fedora-mount
./install.sh
gdrive-fedora-mount setup     # Google authorization in the browser
gdrive-fedora-mount enable
```

Caveats: the **Files** switch in Online Accounts won't reappear (only the gvfs backend can provide
it), and rclone's shared Google client_id is being retired – create your own
([rclone guide](https://rclone.org/drive/#making-your-own-client-id)) and set it with
`gdrive-fedora-mount set-client`. The tool's messages are in Italian for now; the README is in
English.

If you want native integration today, the MR author has an
[experimental COPR](https://discussion.fedoraproject.org/t/call-for-testers-restoring-google-drive-integration-in-gnome/189348)
(replaces gvfs, gnome-online-accounts and gnome-control-center – take a snapshot first). Testing it
and giving feedback helps get the patch merged upstream.
