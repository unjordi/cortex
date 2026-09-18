#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit mac-ssh-*; ver ../SKILL.md
#
# mac-ssh-send-keys.sh - Envia TECLAS a la sesion de consola, POR SSH.
# ==================================================================================================
# Via cliclick (kp:/t:) cuando esta disponible; fallback osascript System Events `keystroke`
# (VERIFICADO funcionando en esta maquina, distinto del verbo "click at" de send-click que SI fallo
# -- keystroke es fiable).
#
# SINTAXIS DE -Keys (mini-lenguaje ADAPTADO del SendKeys de Windows, mismos tokens donde aplica):
#   texto normal se teclea literal;  {ENTER} {TAB} {ESC} {BACKSPACE} {DEL} {F1}..{F12}
#   {UP} {DOWN} {LEFT} {RIGHT}
#   modificadores de UN caracter antes de OTRO token: ^=Ctrl  %=Option/Alt  +=Shift  #=Command
#   (ej. "^a"=Ctrl+A, "#{c}"=Cmd+C). El simbolo `#` para Command es una ADAPTACION propia de este
#   kit (Windows no lo necesita porque no tiene tecla Command) -- Cmd es el modificador MAS usado en
#   atajos Mac (Cmd+C/V/W/Q...), asi que se agrega en vez de forzar `%` a significar dos cosas.
#
# USO (por SSH):
#   mac-ssh-send-keys.sh -Keys "usuario{TAB}clave{ENTER}"
#   mac-ssh-send-keys.sh -Keys "N" -Window "MiApp"
#   mac-ssh-send-keys.sh -Keys "#{w}"                          # Cmd+W (cerrar ventana)
#   mac-ssh-send-keys.sh -Keys "^a{DEL}texto" -ClickX 701 -ClickY 451   # clic (foco) + teclea
#
# PRECONDICION TCC: igual que send-click, necesita permiso de Accesibilidad concedido una vez.
#
# EXIT: 0 si despacho las teclas; 1 sin sesion de consola.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-mac-ssh-env.sh
source "$SCRIPT_DIR/lib-mac-ssh-env.sh"

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

cu="$(mac_console_user)"
[ -z "$cu" ] && { echo "SIN sesion de consola activa" >&2; exit 1; }

if [ -n "$Window" ]; then
    mac_dispatch osascript -e "tell application \"$Window\" to activate" >/dev/null 2>&1
    sleep 0.4
fi
if [ -n "$ClickX" ] && [ -n "$ClickY" ] && mac_dispatch command -v cliclick >/dev/null 2>&1; then
    mac_dispatch cliclick "c:$ClickX,$ClickY"
    sleep 0.3
fi

# --- traductor {TOKEN} -> nombre de tecla AppleScript "key code"/keystroke especial ---
key_code_for() {
    case "$1" in
        ENTER) echo 36 ;; TAB) echo 48 ;; ESC) echo 53 ;; BACKSPACE) echo 51 ;; DEL) echo 117 ;;
        UP) echo 126 ;; DOWN) echo 125 ;; LEFT) echo 123 ;; RIGHT) echo 124 ;;
        F1) echo 122 ;; F2) echo 120 ;; F3) echo 99 ;; F4) echo 118 ;; F5) echo 96 ;; F6) echo 97 ;;
        F7) echo 98 ;; F8) echo 100 ;; F9) echo 101 ;; F10) echo 109 ;; F11) echo 103 ;; F12) echo 111 ;;
        *) echo "" ;;
    esac
}
mods_to_applescript() {
    local m="$1" out=""
    [[ "$m" == *ctrl* ]]  && out="${out}control down, "
    [[ "$m" == *alt* ]]   && out="${out}option down, "
    [[ "$m" == *shift* ]] && out="${out}shift down, "
    [[ "$m" == *cmd* ]]   && out="${out}command down, "
    echo "${out%, }"
}

send_literal() {
    local text="$1"
    [ -z "$text" ] && return
    # cliclick t: PRIMERO: en macOS 26 `System Events keystroke "con espacios"` DESCARTA los espacios
    # (verificado 2026-09-18, aislado: "a b c" -> "abc"). cliclick los teclea bien. Solo si no hay
    # cliclick se cae al keystroke de osascript (que sirve para texto sin espacios).
    if mac_dispatch command -v cliclick >/dev/null 2>&1; then
        mac_dispatch cliclick -w 0 "t:$text"
    else
        local esc="${text//\\/\\\\}"; esc="${esc//\"/\\\"}"
        mac_dispatch osascript -e "tell application \"System Events\" to keystroke \"$esc\"" 2>/dev/null
    fi
}
send_token() {
    local tok="$1" mods="$2" kc; kc="$(key_code_for "$tok")"
    local aslist; aslist="$(mods_to_applescript "$mods")"
    if [ -n "$kc" ]; then
        if [ -n "$aslist" ]; then
            mac_dispatch osascript -e "tell application \"System Events\" to key code $kc using {$aslist}" 2>/dev/null
        else
            mac_dispatch osascript -e "tell application \"System Events\" to key code $kc" 2>/dev/null
        fi
    else
        # token no reconocido: tratalo como texto literal con modificadores (ej. "#{c}" -> Cmd+C)
        local esc="${tok//\\/\\\\}"; esc="${esc//\"/\\\"}"
        if [ -n "$aslist" ]; then
            mac_dispatch osascript -e "tell application \"System Events\" to keystroke \"$esc\" using {$aslist}" 2>/dev/null
        else
            send_literal "$tok"
        fi
    fi
}

i=0; len=${#Keys}; mods=""; buf=""
flush_buf() { send_literal "$buf"; buf=""; }
while [ $i -lt $len ]; do
    c="${Keys:$i:1}"
    case "$c" in
        '^') flush_buf; mods="${mods}ctrl "; i=$((i+1)) ;;
        '%') flush_buf; mods="${mods}alt "; i=$((i+1)) ;;
        '+') flush_buf; mods="${mods}shift "; i=$((i+1)) ;;
        '#') flush_buf; mods="${mods}cmd "; i=$((i+1)) ;;
        '{')
            flush_buf
            close=$(expr index "${Keys:$i}" '}')
            if [ "$close" -eq 0 ]; then
                buf="${buf}${c}"; i=$((i+1))
            else
                tok="${Keys:$((i+1)):$((close-2))}"
                send_token "$tok" "$mods"
                mods=""
                i=$((i+close))
            fi
            ;;
        *)
            if [ -n "$mods" ]; then
                send_token "$c" "$mods"
                mods=""
            else
                buf="${buf}${c}"
            fi
            i=$((i+1))
            ;;
    esac
done
flush_buf

echo "OK teclas enviadas (usuario $cu, verifica con screenshot)"
exit 0
