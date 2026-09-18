#!/usr/bin/env bash
# verificar-arbol-sync.sh — PARITY-CHECK del árbol del cerebro (mecanismo durable anti-drift).
#
# El árbol (familias 🔒/🔔/📜/💡) vive DUPLICADO en varios catálogos y hoy NO se genera desde una
# fuente única (esa decisión está PARQUEADA — generar los brainTiers de los widgets necesita QA visual).
# Mientras tanto, su paridad se VERIFICA aquí: si un catálogo se queda atrás (como pasó — README con 10
# skills mientras brain/skills/ tenía 17), este check FALLA (exit 1) en CI y lo caza.
#
# FASE 1 (este check, exacto y verificable sin build): DOS familias del árbol entre
#   README árbol  ↔  MEMORY.md árbol  ↔  fuente real:
#     · 💡 Skills                      vs  dirnames de brain/skills/
#     · 🔒 Forzosos + 🔔 Automático     vs  brain/hooks/MANIFEST (kind=hook, tier≠retirado)
#   La mitad de HOOKS se agregó tras la auditoría de suficiencia operativa (CRÍTICO-1, 2026-09-18):
#   este mismo checker daba ✅ mientras `.claude/memory/MEMORY.md` listaba DOS guards YA retirados
#   (merge-squash-guard/confirmar-merge-develop) como vivos y ni mencionaba el reemplazo real
#   (merge-develop-guard) — porque hasta entonces esta Fase 1 SOLO miraba Skills. Antídoto: un checker
#   que no puede dar rojo ante un drift real no sirve (ver brain/test-brain.sh, batería "f2").
# FASE 2 (TODO — necesita build+QA visual de los widgets): paridad de los 3 brainTiers
#   (src/plasmoid/.../main.qml · macos/.../PopoverView.swift · windows/.../PopupForm.cs).
#
# Uso:  bash docs/flowcharts/verificar-arbol-sync.sh        (exit 0 = paridad; exit 1 = drift)
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"
cd "$ROOT" || { echo "no pude cd a la raíz del repo ($ROOT)"; exit 2; }

# Allow-list: skill YA documentado en los árboles pero aún NO aterrizado en brain/skills/ (recién anunciado).
# Hoy VACÍO (consolidar-cerebro ya existe). Pon el nombre aquí si vuelve a haber uno pendiente.
KNOWN_PENDING=""

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

# Extrae los NOMBRES de hook de las familias 🔒 Forzosos + 🔔 Automático de un archivo con el árbol
# (README o MEMORY.md). Mismo patrón que arbol_skills(), pero: (a) los bullets pueden ir INDENTADOS
# (la sub-lista "📁 por-repo · viajan en el .claude de cada repo" anida con espacios antes del
# conector ├─/└─) → se despoja el espacio inicial ANTES del conector, no solo tras él; (b) el propio
# label "📁 por-repo…" NO es un hook → se descarta explícitamente; (c) para de capturar en "📜 Normas"
# (así una sola pasada cubre 🔒+🔔 sin colarse a Normas/Skills).
arbol_hooks() {
  awk '
    /🔒 Hooks Forzosos/ { s=1; next }
    s && /📜 Normas/ { exit }
    s {
      line=$0
      n=sub(/^[[:space:]]*[├└]─[[:space:]]*/, "", line)   # quita espacio-inicial + conector (indentado o no)
      if (n == 0) next                                    # no era un bullet (encabezado de familia, nota entre paréntesis…)
      if (line ~ /^📁/) next                               # el label "por-repo" no es un hook
      sub(/^[^[:space:]]+[[:space:]]+/, "", line)          # quita el emoji (1er campo)
      split(line, a, /[[:space:]]/); if (a[1] != "") print a[1]   # 1er token = nombre del hook
    }
  ' "$1" | sort -u
}

# basename vía sed (portable BSD+GNU): -printf es GNU-only → en BSD/macOS fallaba y contaba 0 skills
# (drift espurio que además cegaba el parity real). Ver auditoría 2026-08.
B="$(find brain/skills -maxdepth 1 -mindepth 1 -type d | sed 's#.*/##' | sort -u)"
R="$(arbol_skills README.md)"
C="$(arbol_skills .claude/memory/MEMORY.md)"

# hooks REALES vivos: kind=hook, tier≠retirado (una lápida del MANIFEST NO debe seguir en el árbol).
HM="brain/hooks/MANIFEST"
if [ -f "$HM" ]; then
  HB="$(awk '$1!~/^#/ && NF>=3 && $2!="retirado" && $3=="hook"{print $1}' "$HM" | sort -u)"
else
  HB=""
fi
HR="$(arbol_hooks README.md)"
HC="$(arbol_hooks .claude/memory/MEMORY.md)"

fail=0
echo "brain/skills/: $(echo "$B" | grep -c .) · README árbol: $(echo "$R" | grep -c .) · MEMORY árbol: $(echo "$C" | grep -c .)"
echo "brain/hooks/MANIFEST (vivos, kind=hook): $(echo "$HB" | grep -c .) · README árbol: $(echo "$HR" | grep -c .) · MEMORY árbol: $(echo "$HC" | grep -c .)"

# (1) README y MEMORY deben listar EXACTAMENTE el mismo set de skills.
d_rc="$(comm -3 <(echo "$R") <(echo "$C"))"
if [ -n "$d_rc" ]; then
  echo "❌ README y MEMORY.md difieren en la familia 💡 Skills:"
  echo "$d_rc" | sed 's/^\t/   solo en MEMORY: /; s/^\([^ ]\)/   solo en README: \1/'
  fail=1
fi

# (1h) gemelo de (1) para HOOKS (🔒+🔔): README y MEMORY deben listar EXACTAMENTE el mismo set.
d_rch="$(comm -3 <(echo "$HR") <(echo "$HC"))"
if [ -n "$d_rch" ]; then
  echo "❌ README y MEMORY.md difieren en la familia 🔒/🔔 Hooks:"
  echo "$d_rch" | sed 's/^\t/   solo en MEMORY: /; s/^\([^ ]\)/   solo en README: \1/'
  fail=1
fi

# (2) Todo skill REAL (brain/skills/) debe aparecer en ambos árboles.
for s in $B; do
  echo "$R" | grep -qx "$s" || { echo "❌ README árbol NO lista el skill real: $s"; fail=1; }
  echo "$C" | grep -qx "$s" || { echo "❌ MEMORY árbol NO lista el skill real: $s"; fail=1; }
done

# (2h) gemelo de (2) para HOOKS: todo hook VIVO del MANIFEST (kind=hook, tier≠retirado) debe aparecer
# en ambos árboles; un hook RETIRADO (tier=retirado) NUNCA debe seguir apareciendo (esa es la lápida).
for h in $HB; do
  echo "$HR" | grep -qx "$h" || { echo "❌ README árbol NO lista el hook vivo del MANIFEST: $h"; fail=1; }
  echo "$HC" | grep -qx "$h" || { echo "❌ MEMORY árbol NO lista el hook vivo del MANIFEST: $h"; fail=1; }
done
if [ -f "$HM" ]; then
  RETH="$(awk '$1!~/^#/ && NF>=3 && $2=="retirado"{print $1}' "$HM" | sort -u)"
  for h in $RETH; do
    echo "$HR" | grep -qx "$h" && { echo "❌ README árbol sigue listando '$h' — tier retirado en el MANIFEST (lápida), debe salir del árbol"; fail=1; }
    echo "$HC" | grep -qx "$h" && { echo "❌ MEMORY árbol sigue listando '$h' — tier retirado en el MANIFEST (lápida), debe salir del árbol"; fail=1; }
  done
fi

# (3) Skills en el árbol que NO están en brain/skills/ → solo se permite el KNOWN_PENDING.
for s in $R; do
  echo "$B" | grep -qx "$s" && continue
  [ -n "$KNOWN_PENDING" ] && [ "$s" = "$KNOWN_PENDING" ] && { echo "ℹ️  '$s' en el árbol y aún no en brain/skills/ (esperado — allow-list KNOWN_PENDING)."; continue; }
  echo "❌ README árbol lista '$s' que NO existe en brain/skills/ (¿typo o skill borrado?)"; fail=1
done

# (3h) gemelo de (3) para HOOKS: un nombre en el árbol que no sea un hook vivo del MANIFEST → typo/desconocido.
for h in $HR; do
  echo "$HB" | grep -qx "$h" && continue
  echo "❌ README árbol lista '$h' que NO existe en brain/hooks/MANIFEST como hook vivo (¿typo, hook borrado, o falta agregarlo al MANIFEST?)"; fail=1
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
  echo "✅ parity-check árbol (fase 1): README ↔ MEMORY.md ↔ brain/skills/ ↔ brain/hooks/MANIFEST en paridad · árbol MEMORY.md cercado y atemporal."
else
  echo ""
  echo "⚠️  DRIFT del árbol. Sincroniza las familias 💡 Skills y 🔒/🔔 Hooks en README.md + MEMORY.md con brain/skills/ y brain/hooks/MANIFEST."
fi
exit $fail
