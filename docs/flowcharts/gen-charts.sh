#!/usr/bin/env bash
# gen-charts.sh — regenera TODOS los .svg desde sus .dot (fuente única = los .dot).
# Rutina única de regeneración: tras editar cualquier NN-*.dot, corre esto y commitea el .svg junto al .dot.
# Requiere graphviz (`dot`). macOS: `brew install graphviz` · Debian/Ubuntu: `apt install graphviz`.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v dot >/dev/null 2>&1; then
  echo "❌ falta graphviz (comando dot). Instálalo: brew install graphviz / apt install graphviz" >&2
  exit 1
fi

# Por default regenera SOLO los .svg cuyo .dot es más nuevo (evita churn espurio si tu graphviz
# serializa distinto al que hizo los .svg commiteados). `--force` regenera TODOS (rebuild deliberado).
force=""; [ "${1:-}" = "--force" ] && force=1
n=0 ignorados=""
for f in [0-9]*.dot; do
  [ -e "$f" ] || continue
  svg="${f%.dot}.svg"
  # RED contra la TRAMPA DEL CATCH-ALL (docs/flowcharts/* está gitignored por default): un chart sin su
  # línea `!` en .gitignore se pierde SIN avisar en `git add`. Se chequea SIEMPRE, aunque no se regenere.
  for x in "$f" "$svg"; do
    git check-ignore -q "$x" 2>/dev/null && ignorados="$ignorados $x"
  done
  # Regenera SOLO si el .dot es más nuevo (o --force): evita churn espurio por versión de graphviz.
  if [ -z "$force" ] && [ -e "$svg" ] && [ ! "$f" -nt "$svg" ]; then continue; fi
  dot -Tsvg "$f" -o "$svg"
  echo "  ✅ $svg"
  n=$((n+1))
done
echo "regenerados: $n chart(s) · $(dot -V 2>&1)"
if [ -n "$ignorados" ]; then
  echo "⚠️  IGNORADOS por .gitignore (se perderían en git add) → agrégales su línea '!':$ignorados" >&2
fi
