#!/usr/bin/env bash
# verificar-firma-canonica.sh — DETECTOR (flag, no auto-mutador) de la FIRMA-ÁRBOL canónica
# en un cerebro INSTANCIADO (los que produce cortex: cps, fluxcore, plantilladotnet…).
#
# Hoy los cerebros DRIFTEAN de la firma canónica (fluxcore estaba plano: memorias sin prefijo,
# CLAUDE.md viejo con prosa de guards retirados). Este check las CAZA de forma determinista.
# NO reescribe nada — solo REPORTA desviaciones para que un humano (o la skill `canonizar-cerebro`)
# las arregle. Es el detector que alimenta el GATE del auditor (#44).
#
# La firma canónica (ver CLAUDE.example-barebones.md / MEMORY.example-barebones.md del cortex,
# instancia de referencia = cps y fluxcore):
#   CLAUDE.md (raíz) = firma-árbol: 🎯 Misión → 🧠 Antes de construir → 📁 Dónde va cada cosa →
#                      🖋️ LA FIRMA (árbol capacidades→artefactos) → 🛡️ Reglas duras → @import MEMORY.md
#   MEMORY.md        = detalle 1:1 de la FIRMA + índice de memorias agrupado POR PREFIJO
#                      (dom-/dev-/ux-/qa- + núcleo sin prefijo)
#   Invariante 1:1   = cada memoria (salvo *.local.md) indexada; cada enlace resuelve a archivo real.
#
# NO aplica al META-repo cortex en sí (su árbol vive en README, no en un CLAUDE.md-firma; su
# .claude/memory/ no usa prefijos dom-/dev-/ux-/qa-). Para ESE, el check es docs/flowcharts/verificar-arbol-sync.sh.
#
# Uso:  bash brain/verificar-firma-canonica.sh [RUTA_DEL_CEREBRO] [--strict]
#         RUTA_DEL_CEREBRO  raíz del repo instanciado (default: raíz git del cwd, o el cwd).
#         --strict          exit 1 también si hay WARN (drift), no solo FAIL (estructural). Para el GATE.
#
# Salida: hallazgos etiquetados por severidad + una última línea machine-parseable:
#         FIRMA-CANONICA: <FAIL> fail · <WARN> warn · <ok|drift|roto>
# Exit:   0 = sin FAIL (sin WARN en --strict);  1 = hay FAIL (o WARN en --strict);  2 = error de uso.
set -u

STRICT=0
TARGET=""
for a in "$@"; do
  case "$a" in
    --strict) STRICT=1 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    -*) echo "opción desconocida: $a" >&2; exit 2 ;;
    *) TARGET="$a" ;;
  esac
done

# Resolver la raíz del cerebro a auditar.
if [ -z "$TARGET" ]; then
  TARGET="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
[ -d "$TARGET" ] || { echo "❌ no existe el directorio: $TARGET" >&2; exit 2; }
TARGET="$(cd "$TARGET" && pwd)"

CLAUDEMD="$TARGET/CLAUDE.md"
MEMDIR="$TARGET/.claude/memory"
MEMMD="$MEMDIR/MEMORY.md"

FAIL=0; WARN=0
fail() { FAIL=$((FAIL+1)); printf '  ❌ FAIL: %s\n' "$1"; }
warn() { WARN=$((WARN+1)); printf '  ⚠️  WARN: %s\n' "$1"; }
info() { printf '  ·  %s\n' "$1"; }

echo "==> verificar-firma-canonica · cerebro: $TARGET"

# Guardarraíl: no confundir el META-repo cortex con un cerebro instanciado.
if [ -f "$TARGET/brain/hooks/MANIFEST" ] && [ -f "$TARGET/docs/flowcharts/verificar-arbol-sync.sh" ]; then
  echo "  ·  Parece el META-repo cortex (tiene brain/hooks/MANIFEST): su firma vive en README,"
  echo "     no en un CLAUDE.md-firma. Usa docs/flowcharts/verificar-arbol-sync.sh para ESE árbol. Nada que auditar aquí."
  echo "FIRMA-CANONICA: 0 fail · 0 warn · n/a (meta-repo)"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# (A) CLAUDE.md = firma-árbol con TODAS sus secciones + el @import de MEMORY.md
echo ""
echo "== (A) CLAUDE.md = firma-árbol =="
if [ ! -f "$CLAUDEMD" ]; then
  fail "no hay CLAUDE.md en la raíz ($CLAUDEMD) — la firma-árbol es el entry-point canónico."
else
  # Cada sección se ancla por su emoji (los marcadores canónicos). grep -F = literal, UTF-8 seguro.
  check_sec() { # <patrón-grep> <nombre-humano>
    grep -qF "$1" "$CLAUDEMD" && info "sección presente: $2" || fail "CLAUDE.md sin la sección de la firma: $2 ('$1')"
  }
  check_sec '🎯'  '🎯 Misión / identidad'
  check_sec '🧠'  '🧠 Antes de construir'
  check_sec '📁 Dónde va cada cosa' '📁 Dónde va cada cosa'
  check_sec '🖋️'  '🖋️ LA FIRMA (árbol de capacidades)'
  check_sec '🛡️'  '🛡️ Reglas duras'
  # El @import de MEMORY.md (auto-carga): acepta @.claude/memory/MEMORY.md o @import … MEMORY.md
  if grep -qE '@\.?(import[[:space:]]+)?\.?/?\.claude/memory/MEMORY\.md|@\.claude/memory/MEMORY\.md' "$CLAUDEMD"; then
    info "@import de .claude/memory/MEMORY.md presente (auto-carga)"
  else
    fail "CLAUDE.md sin el @import de .claude/memory/MEMORY.md — MEMORY.md no se auto-cargaría."
  fi
  # El árbol de la firma DEBE ir cercado con fence de código (si no colapsa a prosa — lección games).
  if grep -q '^```' "$CLAUDEMD"; then
    info 'hay bloque cercado (fence ```) — el árbol de la firma no colapsa a prosa'
  else
    warn 'CLAUDE.md sin ningún bloque cercado (fence ```) — el árbol de la firma podría colapsar a prosa al renderizar.'
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# (B) MEMORY.md existe y agrupa el índice POR PREFIJO
echo ""
echo "== (B) MEMORY.md = índice por prefijo =="
if [ ! -f "$MEMMD" ]; then
  fail "no hay .claude/memory/MEMORY.md — es el detalle 1:1 de la firma."
else
  # Debe declarar la taxonomía por prefijo. Basta con que nombre los prefijos como agrupadores.
  grep -qE 'dom-' "$MEMMD" && grep -qE 'dev-' "$MEMMD" \
    && info "el índice referencia la taxonomía por prefijo (dom-/dev-/…)" \
    || warn "MEMORY.md no parece agrupar por prefijo (no menciona dom-/dev-) — ¿índice plano?"
fi

# ─────────────────────────────────────────────────────────────────────────────
# (C) Memorias PREFIJADAS (dom-/dev-/ux-/qa-) o del NÚCLEO
echo ""
echo "== (C) memorias prefijadas o núcleo =="
if [ ! -d "$MEMDIR" ]; then
  fail "no existe .claude/memory/ en $TARGET"
else
  # Núcleo = memorias sin prefijo permitidas (estado/backlog/bitácora/aprendizajes/cómo-trabajar/hilo/cementerio/MEMORY).
  NUCLEO_RE='^(estado-proyecto|bitacora|aprendizajes|como-trabajar-.+|backlog-.*|hilo-mental-actual|cementerio|MEMORY)$'
  PREFIX_RE='^(dom|dev|ux|qa)-'
  unpref=0
  while IFS= read -r f; do
    base="$(basename "$f")"
    case "$base" in *.local.md) continue ;; esac   # personal/sensible: no se juzga ni indexa
    stem="${base%.md}"
    if printf '%s' "$stem" | grep -qE "$PREFIX_RE"; then continue; fi
    if printf '%s' "$stem" | grep -qE "$NUCLEO_RE"; then continue; fi
    fail "memoria SIN prefijo canónico ni núcleo: $base  (→ renómbrala a dom-/dev-/ux-/qa- con git mv)"
    unpref=$((unpref+1))
  done < <(find "$MEMDIR" -maxdepth 1 -type f -name '*.md' | sort)
  [ "$unpref" -eq 0 ] && info "todas las memorias están prefijadas o son del núcleo."
fi

# ─────────────────────────────────────────────────────────────────────────────
# (D) Invariante 1:1  ·  cada memoria indexada  +  cada enlace resuelve a archivo real
echo ""
echo "== (D) 1:1 MEMORY.md ↔ archivos =="
if [ -f "$MEMMD" ] && [ -d "$MEMDIR" ]; then
  # (D1) cada archivo real (salvo scratch/meta/local) está NOMBRADO en MEMORY.md.
  #      Scratch/meta excluidos: MEMORY.md (es el índice), hilo-mental-actual.md (se sobrescribe, es la foto viva).
  MEMTXT="$(cat "$MEMMD")"
  noidx=0
  while IFS= read -r f; do
    base="$(basename "$f")"
    case "$base" in
      MEMORY.md|hilo-mental-actual.md) continue ;;
      *.local.md) continue ;;
    esac
    stem="${base%.md}"
    # "indexado" = su nombre (con o sin .md) aparece en MEMORY.md (link md, wikilink o ref en código).
    if printf '%s' "$MEMTXT" | grep -qF "$stem"; then continue; fi
    fail "memoria NO indexada en MEMORY.md: $base  (rompe el invariante 1:1 — agrégala a su sección de prefijo)"
    noidx=$((noidx+1))
  done < <(find "$MEMDIR" -maxdepth 1 -type f -name '*.md' | sort)
  [ "$noidx" -eq 0 ] && info "cada memoria real está indexada en MEMORY.md."

  # (D2) cada enlace md-link [..](X.md) y wikilink [[X]] de MEMORY.md resuelve a un archivo real.
  broken=0
  # md-links a archivos .md locales (ignora http/https y anclas #…)
  while IFS= read -r tgt; do
    [ -n "$tgt" ] || continue
    tgt="${tgt%%#*}"                     # quita ancla
    case "$tgt" in http*://*|mailto:*) continue ;; esac
    # resuelve relativo a .claude/memory/
    [ -f "$MEMDIR/$tgt" ] || { fail "enlace roto en MEMORY.md → ($tgt) no existe en .claude/memory/"; broken=$((broken+1)); }
  done < <(grep -oE '\]\([^)]+\.md[^)]*\)' "$MEMMD" | sed -E 's/^\]\(//; s/\)$//' | sort -u)
  # wikilinks [[X]] → X.md
  while IFS= read -r wl; do
    [ -n "$wl" ] || continue
    wl="${wl%%#*}"; wl="${wl%%|*}"       # quita ancla y alias
    [ -f "$MEMDIR/$wl.md" ] || { fail "wikilink roto en MEMORY.md → [[$wl]] no resuelve a $wl.md"; broken=$((broken+1)); }
  done < <(grep -oE '\[\[[^]]+\]\]' "$MEMMD" | sed -E 's/^\[\[//; s/\]\]$//' | sort -u)
  [ "$broken" -eq 0 ] && info "cada enlace/wikilink de MEMORY.md resuelve a un archivo real."
else
  info "(D) omitido: falta MEMORY.md o .claude/memory/."
fi

# ─────────────────────────────────────────────────────────────────────────────
# (E) Nombres de hook STALE / RETIRADOS en la prosa (CLAUDE.md + MEMORY.md)
echo ""
echo "== (E) sin nombres de hook retirados en la prosa =="
# Denylist PRECISA de hooks que el cerebro RETIRÓ: si aparecen en la prosa, la doc miente.
# (Baja tasa de FP a propósito: NO adivinamos "todo lo que parezca hook", solo lo confirmado-retirado.)
RETIRED_HOOKS="precompact-volcar-estado"
stale=0
for doc in "$CLAUDEMD" "$MEMMD"; do
  [ -f "$doc" ] || continue
  for h in $RETIRED_HOOKS; do
    if grep -qF "$h" "$doc"; then
      warn "hook RETIRADO nombrado en $(basename "$doc"): '$h' — la prosa quedó stale (ya no existe ese guard)."
      stale=$((stale+1))
    fi
  done
done
[ "$stale" -eq 0 ] && info "sin menciones a hooks retirados conocidos."

# ─────────────────────────────────────────────────────────────────────────────
echo ""
verdict="ok"
[ "$WARN" -gt 0 ] && verdict="drift"
[ "$FAIL" -gt 0 ] && verdict="roto"
echo "FIRMA-CANONICA: $FAIL fail · $WARN warn · $verdict"

if [ "$FAIL" -gt 0 ]; then
  echo "⚠️  El cerebro DRIFTEÓ de la firma canónica. Llévalo con la skill 'canonizar-cerebro' (humano-en-el-loop)."
  exit 1
fi
if [ "$STRICT" -eq 1 ] && [ "$WARN" -gt 0 ]; then
  echo "⚠️  --strict: hay drift (WARN) — el GATE lo trata como falla."
  exit 1
fi
echo "✅ firma canónica respetada (estructura, prefijos, 1:1, prosa sin hooks retirados)."
exit 0
