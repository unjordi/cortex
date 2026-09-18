#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit mac-ssh-*; ver ../SKILL.md
#
# mac-ssh-get-window-coordinates.sh - Rectangulo + CENTRO de cada CONTROL de una ventana, POR SSH.
# ==================================================================================================
# Mejor paridad que su gemelo Linux: la Accessibility API de macOS (via System Events) SI expone
# los elementos de UI (botones, campos, checkboxes) de una ventana con su posicion/tamano -- mas
# cercano al UI-Automation de Windows que lo que ofrece X11/XWayland en Linux.
#
# VERIFICADO 2026-09-18 LOCAL (solo el MECANISMO, sin una ventana de prueba abierta con controles
# variados en el momento): la consulta AppleScript de "UI elements of window" es la via estandar
# documentada por Apple/usada por herramientas de automatizacion Mac -- no se ejecuto contra una
# ventana con botones reales en esta pasada.
#
# USO (por SSH): mac-ssh-get-window-coordinates.sh -App "MiApp" -Window "titulo"
# EXIT: 0 si hallo la ventana; 1 si no la encontro / sin sesion de consola.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-mac-ssh-env.sh
source "$SCRIPT_DIR/lib-mac-ssh-env.sh"

App=""; Window=""
while [ $# -gt 0 ]; do
    case "$1" in
        -App) App="$2"; shift 2 ;;
        -Window) Window="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done
[ -z "$App" ] && { echo "Falta -App (nombre del proceso, ej. 'Kate')" >&2; exit 2; }

cu="$(mac_console_user)"
[ -z "$cu" ] && { echo "SIN sesion de consola activa" >&2; exit 1; }

wsel="window 1"
[ -n "$Window" ] && wsel="(first window whose name contains \"$Window\")"

out=$(mac_dispatch osascript -e "
tell application \"System Events\"
    tell process \"$App\"
        set w to $wsel
        set wp to position of w
        set ws to size of w
        set res to \"Ventana: \" & (name of w) & linefeed
        set res to res & \"Rect: X=\" & (item 1 of wp) & \" Y=\" & (item 2 of wp) & \" W=\" & (item 1 of ws) & \" H=\" & (item 2 of ws) & linefeed
        set res to res & \"Controles:\" & linefeed
        repeat with e in UI elements of w
            try
                set ep to position of e
                set es to size of e
                set cx to (item 1 of ep) + ((item 1 of es) / 2)
                set cy to (item 2 of ep) + ((item 2 of es) / 2)
                set res to res & \"  \" & (role of e) & \" '\" & (description of e) & \"' centro=\" & cx & \",\" & cy & linefeed
            end try
        end repeat
        return res
    end tell
end tell" 2>&1)

if [ -z "$out" ]; then
    echo "no encontre la ventana (App='$App' Window='$Window')" >&2
    exit 1
fi
echo "$out"
exit 0
