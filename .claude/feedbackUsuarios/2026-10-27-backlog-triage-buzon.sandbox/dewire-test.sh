#!/usr/bin/env bash
# Reproduce el filtro jq EXACTO de dewire_hook (sincronizar-cerebro.sh:152-158) sobre un settings con 2 hooks en la misma entrada Stop.
S="$1"; SRC="$2"
cat > "$S/settings-dewire.json" <<'J'
{"hooks":{"Stop":[{"hooks":[
 {"type":"command","command":"bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/dod-verificar.sh\""},
 {"type":"command","command":"bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/recordar-cosechar.sh\""}]}]}}
J
# extrae el cuerpo jq de dewire_hook del script real (lineas entre "jq --arg pat" y la comilla de cierre)
awk '/^dewire_hook\(\)/{f=1} f{print} /^}/{if(f) exit}' "$SRC/brain/sincronizar-cerebro.sh" > "$S/dewire-fn.sh"
cp "$S/settings-dewire.json" "$S/settings-dewire.work.json"
bash -c '. "$1"; dewire_hook "$2" recordar-cosechar' _ "$S/dewire-fn.sh" "$S/settings-dewire.work.json"
echo "--- resultado (debe conservar dod-verificar):"; cat "$S/settings-dewire.work.json"
