# analizar-comando-git.sh — LIB compartida (NO es un hook; se hace `source`). Razona sobre un comando
# git/glab/gh para los git-guards (git-branch-guard · merge-squash-guard · confirmar-merge-develop) →
# UNA sola lógica, dejan de divergir (antídoto al drift H2/H13). bash-3.2-safe. El consumidor verifica
# jq/git si los necesita. Vive junto a los hooks (como delegacion-comun.sh) → viaja en el mismo copy.
# shellcheck shell=bash

# Quita literales entre comillas simples o dobles → un "git push a develop" dentro de un mensaje de
# commit / dato de un grep / doc NO dispara los guards. (Fix #2 · H13.)
acg_despoja_comillas() { printf '%s' "$1" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g"; }

# Quita el VALOR de --repo/-R (p. ej. "-R org/develop") para que un repo cuyo nombre termine en
# /develop|/main NO genere un falso positivo de destino. (H11.)
acg_sin_flag_repo() { printf '%s' "$1" | sed -E 's/(--repo|-R)[[:space:]=]+[^[:space:]]+//g'; }

# Colapsa el PREFIJO de opciones globales de git entre `git` y su subcomando → `git --no-pager push …`,
# `git -c http.sslVerify=false push …`, `git --work-tree=/tmp push …` se normalizan a `git push …`. Sin
# esto, la adyacencia `git+push`/`git+commit` que exigen las detecciones se rompía y el comando evadía
# tanto los git-guards como el escaneo de secretos.
#   · A-03 (FMEA r1): cubrió `-c`/`-C`.
#   · A-R4-01/02 (FMEA r4): git acepta MUCHAS más globales (`--no-pager`, `-p`/`-P`, `--work-tree`,
#     `--git-dir`, `--namespace`, `--exec-path`, `--no-replace-objects`, `--literal-pathspecs`, …) → cada
#     una rompía la adyacencia y evadía TODO el guard de flujo (crítico) y el escaneo de secretos. Se generaliza a la CLASE,
#     no a la enumeración: (a) el set que consume un VALOR por espacio o `=` (debe ir 1º en la alternación
#     para comerse ese valor) y (b) CUALQUIER otro token dash-led (flag booleano o `--x=val`), así una
#     global NUEVA de git ya no reabre el hueco. `(…)+` en ERE lo soportan GNU y BSD sed; POSIX
#     leftmost-longest hace que (a) gane sobre (b) cuando puede comerse el valor.
#   · A-R5-01 (FMEA r5): el VALOR de un value-eater puede ir ENTRECOMILLADO con ESPACIOS —
#     `git -C "/Users/unjordi/Mi unidad/repo" push origin develop` (realista: rutas de Google Drive en
#     esta máquina). El `[^[:space:]]+` se cortaba en el 1er espacio → dejaba `Mi unidad/repo" push…`
#     colgando y rompía la adyacencia → evasión TOTAL. El valor se hace QUOTE-AWARE: `"..."` / `'...'`
#     (con espacios adentro) se consume como UNA unidad. IMPORTANTE: este normalizador corre sobre el RAW
#     (comillas intactas) ANTES de cualquier despoje — un consumidor que primero despoje comillas debe
#     invertir el orden (normalizar el raw, luego despojar) o el valor entrecomillado queda vacío.
#   · A-R6-01 (FMEA r6): la comilla puede ir EN MEDIO del valor — `git -c user.name="a b" push …`
#     (shell-válido, cotidiano). r5 cubrió la comilla al INICIO (`-C "/ruta"`) pero el valor MIXTO
#     `key="val con espacio"` no es ni bare-completo ni quoted-completo → el `[^space]+` se cortaba en el
#     espacio interno y volvía a romper la adyacencia → evasión TOTAL. El VALOR se modela como una SECUENCIA
#     de (char que no es espacio ni comilla | run "…" | run '…'): `([^[:space:]"']|"[^"]*"|'[^']*')+` — así
#     `user.name="a b"` = `user.name=` + `"a b"` casa entero, y las comillas donde sea dentro del token se respetan.
#   · A-R7-01 (FMEA r7): el espacio del valor puede ir ESCAPADO CON BACKSLASH en vez de entrecomillado
#     (`git -c a=b\ c push …` — el shell lo tokeniza como `-c "a=b c"`). El `\` se trataba como char normal
#     y la secuencia se cortaba en el espacio real → misma evasión. Se añade `\\.` (backslash+cualquier char)
#     como alternativa de la secuencia → el par escapado se consume como parte del valor.
# Solo casa opciones INMEDIATAMENTE tras `git` y se detiene en el 1er token NO-dash (el subcomando) → el
# `-c` de `git commit -c <commit>` (tras el subcomando) NO se toca, y `git push -u …` (0 globales) queda intacto.
#   · B4 (FMEA r8): en Windows el binario es `git.exe`; `git.exe push origin develop` rompía el `git`+espacio
#     que exigen TODOS los detectores → evasión total en un OS que la plantilla soporta (Git Bash). 1er sed:
#     colapsa `git.exe`→`git` en posición de ejecutable (inicio / tras separador) antes de todo lo demás.
acg_normaliza_git_prefijo() {
  printf '%s' "$1" \
    | sed -E 's/(^|[^[:alnum:]._-])git\.exe([[:space:]])/\1git\2/g' \
    | sed -E "s/git[[:space:]]+((((-c|-C|--exec-path|--git-dir|--work-tree|--namespace|--attr-source|--config-env|--super-prefix)([[:space:]]+|=)([^[:space:]\"']|\"[^\"]*\"|'[^']*'|\\\\.)+)|(--?[a-zA-Z][a-zA-Z-]*(=([^[:space:]\"']|\"[^\"]*\"|'[^']*'|\\\\.)+)?))[[:space:]]+)+/git /g"
}

# Raíz y rama actual del repo del PROYECTO (CLAUDE_PROJECT_DIR), no del cwd del hook.
acg_rama_actual() { git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null; }

# ¿el comando contiene un `git push`?
acg_es_push() { printf '%s' "$1" | grep -qE 'git[[:space:]]+push([[:space:]]|$)'; }

# Extrae el MR-id del comando: el 1er entero "suelto" (opcional #) tras `mr merge`/`pr merge`, TOLERANTE a
# flags intermedios (`glab mr merge --yes 9` → 9). Antes se exigía el id ADYACENTE al subcomando (A-04, FMEA).
acg_mrid() {
  printf '%s' "$1" | sed -E 's/.*(mr[[:space:]]+(merge|accept)|pr[[:space:]]+merge)[[:space:]]+//' | tr ' ' '\n' | grep -m1 -E '^#?[0-9]+$' | tr -d '#'
}

# ¿nombra develop/main como DESTINO explícito del push, en el MISMO segmento (no cruza ; && ||),
# precedido por espacio/:/'/'/'+' (no matchea feat/develop-x)? El '+' cubre el FORCE-REFSPEC
# (`git push origin +develop`, `git push -f origin +develop`) — el push FORZADO a base, el más
# peligroso, que sin el '+' en el set de separadores se colaba (A2, FMEA 2026-07-30).
acg_push_destino_base() {
  printf '%s' "$1" | grep -qE 'git[[:space:]]+push[^;&|]*[[:space:]:/+](main|develop)([[:space:]]|$)'
}

# ¿el push va SIN un refspec de rama explícito? (pelón, o solo remoto, o `HEAD` → empuja la RAMA
# ACTUAL). Heurística: tras `git push`, quitando opciones (-x/--x/--x=val) y `HEAD`, quedan ≤1
# posicionales (a lo más el remoto). (H1.)
acg_push_sin_refspec() {
  local seg rest tok posargs=0
  seg=$(printf '%s' "$1" | grep -oE 'git[[:space:]]+push[^;&|]*' | head -1)
  [ -n "$seg" ] || return 1
  rest=$(printf '%s' "$seg" | sed -E 's/^git[[:space:]]+push[[:space:]]*//; s/(-o|--push-option)[[:space:]=]+[^[:space:]]+//g')
  for tok in $rest; do
    case "$tok" in
      -*)   : ;;                       # opción → ignora
      HEAD) : ;;                       # HEAD = la rama actual, no un destino explícito
      *)    posargs=$((posargs+1)) ;;  # posicional (remoto o refspec de rama)
    esac
  done
  [ "$posargs" -le 1 ]
}

# ¿el comando EMPUJARÍA a develop/main? — explícito (nombra la rama) O pelón estando parado en
# develop/main. Opera sobre el cmd SIN comillas ni --repo. Cierra H1 (+ H11/H13). Requiere git para
# el caso pelón; sin git cae a fail-open en ese caso (backstop = ramas protegidas server-side).
acg_push_toca_base() {
  local raw sub subu subq
  raw=$(acg_normaliza_git_prefijo "$1")   # A-03: colapsa `git -c/-C …` para no romper la adyacencia git+push
  # A-R3-01 (FMEA r3): recorre CADA subcomando (separado por ; && || & |). Un push a base en CUALQUIERA
  # cuenta — un `git push origin feat/x ; git push origin develop` ya no se cuela por el 2º (el head -1
  # anterior solo miraba el 1º). Cada subcomando se evalúa AISLADO: un "git push …develop" DENTRO del
  # mensaje de un commit entrecomillado NO cuenta (ese subcomando es el commit; su despoja borra el mensaje
  # → es_push=no → se salta; preserva H13). En un subcomando que SÍ es push real evaluamos: A-02
  # (--all/--mirror), destino ENTRECOMILLADO/refspec (A-01/N-01: desquotando ESE subcomando), y el
  # pelón/HEAD por la rama actual.
  while IFS= read -r sub; do
    [ -n "$sub" ] || continue
    subu=$(acg_sin_flag_repo "$(acg_despoja_comillas "$sub")")
    acg_es_push "$subu" || continue
    printf '%s' "$subu" | grep -qE 'git[[:space:]]+push[^;&|]*[[:space:]](--all|--mirror)([[:space:]]|$)' && return 0
    subq=$(acg_sin_flag_repo "$(printf '%s' "$sub" | tr -d "'\"")")
    acg_push_destino_base "$subq" && return 0
    if acg_push_sin_refspec "$subu"; then
      case "$(acg_rama_actual)" in main|develop) return 0 ;; esac
    fi
  done <<EOF
$(printf '%s' "$raw" | awk '{gsub(/[;&|]/,"\n")}1')
EOF
  return 1
}

# ¿el comando mergea un MR/PR nombrando develop·main como destino? (para el bloqueo de release-a-main
# de git-branch-guard: mismo comportamiento de antes, pero sobre cmd sin comillas ni --repo → H11/H13).
acg_merge_menciona_base() {
  local u; u=$(acg_sin_flag_repo "$(acg_despoja_comillas "$1")")
  printf '%s' "$u" | grep -qE '(glab[[:space:]]+mr[[:space:]]+merge|gh[[:space:]]+pr[[:space:]]+merge)[^;&|]*[[:space:]:/](main|develop)([[:space:]]|$)'
}

# ¿el comando EJECUTA una integración REAL de MR/PR (server-side), no ayuda/inspección? Reconoce el
# subcomando REAL `glab mr (merge|accept)` / `gh pr merge`. Antídoto a H3: el viejo escape de
# confirmar-merge-develop casaba `status|list|view` como TOKEN SUELTO en CUALQUIER parte del comando,
# así que `glab mr merge 5 --yes && git status` evadía el gate (el `status` del OTRO comando encadenado
# disparaba el escape). Aquí solo `--help`/`-h`/`--dry-run` (inspección genuina) NO cuentan como merge;
# `glab mr list|view`/`gh pr view` tampoco disparan porque no matchean merge|accept. Sobre cmd sin
# comillas ni --repo (H11/H13). Un `git merge` LOCAL no matchea → sigue libre.
acg_es_merge_mr() {
  local u; u=$(acg_sin_flag_repo "$(acg_despoja_comillas "$1")")
  # `(\.exe)?`: en Windows el binario es `glab.exe`/`gh.exe` — sin esto el `.exe` rompía el
  # `glab`/`gh`+espacio y ambos guards de merge (squash + confirmar-merge) quedaban ciegos (H-R9-01, hermano de B4).
  printf '%s' "$u" | grep -qE '(glab(\.exe)?[[:space:]]+mr[[:space:]]+(merge|accept)|gh(\.exe)?[[:space:]]+pr[[:space:]]+merge)([[:space:]]|$)' || return 1
  printf '%s' "$u" | grep -qE '(^|[[:space:]])(--help|-h|--dry-run)([[:space:]]|$)' && return 1
  return 0
}

# Corre un comando acotado por TIMEOUT (segundos). Usa timeout/gtimeout si existen (Linux, Git Bash,
# macOS con coreutils); si no, un fallback bash puro (corre en bg, un watcher lo mata si excede). Meta:
# que la consulta de red NUNCA cuelgue al hook hasta que el CLI lo mate → evita el fail-open por MUERTE
# del proceso (H5). El watcher redirige su stdout a /dev/null para no retener el pipe hacia jq.
acg__run_timeout() {
  local secs="$1"; shift
  if command -v timeout  >/dev/null 2>&1; then timeout  "$secs" "$@"; return $?; fi
  if command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" "$@"; return $?; fi
  local pid w rc
  "$@" & pid=$!
  ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) >/dev/null 2>&1 & w=$!
  wait "$pid" 2>/dev/null; rc=$?
  kill -TERM "$w" 2>/dev/null; wait "$w" 2>/dev/null
  return "$rc"
}

# Resuelve el target_branch de un MR/PR (glab/gh) para decidir el destino del merge, con:
#  - CACHÉ por (repo,herramienta,mr-id) en TMPDIR → COMPARTIDA entre merge-squash-guard y
#    confirmar-merge-develop: el MISMO `glab mr merge` los dispara a AMBOS ⇒ misma clave. Si un hook
#    corre ANTES que el otro (el caso normal), el 2º relee el caché ⇒ 1 llamada de red, no 2. Ojo: NO
#    es un lock — bajo ejecución REALMENTE simultánea ambos podrían leer el caché vacío y llamar los
#    dos (2 llamadas idénticas, inocuo). Solo cachea un resultado NO vacío (un vacío por timeout/error
#    se reintenta la próxima).
#  - TIMEOUT interno corto (ACG_MR_TIMEOUT, default 6s < el timeout del hook en settings.json: 10s/15s)
#    para que el proceso SIEMPRE termine y EMITA su decisión, en vez de que el CLI lo mate por colgarse
#    y trate el merge como "sin deny" (fail-open por muerte del proceso, H5).
# Devuelve el destino por stdout (vacío si no se pudo resolver → el consumidor aplica SU fail-policy:
# confirmar trata vacío como develop = pide OK; squash trata !develop = no fuerza, para no aplastar un
# release por no resolver). Requiere jq (sin jq devuelve vacío).
ACG_MR_TIMEOUT="${ACG_MR_TIMEOUT:-6}"
acg_destino_de_mr() {
  command -v jq >/dev/null 2>&1 || return 0
  local raw="$1" u tool repo mrid key cache dest
  u=$(acg_despoja_comillas "$raw")
  if printf '%s' "$u" | grep -qE 'glab(\.exe)?[[:space:]]+mr'; then tool=glab; else tool=gh; fi  # (\.exe)?: binario Windows (H-R9-01)
  repo=$(printf '%s' "$raw" | grep -oE '(--repo|-R)[[:space:]=]+[^[:space:]]+' | grep -oE '[^[:space:]=]+$')
  [ -z "$repo" ] && repo=$(git -C "${CLAUDE_PROJECT_DIR:-.}" remote get-url origin 2>/dev/null | sed -E 's#^(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')
  mrid=$(acg_mrid "$u")
  [ -n "$mrid" ] || return 0
  key=$(printf '%s' "${repo}|${tool}|${mrid}" | sed 's/[^A-Za-z0-9]/_/g')
  cache="${TMPDIR:-/tmp}/acg-mrdest-${key}"
  if [ -f "$cache" ]; then cat "$cache"; return 0; fi
  if [ "$tool" = glab ]; then
    dest=$(acg__run_timeout "$ACG_MR_TIMEOUT" glab api "projects/:id/merge_requests/$mrid" ${repo:+-R "$repo"} 2>/dev/null | jq -r '.target_branch // empty' 2>/dev/null)
  else
    dest=$(acg__run_timeout "$ACG_MR_TIMEOUT" gh pr view "$mrid" ${repo:+-R "$repo"} --json baseRefName -q .baseRefName 2>/dev/null)
  fi
  if [ -n "$dest" ]; then
    printf '%s' "$dest" > "$cache" 2>/dev/null
    printf '%s' "$dest"
  fi
  return 0
}

# Lista de MR/PR ABIERTOS del repo, DIGERIBLE a un HINT de candidatos para el juez de merge (capa 3
# "contexto de identificación"). UNA sola consulta (`glab mr list` / `gh pr list` según el remoto),
# acotada por timeout y CACHEADA por repo en TMPDIR (clave distinta a la de acg_destino_de_mr). Sirve
# para IDENTIFICAR el target de una referencia vaga ("el release", "de todo esto") cuando hay UN solo
# candidato — NUNCA como autorización (eso lo decide el juez leyendo líneas USUARIO:). Fail-safe: sin
# jq/binario/red/timeout → imprime vacío → el consumidor degrada a "como hoy" (destino por acg + charla).
# Devuelve un JSON array normalizado [{number,title,baseRefName,headRefName,isDraft}] o vacío.
acg_lista_prs_abiertos() {   # $1=comando (para derivar repo/herramienta) → JSON array | vacío
  command -v jq >/dev/null 2>&1 || return 0
  local raw="$1" u tool repo key cache out
  u=$(acg_despoja_comillas "$raw")
  if printf '%s' "$u" | grep -qE 'glab(\.exe)?[[:space:]]+mr'; then tool=glab; else tool=gh; fi
  repo=$(printf '%s' "$raw" | grep -oE '(--repo|-R)[[:space:]=]+[^[:space:]]+' | grep -oE '[^[:space:]=]+$')
  [ -z "$repo" ] && repo=$(git -C "${CLAUDE_PROJECT_DIR:-.}" remote get-url origin 2>/dev/null | sed -E 's#^(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')
  key=$(printf '%s' "${repo}|${tool}|prlist" | sed 's/[^A-Za-z0-9]/_/g')
  cache="${TMPDIR:-/tmp}/acg-prlist-${key}"
  if [ -f "$cache" ]; then cat "$cache"; return 0; fi
  if [ "$tool" = glab ]; then
    # glab mr list --output json → array con iid/title/target_branch/source_branch/draft. Normalizo al
    # mismo shape que gh (number,title,baseRefName,headRefName,isDraft) para un solo digestor aguas abajo.
    out=$(acg__run_timeout "$ACG_MR_TIMEOUT" glab mr list ${repo:+-R "$repo"} --output json 2>/dev/null \
          | jq -c '[.[] | {number:(.iid // .number), title:(.title // ""), baseRefName:(.target_branch // ""), headRefName:(.source_branch // ""), isDraft:((.draft // .work_in_progress) // false)}]' 2>/dev/null)
  else
    out=$(acg__run_timeout "$ACG_MR_TIMEOUT" gh pr list ${repo:+-R "$repo"} --state open --limit 50 --json number,title,baseRefName,headRefName,isDraft 2>/dev/null)
  fi
  # Solo cachea un ARRAY no vacío válido (un fallo/timeout → vacío → se reintenta la próxima).
  if [ -n "$out" ] && printf '%s' "$out" | jq -e 'type=="array" and length>0' >/dev/null 2>&1; then
    printf '%s' "$out" > "$cache" 2>/dev/null
    printf '%s' "$out"
  fi
  return 0
}

# Digiere el array de acg_lista_prs_abiertos a un BLOQUE de texto plano (HECHOS, no autorización) que
# ayuda al juez a IDENTIFICAR a qué MR se refiere una autorización vaga del USUARIO. Determinista y
# testeable con un array mock (sin red). El conteo "hacia esta base hay exactamente 1" es un HECHO
# computado aquí, no algo que el LLM deba adivinar. Variantes: 1 candidato (INEQUÍVOCO) · ≥2 (exige que
# el USUARIO nombre) · mrid ausente (¿ya mergeado?) · lista no disponible (resuelve solo con la charla).
acg_hint_candidatos() {   # $1=json array(o vacío) $2=destino $3=mrid → bloque de texto | vacío
  command -v jq >/dev/null 2>&1 || return 0
  local arr="$1" destino="$2" mrid="$3" base cnt cands title head b mrline
  local head_ln="--- CONTEXTO FACTUAL DE GIT (no es autorización, solo para IDENTIFICAR el MR) ---"
  local foot_ln="--- fin contexto ---"
  if [ -z "$arr" ] || ! printf '%s' "$arr" | jq -e 'type=="array"' >/dev/null 2>&1; then
    printf '%s\nLista de MRs abiertos: NO DISPONIBLE. Resuelve el referente SOLO con la conversación; ante duda, DENY.\n%s' "$head_ln" "$foot_ln"
    return 0
  fi
  # metadatos del MR juzgado (si figura entre los abiertos)
  title=$(printf '%s' "$arr" | jq -r --arg id "$mrid" 'map(select((.number|tostring)==$id))[0].title // empty' 2>/dev/null | cut -c1-80)
  head=$(printf '%s' "$arr"  | jq -r --arg id "$mrid" 'map(select((.number|tostring)==$id))[0].headRefName // empty' 2>/dev/null)
  b=$(printf '%s' "$arr"     | jq -r --arg id "$mrid" 'map(select((.number|tostring)==$id))[0].baseRefName // empty' 2>/dev/null)
  # base a considerar: el destino resuelto, o (si vacío) el baseRefName del propio MR según la lista
  base="$destino"; [ -z "$base" ] && base="$b"
  if [ -n "$title" ]; then
    mrline="MR juzgado: #$mrid · titulo: \"$title\" · rama: ${head:-?} -> ${b:-?}"
  else
    mrline="MR juzgado: #$mrid · NO figura entre los MRs abiertos (¿ya mergeado/cerrado, o id equivocado?) — no asumas nada sobre el; resuelve solo con la conversacion."
  fi
  if [ -n "$base" ]; then
    cnt=$(printf '%s' "$arr" | jq --arg bs "$base" '[.[]|select(.baseRefName==$bs)]|length' 2>/dev/null)
    cands=$(printf '%s' "$arr" | jq -r --arg bs "$base" '[.[]|select(.baseRefName==$bs)|"#\(.number)"]|join(", ")' 2>/dev/null)
    if [ "${cnt:-0}" = 1 ]; then
      printf '%s\n%s\nMRs abiertos hacia %s ahora mismo: 1 (SOLO %s) => una referencia vaga del USUARIO ("el release","esto","todo esto","de todo esto") hacia esa base es INEQUIVOCA: es %s. (Sigue exigiendo que sea el USUARIO quien autorice; el conteo solo identifica, no autoriza.)\n%s' \
        "$head_ln" "$mrline" "$base" "$cands" "$cands" "$foot_ln"
    elif [ "${cnt:-0}" -ge 2 ] 2>/dev/null; then
      printf '%s\n%s\nMRs abiertos hacia %s ahora mismo: %s (%s) => hay VARIOS candidatos: un OK VAGO del USUARIO NO basta, debe nombrar cual (si no, DENY).\n%s' \
        "$head_ln" "$mrline" "$base" "$cnt" "$cands" "$foot_ln"
    else
      printf '%s\n%s\nMRs abiertos hacia %s ahora mismo: 0 (ninguno figura). No asumas un candidato; resuelve solo con la conversacion.\n%s' \
        "$head_ln" "$mrline" "$base" "$foot_ln"
    fi
  else
    printf '%s\n%s\nNo se pudo determinar la base del MR. Resuelve el referente con la conversacion; ante duda, DENY.\n%s' \
      "$head_ln" "$mrline" "$foot_ln"
  fi
}
