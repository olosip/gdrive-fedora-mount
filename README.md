# gdrive-mount

Google Drive come una normale cartella su Fedora, legato all'account Google di
**Impostazioni → Account online**: compare tra i volumi della Gestione file finché l'account c'è,
e sparisce (con la cache pulita) quando lo rimuovi.

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
gdrive-mount enable    # monta in ~/GoogleDrive
```

Serve un account Google in Impostazioni → Account online (basta che ci sia, anche con solo Email
attiva). Il montaggio parte a ogni accesso solo se l'account è presente.

## Come funziona il legame con Account online

- `gdrive-mount.service` monta il Drive con rclone; prima di partire controlla (`ExecCondition`)
  che l'account Google sia in Account online.
- `gdrive-mount-goa.path` sorveglia `~/.config/goa-1.0/`: quando aggiungi o rimuovi un account
  lancia `gdrive-mount-goa.service`, che monta o smonta di conseguenza. Alla rimozione pulisce
  anche la cache locale e la cartella `~/GoogleDrive` se è vuota.
- Il montaggio è legato a un account preciso (il primo account Google, oppure `GDRIVE_ACCOUNT`).

L'autorizzazione di rclone resta però separata da quella di GNOME: l'interruttore **File** in
Account online non compare, perché lo mostra solo il backend gvfs che Fedora ha tolto. Rimuovere
l'account da Account online non revoca l'accesso di rclone: per quello usa `gdrive-mount uninstall`.

## Comandi

| Comando | Cosa fa |
|---|---|
| `gdrive-mount setup` | collega rclone all'account Google (remote `gdrive`) |
| `gdrive-mount enable` | crea i servizi e monta, se l'account è in Account online |
| `gdrive-mount disable` | smonta e disattiva i servizi |
| `gdrive-mount status` | mostra lo stato |
| `gdrive-mount uninstall` | rimuove tutto, vedi sotto |

Si possono cambiare account, nome del remote e cartella con `GDRIVE_ACCOUNT`, `GDRIVE_REMOTE` e
`GDRIVE_DIR`.

## Disinstallazione senza residui

```bash
gdrive-mount uninstall
```

Rimuove i servizi, la cache di rclone per questo remote, la cartella `~/GoogleDrive` (solo se
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
gdrive-mount set-client
```

Chiede client ID e secret (il secret non viene mostrato), rifà l'autorizzazione nel browser e
riavvia il montaggio. Per una configurazione nuova puoi anche usare
`GDRIVE_CLIENT_ID=... GDRIVE_CLIENT_SECRET=... gdrive-mount setup`.

## Note

- I documenti Google (Docs, Fogli, Presentazioni) compaiono come file `.docx`, `.xlsx`, `.pptx`.
- La cache locale usa al massimo 5 GB e si svuota dopo 24 ore.
- Per revocare l'accesso anche lato Google: myaccount.google.com → Sicurezza → App di terze parti.

## Test

```bash
bash tests/run.sh
```

I test non usano la rete né il tuo account: rclone e systemctl vengono sostituiti da comandi finti
in una home temporanea, e si verifica il legame con Account online e che dopo `uninstall` la home sia identica a prima.
