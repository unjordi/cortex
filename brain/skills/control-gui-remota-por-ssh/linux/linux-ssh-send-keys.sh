#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit linux-ssh-*; ver ../SKILL.md
#
# linux-ssh-send-keys.sh - Envia TECLAS a la sesion grafica interactiva, POR SSH.
# ==================================================================================================
# Via xdotool key/type (XTest sobre XWayland/X11 -- mismo alcance y mismo GOTCHA del permiso EIS de
# KWin que linux-ssh-send-click.sh; leelo ahi si no lo conoces).
#
# SINTAXIS DE -Keys (mini-lenguaje ADAPTADO del SendKeys de Windows, mismos tokens donde aplica):
#   texto normal se teclea literal;  {ENTER} {TAB} {ESC} {BACKSPACE} {DEL} {F1}..{F12}
#   {UP} {DOWN} {LEFT} {RIGHT}
#   modificadores de UN caracter antes de OTRO token: ^=Ctrl  %=Alt  +=Shift  (ej. "^a"=Ctrl+A,
#   "%{F4}"=Alt+F4). A diferencia de Windows, estos modificadores en este script SOLO combinan con
#   el token INMEDIATO siguiente (no hay estado de modificador sostenido entre tokens).
#
# USO (por SSH):
#   linux-ssh-send-keys.sh -Keys "usuario{TAB}clave{ENTER}"
#   linux-ssh-send-keys.sh -Keys "N" -Window "MiApp - Herramienta"
#   linux-ssh-send-keys.sh -Keys "%{F4}"                        # Alt+F4 (cerrar ventana activa)
#   linux-ssh-send-keys.sh -Keys "^a{DEL}texto" -ClickX 701 -ClickY 451   # clic (foco) + teclea
#
# -ClickX/-ClickY: hace click ahi ANTES de teclear, en la MISMA invocacion. En Windows esto evita
# perder el foco entre DOS tareas /IT separadas; aqui no hay ese riesgo especifico (todo corre en
# UN proceso), pero se conserva el flag por PARIDAD de firma y porque sigue siendo util: enfoca el
# campo correcto antes de teclear sin un paso manual aparte.
#
# EXIT: 0 si xdotool despacho las teclas (no garantiza que aterrizaron -- verifica con screenshot);
# 1 si no hay sesion grafica o falta xdotool.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-linux-ssh-env.sh
source "$SCRIPT_DIR/lib-linux-ssh-env.sh"

Keys=""; Window=""; ClickX=""; ClickY=""

while [ $# -gt 0 ]; do
    case "$1" in
        -Keys) Keys="$2"; shift 2 ;;
        -Window) Window="$2"; shift 2 ;;
        -ClickX) ClickX="$2"; shift 2 ;;
        -ClickY) ClickY="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done
[ -z "$Keys" ] && { echo "Falta -Keys" >&2; exit 2; }

resolve_session_env
if ! has_session_desktop; then echo "SIN sesion grafica activa" >&2; exit 1; fi
command -v xdotool >/dev/null 2>&1 || { echo "FALTA xdotool" >&2; exit 1; }

if [ -n "$Window" ]; then
    xdotool search --name "$Window" windowactivate --sync 2>/dev/null | head -1
    sleep 0.4
fi
if [ -n "$ClickX" ] && [ -n "$ClickY" ]; then
    xdotool mousemove "$ClickX" "$ClickY" click 1
    sleep 0.3
fi

# --- traductor del mini-lenguaje {TOKEN} / ^%+ -> nombres de tecla xdotool ---
send_token() {
    local tok="$1" mods="$2" xkey=""
    case "$tok" in
        ENTER) xkey="Return" ;;
        TAB) xkey="Tab" ;;
        ESC) xkey="Escape" ;;
        BACKSPACE) xkey="BackSpace" ;;
        DEL) xkey="Delete" ;;
        UP) xkey="Up" ;; DOWN) xkey="Down" ;; LEFT) xkey="Left" ;; RIGHT) xkey="Right" ;;
        F1|F2|F3|F4|F5|F6|F7|F8|F9|F10|F11|F12) xkey="$tok" ;;
        *) xkey="$tok" ;;
    esac
    if [ -n "$mods" ]; then
        xdotool key "${mods}${xkey}"
    else
        xdotool key "$xkey"
    fi
}

i=0; len=${#Keys}; mods=""
while [ $i -lt $len ]; do
    c="${Keys:$i:1}"
    case "$c" in
        '^') mods="${mods}ctrl+"; i=$((i+1)) ;;
        '%') mods="${mods}alt+"; i=$((i+1)) ;;
        '+') mods="${mods}shift+"; i=$((i+1)) ;;
        '{')
            close=$(expr index "${Keys:$i}" '}')
            if [ "$close" -eq 0 ]; then
                xdotool type --clearmodifiers -- "$c"; i=$((i+1))
            else
                tok="${Keys:$((i+1)):$((close-2))}"
                send_token "$tok" "$mods"
                mods=""
                i=$((i+close))
            fi
            ;;
        *)
            if [ -n "$mods" ]; then
                # atajo con modificador sobre un caracter literal (ej. ^a)
                xdotool key "${mods}${c}"
                mods=""
            else
                xdotool type --clearmodifiers -- "$c"
            fi
            i=$((i+1))
            ;;
    esac
done

echo "OK teclas enviadas (verifica con screenshot -- xdotool no confirma que aterrizaron)"
exit 0
