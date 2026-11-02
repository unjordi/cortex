#!/usr/bin/env bash
# gen-charts.sh — regenera los artefactos de cada flowchart desde su .dot (FUENTE ÚNICA).
# Por cada NN-*.dot genera DOS artefactos, para que no driften entre sí (ver CONVENCIONES.md):
#   · NN-*.svg    — la VISTA (graphviz, vectorial, ~100KB) que se ve al navegar el repo
#   · NN-*.drawio — EDITABLE en draw.io (vía bin/dot2drawio.py, con el layout que calculó graphviz)
# Tras editar cualquier NN-*.dot corre esto y commitea los tres juntos.
# Requiere graphviz (`dot`) y python3 (para dot2drawio). macOS: brew install graphviz · Debian: apt install graphviz.
set -euo pipefail
cd "$(dirname "$0")"
D2D="../../bin/dot2drawio.py"

if ! command -v dot >/dev/null 2>&1; then
  echo "❌ falta graphviz (comando dot). Instálalo: brew install graphviz / apt install graphviz" >&2
  exit 1
fi
have_d2d=1
if ! command -v python3 >/dev/null 2>&1 || [ ! -f "$D2D" ]; then
  echo "⚠️  sin python3 o sin $D2D → regenero solo los .svg (NO los .drawio)." >&2
  have_d2d=""
fi

# Por default regenera SOLO los artefactos cuyo .dot es más nuevo (evita churn espurio si tu graphviz
# serializa distinto al que hizo los commiteados). `--force` regenera TODOS (rebuild deliberado).
force=""; [ "${1:-}" = "--force" ] && force=1
n=0 nd=0 ignorados=""
for f in [0-9]*.dot; do
  [ -e "$f" ] || continue
  svg="${f%.dot}.svg"
  drawio="${f%.dot}.drawio"
  # RED contra la TRAMPA DEL CATCH-ALL (docs/flowcharts/* está gitignored por default): un artefacto sin su
  # línea `!` en .gitignore se pierde SIN avisar en `git add`. Se chequea SIEMPRE, aunque no se regenere.
  for x in "$f" "$svg" "$drawio"; do
    git check-ignore -q "$x" 2>/dev/null && ignorados="$ignorados $x"
  done
  if [ -n "$force" ] || [ ! -e "$svg" ] || [ "$f" -nt "$svg" ]; then
    dot -Tsvg "$f" -o "$svg"; echo "  ✅ $svg"; n=$((n+1))
  fi
  if [ -n "$have_d2d" ] && { [ -n "$force" ] || [ ! -e "$drawio" ] || [ "$f" -nt "$drawio" ]; }; then
    if python3 "$D2D" "$f" "$drawio" >/dev/null 2>&1; then echo "  ✅ $drawio"; nd=$((nd+1)); else echo "⚠️  dot2drawio falló: $f" >&2; fi
  fi
done
echo "regenerados: $n .svg · $nd .drawio · $(dot -V 2>&1)"
if [ -n "$ignorados" ]; then
  echo "⚠️  IGNORADOS por .gitignore (se perderían en git add) → agrégales su línea '!':$ignorados" >&2
fi
