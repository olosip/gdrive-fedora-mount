#!/usr/bin/env bash
# Test senza rete: rclone, systemctl e fusermount3 sono sostituiti da finti comandi.
# Verifica che install -> enable -> uninstall lasci la home esattamente com'era.
set -euo pipefail

root="$(dirname "$(readlink -f "$0")")/.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

export HOME="$work/home"
unset XDG_CONFIG_HOME XDG_CACHE_HOME
stubs="$work/stubs"
mkdir -p "$HOME/.config/gtk-3.0" "$stubs"
printf 'file://%s/Documenti\n' "$HOME" > "$HOME/.config/gtk-3.0/bookmarks"
# Cartelle standard che esistono già in qualsiasi home
mkdir -p "$HOME/.config/systemd/user" "$HOME/.cache" "$HOME/.local/bin"

cat > "$stubs/rclone" <<'EOF'
#!/usr/bin/env bash
conf="$HOME/.config/rclone/rclone.conf"
case "$1" in
    listremotes) [[ -s "$conf" ]] && sed -n 's/^\[\(.*\)\]$/\1:/p' "$conf" ;;
    config)
        case "$2" in
            create) mkdir -p "$(dirname "$conf")"; printf '[%s]\ntype = drive\n' "$3" >> "$conf" ;;
            delete) : > "$conf" ;;
            update) printf '%s = %s\n%s = %s\n' "$4" "$5" "$6" "$7" >> "$conf" ;;            file) echo "Configuration file is stored at:"; echo "$conf" ;;
        esac ;;
    lsd) exit 0 ;;
esac
EOF
printf '#!/bin/sh\necho "systemctl $*" >> "$HOME/../calls"\n' > "$stubs/systemctl"
printf '#!/bin/sh\nexit 0\n' > "$stubs/fusermount3"
chmod +x "$stubs"/*
export PATH="$stubs:$PATH"

snapshot() { (cd "$HOME" && find . | sort; cat .config/gtk-3.0/bookmarks); }
fail() { echo "FALLITO: $*" >&2; exit 1; }

before="$(snapshot)"

bash "$root/install.sh" >/dev/null
[[ -x "$HOME/.local/bin/gdrive-mount" ]] || fail "script non installato"
gdm="$HOME/.local/bin/gdrive-mount"

"$gdm" enable 2>/dev/null && fail "enable dovrebbe fallire senza remote"
"$gdm" setup >/dev/null
"$gdm" enable >/dev/null

unit="$HOME/.config/systemd/user/gdrive-mount.service"
[[ -f "$unit" ]] || fail "unit non creata"
grep -q "mount gdrive: $HOME/GoogleDrive" "$unit" || fail "comando mount errato"
[[ -d "$HOME/GoogleDrive" ]] || fail "cartella di montaggio mancante"
grep -qxF "file://$HOME/GoogleDrive Google Drive" "$HOME/.config/gtk-3.0/bookmarks" || fail "segnalibro mancante"
"$gdm" enable >/dev/null
[[ "$(grep -c GoogleDrive "$HOME/.config/gtk-3.0/bookmarks")" == 1 ]] || fail "segnalibro duplicato"
grep -q "enable --now gdrive-mount.service" "$work/calls" || fail "servizio non abilitato"
"$gdm" status >/dev/null

printf 'mio-id\nmio-secret\n' | "$gdm" set-client >/dev/null 2>&1
grep -qx 'client_id = mio-id' "$HOME/.config/rclone/rclone.conf" || fail "client_id non salvato"
grep -qx 'client_secret = mio-secret' "$HOME/.config/rclone/rclone.conf" || fail "client_secret non salvato"
grep -q "restart gdrive-mount.service" "$work/calls" || fail "servizio non riavviato"

mkdir -p "$HOME/.cache/rclone/vfs/gdrive/x"
ASSUME_YES=1 "$gdm" uninstall >/dev/null

after="$(snapshot)"
if [[ "$before" != "$after" ]]; then
    diff <(echo "$before") <(echo "$after") >&2 || true
    fail "la disinstallazione ha lasciato residui"
fi

# Una cartella di montaggio non vuota non va mai cancellata
bash "$root/install.sh" >/dev/null
"$gdm" setup >/dev/null
"$gdm" enable >/dev/null
echo dati > "$HOME/GoogleDrive/mio-file.txt"
ASSUME_YES=1 "$gdm" uninstall >/dev/null
[[ -f "$HOME/GoogleDrive/mio-file.txt" ]] || fail "cancellati file dell'utente"

echo "Tutti i test superati."
