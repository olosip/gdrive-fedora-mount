#!/usr/bin/env bash
# Test senza rete: rclone, systemctl e fusermount3 sono sostituiti da finti comandi.
# Verifica il legame con Account online e che install -> enable -> uninstall
# lasci la home esattamente com'era.
set -euo pipefail

root="$(dirname "$(readlink -f "$0")")/.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

export HOME="$work/home"
unset XDG_CONFIG_HOME XDG_CACHE_HOME GDRIVE_ACCOUNT GDRIVE_REMOTE GDRIVE_DIR
stubs="$work/stubs"
goa="$HOME/.config/goa-1.0/accounts.conf"
# Cartelle standard che esistono già in qualsiasi home
mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/goa-1.0" "$HOME/.config/systemd/user" \
         "$HOME/.cache" "$HOME/.local/bin" "$stubs"
printf 'file://%s/Documenti\n' "$HOME" > "$HOME/.config/gtk-3.0/bookmarks"
cat > "$goa" <<'EOF'
[Account account_1_1]
Provider=ms_graph
Identity=qualcuno@hotmail.it
MailEnabled=true
EOF

cat > "$stubs/rclone" <<'EOF'
#!/usr/bin/env bash
conf="$HOME/.config/rclone/rclone.conf"
case "$1" in
    listremotes) [[ -s "$conf" ]] && sed -n 's/^\[\(.*\)\]$/\1:/p' "$conf" ;;
    config)
        case "$2" in
            create) mkdir -p "$(dirname "$conf")"; printf '[%s]\ntype = drive\n' "$3" >> "$conf" ;;
            delete) : > "$conf" ;;
            update) printf '%s = %s\n%s = %s\n' "$4" "$5" "$6" "$7" >> "$conf" ;;
            file) echo "Configuration file is stored at:"; echo "$conf" ;;
        esac ;;
    lsd) exit 0 ;;
esac
EOF
printf '#!/bin/sh\necho "systemctl $*" >> "$HOME/../calls"\n' > "$stubs/systemctl"
printf '#!/bin/sh\nexit 0\n' > "$stubs/fusermount3"
chmod +x "$stubs"/*
export PATH="$stubs:$PATH"

snapshot() { (cd "$HOME" && find . | sort; cat .config/gtk-3.0/bookmarks .config/goa-1.0/accounts.conf); }
fail() { echo "FALLITO: $*" >&2; exit 1; }
calls() { cat "$work/calls" 2>/dev/null || true; : > "$work/calls"; }
add_google() {
    cat >> "$goa" <<'EOF'

[Account account_2_3]
Provider=google
Identity=io@gmail.com
MailEnabled=true
EOF
}

before="$(snapshot)"

bash "$root/install.sh" >/dev/null
[[ -x "$HOME/.local/bin/gdrive-fedora-mount" ]] || fail "script non installato"
gdm="$HOME/.local/bin/gdrive-fedora-mount"

"$gdm" enable 2>/dev/null && fail "enable dovrebbe fallire senza remote"
"$gdm" setup >/dev/null
"$gdm" enable 2>/dev/null && fail "enable dovrebbe fallire senza account Google in Account online"
"$gdm" has-account && fail "has-account non deve vedere account Microsoft"

add_google
"$gdm" has-account || fail "account Google non rilevato"
# Installazione precedente col vecchio nome (gdrive-mount): enable deve toglierla
printf '[Unit]\n' > "$HOME/.config/systemd/user/gdrive-mount.service"
printf '[Path]\n' > "$HOME/.config/systemd/user/gdrive-mount-goa.path"
printf '#!/bin/sh\n' > "$HOME/.local/bin/gdrive-mount"
calls >/dev/null
"$gdm" enable >/dev/null
for f in .config/systemd/user/gdrive-mount.service .config/systemd/user/gdrive-mount-goa.path .local/bin/gdrive-mount; do
    [[ -e "$HOME/$f" ]] && fail "residuo della versione precedente: $f"
done

unit="$HOME/.config/systemd/user/gdrive-fedora-mount.service"
[[ -f "$unit" ]] || fail "unit non creata"
grep -q "mount gdrive: $HOME/GoogleDrive" "$unit" || fail "comando mount errato"
grep -q "GDRIVE_ACCOUNT=io@gmail.com" "$unit" || fail "account non legato al servizio"
grep -q "ExecCondition=$gdm has-account" "$unit" || fail "manca il controllo dell'account"
grep -qx "PathChanged=$HOME/.config/goa-1.0" "$HOME/.config/systemd/user/gdrive-fedora-mount-goa.path" || fail "unità path errata"
grep -qx "ExecStart=$gdm sync" "$HOME/.config/systemd/user/gdrive-fedora-mount-goa.service" || fail "unità sync errata"
[[ -d "$HOME/GoogleDrive" ]] || fail "cartella di montaggio mancante"
grep -q GoogleDrive "$HOME/.config/gtk-3.0/bookmarks" && fail "non deve più aggiungere segnalibri"
c="$(calls)"
grep -q "enable gdrive-fedora-mount.service gdrive-fedora-mount-goa.path" <<< "$c" || fail "servizi non abilitati"
grep -q "restart gdrive-fedora-mount.service" <<< "$c" || fail "montaggio non avviato"

# Il vecchio segnalibro delle versioni precedenti viene tolto
printf 'file://%s/GoogleDrive Google Drive\n' "$HOME" >> "$HOME/.config/gtk-3.0/bookmarks"
"$gdm" enable >/dev/null
grep -q GoogleDrive "$HOME/.config/gtk-3.0/bookmarks" && fail "vecchio segnalibro non rimosso"
"$gdm" status >/dev/null

printf 'mio-id\nmio-secret\n' | "$gdm" set-client >/dev/null 2>&1
grep -qx 'client_id = mio-id' "$HOME/.config/rclone/rclone.conf" || fail "client_id non salvato"
grep -qx 'client_secret = mio-secret' "$HOME/.config/rclone/rclone.conf" || fail "client_secret non salvato"
grep -q "restart gdrive-fedora-mount.service" <<< "$(calls)" || fail "servizio non riavviato"

# Account presente: sync avvia il montaggio
GDRIVE_ACCOUNT=io@gmail.com "$gdm" sync >/dev/null
grep -q "start gdrive-fedora-mount.service" <<< "$(calls)" || fail "sync non avvia il montaggio"

# Account rimosso da Account online: sync smonta e pulisce
mkdir -p "$HOME/.cache/rclone/vfs/gdrive/x" "$HOME/.cache/rclone/vfsMeta/gdrive"
sed -i '/^\[Account account_2_3\]/,$d' "$goa"
GDRIVE_ACCOUNT=io@gmail.com "$gdm" has-account && fail "account rimosso ancora visto"
GDRIVE_ACCOUNT=io@gmail.com "$gdm" sync >/dev/null
grep -q "stop gdrive-fedora-mount.service" <<< "$(calls)" || fail "sync non ferma il montaggio"
[[ -e "$HOME/.cache/rclone" ]] && fail "cache non pulita"
[[ -e "$HOME/GoogleDrive" ]] && fail "cartella vuota non rimossa"

# Un altro account Google non deve far ripartire il montaggio legato a io@gmail.com
printf '\n[Account account_3_1]\nProvider=google\nIdentity=altro@gmail.com\n' >> "$goa"
GDRIVE_ACCOUNT=io@gmail.com "$gdm" has-account && fail "montaggio legato all'account sbagliato"
sed -i '/^\[Account account_3_1\]/,$d' "$goa"

ASSUME_YES=1 "$gdm" uninstall >/dev/null

# accounts.conf: sed lascia una riga vuota finale in più, la normalizzo prima del confronto
sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$goa"
after="$(snapshot)"
if [[ "$before" != "$after" ]]; then
    diff <(echo "$before") <(echo "$after") >&2 || true
    fail "la disinstallazione ha lasciato residui"
fi

# Una cartella di montaggio non vuota non va mai cancellata
add_google
bash "$root/install.sh" >/dev/null
"$gdm" setup >/dev/null
"$gdm" enable >/dev/null
echo dati > "$HOME/GoogleDrive/mio-file.txt"
ASSUME_YES=1 "$gdm" uninstall >/dev/null
[[ -f "$HOME/GoogleDrive/mio-file.txt" ]] || fail "cancellati file dell'utente"

echo "Tutti i test superati."
