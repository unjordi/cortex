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
# GOTCHA REAL MULTI-MONITOR (hallado por QA en vivo 2026-09-18, corregido el mismo dia): a
# diferencia de win-ssh-screenshot.ps1 (que captura el VirtualScreen COMPLETO -- todos los
# monitores en una sola imagen), `screencapture -x archivo.png` SIN flags captura SOLO la pantalla
# PRINCIPAL -- una ventana en un monitor externo NO sale. VERIFICADO en esta Mac (3 pantallas: Retina
# integrada 2992x1934 + 2 externas 3440x1440 c/u): `screencapture -x out.png` (sin flags) dio
# EXACTAMENTE el mismo resultado que `-D 1` (solo la principal). macOS NO tiene una opcion nativa
# para "una sola imagen con TODOS los monitores cosidos" como el VirtualScreen de Windows -- lo mas
# cercano y soportado es pasar VARIOS archivos de salida (uno por pantalla, en orden), que
# `screencapture` llena una por una. Por eso, PARIDAD ADAPTADA (documentada, no oculta): por
# DEFAULT este script ahora captura **TODAS** las pantallas, una imagen POR pantalla (no una imagen
# gigante cosida) -- "por default veo TODO" se cumple, solo que como N archivos en vez de 1.
#
# VERIFICADO 2026-09-18 LOCAL en esta Mac (macOS 26.6.2, 3 pantallas reales conectadas):
#   -D 1 -> PNG 2992x1934 (Retina integrada, la principal)
#   -D 2 -> PNG 3440x1440 (externa 1)
#   -D 3 -> PNG 3440x1440 (externa 2)
#   3 archivos de salida (uno por pantalla) -> cada uno con la resolucion real de SU pantalla.
# El permiso TCC ya estaba concedido al proceso que corrio la prueba.
#
# USO (por SSH):
#   mac-ssh-screenshot.sh                        # DEFAULT: TODAS las pantallas, 1 archivo c/u
#   mac-ssh-screenshot.sh -Display 2              # SOLO la pantalla 2 (1=principal, 2=siguiente...)
#   mac-ssh-screenshot.sh -Window "Kate"          # SOLO esa ventana (por titulo, via System Events)
#   mac-ssh-screenshot.sh -Out /tmp/x.png -B64    # guarda + imprime base64 (una pantalla/ventana)
#   mac-ssh-screenshot.sh -B64                    # TODAS las pantallas, cada una con su base64
#
# Con -Out (default /tmp/mac-ssh-shot.png) y captura de UNA sola imagen (-Display/-Window, o solo
# hay 1 pantalla conectada), el PNG se guarda LITERAL en esa ruta. Con el default multi-pantalla
# (N>1 y ni -Display ni -Window), -Out se usa como BASE: "/tmp/mac-ssh-shot.png" -> se guardan
# "/tmp/mac-ssh-shot-1.png", "/tmp/mac-ssh-shot-2.png", ... (uno por pantalla).
#
# EXIT: 0 si genero al menos un PNG; 1 sin sesion de consola / screencapture fallo (probable TCC
# faltante).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-mac-ssh-env.sh
source "$SCRIPT_DIR/lib-mac-ssh-env.sh"

Out="/tmp/mac-ssh-shot.png"
B64=0
Window=""
Display=""
WaitMs=0

while [ $# -gt 0 ]; do
    case "$1" in
        -Out) Out="$2"; shift 2 ;;
        -B64) B64=1; shift ;;
        -Window) Window="$2"; shift 2 ;;
        -Display) Display="$2"; shift 2 ;;
        -WaitMs) WaitMs="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done

cu="$(mac_console_user)"
[ -z "$cu" ] && { echo "SIN sesion de consola activa" >&2; exit 1; }

mkdir -p "$(dirname "$Out")"
[ "$WaitMs" -gt 0 ] 2>/dev/null && sleep "$(awk "BEGIN{print $WaitMs/1000}")"

report_one() {
    local path="$1"
    if [ ! -s "$path" ]; then
        echo "FALLO: no se genero $path (revisa el permiso TCC de Grabacion de pantalla)" >&2
        return 1
    fi
    local sz wh
    sz=$(wc -c < "$path" | tr -d ' ')
    wh=$(sips -g pixelWidth -g pixelHeight "$path" 2>/dev/null | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w"x"h}')
    if [ "$B64" -eq 1 ]; then
        echo "== $path ($wh, $sz bytes) =="
        base64 -i "$path" | tr -d '\n'
        echo ""
    else
        echo "OK screenshot -> $path ($wh, $sz bytes, usuario $cu)"
    fi
    return 0
}

# --- caso 1: ventana especifica por titulo ---
if [ -n "$Window" ]; then
    wid=$(mac_dispatch osascript -e "tell application \"System Events\" to return id of (first window whose (name contains \"$Window\")) of (first application process whose (exists (first window whose name contains \"$Window\")))" 2>/dev/null)
    rm -f "$Out"
    if [ -n "$wid" ]; then
        mac_dispatch screencapture -x -l "$wid" "$Out" 2>/dev/null
    else
        echo "no encontre ventana que contenga '$Window' -- capturo pantalla principal en su lugar" >&2
        mac_dispatch screencapture -x "$Out" 2>/dev/null
    fi
    report_one "$Out" || exit 1
    exit 0
fi

# --- caso 2: una pantalla concreta por numero ---
if [ -n "$Display" ]; then
    rm -f "$Out"
    mac_dispatch screencapture -x -D "$Display" "$Out" 2>/dev/null
    report_one "$Out" || exit 1
    exit 0
fi

# --- caso 3 (DEFAULT): TODAS las pantallas -- paridad con el VirtualScreen de Windows, adaptada a
# N archivos (uno por pantalla) porque screencapture no ofrece un "una sola imagen cosida" nativo ---
n=$(mac_display_count)
if [ "$n" -le 1 ]; then
    rm -f "$Out"
    mac_dispatch screencapture -x "$Out" 2>/dev/null
    report_one "$Out" || exit 1
    exit 0
fi

base="${Out%.*}"; ext="${Out##*.}"
ok=0
for i in $(seq 1 "$n"); do
    f="${base}-${i}.${ext}"
    rm -f "$f"
    mac_dispatch screencapture -x -D "$i" "$f" 2>/dev/null
    report_one "$f" && ok=$((ok+1))
done
[ "$ok" -eq 0 ] && exit 1
exit 0
