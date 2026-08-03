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
#     BLOQUEA salvo que haya (a) autorización EXPRESA del usuario para ESTE merge en el contexto
#     reciente (la juzga un LLM, ver abajo), o (b) una AUTORIZACIÓN DURABLE vigente en disco
#     (.claude/memory/autorizaciones-vigentes.local.md, scope=merge-develop con vencimiento — la
#     escribe el skill turno-nocturno al recibir un OK blanket del usuario; sobrevive compactaciones).
#     La vía (b) JAMÁS cubre releases a main.
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
    | .[-10:] | join("\n")' 2>/dev/null)   # UNA línea por mensaje de usuario, del más viejo al más nuevo
fi

# ── JUEZ DE AUTORIZACIÓN (LLM) — reemplaza el pilón de regex frágiles ────────────────────────────────
# Antes: NEG_RE/NEG_ADJ/DEFER_RE/BOUND_OK_RE/CONF_RE/RELEASE_RE intentaban parsear la INTENCIÓN del
# usuario en lenguaje natural (español, con slang, frustración, negaciones incidentales, listas de ids).
# Era whack-a-mole: cada frasing nuevo abría un falso-positivo o un falso-negativo (3 en una sola noche,
# 2026-08-02: negación-ciega, multi-id, y un cache de destino envenenado). Ahora un modelo chico (Haiku)
# LEE los mensajes recientes del usuario y JUZGA si autorizó EXPRESAMENTE ESTE merge (este MR-id, este
# destino). Es comprensión de lectura, robusta al phrasing — lo que un guard de intención debía ser.
#
# Fail-safe (conservador, NUNCA fail-open): si el LLM no está disponible (sin `claude` CLI, sin red,
# timeout, o respuesta ininteligible) → DENY (pide OK a mano). Los tests lo mockean con
# CLAUDE_MERGE_JUEZ_MOCK (ALLOW|DENY|UNAVAILABLE) para ser deterministas y sin red. Modelo/timeout por env.
cur_mrid=$(acg_mrid "$(acg_despoja_comillas "$cmd")")   # id del comando (tolerante a flags), vía la lib

_juez_merge() {   # $1=destino  $2=mrid  $3=mensajes → imprime ALLOW | DENY | UNAVAILABLE
  [ -n "${CLAUDE_MERGE_JUEZ_MOCK:-}" ] && { printf '%s' "$CLAUDE_MERGE_JUEZ_MOCK"; return 0; }
  command -v claude >/dev/null 2>&1 || { printf 'UNAVAILABLE'; return 0; }
  local prompt out
  prompt="Eres un guardia de seguridad de merges de git. El asistente Claude quiere ejecutar: merge del MR $2 hacia la rama '$1'.
Tu ÚNICA tarea: decidir si el USUARIO autorizó EXPRESAMENTE ESTE merge (este número de MR y esta rama destino) leyendo sus mensajes recientes.

Reglas:
- ALLOW solo si el usuario dio una instrucción CLARA de mergear/integrar que aplica a ESTE MR ($2), o un OK inequívoco de mergear a '$1' ahora mismo. Una lista ('mergea 5 y 6') autoriza a TODOS los ids que nombra.
- Si el destino es 'main': exige lenguaje EXPLÍCITO de RELEASE (release / libera / a main). Un 'mergea' normal NO basta para main.
- DENY si: no hay autorización, la autorización es para OTRO MR distinto, es una negación ('no mergees eso'), un aplazamiento ('espera', 'todavía no', 'déjame revisar'), o si tienes CUALQUIER duda.
- Ignora la frustración, quejas o reclamos del usuario; busca ÚNICAMENTE si autorizó ESTE merge.

Mensajes recientes del usuario (del más viejo al más nuevo):
$3

Responde EXACTAMENTE una palabra en la primera línea: ALLOW o DENY."
  out=$(timeout "${CLAUDE_MERGE_JUEZ_TIMEOUT:-30}" claude -p "$prompt" --model "${CLAUDE_MERGE_JUEZ_MODEL:-claude-haiku-4-5-20251001}" 2>/dev/null \
        | grep -oiE 'ALLOW|DENY' | head -1 | tr '[:lower:]' '[:upper:]')
  [ -n "$out" ] && printf '%s' "$out" || printf 'UNAVAILABLE'
}

# Grant DURABLE (turno-nocturno): un OK persistido a disco cubre scope=merge-develop (NUNCA main). Fast-path
# antes de gastar una llamada al LLM. Sobrevive compactaciones; la cita textual registrada es su evidencia.
if [ "$destino" != "main" ]; then
  AUTH_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/memory/autorizaciones-vigentes.local.md"
  if [ -f "$AUTH_FILE" ]; then
    now_epoch=$(date +%s)
    grant=$(awk -v now="$now_epoch" '/scope=merge-develop/ && match($0, /vence_epoch=[0-9]+/) {
        if (substr($0, RSTART+12, RLENGTH-12) + 0 > now) { print; exit }
      }' "$AUTH_FILE" 2>/dev/null)
    [ -n "$grant" ] && exit 0
  fi
fi

veredicto=$(_juez_merge "$destino" "$cur_mrid" "$recent")
[ "$veredicto" = "ALLOW" ] && exit 0

# DENY o UNAVAILABLE → freno, con el mensaje según el caso.
if [ "$veredicto" = "UNAVAILABLE" ]; then
  r="FRENO (juez no disponible): no pude consultar el juez de autorización de merge (¿sin 'claude' CLI, sin red, o timeout?). Fail-safe conservador: confirma ESTE merge a mano, o reintenta con el LLM disponible. (Override de modelo/timeout: CLAUDE_MERGE_JUEZ_MODEL / CLAUDE_MERGE_JUEZ_TIMEOUT.)"
elif [ "$destino" = "main" ]; then
  r="FRENO (RELEASE a main): el juez no encontró autorización EXPRESA de RELEASE para ESTE release (MR $cur_mrid). main es release-only — pide 'libera/release a main' explícito. Los releases van SIN squash (conservan historia)."
else
  r="FRENO (definición de LISTO): el juez no encontró tu confirmación EXPRESA para integrar ESTE MR ($cur_mrid) a develop.
  (a) Dámela clara para ESTE MR (p. ej. 'mergea el $cur_mrid a develop').
  (b) O itera sin fricción en tu mini/rama de integración con 'git merge' LOCAL (no pasa por este candado).
Recuerda: verde técnico != LISTO; 'sigue/avanza' NO autoriza el merge a develop."
fi
jq -n --arg r "$r" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
