#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit mac-ssh-*; ver ../SKILL.md
#
# mac-ssh-launch.sh - Lanza una app EN la sesion de consola, POR SSH.
# ==================================================================================================
# Via `open -a "<App>"` (por nombre/ruta .app) o `open <ruta>` (doc/URL) -- nativo, hereda el
# LaunchServices de la sesion de consola via mac_dispatch (launchctl asuser si hace falta).
#
# USO (por SSH):
#   mac-ssh-launch.sh -App "Kate"                         # por nombre de app instalada
#   mac-ssh-launch.sh -Path "/Applications/Kate.app"       # por ruta .app
#   mac-ssh-launch.sh -Path "https://ejemplo.com"          # URL -> abre en el navegador default
#   mac-ssh-launch.sh -App "TextEdit" -Args "/tmp/x.txt"   # abre ese archivo CON esa app
#
# EXIT: 0 si disparo el lanzamiento; 1 sin sesion de consola / falto -App o -Path.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-mac-ssh-env.sh
source "$SCRIPT_DIR/lib-mac-ssh-env.sh"

App=""; Path=""; Args=""
while [ $# -gt 0 ]; do
    case "$1" in
        -App) App="$2"; shift 2 ;;
        -Path) Path="$2"; shift 2 ;;
        -Args) Args="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done
[ -z "$App" ] && [ -z "$Path" ] && { echo "Da -App o -Path" >&2; exit 2; }

cu="$(mac_console_user)"
[ -z "$cu" ] && { echo "SIN sesion de consola activa -> no hay donde lanzar" >&2; exit 1; }

if [ -n "$App" ] && [ -n "$Args" ]; then
    mac_dispatch open -a "$App" "$Args"
elif [ -n "$App" ]; then
    mac_dispatch open -a "$App"
else
    mac_dispatch open "$Path"
fi

echo "OK lanzado ${App:+App='$App' }${Path:+Path='$Path' }(usuario $cu)"
exit 0
