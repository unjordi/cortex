#!/usr/bin/env bash
# gen-leyenda-arbol.sh — GENERA el subgrafo .dot de la LEYENDA de los flowcharts a partir del ÁRBOL del
# README (fuente única). Implementa CONVENCIONES.md §3/§7: la leyenda de CADA chart es el árbol COMPLETO
# del cerebro (4 familias × todas sus piezas, emoji canónico) + una mini-clave de valencia de color. NO se
# teclea a mano en cada chart (serían N copias que driftean): se regenera de aquí cuando cambia el README.
#
# Uso:
#   gen-leyenda-arbol.sh                 → imprime el subgraph cluster_leyenda a stdout
#   gen-leyenda-arbol.sh --inject F.dot  → reemplaza en F.dot el bloque entre los marcadores
#       // >>> LEYENDA-ARBOL ... >>>  y  // <<< LEYENDA-ARBOL <<<  (los deja idempotente-regenerables)
#
# Fuente del árbol: el bloque cercado (```) del README que arranca con "🔒 Hooks Forzosos".
# v1 (refinamos poco a poco): tabla HTML por familia, tema oscuro alineado a los charts actuales.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"
README="${CLAUDE_BRAIN_README:-$ROOT/README.md}"
[ -f "$README" ] || { echo "gen-leyenda-arbol: no encuentro README ($README)" >&2; exit 1; }

# ── Paleta (tema oscuro de los charts; parametrizable al refinar) ──
BG="#1b1712"; BORDER="#5fa89e"; TXT="#cfc8c0"; NAMEC="#f2ede6"; FAMC="#d97757"; FAMBG="#2b2622"

# ── Emitir el subgrafo cluster_leyenda: (1) árbol completo del README + (2) mini-clave de valencia ──
emit() {
  echo "  // >>> LEYENDA-ARBOL (generado por gen-leyenda-arbol.sh desde el árbol del README — NO editar a mano) >>>"
  echo "  subgraph cluster_leyenda {"
  echo "    label=\"LEYENDA — árbol completo del cerebro (fuente: README.md)\"; labeljust=\"l\"; fontname=\"Times\"; fontsize=14; fontcolor=\"$BORDER\";"
  echo "    color=\"$BORDER\"; penwidth=1.6; style=\"rounded\"; bgcolor=\"$BG\";"
  # (1) El ÁRBOL como tabla HTML, generado línea-a-línea desde el bloque ``` del README.
  echo "    LEY_ARBOL [shape=none, margin=0, label=<"
  echo "      <table border=\"0\" cellborder=\"1\" cellspacing=\"0\" cellpadding=\"4\" color=\"$BORDER\" bgcolor=\"$BG\">"
  awk -v BG="$BG" -v TXT="$TXT" -v NAMEC="$NAMEC" -v FAMC="$FAMC" -v FAMBG="$FAMBG" '
    function esc(s){ gsub(/&/,"\\&amp;",s); gsub(/</,"\\&lt;",s); gsub(/>/,"\\&gt;",s); return s }
    # localizar el bloque ``` que arranca con 🔒 Hooks Forzosos
    /^```/ { if (cap) { exit } infence=!infence; next }
    infence && /^🔒/ { cap=1 }
    !cap { next }
    {
      line=$0
      # ¿línea de FAMILIA? (empieza en col 0 con un emoji de familia)
      if (line ~ /^(🔒|🔔|📜|💡)/) {
        fam=line; sub(/ *—.*/,"",fam); sub(/ *·.*/,"",fam)   # emoji + nombre de familia (sin la descripción)
        printf "        <tr><td colspan=\"2\" bgcolor=\"%s\"><font color=\"%s\"><b>%s</b></font></td></tr>\n", FAMBG, FAMC, esc(fam)
        next
      }
      # ¿ítem del árbol? (├─ o └─, con posible sangría de por-repo)
      if (line ~ /^[[:space:]]*(├─|└─)/) {
        sub(/^[[:space:]]*(├─|└─)[[:space:]]*/,"",line)      # quita el conector
        if (line ~ /^📁/ || line ~ /^\(/) next               # marcador por-repo / nota → no es pieza
        emoji=line; sub(/[[:space:]].*/,"",emoji)            # 1er campo = emoji canónico
        rest=line;  sub(/^[^[:space:]]+[[:space:]]+/,"",rest)# resto = nombre + descripción
        name=rest;  sub(/[[:space:]][[:space:]]+.*/,"",name) # nombre = hasta el 1er padding de 2+ espacios (puede ser multi-palabra)
        desc=substr(rest, length(name)+1); sub(/^[[:space:]]+/,"",desc)  # descripción = lo que sigue al nombre
        printf "        <tr><td bgcolor=\"%s\"><font color=\"%s\">%s %s</font></td><td bgcolor=\"%s\"><font color=\"%s\">%s</font></td></tr>\n", \
               BG, NAMEC, esc(emoji), esc(name), BG, TXT, esc(desc)
      }
    }
  ' "$README"
  echo "      </table>>];"
  # (2) mini-clave de VALENCIA de color (CONVENCIONES §2: 🔴=DENY, 🚧=hueco; corrige el rojo=HUECO viejo).
  echo "    LEY_VAL [shape=none, margin=0, label=<"
  echo "      <table border=\"0\" cellborder=\"1\" cellspacing=\"0\" cellpadding=\"4\" color=\"$BORDER\" bgcolor=\"$BG\">"
  echo "        <tr><td colspan=\"2\" bgcolor=\"$FAMBG\"><font color=\"$FAMC\"><b>valencia de color</b></font></td></tr>"
  echo "        <tr><td bgcolor=\"#2b2b2b\" border=\"2\" color=\"#7fb069\"><font color=\"$NAMEC\">🟢</font></td><td bgcolor=\"$BG\"><font color=\"$TXT\">OK / pasa</font></td></tr>"
  echo "        <tr><td bgcolor=\"#2b2b2b\" border=\"2\" color=\"#e08e45\"><font color=\"$NAMEC\">🟠</font></td><td bgcolor=\"$BG\"><font color=\"$TXT\">aviso / ASK (no bloquea)</font></td></tr>"
  echo "        <tr><td bgcolor=\"#2b2b2b\" border=\"2\" color=\"#c9a227\"><font color=\"$NAMEC\">🟡</font></td><td bgcolor=\"$BG\"><font color=\"$TXT\">latente / frágil (funciona hoy, sin garantía)</font></td></tr>"
  echo "        <tr><td bgcolor=\"#2b2b2b\" border=\"2\" color=\"#c0392b\"><font color=\"$NAMEC\">🔴</font></td><td bgcolor=\"$BG\"><font color=\"$TXT\">DENY / bloqueo (guard OK)</font></td></tr>"
  echo "        <tr><td bgcolor=\"#2b2b2b\" border=\"2\" color=\"#9e9e9e\"><font color=\"$NAMEC\">🚧</font></td><td bgcolor=\"$BG\"><font color=\"$TXT\">hueco / deuda (por construir)</font></td></tr>"
  echo "        <tr><td bgcolor=\"$BG\"><font color=\"$NAMEC\">⚠</font></td><td bgcolor=\"$BG\"><font color=\"$TXT\">el paso ESCRIBE git</font></td></tr>"
  echo "      </table>>];"
  echo "    LEY_ARBOL -> LEY_VAL [style=invis];"
  echo "  }"
  echo "  // <<< LEYENDA-ARBOL <<<"
}

if [ "${1:-}" = "--inject" ]; then
  f="${2:-}"; [ -f "$f" ] || { echo "gen-leyenda-arbol --inject: no existe $f" >&2; exit 1; }
  if ! grep -q '// >>> LEYENDA-ARBOL' "$f" || ! grep -q '// <<< LEYENDA-ARBOL <<<' "$f"; then
    echo "gen-leyenda-arbol --inject: $f no tiene los marcadores. Añade dentro del digraph:" >&2
    echo "    // >>> LEYENDA-ARBOL ... >>>   y   // <<< LEYENDA-ARBOL <<<" >&2
    exit 2
  fi
  # El bloque va a un archivo y awk lo relee con getline (evita el bug de `-v` multilínea del awk de macOS,
  # que trunca el valor en el primer newline). El bloque YA trae sus dos marcadores → queda regenerable.
  blk="$(mktemp)"; emit > "$blk"
  tmp="$(mktemp)"
  awk -v rf="$blk" '
    /\/\/ >>> LEYENDA-ARBOL/ { while ((getline l < rf) > 0) print l; close(rf); skip=1; next }
    /\/\/ <<< LEYENDA-ARBOL <<</ { skip=0; next }
    !skip { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
  rm -f "$blk"
  echo "gen-leyenda-arbol: leyenda regenerada en $f"
else
  emit
fi
