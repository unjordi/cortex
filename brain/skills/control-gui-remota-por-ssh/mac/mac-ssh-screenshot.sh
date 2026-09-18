#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit mac-ssh-*; ver ../SKILL.md
#
# mac-ssh-screenshot.sh - Captura la pantalla de la sesion de consola, POR SSH.
# ==================================================================================================
# Via `screencapture -x` (nativo, sin dependencias). macOS es single-seat -- no hay aislamiento de
# logon-session como en Windows, asi que no hace falta un mecanismo de despacho por-gesto; ver
# lib-mac-ssh-env.sh para el detalle de mac_dispatch().
#
# GOTCHA REAL, PRECONDICION (no es un bug, es un requisito de una sola vez): `screencapture` exige
# permiso TCC de "Grabacion de pantalla" concedido al proceso que lo invoca (Terminal/sshd/lo que
# despache el comando). SIN ese permiso, la captura sale NEGRA (o el comando falla en versiones
# recientes de macOS) -- no hay `tccutil` que lo pre-autorice para un proceso lanzado por SSH; hay
# que concederlo UNA vez via System Settings -> Privacidad y seguridad -> Grabacion de pantalla,
# igual que la excepcion de Red Local de macOS 26 ya documentada en la memoria de maquina.
#
# VERIFICADO 2026-09-18 LOCAL en esta Mac (macOS 26.6.2): `screencapture -x` genero un PNG real de
# 2992x1934 (Retina), 642KB, mostrando el escritorio real -- el permiso TCC ya estaba concedido al
# proceso que corrio la prueba, asi que este script en si SI funciona de punta a punta; lo que NO
# se pudo confirmar en esta pasada es el caso de una sesion SSH genuina contra un proceso SIN el
# permiso ya concedido (ver nota en lib-mac-ssh-env.sh sobre por que no se probo loopback SSH real).
#
# USO (por SSH):
#   mac-ssh-screenshot.sh                       # guarda PNG, imprime ruta+tamano
#   mac-ssh-screenshot.sh -B64                  # ademas IMPRIME el PNG en base64
#   mac-ssh-screenshot.sh -Out /tmp/x.png -B64
#   mac-ssh-screenshot.sh -Window "Kate"        # solo esa ventana (por titulo, via System Events)
#
# EXIT: 0 si genero el PNG; 1 sin sesion de consola / screencapture fallo (probable TCC faltante).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-mac-ssh-env.sh
source "$SCRIPT_DIR/lib-mac-ssh-env.sh"

Out="/tmp/mac-ssh-shot.png"
B64=0
Window=""
WaitMs=0

while [ $# -gt 0 ]; do
    case "$1" in
        -Out) Out="$2"; shift 2 ;;
        -B64) B64=1; shift ;;
        -Window) Window="$2"; shift 2 ;;
        -WaitMs) WaitMs="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done

cu="$(mac_console_user)"
[ -z "$cu" ] && { echo "SIN sesion de consola activa" >&2; exit 1; }

mkdir -p "$(dirname "$Out")"
[ "$WaitMs" -gt 0 ] 2>/dev/null && sleep "$(awk "BEGIN{print $WaitMs/1000}")"
rm -f "$Out"

wid=""
if [ -n "$Window" ]; then
    wid=$(mac_dispatch osascript -e "tell application \"System Events\" to return id of (first window whose (name contains \"$Window\")) of (first application process whose (exists (first window whose name contains \"$Window\")))" 2>/dev/null)
fi
if [ -n "$wid" ]; then
    mac_dispatch screencapture -x -l "$wid" "$Out" 2>/dev/null
else
    mac_dispatch screencapture -x "$Out" 2>/dev/null
fi

if [ ! -s "$Out" ]; then
    echo "FALLO: no se genero el PNG (revisa el permiso TCC de Grabacion de pantalla -- ver arriba)" >&2
    exit 1
fi

sz=$(wc -c < "$Out" | tr -d ' ')
if [ "$B64" -eq 1 ]; then
    base64 -i "$Out" | tr -d '\n'
    echo ""
else
    echo "OK screenshot -> $Out ($sz bytes, usuario $cu)"
fi
exit 0
