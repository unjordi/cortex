#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit linux-ssh-*; ver ../SKILL.md
#
# linux-ssh-maximize-window.sh - Maximiza/restaura/minimiza una ventana por titulo, POR SSH.
# ==================================================================================================
# Via `xdotool windowsize --sync X 100% 100%` (maximizar), `windowminimize` (minimizar). "Restaurar"
# no tiene un comando directo en xdotool -- se aproxima devolviendo un tamano/posicion razonable
# (no hay equivalente limpio al SW_RESTORE de win32 que recuerde el tamano PREVIO). Documentado como
# adaptacion, no como bug.
#
# USO (por SSH):
#   linux-ssh-maximize-window.sh -Window "MiApp" -State Maximize
#   linux-ssh-maximize-window.sh -Window "MiApp" -State Minimize
#   linux-ssh-maximize-window.sh -Window "MiApp" -State Restore
#
# EXIT: 0 si hallo la ventana; 1 si no la encontro.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-linux-ssh-env.sh
source "$SCRIPT_DIR/lib-linux-ssh-env.sh"

Window=""; State="Maximize"
while [ $# -gt 0 ]; do
    case "$1" in
        -Window) Window="$2"; shift 2 ;;
        -State) State="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done
[ -z "$Window" ] && { echo "Falta -Window" >&2; exit 2; }

resolve_session_env
if ! has_session_desktop; then echo "SIN sesion grafica activa" >&2; exit 1; fi
command -v xdotool >/dev/null 2>&1 || { echo "FALTA xdotool" >&2; exit 1; }

w=$(xdotool search --name "$Window" 2>/dev/null | head -1)
[ -z "$w" ] && { echo "no encontre ventana que contenga '$Window'" >&2; exit 1; }

case "$State" in
    Maximize)
        xdotool windowactivate "$w" 2>/dev/null
        xdotool windowsize --sync "$w" 100% 100%
        xdotool windowmove "$w" 0 0
        ;;
    Minimize) xdotool windowminimize "$w" ;;
    Restore)
        xdotool windowactivate "$w" 2>/dev/null
        xdotool windowmove "$w" 100 100
        xdotool windowsize "$w" 1024 768
        ;;
    *) echo "State invalido: $State (Maximize|Minimize|Restore)" >&2; exit 2 ;;
esac
echo "OK $State -> '$Window'"
exit 0
