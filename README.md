# gdrive-fedora-mount

Google Drive as a regular folder on Fedora, tied to the Google account in
**Settings → Online Accounts**: it shows up as a volume in Files (Nautilus) while the account
exists, and disappears (cache cleared) when you remove it.

## Why

Since GNOME 50 (Fedora 44, Ubuntu 26.04), gvfs no longer ships its Google Drive backend: the
`libgdata` library it relied on has been unmaintained for years and is now archived. That's why,
in **Settings → Online Accounts**, the Google account no longer offers the **Files** switch
(Microsoft 365 still does).

You can check it on your system: `/usr/libexec/gvfsd-onedrive` exists, `gvfsd-google` doesn't.
Fedora's `gvfs` changelog (2026-02-18) says: *"Drop support for unmaintained libgdata"*.

A new official implementation is under review
([GNOME/gvfs!323](https://gitlab.gnome.org/GNOME/gvfs/-/merge_requests/323), milestone GNOME 52),
so not before Fedora 46. Meanwhile this tool uses **rclone**, which is in the official Fedora
repositories, and doesn't replace any system package.

## Installation

```bash
sudo dnf install rclone
git clone https://github.com/olosip/gdrive-fedora-mount.git
cd gdrive-fedora-mount
./install.sh
gdrive-fedora-mount setup     # opens the browser: sign in to Google and authorize rclone
gdrive-fedora-mount enable    # mounts at ~/GoogleDrive
```

You need a Google account in Settings → Online Accounts (just having it is enough, even with only
Mail enabled). At every login the mount starts only if the account is there.

## How the Online Accounts link works

- `gdrive-fedora-mount.service` mounts the Drive with rclone; before starting it checks
  (`ExecCondition`) that the Google account is in Online Accounts.
- `gdrive-fedora-mount-goa.path` watches `~/.config/goa-1.0/`: when you add or remove an account it
  runs `gdrive-fedora-mount-goa.service`, which mounts or unmounts accordingly. On removal it also
  clears the local cache and `~/GoogleDrive` if empty.
- The mount is tied to one specific account (the first Google account, or `GDRIVE_ACCOUNT`).

rclone's authorization is still separate from GNOME's: the **Files** switch in Online Accounts
won't reappear, because only the gvfs backend Fedora removed can provide it. Removing the account
from Online Accounts doesn't revoke rclone's access: use `gdrive-fedora-mount uninstall` for that.

## Commands

| Command | What it does |
|---|---|
| `gdrive-fedora-mount setup` | connects rclone to your Google account (remote `gdrive`) |
| `gdrive-fedora-mount set-client` | switches to your own Google client_id (see below) |
| `gdrive-fedora-mount enable` | creates the services and mounts, if the account is in Online Accounts |
| `gdrive-fedora-mount disable` | unmounts and disables the services |
| `gdrive-fedora-mount status` | shows the status |
| `gdrive-fedora-mount uninstall` | removes everything, see below |

Account, remote name and folder can be changed with `GDRIVE_ACCOUNT`, `GDRIVE_REMOTE` and
`GDRIVE_DIR`. The tool's messages are in Italian for now.

## Clean uninstall

```bash
gdrive-fedora-mount uninstall
```

Removes the services, rclone's cache for this remote, `~/GoogleDrive` (only if empty: your files
are never deleted), the script itself and, if you confirm, rclone's authorization. If you don't
need rclone for anything else:

```bash
sudo dnf remove rclone
```

## Your own client ID (recommended)

By default rclone uses a Google client_id shared by all its users, which is being retired and will
stop working. To avoid losing access, create your own OAuth client following
[rclone's guide](https://rclone.org/drive/#making-your-own-client-id) (Google Cloud Console →
Google Drive API → "Desktop app" credentials), then:

```bash
gdrive-fedora-mount set-client
```

It asks for the client ID and secret (the secret is not echoed), re-authorizes in the browser and
restarts the mount. For a new setup you can also use
`GDRIVE_CLIENT_ID=... GDRIVE_CLIENT_SECRET=... gdrive-fedora-mount setup`.

## Upgrading from gdrive-mount

Up to version 0.2 the tool was called `gdrive-mount`. Install the new version and run
`gdrive-fedora-mount enable`: it removes the old services and script automatically.

## Notes

- Google Docs, Sheets and Slides show up as `.docx`, `.xlsx` and `.pptx` files.
- The local cache uses at most 5 GB and expires after 24 hours.
- To revoke access on Google's side too: myaccount.google.com → Security → Third-party apps.

## Tests

```bash
bash tests/run.sh
```

The tests use neither the network nor your account: rclone and systemctl are replaced by fakes in a
temporary home. They check the Online Accounts link, the upgrade from the old name, and that after
`uninstall` the home is exactly as before.

## License

[MIT](LICENSE)
