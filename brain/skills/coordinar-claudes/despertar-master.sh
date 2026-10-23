#!/usr/bin/env bash
# despertar-master.sh — resuelve y DESPIERTA una sesión master de Claude Code desde la FUENTE
# CONFIABLE (los transcripts locales), NO desde masters.json (que driftea y genera conflictos de sync).
#
# Fuente de verdad cada transcript ~/.claude/projects/<slug>/<id>.jsonl trae el
# NOMBRE en su último `"customTitle"` (el CLI le agrega " (N)" al duplicar un nombre), el folder de
# resume en su último `"cwd"`, y la vida en el mtime del archivo. Por NOMBRE gana el transcript MÁS
# RECIENTE — así "<x>-master (2)" (vivo) le gana a "<x>-master" (viejo), sin preguntarle a nadie.
#
# Modos:
#   despertar-master.sh                 lista los masters (igual que --lista)
#   despertar-master.sh --lista|-l      tabla: nombre · id · edad · estado (viva/idle) · cwd
#   despertar-master.sh <nombre>        despierta ese master (o avisa que ya está vivo y NO lo relanza)
#   despertar-master.sh <nombre> --no-esperar   lanza y regresa sin esperar a que cargue
#   despertar-master.sh <nombre> --mensaje <archivo>   lo despierta y le entrega <archivo> como su primer
#                                       mensaje (prompt inicial del resume; no depende de teclear en la TUI)
#   despertar-master.sh --cerrar <nombre>   cierra la sesión (proceso claude + screen) y verifica que cerró
#   despertar-master.sh --curar         (re)genera el roster LOCAL ~/.claude/masters.json desde los
#                                       transcripts vivos de *-master (curado de ids idle se conserva)
#   despertar-master.sh --help|-h       esta ayuda
#
# Overrides: $DESPERTAR_VIVA_MIN (min para considerar viva una sesión, def 15) ·
#            $DESPERTAR_ESPERA_S (seg a esperar la carga tras lanzar, def 240) ·
#            $CLAUDE_PROJECTS_DIR (carpeta de transcripts, def ~/.claude/projects).
set -u

VIVA_MIN="${DESPERTAR_VIVA_MIN:-15}"
ESPERA_S="${DESPERTAR_ESPERA_S:-240}"
PROJECTS="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"

# ── helpers de lectura del transcript ────────────────────────────────────────────────────────────
# mtime epoch PORTABLE: GNU `stat -c %Y` PRIMERO (falla LIMPIO en BSD, sin ensuciar stdout), luego BSD
# `stat -f %m`. Al revés MUERDE: en GNU `-f` es --file-system y `%m` vuelca basura con exit 0 → rompe
# la aritmética bajo set -u.
_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }
_edad_min() {
  local m now; m="$(_mtime "$1")"; case "$m" in ''|*[!0-9]*) m=0 ;; esac
  now="$(date +%s 2>/dev/null || echo 0)"
  echo $(( (now - m) / 60 ))
}
# último customTitle del transcript, SIN el sufijo " (N)" que el CLI agrega al duplicar nombres.
_titulo() { grep -ao '"customTitle":"[^"]*"' "$1" 2>/dev/null | tail -1 | cut -d'"' -f4 | sed 's/ ([0-9]\{1,\})$//'; }
# último cwd del transcript (dónde resumir la sesión).
_cwd() { grep -ao '"cwd":"[^"]*"' "$1" 2>/dev/null | tail -1 | cut -d'"' -f4; }
# resume-safe cwd: si el último cwd cae en un worktree ENLAZADO (git-dir != git-common-dir), ese folder
# puede MORIR al borrarse el worktree tras un merge → resuelve al toplevel del worktree PRINCIPAL (1ª
# entrada de `git worktree list`). Un cwd que es el árbol principal o un SUBFOLDER del repo (git-dir ==
# git-common-dir) se deja INTACTO (no se saca a un master que vive a propósito en un subdir). Fuera de un
# repo git, o si el cwd no existe aquí (otra máquina), se devuelve crudo.
_resolver_cwd() {
  local c="$1" gd gcd main
  [ -n "$c" ] && [ -d "$c" ] || { printf '%s' "$c"; return; }
  gd=$(git -C "$c" rev-parse --git-dir 2>/dev/null) || { printf '%s' "$c"; return; }
  gcd=$(git -C "$c" rev-parse --git-common-dir 2>/dev/null)
  if [ -n "$gcd" ] && [ "$gd" != "$gcd" ]; then
    main=$(git -C "$c" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')
    [ -n "$main" ] && [ -d "$main" ] && { printf '%s' "$main"; return; }
  fi
  printf '%s' "$c"
}

# ── vida por SEÑAL DIRECTA, no solo mtime ─────────────────────────────────────────────────────────
# El mtime del transcript es un PROXY: un master puede estar VIVO pero idle > VIVA_MIN. La señal
# AUTORITATIVA es que corra su `screen` (así lo lanza esta skill) o un proceso `claude --resume <id>`.
# Sin esto, relanzar un master idle crea un 2º escritor sobre su transcript (doble lanzamiento
# sobre el mismo id). Residual conocido: una sesión hospedada
# por `claude daemon`, idle y sin screen, NO trae el id en su cmdline → no se detecta por proceso; el
# mtime la cubre mientras se use (escribe su transcript) y el screen cubre las lanzadas por aquí.
# Fail-open: sin screen/pgrep estas señales no aplican y manda el mtime.
_screen_nombres() { screen -ls 2>/dev/null | sed -n 's/^[[:space:]]*[0-9][0-9]*\.\([^[:space:]]*\).*/\1/p'; }
# _pids_master NOMBRE ID → PIDs de procesos `claude` retomados por id o por título.
# Solo cuenta un proceso cuyo EJECUTABLE (argv[0]) es `claude`: así nunca se cuenta a sí mismo ni a un
# bash/grep/script que lleve el patrón en su línea de comando. Usa ps: pgrep -f no ve los argumentos de
# algunos procesos en macOS.
_pids_master() {
  local name="$1" id="$2"
  ps -axo pid=,command= 2>/dev/null | awk -v id="${id:-@@}" -v name="$name" '
    { exe=$2; sub(/.*\//, "", exe); if (exe != "claude") next
      for (k=3; k<=NF; k++) if ($k ~ /^--resume/) {
        v=$k; sub(/^--resume=?/, "", v)
        if (v == "") for (m=k+1; m<=NF; m++) if ($m !~ /^--/) { v=$m; break }
        if (v == id || v == name) { print $1; next }
      } }'
}
_vivo_por_senal() {   # NAME ID → 0 si hay un screen con ese nombre o un proceso claude --resume <id>
  local name="$1" id="$2"
  _screen_nombres | grep -qxF "$name" && return 0
  [ -n "$(_pids_master "$name" "$id")" ] && return 0   # por id o por título
  return 1
}
_viva() {   # EDAD NAME ID → 0 si viva por mtime reciente O por señal directa (screen/proceso)
  local edad="$1" name="$2" id="$3"
  [ "${edad:-999999}" -lt "$VIVA_MIN" ] 2>/dev/null && return 0
  _vivo_por_senal "$name" "$id"
}

# imprime "<edad_min>\t<nombre>\t<id>\t<cwd>\t<transcript>" por CADA transcript cuyo título contenga
# "-master", del MÁS NUEVO al más viejo (ls -t). Sin coincidencias → nada (no truena; no hay pipefail).
_enumerar() {
  local f t id edad cwd
  while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$f" ] || continue
    t="$(_titulo "$f")"
    case "$t" in *-master*) ;; *) continue ;; esac
    id="$(basename "$f" .jsonl)"
    edad="$(_edad_min "$f")"
    cwd="$(_resolver_cwd "$(_cwd "$f")")"
    printf '%s\t%s\t%s\t%s\t%s\n' "$edad" "$t" "$id" "$cwd" "$f"
  done < <(ls -t "$PROJECTS"/*/*.jsonl 2>/dev/null)
}

# una fila por NOMBRE: la del transcript MÁS RECIENTE (primera aparición, porque _enumerar va newest-first).
_tabla() { _enumerar | awk -F'\t' '!seen[$2]++'; }

# ── modos ────────────────────────────────────────────────────────────────────────────────────────
uso() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
}

listar() {
  local edad t id cwd estado n=0
  # Columnas en ASCII puro: un glifo multibyte (●/─) descuadra printf %-Ns (cuenta bytes, no ancho).
  printf '%-26s %-8s %-6s %s\n' "MASTER" "EDAD" "ESTADO" "CWD (resume)"
  printf '%-26s %-8s %-6s %s\n' "--------------------------" "--------" "------" "------------"
  while IFS=$'\t' read -r edad t id cwd _; do
    [ -n "$t" ] || continue
    if _viva "$edad" "$t" "$id"; then estado="viva"; else estado="idle"; fi
    printf '%-26s %-8s %-6s %s\n' "$t" "${edad}m" "$estado" "$cwd"
    n=$((n+1))
  done < <(_tabla)
  [ "$n" -gt 0 ] || echo "(sin sesiones *-master en $PROJECTS)"
}

# captura la pantalla de un screen (NECESITA -p 0 -h; sin eso sale vacía ).
_pantalla() {
  local f out; f="$(mktemp 2>/dev/null)" || return 1
  screen -S "$1" -p 0 -X hardcopy -h "$f" 2>/dev/null || true
  LC_ALL=C sed 's/[^[:print:]]//g' "$f" 2>/dev/null
  rm -f "$f" 2>/dev/null
}

# espera hasta ESPERA_S a que la sesión relanzada pinte su URL de sesión (la devuelve) o pida confiar
# el folder (lo reporta). Devuelve 0+URL, 2+"TRUST", o 1 (timeout).
_esperar_carga() {
  local nombre="$1" fin out url
  fin=$(( $(date +%s) + ESPERA_S ))
  while [ "$(date +%s)" -lt "$fin" ]; do
    sleep 4
    out="$(_pantalla "$nombre")"
    url="$(printf '%s' "$out" | grep -ao 'https://claude.ai/code/session_[A-Za-z0-9_]*' | tail -1)"
    if [ -n "$url" ]; then printf '%s' "$url"; return 0; fi
    case "$out" in
      *"trust this folder"*|*"Do you trust"*|*"trust the files"*) return 2 ;;
    esac
  done
  return 1
}

despertar() {
  local nombre="$1" esperar="${2:-si}" msgf="${3:-}" row edad t id cwd inner
  row="$(_tabla | awk -F'\t' -v n="$nombre" '$2==n {print; exit}')"
  if [ -z "$row" ]; then
    echo "[despertar-master] no encontré un master llamado '$nombre'." >&2
    echo "Masters disponibles:" >&2
    listar >&2
    return 1
  fi
  IFS=$'\t' read -r edad t id cwd _ <<EOF
$row
EOF

  if _viva "$edad" "$t" "$id"; then
    local porque="mtime ${edad}m"
    _vivo_por_senal "$t" "$id" && porque="screen/proceso corriendo"
    echo "[despertar-master] '$t' ya está VIVA ($porque). NO la relanzo (evito un 2º escritor sobre su transcript)."
    echo "   id=$id  cwd=$cwd"
    echo "   (si de verdad quieres otra instancia, resúmela a mano: cd '$cwd' && claude --resume $id)"
    return 0
  fi

  [ -d "$cwd" ] || { echo "[despertar-master] el cwd de '$t' no existe en esta máquina: $cwd" >&2; return 1; }
  command -v screen >/dev/null 2>&1 || { echo "[despertar-master] falta 'screen' en esta máquina." >&2; return 1; }

  # Limpia TODO CLAUDE* heredado antes de lanzar: si el hijo hereda CLAUDECODE/CLAUDE_PID se cree anidado
  # y NO guarda transcript. El claude hijo re-lee su settings.json, así que desechar los CLAUDE* es seguro.
  inner="for v in \$(compgen -e 2>/dev/null | grep '^CLAUDE' 2>/dev/null); do unset \"\$v\"; done; "
  inner="$inner cd $(printf '%q' "$cwd") && exec claude --resume $(printf '%q' "$id") --remote-control $(printf '%q' "$t")"
  if [ -n "$msgf" ]; then
    [ -f "$msgf" ] || { echo "[despertar-master] no existe el archivo del mensaje: $msgf" >&2; return 1; }
    inner="$inner $(printf '%q' "$(cat "$msgf")")"
  fi
  echo "[despertar-master] lanzando '$t'  (id=$id)  en  $cwd …"
  screen -dmS "$t" bash -lc "$inner"

  if [ "$esperar" = "no" ]; then
    echo "   lanzada en screen '$t'. Revisa con: screen -r $t   (o -X hardcopy -p 0 -h)"
    return 0
  fi

  local res rc
  res="$(_esperar_carga "$t")"; rc=$?
  case "$rc" in
    0) echo "   ✅ '$t' cargó. URL de sesión: $res" ;;
    2) echo "   ⚠️ '$t' pide CONFIAR el folder. Entra con 'screen -r $t', acepta (↓ + Enter / 'y'), y re-chequea." ;;
    *) echo "   ⏳ '$t' no pintó su URL en ${ESPERA_S}s (un transcript grande tarda; arsenal-master ~4 min). Revisa: screen -r $t" ;;
  esac
}

# ── dispatch ─────────────────────────────────────────────────────────────────────────────────────
# cerrar NOMBRE → cierra el proceso `claude` de ese master (por id o por título) y su screen; verifica.
cerrar() {
  local nombre="$1" row id pids i
  row="$(_tabla | awk -F'\t' -v n="$nombre" '$2==n {print; exit}')"
  [ -n "$row" ] || { echo "[despertar-master] no encontré un master llamado '$nombre'." >&2; return 1; }
  id="$(printf '%s' "$row" | cut -f3)"
  pids="$(_pids_master "$nombre" "$id")"
  [ -n "$pids" ] && kill -TERM $pids 2>/dev/null
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [ -n "$(_pids_master "$nombre" "$id")" ] || break; sleep 1
  done
  screen -S "$nombre" -X quit >/dev/null 2>&1 || true
  if [ -n "$(_pids_master "$nombre" "$id")" ] || _screen_nombres | grep -qxF "$nombre"; then
    echo "[despertar-master] '$nombre' NO cerró (proceso o screen vivos)." >&2; return 1
  fi
  echo "[despertar-master] '$nombre' cerrado (sin proceso ni screen)."
}

# --curar → (re)genera el ROSTER LOCAL (~/.claude/masters.json, honra CLAUDE_CONFIG_DIR) desde los
# transcripts VIVOS de *-master: un master vivo ACTUALIZA su entrada {id,name,target} (target = cwd RESUELTO
# —worktree→repo principal— con el prefijo $HOME quitado); las entradas curadas de ids NO vistos ahora se
# CONSERVAN (no se borra un master idle). publicar-roster lo publica como masters-<host>.json y seed lo une.
curar() {
  local roster="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/masters.json" live
  command -v node >/dev/null 2>&1 || { echo "[despertar-master] --curar necesita node" >&2; return 1; }
  mkdir -p "$(dirname "$roster")" 2>/dev/null || true
  live="$(_tabla | while IFS=$'\t' read -r edad t id cwd _; do
            [ -n "$t" ] && [ -n "$id" ] || continue
            printf '%s\t%s\t%s\n' "$id" "$t" "${cwd#"$HOME/"}"
          done)"
  printf '%s' "$live" | node -e '
    const fs=require("fs"), roster=process.argv[1];
    const m=new Map();
    try{ const j=JSON.parse(fs.readFileSync(roster,"utf8")); for(const e of (j.masters||[])) if(e&&e.id) m.set(e.id,{id:e.id,name:e.name||e.id,target:e.target||""}); }catch(_){}
    let upd=0;
    for(const ln of fs.readFileSync(0,"utf8").split("\n").filter(Boolean)){
      const [id,name,target]=ln.split("\t"); if(!id) continue;
      m.set(id,{id,name:name||id,target:target||""}); upd++;
    }
    fs.writeFileSync(roster, JSON.stringify({masters:[...m.values()]},null,2)+"\n");
    process.stderr.write("[despertar-master] roster curado: "+roster+" ("+m.size+" master(s); "+upd+" vivo(s) refrescado(s))\n");
  ' "$roster"
}

case "${1:-}" in
  ""|--lista|-l)     listar ;;
  --curar)           curar ;;
  --cerrar)          [ -n "${2:-}" ] || { echo "[despertar-master] uso: --cerrar <nombre>" >&2; exit 2; }; cerrar "$2" ;;
  --help|-h)         uso ;;
  --*)               echo "[despertar-master] opción desconocida: $1" >&2; uso >&2; exit 2 ;;
  *)
    case "${2:-}" in
      --no-esperar) despertar "$1" no ;;
      "")           despertar "$1" si ;;
      --mensaje)    [ -n "${3:-}" ] || { echo "[despertar-master] uso: <nombre> --mensaje <archivo>" >&2; exit 2; }
                    VIVA_MIN=0; despertar "$1" si "$3" ;;   # edad 0: decide solo por proceso/screen
      *)            echo "[despertar-master] argumento extra desconocido: $2" >&2; exit 2 ;;
    esac
    ;;
esac
