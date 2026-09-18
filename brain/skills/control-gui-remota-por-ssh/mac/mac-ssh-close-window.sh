#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit mac-ssh-*; ver ../SKILL.md
#
# mac-ssh-close-window.sh - Cierra la ventana frontal de una app (cierre GRACIOSO), POR SSH.
# ==================================================================================================
# Activa la app y le manda Cmd+W via System Events keystroke -- el idiomatico "cerrar ventana" de
# macOS (equivalente a WM_CLOSE de Windows / al boton X): GRACIOSO, puede disparar un dialogo
# "guardar cambios?" si la app tiene estado sin guardar.
#
# USO (por SSH): mac-ssh-close-window.sh -App "Kate"
# EXIT: 0 si disparo el cierre; 1 sin sesion de consola / falto -App.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-mac-ssh-env.sh
source "$SCRIPT_DIR/lib-mac-ssh-env.sh"

App=""
while [ $# -gt 0 ]; do
    case "$1" in
        -App) App="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done
[ -z "$App" ] && { echo "Falta -App" >&2; exit 2; }

cu="$(mac_console_user)"
[ -z "$cu" ] && { echo "SIN sesion de consola activa" >&2; exit 1; }

mac_dispatch osascript -e "tell application \"$App\" to activate" >/dev/null 2>&1
sleep 0.3
mac_dispatch osascript -e "tell application \"System Events\" to keystroke \"w\" using command down" 2>&1

echo "OK cerre (Cmd+W) -> '$App'"
exit 0
