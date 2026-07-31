#!/usr/bin/env bash
# aviso-contexto.sh — PostToolUse hook (tier GLOBAL). Convierte el AUTO-COMPACT-SORPRESA en un caso RARO.
#
# Problema: el auto-compact (contexto lleno) dispara SOLO, SIN aviso, y a menudo sin que se haya corrido
# el skill `checkpoint` → se pierde el HILO reciente. `precompact` NO puede ayudar (PreCompact no tiene
# canal para inyectar contexto ni pedir acción; por eso se retiró). Este hook vigila cuán LLENO está el
# contexto y, al cruzar una banda POR DEBAJO del punto de auto-compact, INYECTA un aviso para que el
# modelo vuelque con `checkpoint` y proponga al usuario un /compact PROACTIVO (con holgura).
# El aviso ESCALA por banda: 1 = heads-up con holgura; 2 = checkpoint AHORA + propón /compact; ≥3 =
# INMINENTE → ORDENA RE-correr `checkpoint` (aunque ya se corrió: desde entonces pasó más trabajo y el hilo
# quedó atrás) + compactar YA. El hook no puede correr el skill, pero sí ORDENAR su re-ejecución.
#
# Por qué PostToolUse (y no Stop/UserPromptSubmit): es el ÚNICO evento que dispara DURANTE una corrida
# autónoma larga (muchos tool-calls sin turno del usuario) — justo cuando el auto-compact golpea. Stop
# solo dispara al FIN del turno (se lo pierde a mitad de una ráfaga); UserPromptSubmit no dispara nada
# mientras el modelo trabaja solo. El costo (fire por cada tool) se paga con el debounce por BANDA.
#
# Métrica = TOKENS REALES de contexto (no líneas ni bytes). El transcript YA trae el conteo exacto: el
# ÚLTIMO objeto `usage` refleja el tamaño ACTUAL del contexto. Fórmula:
#   ctx = input_tokens + cache_creation_input_tokens + cache_read_input_tokens   (NO output_tokens).
# Por qué NO líneas (el bug que esto arregla): con líneas GORDAS (imágenes base64, tool-outputs enormes)
# el `wc -l` SUBESTIMA los tokens → nunca cruza el umbral → auto-compact sorpresa (band 0, silencio total;
# observado en sesiones reales a ~665K tokens con solo ~1000 líneas de crecimiento). Por qué NO bytes:
# las imágenes base64 inflan los bytes SIN inflar los tokens (mismo ~665K ctx medía 3 MB o 35 MB según
# cuántas imágenes) → sesgo. Los tokens del `usage` son la verdad que el CLI mismo usa para auto-compactar.
#
# Techo = el PUNTO DE AUTO-COMPACT real de ESTA sesión, DERIVADO (no hardcodeado): ventana × pct.
#   - Ventana (leída de settings.json — user < proyecto < local, el más específico gana): 1,000,000 si el
#     modelo trae el marcador "[1m]" O es un 1M-NATIVO por nombre (opus-4-7/4-8/5, sonnet-5, fable-5,
#     mythos-5, que llevan el id pelón SIN sufijo); si no, 200,000. (El transcript NO guarda la ventana y
#     el modelo sale pelón ahí; settings.json SÍ trae el id del modelo → es la señal fiable.) Ver bloque (1).
#   - pct de auto-compact: env `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (el CLI la respeta; el usuario puede
#     bajarla, p. ej. a 70); si no está, default 92 (≈ el del CLI, con holgura para alcanzar a checkpointear).
# Bandas como % de ESE techo: ℹ️ 76% · ⚠️ 88% · 🚨 95%. Por qué el techo NO es la VENTANA: lo que queremos
# anticipar es el AUTO-COMPACT (que pega a ventana×pct), no "llenar la ventana" — por eso el % del aviso
# NO coincide con el % de `/context` (ese es sobre la ventana; denominadores distintos, a propósito).
# Bug que esto arregla (2026-07-27): el techo estaba FIJO en 660K → en una sesión de 1M @ 70% gritaba
# "compacta" al 60% de la ventana (band-aid). Escape hatches: `AVISO_CONTEXTO_CEILING_TOKENS` fija el
# techo ABSOLUTO a mano (gana sobre todo); `AVISO_CONTEXTO_WINDOW_TOKENS` fija la VENTANA. Al ser
# absoluto, tras un /compact el `usage` baja SOLO → la banda cae SOLA → el aviso se limpia SOLO
# (auto-cura), sin baseline.
# Robustez (2026-07-28): la detección de ventana puede FALLAR en runtime (settings a medio escribir,
# timing, $HOME distinto, un settings de proyecto sin "[1m]") y caer al default chico de 200K → falso
# "🚨 INMINENTE". Antídoto por invariante FÍSICO: el contexto NO cabe en una ventana menor que él mismo,
# así que si el ctx MEDIDO supera la ventana detectada, ésta se promueve a 1M (la única mayor conocida
# de Claude). Ata el techo al dato DURO del transcript, no a leer bien settings. Solo SUBE la ventana →
# nunca inventa falsos positivos, solo suprime los IMPOSIBLES. Bug real: ctx=381K con la ventana
# mal-detectada en 200K → techo 140K@70% → falso "INMINENTE" al 38% de una ventana de 1M.
#
# Debounce: solo avisa al SUBIR de banda. La marca .contexto-aviso guarda "<última_banda> <último_ctx>";
# si el ctx baja (hubo compact / sesión nueva) la banda se recalcula hacia abajo → se re-arma sola.
#
# Fail-open: sin jq, sin transcript, sin memoria del repo, sin `usage`, o cualquier error → exit 0 sin
# ruido. Genérico y stack-agnóstico → se instala GLOBAL (install-brain.sh). Pareja de `checkpoint`
# (vuelca el hilo) y `rehidratar-hilo` (reinyecta el hilo tras compactar).
set -u

command -v jq >/dev/null 2>&1 || exit 0        # sin jq no podemos leer/emitir JSON → fail-open silencioso

input=$(cat 2>/dev/null || true)
tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
{ [ -n "${tp:-}" ] && [ -f "$tp" ]; } || exit 0 # sin transcript → nada que medir

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MEM="$ROOT/.claude/memory"
[ -d "$MEM" ] || exit 0                          # repo sin el sistema de memoria → no incumbe
AVISO_F="$MEM/.contexto-aviso"

# Tokens de contexto ACTUALES = último `usage` del transcript (excluye subagentes/sidechain, que traen
# su propio usage y contaminarían la medición del hilo principal). fromjson? salta líneas malformadas.
# Se calcula ANTES del techo porque la AUTO-CORRECCIÓN de ventana (abajo) se ata a este dato DURO.
ctx=$(tail -n 400 "$tp" 2>/dev/null | jq -rR '
    fromjson? | select(.isSidechain != true) | (.message.usage // empty)
    | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)
  ' 2>/dev/null | tail -1 | tr -cd '0-9')
[ -n "$ctx" ] || exit 0                          # sin usage aún → nada que medir (fail-open)

# Techo = punto de auto-compact = ventana_real × pct_autocompact/100. DERIVADO de las señales reales.
# Escape hatches (de más fuerte a más débil): `AVISO_CONTEXTO_CEILING_TOKENS` fija el techo ABSOLUTO y
# gana sobre todo (tests / manual); `AVISO_CONTEXTO_WINDOW_TOKENS` fija la VENTANA a mano; si no hay
# ninguno, la ventana se DERIVA del modelo. En los casos derivado y por-ventana se aplica la
# AUTO-CORRECCIÓN por invariante físico (1b).
CEILING="${AVISO_CONTEXTO_CEILING_TOKENS:-}"
case "$CEILING" in
  ''|*[!0-9]*)
    # (1) Ventana: override explícito `AVISO_CONTEXTO_WINDOW_TOKENS`, o derivada del modelo. La ventana de
    #     1M se detecta de DOS formas: (a) el marcador "[1m]" en el id del modelo, y (b) los modelos
    #     1M-NATIVOS que llevan el id PELÓN, SIN sufijo (opus-4-7/4-8/5, sonnet-5, fable-5, mythos-5).
    #     Sin (b) esos modelos caían al default de 200K → el hook gritaba "¡compacta!" con la ventana real
    #     al ~13-19% (falso positivo real, jul 2026, Opus 5 y 4.8: /context marcaba 166K/1M=17% y el hook
    #     "89% rumbo al auto-compact"). La lista es CONSERVADORA: un modelo desconocido asume 200K (avisa
    #     de MÁS, no de menos), y el invariante físico (1b) corrige hacia 1M en cuanto el ctx pasa de 200K.
    #     Precedencia settings: user < proyecto < local (el más específico gana → recorremos en ese orden).
    WINDOW="${AVISO_CONTEXTO_WINDOW_TOKENS:-}"
    case "$WINDOW" in
      ''|*[!0-9]*)
        model=""
        for s in "$HOME/.claude/settings.json" "$ROOT/.claude/settings.json" "$ROOT/.claude/settings.local.json"; do
          [ -f "$s" ] || continue
          m=$(jq -r '.model // empty' "$s" 2>/dev/null)
          [ -n "$m" ] && model="$m"
        done
        case "$model" in
          *'[1m]'*)                                                      WINDOW=1000000 ;;  # marcador explícito
          *opus-4-7*|*opus-4-8*|*opus-5*|*sonnet-5*|*fable-5*|*mythos-5*) WINDOW=1000000 ;;  # 1M-NATIVOS (id pelón)
          *)                                                             WINDOW=200000  ;;  # desconocido → conservador
        esac
        ;;
    esac
    # (1b) AUTO-CORRECCIÓN por invariante FÍSICO: el contexto no cabe en una ventana MENOR que él mismo.
    #      Si la ventana quedó en la chica (200K) por una detección fallida en runtime pero el ctx real
    #      YA la supera, es imposible que sea una sesión de 200K (habría auto-compactado mucho antes) →
    #      la única ventana MAYOR conocida de Claude es 1M → promuévela. Ata el techo al dato DURO del
    #      transcript en vez de a leer bien settings. Solo SUBE la ventana → nunca crea falsos positivos.
    [ "$ctx" -gt "$WINDOW" ] 2>/dev/null && WINDOW=1000000
    # (2) pct de auto-compact: override del usuario (el CLI la respeta) o default 92 (holgura p/ checkpoint).
    PCT="${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-92}"
    case "$PCT" in ''|*[!0-9]*) PCT=92 ;; esac
    { [ "$PCT" -ge 1 ] && [ "$PCT" -le 100 ]; } 2>/dev/null || PCT=92
    CEILING=$(( WINDOW * PCT / 100 ))
    ;;
esac
[ "$CEILING" -gt 0 ] 2>/dev/null || CEILING=$(( 200000 * 92 / 100 ))

# Umbrales de banda como % del techo (aritmética entera).
t1=$(( CEILING * 76 / 100 ))   # ℹ️  heads-up con holgura
t2=$(( CEILING * 88 / 100 ))   # ⚠️  checkpoint AHORA + propón /compact
t3=$(( CEILING * 95 / 100 ))   # 🚨  INMINENTE

band=0
[ "$ctx" -ge "$t1" ] && band=1
[ "$ctx" -ge "$t2" ] && band=2
[ "$ctx" -ge "$t3" ] && band=3

# Marca de debounce: "<última_banda_avisada> <último_ctx_visto>".
last_band=0
if [ -f "$AVISO_F" ]; then
  read -r last_band _ < "$AVISO_F" 2>/dev/null || true
  case "${last_band:-}" in ''|*[!0-9]*) last_band=0;; esac
fi
# Si el contexto bajó (un /compact / sesión nueva), la banda actual es menor → re-armamos el debounce
# a la banda actual para poder volver a avisar cuando vuelva a subir.
[ "$band" -lt "$last_band" ] && last_band="$band"

# Persistimos SIEMPRE (la banda sube; el ctx sirve para depurar/futuro).
new_band=$last_band
[ "$band" -gt "$new_band" ] && new_band=$band
printf '%s %s\n' "$new_band" "$ctx" > "$AVISO_F" 2>/dev/null || true

# ¿Cruzamos una banda NUEVA (>=1)? Si no, silencio (debounce).
{ [ "$band" -ge 1 ] && [ "$band" -gt "$last_band" ]; } || exit 0

pct=$(( ctx * 100 / CEILING ))   # % RUMBO AL AUTO-COMPACT (no % de la ventana → no cuadra con /context, a propósito)
ctxk=$(( ctx / 1000 ))
ceilk=$(( CEILING / 1000 ))      # punto de auto-compact en K

# Procedencia del techo → CADA aviso se AUTO-JUSTIFICA. Si el mensaje no dice DE DÓNDE sale el %, un
# Claude nuevo lo lee como el bug 1M-vs-200K de antes y NO le cree (Jordi, 2026-07-30: "los claudios
# luego no le creen"). Cita ventana detectada + pct + su FUENTE (override DELIBERADO vs default).
if [ -n "${AVISO_CONTEXTO_CEILING_TOKENS:-}" ]; then
  PROCEDENCIA="📐 Techo fijado a mano por AVISO_CONTEXTO_CEILING_TOKENS=${AVISO_CONTEXTO_CEILING_TOKENS}."
else
  wink=$(( ${WINDOW:-200000} / 1000 ))
  if [ -n "${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-}" ]; then
    PROCEDENCIA="📐 Techo REAL ~${ceilk}K = ${PCT}% de la ventana ${wink}K, por CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=${PCT} (override DELIBERADO de Jordi, NO un bug — créele: el CLI auto-compacta a ese mismo %)."
  else
    PROCEDENCIA="📐 Techo REAL ~${ceilk}K = ${PCT}% (default) de la ventana ${wink}K detectada."
  fi
fi

# ── Escalada de urgencia por BANDA ───────────────────────────────────────────────────────────────
#   banda 1  → heads-up con holgura (aún hay margen; solo recuerda el orden checkpoint→compact).
#   banda 2  → checkpoint AHORA + propón /compact proactivo (mensaje fuerte del orden obligatorio).
#   banda ≥3 → INMINENTE: RE-checkpoint (aunque ya lo corriste — desde entonces pasó más trabajo y el
#              hilo quedó atrás) + compacta YA. El hook no puede correr el skill, pero SÍ ordenarlo.
if [ "$band" -ge 3 ]; then
  msg="🚨 AUTO-COMPACT INMINENTE (~${ctxk}K tokens ≈ ${pct}% del punto de auto-compact ~${ceilk}K). Corre \`checkpoint\` DE NUEVO AHORA MISMO —SÍ, aunque YA lo hayas corrido en este tramo: desde entonces pasó más trabajo y el hilo volcado quedó atrás— y ENSEGUIDA compacta (propón /compact al usuario con holgura). Si el auto-compact —contexto lleno, SIN aviso— te gana antes, rehidratarás un hilo VIEJO. Orden inviolable: 1) \`checkpoint\` FRESCO → 2) /compact. ${PROCEDENCIA}"
elif [ "$band" -ge 2 ]; then
  msg="⚠️ Contexto ALTO (~${ctxk}K tokens ≈ ${pct}% rumbo al auto-compact ~${ceilk}K). REGLA DURA DE ORDEN (no la saltes): ANTES de siquiera PROPONER o hacer un /compact, el skill \`checkpoint\` YA TIENE QUE HABER CORRIDO en este tramo (volcar el HILO a hilo-mental-actual.md, fresco y en la rama actual). Orden OBLIGATORIO: 1) corre \`checkpoint\` AHORA → 2) SOLO DESPUÉS propón un /compact PROACTIVO (con holgura, antes de que el auto-compact —SIN aviso— te gane). Proponer/ejecutar /compact SIN checkpoint fresco antes = perder el hilo reciente: es un ERROR. (Si YA corriste checkpoint en este tramo y sigue fresco, no lo repitas: procede.) ${PROCEDENCIA}"
else
  msg="ℹ️ Contexto creciendo (~${ctxk}K tokens ≈ ${pct}% rumbo al auto-compact ~${ceilk}K). Heads-up (aún hay HOLGURA): cuando vayas a compactar, PRIMERO corre \`checkpoint\` (vuelca el HILO a hilo-mental-actual.md, fresco y en la rama actual) y SOLO DESPUÉS compacta. No compactes sin ese volcado. (El % es RUMBO AL AUTO-COMPACT, no % de tu ventana — por eso no cuadra con /context.) ${PROCEDENCIA}"
fi

jq -n --arg c "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
exit 0
