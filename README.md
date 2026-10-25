# gdrive-mount

Google Drive come una normale cartella su Fedora, con un segnalibro in Gestione file (Nautilus).

## Perché

Da GNOME 50 (Fedora 44, Ubuntu 26.04) gvfs non include più il backend Google Drive: la libreria
`libgdata` su cui si basava non ha più un manutentore. Per questo in **Impostazioni → Account online**
l'account Google non mostra più l'opzione **File**.

È in revisione una nuova implementazione ufficiale
([GNOME/gvfs!323](https://gitlab.gnome.org/GNOME/gvfs/-/merge_requests/323), milestone GNOME 52,
quindi al più presto Fedora 46). Nel frattempo questo strumento usa **rclone**, che è nei repository
Fedora e non sostituisce nessun pacchetto di sistema.

## Installazione

```bash
sudo dnf install rclone
./install.sh
gdrive-mount setup     # si apre il browser: accedi a Google e autorizza rclone
gdrive-mount enable    # monta in ~/GoogleDrive e aggiunge il segnalibro "Google Drive"
```

Il montaggio parte da solo a ogni accesso (servizio `systemd --user` chiamato `gdrive-mount.service`).

## Comandi

| Comando | Cosa fa |
|---|---|
| `gdrive-mount setup` | collega rclone all'account Google (remote `gdrive`) |
| `gdrive-mount enable` | crea e avvia il servizio, aggiunge il segnalibro |
| `gdrive-mount disable` | smonta, ferma il servizio, toglie il segnalibro |
| `gdrive-mount status` | mostra lo stato |
| `gdrive-mount uninstall` | rimuove tutto, vedi sotto |

Si possono cambiare il nome del remote e la cartella con `GDRIVE_REMOTE` e `GDRIVE_DIR`.

## Disinstallazione senza residui

```bash
gdrive-mount uninstall
```

Rimuove servizio, segnalibro, cache di rclone per questo remote, la cartella `~/GoogleDrive` (solo se
vuota: i tuoi file non vengono mai cancellati), lo script stesso e, se confermi, l'autorizzazione di
rclone. Se rclone non ti serve per altro:

```bash
sudo dnf remove rclone
```

## Client ID proprio (consigliato)

rclone usa per default un client_id Google condiviso tra tutti i suoi utenti, che è in via di ritiro
e smetterà di funzionare. Per non restare senza accesso, crea un client OAuth tuo seguendo
[la guida di rclone](https://rclone.org/drive/#making-your-own-client-id) (Google Cloud Console →
API Google Drive → credenziali "App desktop"), poi:

```bash
# nuova configurazione
GDRIVE_CLIENT_ID=... GDRIVE_CLIENT_SECRET=... gdrive-mount setup

# oppure, se il remote esiste già
rclone config update gdrive client_id=... client_secret=...
rclone config reconnect gdrive:
systemctl --user restart gdrive-mount.service
```

## Note

- I documenti Google (Docs, Fogli, Presentazioni) compaiono come file `.docx`, `.xlsx`, `.pptx`.
- La cache locale usa al massimo 5 GB e si svuota dopo 24 ore.
- Per revocare l'accesso anche lato Google: myaccount.google.com → Sicurezza → App di terze parti.

## Test

```bash
bash tests/run.sh
```

I test non usano la rete né il tuo account: rclone e systemctl vengono sostituiti da comandi finti
in una home temporanea, e si verifica che dopo `uninstall` la home sia identica a prima.
