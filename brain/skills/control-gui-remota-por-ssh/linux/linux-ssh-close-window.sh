#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit linux-ssh-*; ver ../SKILL.md
#
# linux-ssh-close-window.sh - Cierra una ventana por titulo (cierre GRACIOSO), POR SSH.
# ==================================================================================================
# `xdotool windowclose` manda la solicitud de cierre estandar de la ventana (equivalente a WM_CLOSE
# de Windows / al boton X) -- GRACIOSO: si la app tiene cambios sin guardar, puede mostrar su propio
# dialogo. Solo ventanas X11/XWayland (mismo limite que list-windows).
#
# USO (por SSH): linux-ssh-close-window.sh -Window "MiApp"
# EXIT: 0 hallo y mando cerrar; 1 no la encontro / sin sesion.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-linux-ssh-env.sh
source "$SCRIPT_DIR/lib-linux-ssh-env.sh"

Window=""
while [ $# -gt 0 ]; do
    case "$1" in
        -Window) Window="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done
[ -z "$Window" ] && { echo "Falta -Window" >&2; exit 2; }

resolve_session_env
if ! has_session_desktop; then echo "SIN sesion grafica activa" >&2; exit 1; fi
command -v xdotool >/dev/null 2>&1 || { echo "FALTA xdotool" >&2; exit 1; }

w=$(xdotool search --name "$Window" 2>/dev/null | head -1)
[ -z "$w" ] && { echo "no encontre ventana que contenga '$Window'" >&2; exit 1; }

xdotool windowclose "$w"
echo "OK cerre (windowclose) -> '$Window'"
exit 0
