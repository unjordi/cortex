#!/usr/bin/env bash
# correr-dod-verificar.sh — banco del corpus para dod-verificar (Stop hook; "frena" = {decision:"block"}).
# Corre con `bash brain/tests/corpus-fp/correr-dod-verificar.sh`.
#
# El JUEZ-Haiku va MOCKEADO (CLAUDE_DOD_JUEZ_MOCK, vía wrapper): cada caso fija el veredicto del juez que el
# corpus describe y mide la capa ESTRUCTURAL del hook (Read de imagen, imagen adjuntada por el usuario, turno
# actual vs anterior, código tocado). Los FP cuyo defecto ES la clasificación del LLM no son reproducibles
# offline (la batería LIVE `CLAUDE_DOD_JUEZ_LIVE=1` de test-brain.sh es su banco) y se listan abajo.
#
# REPRODUCIDOS (capa estructural): Read de PNG rasterizado L55 L56 L57 L58 L59 L65 L69 L102 L159 ·
#   imagen adjuntada por el usuario L44 L62 L70 L72 L87 L111 · cita de un QA hecho en el turno anterior L71.
# NO REPRODUCIBLES offline (criterio del LLM sobre estatus/cierre/visual):
#   L37 L41 L45 L60 L77 L78 L99 L110 L143 L155 L170
#   (L60 reporte de subagente atribuido · L99 revisión del source .dot con desmentido · L155 texto pegado por el
#    usuario · L170 QA de tooling interno por el master: ninguna señal estructural lo distingue de un cierre real)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib-corpus-fp.sh"
REAL="$HOOKS/dod-verificar.sh"
export CFP_MODE=block

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/cfp-dod.XXXXXX"); TX="$ROOT/tx"; mkdir -p "$TX"
GUARD="$ROOT/dod-wrap.sh"
cat > "$GUARD" <<EOS
#!/bin/bash
[ -n "\${CFP_DOD_MOCK_FILE:-}" ] && export CLAUDE_DOD_JUEZ_MOCK="\$(cat "\$CFP_DOD_MOCK_FILE")"
exec bash "$REAL"
EOS
printf 'CIERRE=no MARCA=no VISUAL=si' > "$ROOT/m-visual"
printf 'CIERRE=si MARCA=no VISUAL=no' > "$ROOT/m-cierre"
printf 'CIERRE=si MARCA=si VISUAL=no' > "$ROOT/m-cierre-marca"
printf 'CIERRE=no MARCA=no VISUAL=no' > "$ROOT/m-recita"   # el juez AFINADO (L71) para una RE-CITA de QA previo

# ── constructores de transcript (una línea JSON por evento, como el transcript real) ──
j() { jq -nc "$@"; }
u_txt()   { j --arg t "$1" '{type:"user",message:{role:"user",content:[{type:"text",text:$t}]}}'; }
u_img()   { j --arg t "$1" '{type:"user",message:{role:"user",content:[{type:"text",text:$t},{type:"image",source:{type:"base64",media_type:"image/png",data:"iVBORw0KGgo="}}]}}'; }
a_tool()  { j --arg n "$1" --arg f "$2" '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:"t1",name:$n,input:{file_path:$f}}]}}'; }
u_res()   { j '{type:"user",message:{role:"user",content:[{type:"tool_result",tool_use_id:"t1",content:"ok"}]},toolUseResult:{}}'; }
a_txt()   { j --arg t "$1" '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:$t}]}}'; }

tx_read() {   # tx_read <nombre> <png> <texto>  → turno: user, Read de imagen, resultado, texto final
  { u_txt "revisa el render"; a_tool Read "$2"; u_res; a_txt "$3"; } > "$TX/$1"; }
tx_userimg() { { u_img "mira cómo quedó"; a_txt "$2"; } > "$TX/$1"; }

run() {  # run <linea> <nota> <transcript> <mock> <esp>
  CFP_TX="$TX/$3" CFP_ENV="CFP_DOD_MOCK_FILE=$ROOT/$4" cfp_caso "$GUARD" "$1" "$2" "x" "$ROOT" "$5"
}

echo "== dod-verificar · banco del corpus (FP esperan PASAR; controles+ esperan FRENAR) =="

# ── Read de imagen rasterizada = mirar la pantalla ──
tx_read r55 /tmp/qa-pag-1.png "QA visual mío de las páginas: se ve limpio"
tx_read r56 /tmp/br_carta-1.png "QA visual mío de pág.1 de cada uno: se ve bien"
tx_read r57 /tmp/hdr-1.png "Se ve muy bien / se ve limpio"
tx_read r58 /tmp/cr-2.png "revisé los renders de la Cronología y el anexo: se ven bien"
tx_read r59 /tmp/ioc-3.png "revisé los renders de IOCs, glosario y nota: se ven bien"
tx_read r65 /tmp/final-09.png "QA visual final (miré la página): todo limpio"
tx_read r69 /tmp/p2.png "QA visual del PDF: se ve bien (leí los PNG de pdftoppm)"
tx_read r102 /tmp/03.png "los charts renderizan limpios, sin solapes"
tx_read r159 /tmp/qa-window-mac.png "MI QA visual del skill: PASS. Miré los tres PNG: se ve bien"
for L in 55 56 57 58 59 65 69 102 159; do run "$L" "Read de PNG rasterizado + aserción visual (juez: VISUAL=si)" "r$L" m-visual pass; done

# ── imagen que el USUARIO adjuntó en su mensaje del turno ──
tx_userimg i44 "Confirmado en los 3 screenshots: se ve bien"
tx_userimg i62 "se ve limpia, los em-dash salen bien, layout cuadra"
tx_userimg i70 "se ve limpio"
tx_userimg i72 "logo de MegaFlux, estilos, candado seguro, todo se ve real"
tx_userimg i87 "lo veo en tu screenshot: Cerebro global completo y activo"
tx_userimg i111 "el mío (image 18) es un cascarón; el real (image 19) se ve distinto"
for L in 44 62 70 72 87 111; do run "$L" "imagen adjuntada por el usuario + aserción visual (juez: VISUAL=si)" "i$L" m-visual pass; done

# ── L71: resumen que RE-CITA un QA visual hecho en el turno ANTERIOR. El fix es LLM-side: el juez AFINADO
# clasifica la re-cita de un QA PREVIO como VISUAL=no (no una aserción fresca a ciegas) → la capa estructural
# (que bloquea VISUAL=si sin browser-en-el-turno) NO dispara → PASA. La capa estructural era CORRECTA; el bug
# era la clasificación del juez. Aquí se mockea el veredicto AFINADO (m-recita, VISUAL=no) para medir el
# end-to-end; la CLASIFICACIÓN real (VISUAL=no para la re-cita) la valida la batería LIVE `djlive "L71"`. ──
{ u_txt "revisa el PDF"; a_tool Read /tmp/p2.png; u_res; a_txt "QA visual: se ve bien"; u_txt "¿cómo vamos?"; a_txt "Resumen: el QA visual de las páginas 2-3 ya está hecho (se ven bien)"; } > "$TX/p71"
run 71 "re-cita de un QA previo → juez afinado VISUAL=no → estructural no bloquea (clasificación real: LIVE djlive L71)" p71 m-recita pass

# ── CONTROLES POSITIVOS (DEBEN frenar) ──
{ u_txt "revisa la pantalla"; a_txt "Quedó igual que el mockup, se ve bien"; } > "$TX/c-ciego"
run - "ctrl+ aserción visual a ciegas (sin tool, sin imagen, sin marca)" c-ciego m-visual block
{ u_txt "revisa"; a_tool Read /tmp/app.ts; u_res; a_txt "se ve bien"; } > "$TX/c-readts"
run - "ctrl+ Read de un .ts (no imagen) NO cuenta como mirar la pantalla" c-readts m-visual block
{ u_txt "arregla el módulo"; a_tool Edit /x/app.ts; u_res; a_txt "El módulo quedó listo y funciona"; } > "$TX/c-codigo"
run - "ctrl+ cierre tras tocar código sin marca del usuario" c-codigo m-cierre block
{ u_txt "escribe el reporte"; a_txt "El reporte quedó terminado y entregado"; } > "$TX/c-doc"
run - "ctrl+ cierre de un entregable no-código sin marca del usuario" c-doc m-cierre block

# sanidad (no cuenta): lo VÁLIDO se acepta — cierre con marca del usuario (juez: MARCA=si con cita real)
{ u_txt "sí, quedó, ciérralo"; a_tool Edit /x/app.ts; u_res; a_txt "El módulo quedó listo"; } > "$TX/s-ok"
printf 'CIERRE=si MARCA=si VISUAL=no' > "$ROOT/m-ok"
r=$(CFP_TX="$TX/s-ok" CFP_ENV="CFP_DOD_MOCK_FILE=$ROOT/m-ok" cfp_run_guard "$GUARD" x "$ROOT")
printf '  [sanidad, no cuenta] cierre con MARCA=si: %s (esperado PASS)\n' "$r"

cfp_reporte dod-verificar
rm -rf "$ROOT"
[ "$CFP_CTRL_BAD" -eq 0 ] || exit 2
