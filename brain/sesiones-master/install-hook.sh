#!/usr/bin/env bash
# install-hook.sh — cablea el auto-export de sesiones master en ESTA máquina (correr UNA vez por compu).
# Copia exportar-sesion-master.sh (canónico aquí en Drive) a ~/.claude/hooks/ y lo registra en los
# eventos Stop + SessionEnd + PreCompact de ~/.claude/settings.json (idempotente). Ruta local estable
# (~/.claude/hooks/) para no depender de que Drive esté montado. Re-córrelo para refrescar el hook.
#   Stop       = backbone (con debounce) → mantiene la master fresca DURANTE la sesión (aunque nunca termine).
#   SessionEnd = estado final en salida limpia + detecta/registra masters nuevos por título.
#   PreCompact = bonus, justo antes de compactar.
#
# Uso:  ./install-hook.sh            (instala/actualiza)
#       ./install-hook.sh --uninstall (quita el cableado de los 3 eventos y el hook)
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DIR/exportar-sesion-master.sh"
HOOKS="$HOME/.claude/hooks"
DST="$HOOKS/exportar-sesion-master.sh"
GSET="$HOME/.claude/settings.json"
EVENTS="Stop SessionEnd PreCompact"

command -v jq >/dev/null 2>&1 || { echo "install-hook: falta jq (brew install jq)"; exit 1; }

if [ "${1:-}" = "--uninstall" ]; then
  if [ -f "$GSET" ]; then
    for ev in $EVENTS; do
      tmp="$(mktemp)"
      jq --arg ev "$ev" '
        if .hooks[$ev] then .hooks[$ev] |= map(select( ([.hooks[]?.command]|join(" ")) | test("exportar-sesion-master") | not )) else . end
      ' "$GSET" > "$tmp" && mv "$tmp" "$GSET"
    done
    echo "descableado de settings.json ($EVENTS)"
  fi
  rm -f "$DST" && echo "hook removido de $HOOKS"
  exit 0
fi

[ -f "$SRC" ] || { echo "install-hook: no encuentro $SRC"; exit 1; }
mkdir -p "$HOOKS"
cp -f "$SRC" "$DST"; chmod +x "$DST"
echo "ok: hook copiado a $DST"

[ -f "$GSET" ] || echo '{}' > "$GSET"
for ev in $EVENTS; do
  tmp="$(mktemp)"
  jq --arg ev "$ev" '.hooks=(.hooks//{}) | .hooks[$ev]=(.hooks[$ev]//[])
      | if any(.hooks[$ev][]?; ([.hooks[]?.command]|join(" "))|test("exportar-sesion-master"))
        then . else .hooks[$ev] += [{"hooks":[{"type":"command","command":"bash \"$HOME/.claude/hooks/exportar-sesion-master.sh\"","shell":"bash"}]}] end
     ' "$GSET" > "$tmp" && mv "$tmp" "$GSET"
  echo "ok: $ev cableado en $GSET"
done
echo ""
echo "Listo. Stop(debounce)+SessionEnd+PreCompact exportan las sesiones *-master a $DIR (Drive sincroniza)."
