#!/usr/bin/env bash
# dod-verificar.sh — Stop hook: hace cumplir la DEFINICIÓN DE "LISTO" (norma mutua e inviolable).
# Versión GENÉRICA (semilla plantillaRepoVacio): agnóstica de stack — no asume .NET ni un build tool
# concreto. El candado DURO es la marca de (1)/(2); la verificación técnica (build/tests/lint) se
# RECUERDA (varía por stack) pero no se puede detectar de forma fiable en un repo cualquiera.
#
# "LISTO" (terminado/funciona/en producción) solo es válido si se cumple UNA de dos:
#   (1) FUNCIONALIDAD CONFIRMADA por el usuario (o una prueba funcional acordada como suficiente), o
#   (2) AUTORIZACIÓN EXPRESA de cierre del usuario para ESA cosa concreta.
# "verde técnico" (build/tests/lint) es VERIFICADO TÉCNICAMENTE: necesario, NO suficiente.
# "sigue/avanza" NO es "listo"; "revisamos en la mañana" ⇒ preview, no listo.
#
# ── JUEZ-Haiku (LLM) — reemplaza el PILÓN de regex (CLAIM_RE/DOWNGRADE/META_LISTO/WEAK_STATUS/MECH_*/
# CONF_RE/VISUAL_RE + la lógica G1/H4/P2a/MEDIO-1) que clasificaba ESTATUS-vs-CIERRE a mano. Era
# whack-a-mole: cada frasing nuevo abría un FP o un FN (el último, 2026-08-02: "verificado técnicamente
# de punta a punta … tras tu OK" — puro estatus — disparó porque contenía el token "de punta a punta").
# Ahora Haiku LEE el último mensaje del asistente + los mensajes del USUARIO del turno y clasifica 3 ejes:
#   CIERRE = el asistente DECLARA un ENTREGABLE listo/terminado/funciona (claim de cierre), NO estatus/
#            espera/paso-mecánico/pregunta/downgrade-a-preview/celebración/"verde técnico".
#   MARCA  = el USUARIO (en SUS propios mensajes) dio (1) confirmación funcional o (2) autorización expresa
#            de cierre. NUNCA se infiere de la prosa de Claude (ALTO-1: anti auto-atestiguamiento — por eso
#            el juez recibe SOLO el texto del usuario para este eje).
#   VISUAL = el asistente afirma una OBSERVACIÓN VISUAL (se ve/quedó como el mockup / en Chrome / la
#            pantalla muestra / el render). Combinado con "¿corrió una tool de navegador?" (ESTRUCTURAL) da
#            el bloqueo B2 (QA visual a ciegas).
# Lo ESTRUCTURAL se queda (no era regex frágil de intención): ¿el turno tocó CÓDIGO? (file_path / sed -i /
# redirección / Task de sub-agente), ¿corrió una tool de navegador?, build/mem como recordatorio, y el
# recordatorio B4 de paridad en migraciones.
#
# FAIL-SAFE (a diferencia de confirmar-merge-develop, que fail-safe DENY): dod es un NAG de disciplina, no
# un límite de seguridad. Si el juez no está (sin `claude`, sin red, timeout, o respuesta ininteligible) →
# FAIL-OPEN (deja cerrar el turno). Bloquear CADA Stop cuando Haiku esté caído atraparía al usuario en un
# loop sin poder terminar. Mockeable con CLAUDE_DOD_JUEZ_MOCK (tests deterministas); el JUICIO real se
# prueba LIVE con la batería de FP/FN históricos en test-brain.sh. Modelo/timeout por env.
#
# "Este turno" = desde el último mensaje real del usuario. stop_hook_active evita loops. Requiere jq.
set -u

# _juez_dod($texto_asistente, $texto_usuario) → "CIERRE=si|no MARCA=si|no VISUAL=si|no" | UNAVAILABLE
# Definido ARRIBA (source-only) para que el test lo corra IDÉNTICO al hook (cero drift).
_juez_dod() {
  [ -n "${CLAUDE_DOD_JUEZ_MOCK:-}" ] && { printf '%s' "$CLAUDE_DOD_JUEZ_MOCK"; return 0; }
  command -v claude >/dev/null 2>&1 || { printf 'UNAVAILABLE'; return 0; }
  local prompt out c m v
  prompt="Eres un guardia que hace cumplir la definición de LISTO en un equipo de software. Clasificas UN mensaje del asistente Claude (y los mensajes del usuario del mismo turno) en tres ejes independientes. NO juzgas si el trabajo está bien; solo clasificas el ACTO DE HABLA.

EJE 1 — CIERRE: ¿el ASISTENTE declara que un ENTREGABLE (un módulo, feature, migración, endpoint, página, tarea, la app, el fix, 'el widget', 'lo') está LISTO / terminado / funciona / 'quedó' / 'a la par' / 'de punta a punta' / 'en producción' / 'cerrado' / 'terminamos' / 🏁?
- CIERRE=si: afirma el cierre de un entregable ('el módulo quedó listo', 'ya funciona el widget', 'terminamos la migración', '🏁 quedó terminado').
- CIERRE=no cuando es cualquiera de estos (aunque use palabras como 'listo/terminado'):
  · ESTATUS/PROGRESO: 'voy avanzando', 'te aviso cuando termine', 'sigo con el siguiente'.
  · ESPERA/PIDE OK: 'en preview', 'a tu revisión', 'con tu OK lo cierro', 'pendiente de tu QA', 'esperando tu OK', 'no lo cierro / no lo mergeo todavía'.
  · PASO MECÁNICO del proceso (git/memoria/CI, NO un entregable): 'checkpoint hecho', 'push hecho', 'MR abierto', 'commit hecho', 'memoria actualizada', 'bitácora al día', 'la rama quedó pusheada'.
  · PREGUNTA: '¿ya quedó terminado?', '¿lo cierro y abro el MR?', 'Terminé el fix. ¿Lo cierro?'.
  · CELEBRACIÓN sin entregable: '🎉 ¡qué bonito quedó el día!', '¡genial! ¡vamos! ✨🚀'.
  · SOLO VERDE TÉCNICO: 'verificado técnicamente', 'build verde', '488 PASS', 'CI en verde' — eso es verificado técnicamente, NO un cierre de LISTO.
- REGLA DE CO-UBICACIÓN (importante): si el mensaje AFIRMA un cierre y ADEMÁS cuelga una pregunta o un 'dime si reviso algo más', sigue siendo CIERRE=si (la pregunta tacked-on NO lo salva). PERO si el mensaje DEGRADA explícitamente a preview/revisión ('quedó terminado, PERO lo dejo en preview, a tu revisión') → CIERRE=no: está declarando que NO está listo, aunque diga 'terminado'.

EJE 2 — MARCA: ¿el USUARIO, en SUS propios mensajes de abajo, dio (1) confirmación funcional ('lo validé', 'sí funciona', 'quedó bien', 'QA ok') o (2) autorización EXPRESA de cierre ('ciérralo', 'sí, quedó, ciérralo', 'dale ciérrala', 'luz verde', 'diste el ok', 'lo apruebo')?
- MARCA=si solo si está en palabras del PROPIO USUARIO. MARCA=no si no hay tal cosa, o si el usuario está vacío. NUNCA infieras MARCA de lo que el asistente diga que el usuario dijo (eso sería auto-atestiguamiento).

EJE 3 — VISUAL: ¿el ASISTENTE hace una ASERCIÓN DE APARIENCIA sobre una UI renderizada — 'se ve/quedó igual/como el mockup', 'en Chrome se ve', 'la pantalla muestra', 'el render se ve bien', 'hice QA visual'?
- VISUAL=si si el mensaje AFIRMA cómo SE VE la interfaz (comparación con un mockup/diseño, 'se ve bien', 'quedó igual/idéntico'), AUNQUE hedge o admita que 'no corrió un screenshot' o que 'confía en que se ve bien' — lo que cuenta es que hace la aserción de apariencia; si de verdad miró se verifica APARTE (estructural). VISUAL=no si no habla de apariencia visual (aunque diga 'terminado', 'funciona' o 'verificado técnicamente').

MENSAJE DEL ASISTENTE (a clasificar):
$1

MENSAJES DEL USUARIO EN ESTE TURNO:
$2

Responde EXACTAMENTE una línea, sin nada más:
CIERRE=<si|no> MARCA=<si|no> VISUAL=<si|no>"
  out=$(timeout "${CLAUDE_DOD_JUEZ_TIMEOUT:-30}" claude -p "$prompt" --model "${CLAUDE_DOD_JUEZ_MODEL:-claude-haiku-4-5-20251001}" 2>/dev/null)
  _dod_flag() { printf '%s' "$1" | grep -oiE "$2=(s[ií]|no)" | head -1 | grep -oiE '(s[ií]|no)' | tr 'A-Z' 'a-z' | sed 's/sí/si/'; }
  c=$(_dod_flag "$out" CIERRE); m=$(_dod_flag "$out" MARCA); v=$(_dod_flag "$out" VISUAL)
  if [ -n "$c" ] && [ -n "$m" ] && [ -n "$v" ]; then printf 'CIERRE=%s MARCA=%s VISUAL=%s' "$c" "$m" "$v"
  else printf 'UNAVAILABLE'; fi
}

# Los tests SOURCEAN con _CMD_DOD_SOURCE_ONLY=1 para obtener SOLO _juez_dod (sin correr el cuerpo del hook,
# que llama `exit` y mataría al test). En operación normal la var no está y el hook corre completo.
[ "${_CMD_DOD_SOURCE_ONLY:-}" = "1" ] && return 0 2>/dev/null

input=$(cat 2>/dev/null || true)
command -v jq >/dev/null 2>&1 || exit 0

active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0

tpath=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
{ [ -z "$tpath" ] || [ ! -f "$tpath" ]; } && exit 0

window=$(tail -n 1500 "$tpath" 2>/dev/null)
[ -z "$window" ] && exit 0

# Recorte al TURNO ACTUAL (desde el último mensaje genuino del usuario: role=user con texto, NO un
# tool_result ni un system-reminder inyectado).
turn=$(printf '%s\n' "$window" | awk '
  { lines[NR]=$0 }
  ($0 ~ /"role":[ ]*"user"/ || $0 ~ /"type":[ ]*"user"/) && $0 !~ /tool_result/ && $0 !~ /tool_use_id/ { last=NR }
  END { start = (last ? last : 1); for (i=start; i<=NR; i++) print lines[i] }')
[ -z "$turn" ] && turn="$window"

# Último mensaje de texto del asistente (dentro del turno actual). Sin texto del asistente → nada que juzgar.
last=$(printf '%s\n' "$turn" | jq -rs '[.[] | select((.message.role // .type)=="assistant") | (.message.content[]? | select(.type=="text") | .text)] | last // ""' 2>/dev/null)
[ -z "$last" ] && exit 0

# Texto de los mensajes del USUARIO del turno (para el eje MARCA). ALTO-1: SOLO mensajes role=user, NUNCA
# la prosa de Claude → el juez no puede auto-atestiguarse una autorización que el usuario no dio. Se
# excluyen META/inyectados y system-reminders (traen léxico de OK que no es del usuario).
usertext=$(printf '%s\n' "$turn" | jq -rs '
  [ .[] | select((.message.role // .type)=="user")
        | select((.isMeta // false) != true)
        | ((.message.content // [.message])
           | if type=="array"
             then (map(if type=="string" then . elif (.type? == "text") then .text else "" end) | join(" "))
             else (. // "") end)
        | select(. != "")
        | select(test("<system-reminder>") | not) ] | join("  ")' 2>/dev/null)

# ── EL JUEZ clasifica los 3 ejes. FAIL-OPEN si no está disponible (dod es nag, no seguridad). ──
veredicto=$(_juez_dod "$last" "$usertext")
[ "$veredicto" = "UNAVAILABLE" ] && exit 0
_g() { printf '%s' "$veredicto" | grep -oiE "$1=[a-zíí]+" | head -1 | cut -d= -f2 | tr 'A-Z' 'a-z'; }
cierre=$(_g CIERRE); marca=$(_g MARCA); visual=$(_g VISUAL)

# ── ¿corrió una tool de NAVEGADOR en el turno? (ESTRUCTURAL — por el "name" del tool_use, no por prosa).
# Reconoce cualquier driver MCP (claude-in-chrome/playwright/puppeteer/chrome/browser) + el tool `computer`.
browser=no
printf '%s' "$turn" | grep -qE '"name"[[:space:]]*:[[:space:]]*"(mcp__(claude-in-chrome|playwright|puppeteer|chrome|browser)[a-z0-9_-]*__[a-z_]+|computer)"' && browser=si

# ── B2: OBSERVACIÓN VISUAL a ciegas — afirma haber visto la pantalla SIN correr tool de navegador, y el
# usuario no lo confirmó. Bloquea INDEPENDIENTE de si tocó código (declarar QA visual a ciegas es el daño). ──
if [ "$visual" = "si" ] && [ "$marca" != "si" ] && [ "$browser" != "si" ]; then
  vreason="DETENTE — afirmaste una OBSERVACIÓN VISUAL ('se ve/quedó como el mockup / en Chrome / la pantalla muestra…') pero en ESTE turno NO corriste NINGUNA tool de navegador/screenshot: lo estás declarando A CIEGAS. No uses léxico de QA visual sin haber mirado la pantalla. Estatus honesto: 'verificado técnicamente, SIN QA visual (a ciegas)' — el QA visual lo hace el usuario o una captura real. (Lección real (2026-07): se insinuó QA de Chrome sin verla y reaparecieron bugs ya resueltos.)"
  jq -n --arg r "$vreason" '{decision:"block", reason:$r}'
  exit 0
fi

# ── Candado principal: solo aplica si el asistente AFIRMA un CIERRE. ──
[ "$cierre" = "si" ] || exit 0

# ¿El TURNO tocó CÓDIGO (algún archivo que NO sea documentación ni memoria)? Si no, un "listo" de docs/config
# no exige verificación técnica. (ESTRUCTURAL — se conserva íntegro del diseño previo.)
codigo=$(printf '%s' "$turn" | grep -oE '"file_path":"[^"]+"' | grep -vE '\.(md|txt)"|/\.claude/memory/' | head -1)
# G2(a): editar por Bash (sed -i / patch / redirección `>`/`tee`) NO genera "file_path" → inspecciona los Bash.
if [ -z "$codigo" ]; then
  _bash=$(printf '%s' "$turn" | jq -rs '[.[] | (.message.content[]? // empty) | select(.type=="tool_use" and .name=="Bash") | (.input.command // "")] | join("\n")' 2>/dev/null)
  if printf '%s' "$_bash" | grep -qE 'sed[[:space:]]+-i|(^|[[:space:]])patch([[:space:]]|$)'; then
    codigo="(bash-inplace)"
  else
    codigo=$(printf '%s\n' "$_bash" \
      | grep -oE '(>>?|(^|[[:space:]])tee([[:space:]]+-a)?)[[:space:]]*[^[:space:]|;&<>]+\.[A-Za-z0-9]+' \
      | grep -oE '[^[:space:]|;&<>]+\.[A-Za-z0-9]+$' \
      | grep -vE '\.(md|txt|log)$|^/dev/' | head -1)
  fi
fi
# ALTO-2: un fan-out DELEGA la edición a un SUB-AGENTE (tool Task); sus tool_use viven en OTRO transcript,
# invisibles aquí → un orquestador que declara "la ola quedó" nunca disparaba. Un Task en el turno = POSIBLE
# código tocado → entra al gate de evidencia (1)/(2).
if [ -z "$codigo" ]; then
  printf '%s' "$turn" | grep -qE '"name"[[:space:]]*:[[:space:]]*"Task"' && codigo="(task-subagente)"
fi
[ -z "$codigo" ] && exit 0

# Candado DURO: sin (1)/(2) del USUARIO no se puede declarar LISTO tras tocar código.
[ "$marca" = "si" ] && exit 0

# Recordatorios SOFT (build/tests/lint y memoria — se reportan, no bloquean por sí solos).
printf '%s' "$turn" | grep -qiE '(npm|pnpm|yarn|bun)[[:space:]]+(run[[:space:]]+)?(build|test|lint)|dotnet[[:space:]]+(build|test)|make([[:space:]]|$)|cargo[[:space:]]+(build|test|check)|pytest|go[[:space:]]+(build|test)|gradle|mvn|scripts/(build|test)|npm[[:space:]]+ci' && build=si || build=no
printf '%s' "$turn" | grep -qE '"file_path":"[^"]*\.claude/memory/' && mem=si || mem=no

# B4: si el cierre es de MIGRACIÓN, la prueba acordada NO es build+tests — es una auditoría de PARIDAD.
mig=""
printf '%s' "$last" | grep -qiE 'migrac|migrad|paridad|legad' && mig="
  • OJO MIGRACIÓN: la prueba ACORDADA para declarar avance NO es build+tests, es una AUDITORÍA DE PARIDAD legado→nuevo (inventario de paridad + el módulo real del legado). Un build verde ≠ paridad; córrela y cítala."

reason="DETENTE — declaraste algo LISTO/terminado/funciona tras tocar código, sin cumplir la definición mutua de LISTO.
Estado de la evidencia de ESTE turno:
  • marca de (1) funcionalidad CONFIRMADA por el usuario o (2) autorización EXPRESA de cierre: ${marca}  ← REQUERIDO
  • verificación técnica (build/tests/lint) citada en el turno: ${build}  (recordatorio)
  • memoria actualizada (.claude/memory/): ${mem}  (recordatorio)${mig}
Recuerda: verde técnico != LISTO. 'sigue/avanza' NO es 'listo'. Sin (1) o (2) NO puedes declarar LISTO.
Antes de cerrar:
  1) Corre la verificación que aplique a tu stack (build/tests/lint) y CITA la salida.
  2) Actualiza .claude/memory/ (hecho[commit+fecha] / pendiente / fuera-por-decisión).
  3) NO declares LISTO ni integres a develop sin (1) confirmación funcional del usuario o (2) su autorización expresa — y CÍTALA.
Si NO es un cierre (estás dando estatus o esperando su OK), dilo con lenguaje de estatus ('en preview', 'con tu OK', 'te aviso') y podrás cerrar el turno."

jq -n --arg r "$reason" '{decision:"block", reason:$r}'
exit 0
