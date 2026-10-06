#!/usr/bin/env bash
# QA de la extensión en un GNOME Shell ANIDADO y AISLADO (ventana aparte, sin tocar tu panel real
# ni tu dconf). Requiere el paquete mutter-devkit (Fedora: `sudo dnf install mutter-devkit`).
#
#   ./dev-anidado.sh [pestaña]   → (re)arranca el shell anidado, abre el popup en esa pestaña (0-6)
#                                  y deja la captura en $CORTEX_DEV/shot.png
#
# Reiniciar es OBLIGATORIO tras cada cambio: GJS cachea los módulos ES de la extensión.
# Lee el caché REAL (~/.cache/cortex) para mostrar datos verdaderos.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UUID="cortex@unjordi.github.io"
DEV="${CORTEX_DEV:-${XDG_RUNTIME_DIR:-/tmp}/cortex-gnome-dev}"
TAB="${1:-0}"

mkdir -p "$DEV/data/gnome-shell/extensions" "$DEV/config"
ln -sfn "$SRC" "$DEV/data/gnome-shell/extensions/$UUID"

# Patrón ANCLADO: un `pkill -f` sin ^ casa con la línea de comando de este mismo script y lo mata.
pkill -f "^gnome-shell --devkit" || true
sleep 2

# XDG_DATA_HOME/XDG_CONFIG_HOME propios ⇒ extensiones y dconf aislados del usuario real.
# --unsafe-mode habilita Eval y Screenshot por D-Bus (solo en este bus privado).
(setsid nohup env XDG_DATA_HOME="$DEV/data" XDG_CONFIG_HOME="$DEV/config" \
  dbus-run-session -- bash -c "
    echo \"\$DBUS_SESSION_BUS_ADDRESS\" > '$DEV/bus'
    gsettings set org.gnome.shell disable-user-extensions false
    gsettings set org.gnome.shell enabled-extensions \"['$UUID']\"
    gsettings set org.gnome.shell welcome-dialog-last-shown-version '99'
    gnome-shell --devkit --wayland --unsafe-mode" > "$DEV/log" 2>&1 &)
sleep 10

export DBUS_SESSION_BUS_ADDRESS="$(cat "$DEV/bus")"
gdbus call --session --dest org.gnome.Shell.Extensions --object-path /org/gnome/Shell/Extensions \
  --method org.gnome.Shell.Extensions.GetExtensionInfo "$UUID" | grep -o -E "'(state|error)': <[^>]*>" || true
gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval \
  "const i=Main.panel.statusArea['$UUID']; i.menu.open(); i._tab=$TAB; i._renderPopup(); 'ok'" >/dev/null
sleep 1
gdbus call --session --dest org.gnome.Shell.Screenshot --object-path /org/gnome/Shell/Screenshot \
  --method org.gnome.Shell.Screenshot.Screenshot false false "$DEV/shot.png" >/dev/null
grep -E "JS ERROR" "$DEV/log" | head -5 || true
echo "captura: $DEV/shot.png · log: $DEV/log"
