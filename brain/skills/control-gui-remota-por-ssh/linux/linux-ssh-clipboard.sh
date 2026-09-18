#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit linux-ssh-*; ver ../SKILL.md
#
# linux-ssh-clipboard.sh - Lee/escribe el portapapeles de la sesion grafica, POR SSH.
# ==================================================================================================
# Preferido: wl-copy/wl-paste (wl-clipboard, protocolo Wayland nativo) si hay WAYLAND_DISPLAY.
# Fallback: xclip/xsel (X11/XWayland) si no hay Wayland. NO dispara el permiso EIS de KWin (el
# portapapeles es un protocolo aparte, no input sintetico) -- VERIFICADO 2026-09-18 en cachy:
# `wl-copy`/`wl-paste` funcionaron sin ningun prompt.
#
# GOTCHA REAL (verificado 2026-09-18): `wl-copy` por diseno SE QUEDA CORRIENDO en segundo plano
# para poder SERVIR la seleccion mientras nadie la sobreescribe -- si lo corres en primer plano
# dentro de un comando SSH, la sesion SSH se queda COLGADA esperando a que ese proceso termine
# (nunca termina solo). Este script lo lanza con `setsid ... &` + `disown` para evitar el cuelgue.
#
# USO (por SSH):
#   linux-ssh-clipboard.sh -Get
#   linux-ssh-clipboard.sh -Set "texto a copiar"
#
# EXIT: 0 ok; 1 sin sesion grafica / falta herramienta de portapapeles.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-linux-ssh-env.sh
source "$SCRIPT_DIR/lib-linux-ssh-env.sh"

Get=0; SetText=""
while [ $# -gt 0 ]; do
    case "$1" in
        -Get) Get=1; shift ;;
        -Set) SetText="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done
[ "$Get" -eq 0 ] && [ -z "$SetText" ] && { echo "Da -Get o -Set \"texto\"" >&2; exit 2; }

resolve_session_env
if ! has_session_desktop; then echo "SIN sesion grafica activa" >&2; exit 1; fi

if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-paste >/dev/null 2>&1; then
    if [ "$Get" -eq 1 ]; then
        wl-paste -n 2>/dev/null
    else
        printf '%s' "$SetText" | setsid nohup wl-copy >/dev/null 2>&1 &
        disown
        echo "OK portapapeles (wl-copy) <- \"$SetText\""
    fi
elif command -v xclip >/dev/null 2>&1; then
    if [ "$Get" -eq 1 ]; then
        DISPLAY="$DISPLAY" xclip -selection clipboard -o 2>/dev/null
    else
        printf '%s' "$SetText" | DISPLAY="$DISPLAY" xclip -selection clipboard
        echo "OK portapapeles (xclip) <- \"$SetText\""
    fi
elif command -v xsel >/dev/null 2>&1; then
    if [ "$Get" -eq 1 ]; then
        DISPLAY="$DISPLAY" xsel --clipboard --output 2>/dev/null
    else
        printf '%s' "$SetText" | DISPLAY="$DISPLAY" xsel --clipboard --input
        echo "OK portapapeles (xsel) <- \"$SetText\""
    fi
else
    echo "FALTA herramienta de portapapeles (wl-clipboard / xclip / xsel)" >&2
    exit 1
fi
exit 0
