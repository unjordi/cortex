#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit linux-ssh-*; ver ../SKILL.md
#
# linux-ssh-get-window-coordinates.sh - Rectangulo + CENTRO de UNA ventana por titulo, POR SSH.
# ==================================================================================================
# PARIDAD PARCIAL con win-ssh-get-window-coordinates.ps1 -- documentada, no es un hueco escondido:
# Windows puede enumerar los HWND HIJOS de una ventana (cada boton/checkbox clasico es su propio
# HWND) y dar el centro de CADA control. En Linux/X11 los toolkits modernos (GTK/Qt) dibujan sus
# widgets DENTRO de una sola X-window -- no hay "hijos" que enumerar por API de ventanas. El
# equivalente real seria AT-SPI (accessibility bus, `busctl --user` contra org.a11y.atspi) --
# SIN CONFIRMAR en esta pasada, queda como trabajo futuro si hace falta precision por-control.
# Este script da lo que SI es robusto y generico: el rectangulo de la VENTANA y su CENTRO, para
# clickear con `linux-ssh-send-click.sh` sin tener que adivinar por el screenshot solo.
#
# USO (por SSH):
#   linux-ssh-get-window-coordinates.sh -Window "MiApp - Herramienta"
#
# EXIT: 0 si hallo la ventana; 1 si no la encontro / sin sesion grafica / falta xdotool.
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

name=$(xdotool getwindowname "$w" 2>/dev/null)
geo=$(xdotool getwindowgeometry --shell "$w" 2>/dev/null)
x=$(printf '%s\n' "$geo" | grep '^X=' | cut -d= -f2)
y=$(printf '%s\n' "$geo" | grep '^Y=' | cut -d= -f2)
wd=$(printf '%s\n' "$geo" | grep '^WIDTH=' | cut -d= -f2)
ht=$(printf '%s\n' "$geo" | grep '^HEIGHT=' | cut -d= -f2)
cx=$((x + wd/2))
cy=$((y + ht/2))

echo "Ventana: $name"
echo "Rect: X=$x Y=$y W=$wd H=$ht"
echo "Centro: $cx,$cy"
echo "(sin desglose por-control -- ver nota de paridad parcial arriba del script)"
exit 0
