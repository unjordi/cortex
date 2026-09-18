#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit mac-ssh-*; ver ../SKILL.md
#
# mac-ssh-send-click.sh - Manda UN click (o doble/derecho) por COORDENADA, POR SSH.
# ==================================================================================================
# Via cliclick (brew install cliclick) -- CLI dedicado, confiable, via CGEventCreateMouseEvent de
# bajo nivel. Es la UNICA via que este kit soporta para clicks -- el verbo AppleScript equivalente
# de System Events resulto poco fiable en la version de macOS probada (ver nota mas abajo) y ademas
# es un patron asociado a malware de automatizacion de permisos en macOS, asi que este kit no lo
# incluye como fallback ejecutable.
#
# PRECONDICION TCC: cliclick necesita el permiso de Accesibilidad concedido al proceso que lo
# invoca (Terminal/sshd), concedido UNA vez via System Settings -> Privacidad y seguridad ->
# Accesibilidad -- igual precondicion que el screenshot necesita para Grabacion de pantalla.
#
# VERIFICADO 2026-09-18 LOCAL en esta Mac (macOS 26.6.2): `brew install cliclick` + `cliclick
# m:X,Y` + `cliclick c:.` corrieron sin error (exit 0) con el permiso de Accesibilidad ya concedido.
# El verbo AppleScript de System Events para clicks por coordenada (fuera del alcance de este kit)
# fallo con error -25200 en esta misma maquina/version -- otro motivo para no depender de el.
# NO se hizo click sobre un elemento real de la UI del usuario en vivo para evitar interferir con
# una sesion de trabajo activa en pantalla.
#
# USO (por SSH):
#   mac-ssh-send-click.sh -X 500 -Y 500
#   mac-ssh-send-click.sh -X 500 -Y 500 -Window "MiApp"    # activa esa app antes de clickear
#   mac-ssh-send-click.sh -X 900 -Y 400 -Button right
#   mac-ssh-send-click.sh -X 240 -Y 560 -Double
#
# EXIT: 0 si despacho el click; 1 sin sesion de consola / falta cliclick.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-mac-ssh-env.sh
source "$SCRIPT_DIR/lib-mac-ssh-env.sh"

X=""; Y=""; Button="left"; Double=0; Window=""

while [ $# -gt 0 ]; do
    case "$1" in
        -X) X="$2"; shift 2 ;;
        -Y) Y="$2"; shift 2 ;;
        -Button) Button="$2"; shift 2 ;;
        -Double) Double=1; shift ;;
        -Window) Window="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done
[ -z "$X" ] || [ -z "$Y" ] && { echo "Faltan -X -Y" >&2; exit 2; }

cu="$(mac_console_user)"
[ -z "$cu" ] && { echo "SIN sesion de consola activa" >&2; exit 1; }
mac_dispatch command -v cliclick >/dev/null 2>&1 || { echo "FALTA cliclick (brew install cliclick)" >&2; exit 1; }

if [ -n "$Window" ]; then
    mac_dispatch osascript -e "tell application \"$Window\" to activate" >/dev/null 2>&1
    sleep 0.4
fi

case "$Button:$Double" in
    left:0)  mac_dispatch cliclick "c:$X,$Y" ;;
    left:1)  mac_dispatch cliclick "dc:$X,$Y" ;;
    right:*) mac_dispatch cliclick "rc:$X,$Y" ;;
    *)       mac_dispatch cliclick "c:$X,$Y" ;;
esac

dbl=""
[ "$Double" -eq 1 ] && dbl="-doble"
echo "OK click ${Button}${dbl} en $X,$Y (via cliclick, usuario $cu)"
exit 0
