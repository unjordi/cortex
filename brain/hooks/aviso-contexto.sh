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
# Bandas ABSOLUTAS como % de un techo (auto-compact observado ~660K): ℹ️ 76% · ⚠️ 88% · 🚨 95%. El techo
# es tunable por env `AVISO_CONTEXTO_CEILING_TOKENS` (default 660000). Al ser absolutas ya NO se necesita
# baseline: tras un /compact el `usage` baja SOLO → la banda cae SOLA → el aviso se limpia SOLO (auto-cura).
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

# Techo (punto ~auto-compact) tunable por env; guarda contra basura → default razonable.
CEILING="${AVISO_CONTEXTO_CEILING_TOKENS:-660000}"
case "$CEILING" in ''|*[!0-9]*) CEILING=660000;; esac
[ "$CEILING" -gt 0 ] 2>/dev/null || CEILING=660000

# Tokens de contexto ACTUALES = último `usage` del transcript (excluye subagentes/sidechain, que traen
# su propio usage y contaminarían la medición del hilo principal). fromjson? salta líneas malformadas.
ctx=$(tail -n 400 "$tp" 2>/dev/null | jq -rR '
    fromjson? | select(.isSidechain != true) | (.message.usage // empty)
    | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)
  ' 2>/dev/null | tail -1 | tr -cd '0-9')
[ -n "$ctx" ] || exit 0                          # sin usage aún → nada que medir (fail-open)

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

pct=$(( ctx * 100 / CEILING ))
ctxk=$(( ctx / 1000 ))

# ── Escalada de urgencia por BANDA ───────────────────────────────────────────────────────────────
#   banda 1  → heads-up con holgura (aún hay margen; solo recuerda el orden checkpoint→compact).
#   banda 2  → checkpoint AHORA + propón /compact proactivo (mensaje fuerte del orden obligatorio).
#   banda ≥3 → INMINENTE: RE-checkpoint (aunque ya lo corriste — desde entonces pasó más trabajo y el
#              hilo quedó atrás) + compacta YA. El hook no puede correr el skill, pero SÍ ordenarlo.
if [ "$band" -ge 3 ]; then
  msg="🚨 AUTO-COMPACT INMINENTE (~${ctxk}K tokens de contexto ≈ ${pct}% del techo). Corre \`checkpoint\` DE NUEVO AHORA MISMO —SÍ, aunque YA lo hayas corrido en este tramo: desde entonces pasó más trabajo y el hilo volcado quedó atrás— y ENSEGUIDA compacta (propón /compact al usuario con holgura). Si el auto-compact —contexto lleno, SIN aviso— te gana antes, rehidratarás un hilo VIEJO. Orden inviolable: 1) \`checkpoint\` FRESCO → 2) /compact."
elif [ "$band" -ge 2 ]; then
  msg="⚠️ Contexto ALTO (~${ctxk}K tokens ≈ ${pct}% del techo). REGLA DURA DE ORDEN (no la saltes): ANTES de siquiera PROPONER o hacer un /compact, el skill \`checkpoint\` YA TIENE QUE HABER CORRIDO en este tramo (volcar el HILO a hilo-mental-actual.md, fresco y en la rama actual). Orden OBLIGATORIO: 1) corre \`checkpoint\` AHORA → 2) SOLO DESPUÉS propón un /compact PROACTIVO (con holgura, antes de que el auto-compact —SIN aviso— te gane). Proponer/ejecutar /compact SIN checkpoint fresco antes = perder el hilo reciente: es un ERROR. (Si YA corriste checkpoint en este tramo y sigue fresco, no lo repitas: procede.)"
else
  msg="ℹ️ Contexto creciendo (~${ctxk}K tokens ≈ ${pct}% del techo). Heads-up (aún hay HOLGURA): cuando vayas a compactar, PRIMERO corre \`checkpoint\` (vuelca el HILO a hilo-mental-actual.md, fresco y en la rama actual) y SOLO DESPUÉS compacta. No compactes sin ese volcado."
fi

jq -n --arg c "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
exit 0
