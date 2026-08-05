#!/usr/bin/env bash
# verificar-arbol-sync.sh — PARITY-CHECK del árbol del cerebro (mecanismo durable anti-drift).
#
# El árbol (familias 🔒/🔔/📜/💡) vive DUPLICADO en varios catálogos y hoy NO se genera desde una
# fuente única (esa decisión está PARQUEADA — generar los brainTiers de los widgets necesita QA visual).
# Mientras tanto, su paridad se VERIFICA aquí: si un catálogo se queda atrás (como pasó — README con 10
# skills mientras brain/skills/ tenía 17), este check FALLA (exit 1) en CI y lo caza.
#
# FASE 1 (este check, exacto y verificable sin build): la familia 💡 Skills entre
#   README árbol  ↔  MEMORY.md árbol  ↔  dirnames de brain/skills/
# FASE 2 (TODO — necesita build+QA visual de los widgets): paridad de los 3 brainTiers
#   (src/plasmoid/.../main.qml · macos/.../PopoverView.swift · windows/.../PopupForm.cs).
#
# Uso:  bash docs/flowcharts/verificar-arbol-sync.sh        (exit 0 = paridad; exit 1 = drift)
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"
cd "$ROOT" || { echo "no pude cd a la raíz del repo ($ROOT)"; exit 2; }

# consolidar-cerebro llega con el PR #234 → aún puede no estar en brain/skills/, pero SÍ en los árboles.
KNOWN_PENDING="consolidar-cerebro"

# Extrae los NOMBRES de skill de la familia 💡 de un archivo con el bloque de árbol (README o MEMORY.md).
arbol_skills() {
  awk '
    /💡 Skills/ { s=1; next }
    s && /^```/ { exit }
    s && /^[├└]─/ {
      line=$0
      sub(/^[├└]─[[:space:]]*/, "", line)               # quita el conector
      sub(/^[^[:space:]]+[[:space:]]+/, "", line)        # quita el emoji (1er campo)
      split(line, a, /[[:space:]]/); if (a[1] != "") print a[1]   # 1er token = nombre del skill
    }
  ' "$1" | sort -u
}

B="$(find brain/skills -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort -u)"
R="$(arbol_skills README.md)"
C="$(arbol_skills .claude/memory/MEMORY.md)"

fail=0
echo "brain/skills/: $(echo "$B" | grep -c .) · README árbol: $(echo "$R" | grep -c .) · MEMORY árbol: $(echo "$C" | grep -c .)"

# (1) README y MEMORY deben listar EXACTAMENTE el mismo set de skills.
d_rc="$(comm -3 <(echo "$R") <(echo "$C"))"
if [ -n "$d_rc" ]; then
  echo "❌ README y MEMORY.md difieren en la familia 💡 Skills:"
  echo "$d_rc" | sed 's/^\t/   solo en MEMORY: /; s/^\([^ ]\)/   solo en README: \1/'
  fail=1
fi

# (2) Todo skill REAL (brain/skills/) debe aparecer en ambos árboles.
for s in $B; do
  echo "$R" | grep -qx "$s" || { echo "❌ README árbol NO lista el skill real: $s"; fail=1; }
  echo "$C" | grep -qx "$s" || { echo "❌ MEMORY árbol NO lista el skill real: $s"; fail=1; }
done

# (3) Skills en el árbol que NO están en brain/skills/ → solo se permite el KNOWN_PENDING.
for s in $R; do
  echo "$B" | grep -qx "$s" && continue
  [ "$s" = "$KNOWN_PENDING" ] && { echo "ℹ️  '$s' en el árbol y aún no en brain/skills/ (esperado — PR #234)."; continue; }
  echo "❌ README árbol lista '$s' que NO existe en brain/skills/ (¿typo o skill borrado?)"; fail=1
done

# (4) El árbol del MEMORY.md es CANÓNICO: CERCADO y ATEMPORAL (gradiente de estabilidad — atemporal como main).
# Se inspecciona SOLO el contenido ESTRICTAMENTE entre los marcadores (excluye las propias líneas
# <!-- ARBOL:START/END --> — la de START menciona 'VERIFICADO' como parte del comentario, no del árbol).
INNER="$(awk '/<!-- ARBOL:START/{f=1;next} /<!-- ARBOL:END/{f=0} f' .claude/memory/MEMORY.md)"
if [ -z "$INNER" ]; then
  echo "❌ MEMORY.md: no encontré el bloque <!-- ARBOL:START --> … <!-- ARBOL:END --> (o está vacío)."
  fail=1
else
  # (4a) DEBE ir cercado con ``` (si no, el árbol colapsa a prosa en TODO render — lección games).
  fences="$(printf '%s\n' "$INNER" | grep -c '^```')"
  first="$(printf '%s\n' "$INNER" | grep -m1 -v '^[[:space:]]*$')"
  if [ "$fences" -lt 2 ] || [ "$first" != '```' ]; then
    echo "❌ MEMORY.md: el árbol entre ARBOL:START/END NO está cercado con \`\`\` (colapsa a prosa al renderizar)."
    fail=1
  fi
  # (4b) ATEMPORAL: sin fechas 20XX-XX-XX ni RESUELTO/VERIFICADO (eso vive en las ramitas, no en el canónico).
  temporal="$(printf '%s\n' "$INNER" | grep -nE '20[0-9]{2}-[0-9]{2}-[0-9]{2}|RESUELTO|VERIFICADO' || true)"
  if [ -n "$temporal" ]; then
    echo "❌ MEMORY.md: el árbol es ATEMPORAL (gradiente de estabilidad) — quita fechas/estado de estas líneas:"
    printf '%s\n' "$temporal" | sed 's/^/     /'
    fail=1
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "✅ parity-check árbol (fase 1): README ↔ MEMORY.md ↔ brain/skills/ en paridad · árbol MEMORY.md cercado y atemporal."
else
  echo ""
  echo "⚠️  DRIFT del árbol. Sincroniza la familia 💡 Skills en README.md + MEMORY.md con brain/skills/."
fi
exit $fail
