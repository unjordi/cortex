#!/usr/bin/env bash
# confirmar-merge-develop.sh — PreToolUse/Bash: EXIGE confirmación EXPRESA del usuario antes de
# INTEGRAR a develop/main por MR. Hace cumplir, en el punto exacto del merge, la definición de LISTO.
#
# Modelo "MINI-DEVELOP-por-dev" (acordado con el usuario):
#   - Cada dev trabaja en su rama personal de integración `Develop<Usuario>` (p. ej.
#     `DevelopAna`, `DevelopBeto`, `carlos`…): sus ramitas de feature se mergean AHÍ de forma CONTINUA y sin
#     drama — este candado NO las intercepta. Igual las ramas `epic/*`, `integracion/*` y demás.
#   - El ÚNICO cruce que pasa por este candado es integrar al `develop` COMPARTIDO (o promover a
#     `main`) vía MR (`glab mr merge|accept` / `gh pr merge`, incluido armar `--auto-merge`):
#     BLOQUEA salvo que haya (a) una MARCA de confirmación expresa del usuario en el contexto
#     reciente, o (b) una AUTORIZACIÓN DURABLE vigente en disco (.claude/memory/
#     autorizaciones-vigentes.local.md, scope=merge-develop con vencimiento — la escribe el skill
#     turno-nocturno al recibir un OK blanket del usuario; sobrevive compactaciones). La vía (b)
#     JAMÁS cubre releases a main.
#
# ALCANCE: SOLO repos COMPARTIDOS (marca `.claude/repo-compartido`, viaja por git). En repos
# personales/solo (sin la marca) NO gatea nada → cero fricción ahí; ese caso lo cuidan git-branch-guard
# (no push directo a develop/main) + merge-squash-guard. `git merge` LOCAL a cualquier rama tampoco se
# intercepta. Complementa a git-branch-guard y merge-squash-guard (exige --squash a develop). Fail-open sin jq.
set -u
# dedupe doble-cableado: si soy la copia del REPO y la copia GLOBAL existe, cedo (la global maneja
# esta invocación) → evita disparo doble (y doble llamada de red) en máquina con el cerebro global;
# en un clon SIN bootstrap la del repo sí corre. NO-debilitante: sigue exigiendo el OK igual.
case "$0" in "$HOME/.claude/hooks/"*) : ;; *) [ -f "$HOME/.claude/hooks/$(basename "$0")" ] && exit 0 ;; esac
input=$(cat 2>/dev/null || true)
command -v jq >/dev/null 2>&1 || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# shellcheck source=analizar-comando-git.sh
. "$(dirname "$0")/analizar-comando-git.sh"

# ¿Es una INTEGRACIÓN server-side de MR/PR REAL? (git merge local NO cuenta → iterar en integración es
# libre; ayuda/inspección tampoco). La lib ancla el reconocimiento al subcomando real → un token suelto
# de OTRO comando encadenado (`glab mr merge 5 --yes && git status`) YA NO evade el gate (H3).
acg_es_merge_mr "$cmd" || exit 0

# ALCANCE: solo repos COMPARTIDOS. Sin la marca `.claude/repo-compartido` (que viaja por git en los
# repos de equipo), este candado no aplica → repos personales/solo mergean a su develop sin pedir OK.
[ -f "${CLAUDE_PROJECT_DIR:-.}/.claude/repo-compartido" ] || exit 0

# DESTINO del merge: main = RELEASE (autorización SUPER explícita); develop/otro = confirmación normal.
# Lo resuelve la lib (acg_destino_de_mr): caché por MR-id COMPARTIDA con merge-squash-guard (típicamente
# 1 llamada de red, no 2; no es lock) + timeout interno para no fallar-abierto por muerte del proceso (H5).
# FAIL-SAFE: si no podemos determinar el destino (vacío por timeout/error), se trata como develop (conservador → pide OK).
destino=$(acg_destino_de_mr "$cmd")

# Ramas personales de integración (Develop<Usuario>, epic/*, integracion/*, feat/*, fix/*…) reciben
# merge CONTINUO sin gate: ahí vive el día a día del modelo MINI-DEVELOP-por-dev. SOLO el `develop`
# COMPARTIDO y `main` piden confirmación. destino vacío/desconocido → conservador (se trata como develop).
if [ -n "$destino" ] && [ "$destino" != "develop" ] && [ "$destino" != "main" ]; then
  exit 0
fi

# Autorización reciente del usuario. Buscamos en los ÚLTIMOS ~10 MENSAJES DE USUARIO — NO en las
# últimas N líneas CRUDAS del transcript. Por qué: los recordatorios inyectados gigantes (additionalContext)
# y las salidas de tool NO son role=user, pero SÍ inflan el conteo de líneas → con una ventana de líneas
# crudas, un "mergea 222" real queda ENTERRADO fuera de la ventana y el guard da runaround (falso negativo,
# no que "no puedas"). Filtrar a mensajes de usuario y tomar los últimos 10 es inmune a ese ruido y sigue
# acotado por recencia (un OK de hace 20 turnos NO cuenta). tail -4000 solo acota el costo de leer.
recent=""
tpath=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -n "$tpath" ] && [ -f "$tpath" ]; then
  recent=$(tail -n 4000 "$tpath" 2>/dev/null | jq -rs '
    [ .[] | select((.message.role // .type)=="user")
          | select((.isMeta // false) != true)         # A-06 (FMEA): descarta mensajes META/inyectados (no son del usuario)
          | ((.message.content // [.message])
             | if type=="array"
               then (map(if type=="string" then . elif (.type? == "text") then .text else "" end) | join(" "))
               else (. // "") end)
          | select(. != "")                   # descarta tool_result (mapea a "") → solo texto real del usuario
          | select(test("<system-reminder>") | not) ]  # A-06: descarta bloques con marca de inyección (CLAUDE.md/recordatorios)
    | .[-10:] | join("\n")' 2>/dev/null)   # UNA línea por mensaje de usuario → permite filtrar por-línea
fi                                          # (negación adyacente A3 · id de MR ligado al OK A4)

# ── A3 (NEGATION-BLIND) + A4 (OK TRANSITIVO) · FMEA 2026-07-30 ────────────────────────────────────
# Antes: `grep -qiE "$OK_RE" "$recent"` aceptaba la marca SIN polaridad ni ligadura al MR → "no te di
# autorización todavía" ABRÍA el merge (A3), y un "mergea el MR 5" autorizaba un `merge 9` distinto (A4).
# Ahora evaluamos MENSAJE-POR-MENSAJE (una línea = un msg de usuario) y una línea SOLO cuenta como OK si:
#   (A3) NO trae una negación (no|sin|nunca|jamás — cubre "todavía no"/"aún no", que contienen "no");
#   (A4) si LIGA el OK a un MR-id explícito ("mergea el MR 5"), ese id coincide con el del comando actual.
#        Un OK GENÉRICO (sin id) conserva el comportamiento por RECENCIA (no se endurece de más).
# A-05 (FMEA): además de no/sin/nunca/jamás, cubre negaciones/prohibiciones frecuentes que traían un verbo
# de merge y pasaban como OK ("ni se te ocurra mergear el 5", "para nada", "de ninguna manera", "tampoco",
# "evita"). "ni se te ocurra"/"ni loco" van como frase para no atrapar "ni bien" (= apenas), que NO niega.
NEG_RE='(\b(no|sin|nunca|jam[aá]s|tampoco|evit[aeé][a-z]*)\b|para nada|de ninguna manera|de ning[uú]n modo|ni se te ocurra|ni loc[ao])'
# Verbo de merge/OK inmediatamente seguido de (el)? (MR)? #?<n> → marca que el OK va dirigido a ESE MR.
BOUND_OK_RE='(merg[eé]a[a-zé]*|mérga(lo|los)?|dale( el)? merge|integr[ao][a-zé]*|emp[uú]j[a-zé]*|s[uú]b[a-zé]*|m[aá]nd[a-zé]*|m[eé]t[ae][a-zé]*)[[:space:]]+(el[[:space:]]+)?(mr[[:space:]]+)?#?[0-9]+'
# MR-id del COMANDO actual (para la ligadura A4). Vacío si el comando no nombra id → A4 no aplica (recencia).
cur_mrid=$(acg_mrid "$(acg_despoja_comillas "$cmd")")   # A-04 (FMEA): id tolerante a flags (`--yes 9`), vía la lib

# ¿hay en $recent una línea que sea un OK VÁLIDO (no negado y no ligado a OTRO MR) para $1 (regex de OK)?
_ok_para_este_merge() {
  local re="$1" line ids
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s' "$line" | grep -qiE "$re"    || continue    # trae una marca de OK
    printf '%s' "$line" | grep -qiE "$NEG_RE" && continue    # (A3) negada → no cuenta
    ids=$(printf '%s' "$line" | grep -oiE "$BOUND_OK_RE" | grep -oE '[0-9]+')
    if [ -n "$ids" ] && [ -n "$cur_mrid" ]; then             # (A4) OK ligado a un MR-id concreto…
      printf '%s\n' "$ids" | grep -qx "$cur_mrid" || continue # …y NO es este → no autoriza este merge
    fi
    return 0                                                 # OK válido (genérico, o ligado a ESTE MR)
  done <<EOF
$recent
EOF
  return 1
}

# RELEASE_RE: lenguaje de release-a-main. Se usa en AMBAS ramas — exige release para main, y TAMBIÉN
# vale como confirmación del merge INTERMEDIO a develop (un release a main pasa forzosamente por
# develop, así que autorizar el release autoriza su paso a develop). Antídoto al falso-negativo del
# 2026-07-20: "ya puedes empujar el brain a main" frenó el PR intermedio a develop porque el CONF_RE
# de develop no reconocía lenguaje de release. La autorización de release es MÁS fuerte, no menos.
RELEASE_RE='hasta main|\brelease\b|(a|hacia|hast[ao]) main|liber(a|ar|alo|é)|promue?v(e|er)[a-zé ]*main|merge[a-zé ]* a? *main'

if [ "$destino" = "main" ]; then
  # RELEASE a main: exige autorización SUPER explícita de release. Un 'mergea' genérico (que vale
  # para develop) NO autoriza un release a main. (A3: una negación adyacente NO cuenta como OK.)
  _ok_para_este_merge "$RELEASE_RE" && exit 0
  jq -n --arg r "FRENO (RELEASE a main): promover develop→main es una decisión de RELEASE que exige autorización SUPER explícita del usuario para ESTE release (p. ej. 'release a main', 'hasta main', 'libera'), y no la encuentro en el contexto reciente.
  (a) Si ya la dio, CÍTALA y reintenta.
  (b) main es release-only: un 'mergea' genérico (que vale para develop) NO autoriza un release a main. Los releases van SIN squash (conservan historia)." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
fi

# Destino develop (o desconocido → conservador): confirmación normal. "sigue/avanza" NO cuenta.
CONF_RE='merg[eé]a|mérga(lo|los)?|dale( el)? merge|haz(lo|le)?( el)? *merge|merge a develop|integra[a-zé ]*a? *develop|s[ií],? merge|ci[eé]rra(lo)?|cierra el slice|ll[eé]va(lo|los)?[a-zé ,]*develop|s[uú]b(e|elo|elos|ir|an|í)[a-zé ,]*develop|m[aá]nda(lo|los)?[a-zé ,]*develop|emp[uú]j(a|á|e)(lo|los|le)?[a-zé ,]*develop|m[eé]te(le|lo|los)?[a-zé ,]*develop|ya (puedes|podés|puedo) mergear|adelante[a-zé ]*(el )?merge|autoriz|luz verde (para|de|expresa)|visto bueno|aprob(ado|é|ó)?|va! *(merge|mr|develop|cierra)'
_ok_para_este_merge "$CONF_RE" && exit 0
# Un OK de RELEASE-a-main también cubre este paso intermedio a develop (el release pasa por develop).
_ok_para_este_merge "$RELEASE_RE" && exit 0

# ── Autorización DURABLE (sobrevive compactaciones): grant EXPLÍCITO del usuario persistido a disco
# (lo escribe el skill turno-nocturno al recibir el OK, con la CITA textual del usuario y un
# vencimiento). SOLO cubre scope=merge-develop — un release a main NUNCA llega aquí (su early-exit
# está arriba y NO consulta este archivo). Fail-safe: sin archivo / grant vencido / línea malformada
# → el freno normal de abajo. Caso real (2026-07-12): un OK blanket ("autorizo todos los merges a
# develop de aquí a mañana a las 10am") murió al COMPACTARSE el contexto (quedó fuera de la ventana
# de mensajes que escaneamos) → merges legítimos frenados toda la noche. El grant en disco es la
# versión durable de ese OK; la cita textual registrada es su evidencia.
AUTH_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/memory/autorizaciones-vigentes.local.md"
if [ -f "$AUTH_FILE" ]; then
  now_epoch=$(date +%s)
  grant=$(awk -v now="$now_epoch" '/scope=merge-develop/ && match($0, /vence_epoch=[0-9]+/) {
      if (substr($0, RSTART+12, RLENGTH-12) + 0 > now) { print; exit }
    }' "$AUTH_FILE" 2>/dev/null)
  [ -n "$grant" ] && exit 0
fi

jq -n --arg r "FRENO (definición de LISTO): integrar a develop por MR exige la confirmación EXPRESA del usuario para ESTE cierre, y no la encuentro en el contexto reciente.
  (a) Si ya te dio el OK explícito, CÍTALO y reintenta.
  (b) Para seguir iterando SIN fricción: trabaja en una rama de INTEGRACIÓN (integracion/<sprint> o epic/<tema>) y mergea las ramitas ahí con 'git merge' LOCAL (libre, no pasa por este candado); solo el MR de esa rama de integración → develop pasa por aquí.
Recuerda: verde técnico != LISTO; 'sigue/avanza' NO autoriza el merge a develop." \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
