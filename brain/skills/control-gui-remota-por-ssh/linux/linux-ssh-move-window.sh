#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit linux-ssh-*; ver ../SKILL.md
#
# linux-ssh-move-window.sh - Mueve/redimensiona una ventana por titulo, POR SSH.
# ==================================================================================================
# Via `xdotool windowmove`/`windowsize` -- solo ventanas X11/XWayland (mismo limite que
# list-windows). NO dispara el permiso EIS de KWin (ese es solo para mouse/teclado sinteticos;
# mover/redimensionar una ventana es una operacion de gestion de ventanas, no de input).
#
# USO (por SSH):
#   linux-ssh-move-window.sh -Window "MiApp" -X 100 -Y 100
#   linux-ssh-move-window.sh -Window "MiApp" -X 0 -Y 0 -W 1200 -H 800
#
# EXIT: 0 si hallo la ventana y disparo el move/resize; 1 si no la encontro.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-linux-ssh-env.sh
source "$SCRIPT_DIR/lib-linux-ssh-env.sh"

Window=""; X=""; Y=""; W=""; H=""
while [ $# -gt 0 ]; do
    case "$1" in
        -Window) Window="$2"; shift 2 ;;
        -X) X="$2"; shift 2 ;;
        -Y) Y="$2"; shift 2 ;;
        -W) W="$2"; shift 2 ;;
        -H) H="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done
[ -z "$Window" ] && { echo "Falta -Window" >&2; exit 2; }
{ [ -z "$X" ] || [ -z "$Y" ]; } && { echo "Falta -X -Y" >&2; exit 2; }

resolve_session_env
if ! has_session_desktop; then echo "SIN sesion grafica activa" >&2; exit 1; fi
command -v xdotool >/dev/null 2>&1 || { echo "FALTA xdotool" >&2; exit 1; }

w=$(xdotool search --name "$Window" 2>/dev/null | head -1)
[ -z "$w" ] && { echo "no encontre ventana que contenga '$Window'" >&2; exit 1; }

xdotool windowmove "$w" "$X" "$Y"
if [ -n "$W" ] && [ -n "$H" ]; then
    xdotool windowsize "$w" "$W" "$H"
fi
echo "OK movida '$Window' -> $X,$Y${W:+ (${W}x${H})}"
exit 0
