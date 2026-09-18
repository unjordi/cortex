#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit linux-ssh-*; ver ../SKILL.md
#
# linux-ssh-send-click.sh - Manda UN click (o doble/derecho) por COORDENADA, POR SSH.
# ==================================================================================================
# Via xdotool (protocolo XTest sobre XWayland/X11) -- por eso SOLO alcanza ventanas X11/XWayland
# (apps nativas Wayland no reciben el evento; ver limite documentado en ../SKILL.md).
#
# GOTCHA REAL, CRITICO (verificado 2026-09-18 en cachy, KDE Plasma 6.7): KWin pide una
# CONFIRMACION GRAFICA de un humano ("Control remoto: xdotool esta solicitando controlar
# dispositivos de entrada" -> Permitir/Denegar) la PRIMERA vez que xdotool intenta mover el mouse o
# mandar una tecla en la sesion -- es el analogo Linux/Wayland al permiso TCC de Accesibilidad de
# macOS. HASTA que un humano clickea "Permitir" (idealmente marcando "permitir siempre") en la
# consola real de la maquina, el evento se DESCARTA EN SILENCIO: xdotool sale con exit 0 igual
# (fire-and-forget, no espera la decision) -- el exit code NO es evidencia de que el click aterrizo.
# SIEMPRE verifica con un screenshot antes/despues, nunca confies solo en el exit code.
# Atajo (para el DUENO de la maquina, no lo corras tu solo por SSH sin avisar -- es un cambio de
# seguridad): `kwriteconfig6 --file kwinrc --group Xwayland --key XwaylandEisNoPromptApps xdotool`
# + `qdbus6 org.kde.KWin /KWin reconfigure` pre-autoriza xdotool sin volver a preguntar.
#
# USO (por SSH):
#   linux-ssh-send-click.sh -X 1180 -Y 590
#   linux-ssh-send-click.sh -X 1180 -Y 590 -Window "MiApp - Herramienta"   # activa esa ventana antes
#   linux-ssh-send-click.sh -X 900 -Y 400 -Button right
#   linux-ssh-send-click.sh -X 240 -Y 560 -Double
#
# EXIT: 0 si xdotool despacho el evento (NO garantiza que aterrizo -- ver gotcha arriba); 1 si no
# hay sesion grafica o falta xdotool.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-linux-ssh-env.sh
source "$SCRIPT_DIR/lib-linux-ssh-env.sh"

X=""; Y=""; Button="left"; Double=0; Window=""; WaitMs=250

while [ $# -gt 0 ]; do
    case "$1" in
        -X) X="$2"; shift 2 ;;
        -Y) Y="$2"; shift 2 ;;
        -Button) Button="$2"; shift 2 ;;
        -Double) Double=1; shift ;;
        -Window) Window="$2"; shift 2 ;;
        -WaitMs) WaitMs="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done
if [ -z "$X" ] || [ -z "$Y" ]; then echo "Faltan -X -Y" >&2; exit 2; fi

resolve_session_env
if ! has_session_desktop; then echo "SIN sesion grafica activa" >&2; exit 1; fi
command -v xdotool >/dev/null 2>&1 || { echo "FALTA xdotool" >&2; exit 1; }

btn=1
[ "$Button" = "right" ] && btn=3
[ "$Button" = "middle" ] && btn=2

if [ -n "$Window" ]; then
    xdotool search --name "$Window" windowactivate --sync 2>/dev/null | head -1
    sleep 0.4
fi

xdotool mousemove "$X" "$Y"
sleep "$(awk "BEGIN{print $WaitMs/1000}")"
if [ "$Double" -eq 1 ]; then
    xdotool click --repeat 2 --delay 80 "$btn"
else
    xdotool click "$btn"
fi

echo "OK click ${Button}$([ $Double -eq 1 ] && echo -doble) en $X,$Y (verifica con screenshot -- xdotool no confirma que aterrizo)"
exit 0
