#!/usr/bin/env bash
# Installa gdrive-fedora-mount in ~/.local/bin (nessun permesso di root richiesto).
set -euo pipefail

src="$(dirname "$(readlink -f "$0")")/gdrive-fedora-mount"
dest="$HOME/.local/bin/gdrive-fedora-mount"

mkdir -p "$(dirname "$dest")"
install -m 0755 "$src" "$dest"
echo "Installato in $dest"

if ! command -v rclone >/dev/null 2>&1; then
    echo "Manca rclone. Installalo con: sudo dnf install rclone"
fi
echo "Poi esegui: gdrive-fedora-mount setup && gdrive-fedora-mount enable"
