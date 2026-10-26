#!/usr/bin/env bash
# verificar-charts-sync.sh — PARITY-CHECK de los FLOWCHARTS vs el código (mecanismo durable anti-drift).
#
# Hermano de verificar-arbol-sync.sh (ese verifica el ÁRBOL del README/MEMORY vs brain/; ESTE verifica los
# .dot de docs/flowcharts/ vs el código real). Nace de la auditoría 2026-10-23: los charts tenían drift que
# ningún check cazaba — `gen-leyenda-arbol.sh --check` caza drift de la LEYENDA incrustada, y verificar-arbol
# el catálogo, pero el CONTENIDO/referencias de los charts no se verificaba contra el código. Hallazgos reales
# que este check caza (y que motivaron su creación): (1) CONVENCIONES §9 listaba un chart 12 que no existe como
# archivo; (2) 03/07/08/13 decían "fan-out de 6/5 hooks" cuando el fan-out real (ev_de de install-brain.sh) es
# de 4; (3) un hook RETIRADO nombrado como VIVO en un nodo (hoy limpio — todas las menciones son históricas).
#
# ⚠️ ALCANCE (no leer como garantía de que los charts dicen la verdad): este check verifica REFERENCIAS
# ESTRUCTURALES (qué chart existe, qué hook se nombra, qué número de fan-out se cita) — NO el COMPORTAMIENTO ni
# el FLUJO que cada chart describe. Un chart puede pasar los 3 checks y aun así tener un nodo que miente sobre
# la lógica real de un guard (eso lo caza una lectura humana / la dupla de auditores, no este script).
#
# Uso:  bash docs/flowcharts/verificar-charts-sync.sh     (exit 0 = paridad; exit 1 = drift; exit 2 = error)
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"
cd "$ROOT" || { echo "no pude cd a la raíz del repo ($ROOT)"; exit 2; }
FC="docs/flowcharts"
CONV="$FC/CONVENCIONES.md"
fail=0

# ── Check 1: CONVENCIONES §9 (tabla "| Nº | Título |…") ↔ archivos NN-*.dot, bidireccional ──────────────
# Cada fila con Nº que NO esté marcada "NO MATERIALIZADO" debe tener su NN-*.dot; y cada NN-*.dot debe tener
# su fila. Caza el chart fantasma (listado sin archivo) y el chart huérfano (archivo sin fila).
tabla_nums=$(grep -E '^\|[[:space:]]*[0-9]{2}[[:space:]]*\|' "$CONV" 2>/dev/null \
  | grep -vi 'NO MATERIALIZADO' | sed -E 's/^\|[[:space:]]*([0-9]{2}).*/\1/' | sort -u)
dot_nums=$(ls "$FC"/[0-9][0-9]-*.dot 2>/dev/null | sed -E 's#.*/([0-9]{2})-.*#\1#' | sort -u)
for n in $tabla_nums; do
  ls "$FC/$n-"*.dot >/dev/null 2>&1 || { echo "❌ CONVENCIONES §9 lista el chart $n pero NO existe $FC/$n-*.dot (chart fantasma; márcalo 'NO MATERIALIZADO' o créalo)"; fail=1; }
done
for n in $dot_nums; do
  printf '%s\n' "$tabla_nums" | grep -qx "$n" || { echo "❌ existe $FC/$n-*.dot pero CONVENCIONES §9 no lo lista (chart huérfano; agrégalo a la tabla)"; fail=1; }
done

# ── Check 2: ningún chart nombra un hook RETIRADO como VIVO (mismo patrón que verificar-firma-canonica #11) ──
# Retirados = MANIFEST tier=retirado ∪ RETIRED. Una mención en un COMENTARIO // o CON marca de retiro en la
# misma línea es HISTORIA legítima (lápida); solo un nodo VIVO que lo nombre sin marca es drift.
HM="brain/hooks/MANIFEST"; RETF="brain/hooks/RETIRED"
RET="$( { [ -f "$HM" ] && awk '$1!~/^#/ && NF>=3 && $2=="retirado"{print $1}' "$HM"; [ -f "$RETF" ] && grep -vE '^[[:space:]]*(#|$)' "$RETF"; } | sort -u)"
RETMARK='retir|jubil|absorb|consolid|reemplaz|deprecat|antiguo|🪦|l[áa]pida|viejo|ya no|sali[eó]ron|se RETIR'
for f in "$FC"/[0-9][0-9]-*.dot; do
  [ -e "$f" ] || continue
  for h in $RET; do
    while IFS= read -r line; do
      case "$(printf '%s' "$line" | sed 's/^[[:space:]]*//')" in //*) continue ;; esac   # comentario dot = historia
      printf '%s' "$line" | grep -qiE "$RETMARK" && continue                               # marca de retiro = lápida
      echo "❌ $(basename "$f"): nombra el hook RETIRADO '$h' como VIVO (sin marca de retiro): $(printf '%s' "$line" | sed 's/^[[:space:]]*//' | cut -c1-70)"; fail=1
    done < <(grep -- "$h" "$f" 2>/dev/null)
  done
done

# ── Check 3: el conteo del fan-out PreToolUse/Bash en los charts == el REAL (ev_de de install-brain.sh) ──
# Deriva el canónico contando los nombres que ev_de mapea a "PreToolUse|Bash" (fuente de verdad del cableado).
# Luego exige que toda frase que declara ese conteo en los charts/CONVENCIONES lo cite igual.
EVLINE="$(grep -E '\)[[:space:]]*echo[[:space:]]*"PreToolUse\|Bash"' brain/install-brain.sh | head -1)"
CANON="$(printf '%s' "$EVLINE" | sed -E 's/\).*//; s/[[:space:]]//g' | tr '|' '\n' | grep -c .)"
if [ -z "$CANON" ] || [ "$CANON" -lt 1 ] 2>/dev/null; then
  echo "ℹ️  no pude derivar el conteo del fan-out de ev_de (install-brain.sh) — omito el check 3"
else
  # Frases git-fan-out-ESPECÍFICAS que cargan el conteo: 'fan-out de N' y 'raíz de N'. El conteo es UN dígito
  # (1-9); una referencia a CHART es 2 dígitos 0-padded (`fan-out de 03`) → se descarta con `^[0-9]$`. Se evita
  # 'N hooks' a propósito: ese phrasing lo usan TAMBIÉN los otros fan-outs (Task=2, SessionStart=4) → ambiguo.
  bad_counts="$(grep -rhoE 'fan-out de [0-9]+|raíz de [0-9]+' "$FC"/*.dot "$CONV" 2>/dev/null \
    | grep -oE '[0-9]+$' | grep -E '^[0-9]$' | sort -u | grep -vx "$CANON" || true)"
  if [ -n "$bad_counts" ]; then
    echo "❌ conteo del fan-out PreToolUse/Bash en los charts DIFIERE del real (ev_de → $CANON hooks). Conteos (1 dígito) hallados que NO son $CANON: $(printf '%s' "$bad_counts" | tr '\n' ' ')"
    echo "   Revisa 'fan-out de N' / 'raíz de N' (N de un dígito = conteo; NN = ref a chart) en $FC/*.dot y CONVENCIONES.md"
    fail=1
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "✅ parity-check flowcharts: CONVENCIONES §9 ↔ NN-*.dot · 0 hooks retirados como vivos · fan-out = $CANON (== ev_de)."
else
  echo ""
  echo "⚠️  DRIFT de flowcharts. Sincroniza docs/flowcharts/*.dot + CONVENCIONES.md con el código (doc=realidad) y regenera los .svg con gen-charts.sh."
fi
exit $fail
