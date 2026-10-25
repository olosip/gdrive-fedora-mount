# Post per forum (Fedora Discussion, Reddit r/Fedora, forum italiani)

---

## 🇮🇹 Versione italiana

**Titolo:** Fedora 44: Google Drive sparito da "Account online"? Ecco perché e come riaverlo

Dopo l'aggiornamento a Fedora 44 avete notato che in **Impostazioni → Account online** l'account
Google mostra solo Email, Calendario e Contatti, mentre l'opzione **File** è sparita? E magari su
Debian 13 o Fedora 43 c'era ancora?

**Non è un problema della vostra configurazione.** GNOME 50 ha tolto il supporto a Google Drive da
gvfs: si basava su `libgdata`, una libreria senza manutentore da circa 4 anni e ormai archiviata.
Fedora ha seguito il 18 febbraio 2026 (changelog di `gvfs`: *"Drop support for unmaintained
libgdata"*). Lo stesso vale per Ubuntu 26.04. Potete verificarlo così: in `/usr/libexec/` c'è
`gvfsd-onedrive` ma non `gvfsd-google`.

**Arriverà una soluzione ufficiale?** Sì, probabilmente: la merge request
[GNOME/gvfs!323 "Re-implement Google Drive support"](https://gitlab.gnome.org/GNOME/gvfs/-/merge_requests/323)
è in revisione con milestone **GNOME 52**. Quindi **non con Fedora 45** (GNOME 51), ma forse con
Fedora 46, nella primavera 2027.

**Nel frattempo** ho scritto un piccolo strumento, [gdrive-mount](https://github.com/olosip/gdrive-mount), che usa **rclone** (nei
repo ufficiali Fedora) e non sostituisce nessun pacchetto di sistema:

- monta Google Drive in `~/GoogleDrive`, che compare tra i volumi della Gestione file;
- è legato all'account Google di Account online: monta solo se l'account c'è, e quando lo rimuovete
  smonta e pulisce la cache;
- si disinstalla senza lasciare residui (`gdrive-mount uninstall`).

```bash
sudo dnf install rclone
git clone https://github.com/olosip/gdrive-mount.git && cd gdrive-mount
./install.sh
gdrive-mount setup     # autorizzazione Google nel browser
gdrive-mount enable
```

Due avvertenze oneste:
- l'interruttore **File** in Account online non torna: quello lo può mostrare solo il backend gvfs;
- rclone usa di default un client_id Google condiviso che verrà ritirato: conviene crearne uno
  proprio ([guida rclone](https://rclone.org/drive/#making-your-own-client-id)) e impostarlo con
  `gdrive-mount set-client`.

Se volete l'integrazione nativa già adesso, esiste un
[COPR sperimentale](https://discussion.fedoraproject.org/t/call-for-testers-restoring-google-drive-integration-in-gnome/189348)
dell'autore della merge request: sostituisce gvfs, gnome-online-accounts e gnome-control-center,
quindi fate prima uno snapshot. Testarlo e lasciare feedback aiuta a far entrare la patch upstream.

---

## 🇬🇧 English version

**Title:** Fedora 44: Google Drive "Files" missing from Online Accounts – why, and a workaround

After upgrading to Fedora 44, the Google account in **Settings → Online Accounts** only offers
Mail, Calendar and Contacts – the **Files** switch is gone (while Microsoft 365 still has it).

**It's not your setup.** GNOME 50 dropped Google Drive from gvfs because it depended on `libgdata`,
which has been unmaintained for ~4 years and is now archived. Fedora followed on 2026-02-18 (`gvfs`
changelog: *"Drop support for unmaintained libgdata"*); Ubuntu 26.04 is affected too. Quick check:
`/usr/libexec/gvfsd-onedrive` exists, `gvfsd-google` doesn't.

**Will it come back?** Likely: [GNOME/gvfs!323 "Re-implement Google Drive support"](https://gitlab.gnome.org/GNOME/gvfs/-/merge_requests/323)
is under review, milestone **GNOME 52** – so not Fedora 45 (GNOME 51), maybe Fedora 46 (spring 2027).

**Meanwhile** I wrote a small tool, [gdrive-mount](https://github.com/olosip/gdrive-mount), based on **rclone** (in the official
Fedora repos), which doesn't replace any system package:

- mounts Google Drive at `~/GoogleDrive`, shown as a volume in Files (Nautilus);
- follows your Google account in Online Accounts: mounts only while the account exists, unmounts
  and clears the cache when you remove it;
- uninstalls cleanly (`gdrive-mount uninstall`).

```bash
sudo dnf install rclone
git clone https://github.com/olosip/gdrive-mount.git && cd gdrive-mount
./install.sh
gdrive-mount setup     # Google authorization in the browser
gdrive-mount enable
```

Caveats: the **Files** switch in Online Accounts won't reappear (only the gvfs backend can provide
it), and rclone's shared Google client_id is being retired – create your own
([rclone guide](https://rclone.org/drive/#making-your-own-client-id)) and set it with
`gdrive-mount set-client`. The tool's messages and README are in Italian for now.

If you want native integration today, the MR author has an
[experimental COPR](https://discussion.fedoraproject.org/t/call-for-testers-restoring-google-drive-integration-in-gnome/189348)
(replaces gvfs, gnome-online-accounts and gnome-control-center – take a snapshot first). Testing it
and giving feedback helps get the patch merged upstream.
