#!/usr/bin/env bash
# verificar-arbol-sync.sh — PARITY-CHECK del árbol del cerebro (mecanismo durable anti-drift).
#
# El árbol (familias 🔒/🔔/📜/💡) vive DUPLICADO en varios catálogos y hoy NO se genera desde una
# fuente única (esa decisión está PARQUEADA — generar los brainTiers de los widgets necesita QA visual).
# Mientras tanto, su paridad se VERIFICA aquí: si un catálogo se queda atrás (como pasó — README con 10
# skills mientras brain/skills/ tenía 17), este check FALLA (exit 1) en CI y lo caza.
#
# FASE 1 (este check, exacto y verificable sin build): la familia 💡 Skills entre
#   README árbol  ↔  CLAUDE.md árbol  ↔  dirnames de brain/skills/
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

# Extrae los NOMBRES de skill de la familia 💡 de un archivo con el bloque de árbol (README o CLAUDE.md).
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
C="$(arbol_skills CLAUDE.md)"

fail=0
echo "brain/skills/: $(echo "$B" | grep -c .) · README árbol: $(echo "$R" | grep -c .) · CLAUDE árbol: $(echo "$C" | grep -c .)"

# (1) README y CLAUDE deben listar EXACTAMENTE el mismo set de skills.
d_rc="$(comm -3 <(echo "$R") <(echo "$C"))"
if [ -n "$d_rc" ]; then
  echo "❌ README y CLAUDE.md difieren en la familia 💡 Skills:"
  echo "$d_rc" | sed 's/^\t/   solo en CLAUDE: /; s/^\([^ ]\)/   solo en README: \1/'
  fail=1
fi

# (2) Todo skill REAL (brain/skills/) debe aparecer en ambos árboles.
for s in $B; do
  echo "$R" | grep -qx "$s" || { echo "❌ README árbol NO lista el skill real: $s"; fail=1; }
  echo "$C" | grep -qx "$s" || { echo "❌ CLAUDE árbol NO lista el skill real: $s"; fail=1; }
done

# (3) Skills en el árbol que NO están en brain/skills/ → solo se permite el KNOWN_PENDING.
for s in $R; do
  echo "$B" | grep -qx "$s" && continue
  [ "$s" = "$KNOWN_PENDING" ] && { echo "ℹ️  '$s' en el árbol y aún no en brain/skills/ (esperado — PR #234)."; continue; }
  echo "❌ README árbol lista '$s' que NO existe en brain/skills/ (¿typo o skill borrado?)"; fail=1
done

if [ "$fail" -eq 0 ]; then
  echo "✅ parity-check árbol (fase 1): README ↔ CLAUDE.md ↔ brain/skills/ en paridad."
else
  echo ""
  echo "⚠️  DRIFT del árbol. Sincroniza la familia 💡 Skills en README.md + CLAUDE.md con brain/skills/."
fi
exit $fail
