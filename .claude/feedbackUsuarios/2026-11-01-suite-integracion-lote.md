# Suite completa sobre integracion/lote (f2a9af6f) en la cachy — claudio-master, 2026-11-01 ~21:00
Log: cachy:/tmp/tb-integ.log. Resultado: 1415 PASS · 15 FAIL.

## Ya fallaban en develop (6) — filas nuevas del lote, como acordamos
juez-comun (a·#2) y (a3·#2) · verificar-cerebro drift sin dirección · A2/M4 `--dry-run` muta CLAUDE.md · arbol (drift entre catálogos) · f2 (baseline de paridad).

## Fila 14, esperados (3)
e6c4 (leyenda de los .dot) · e6c5 (.svg rancios: retirado-dod-verificar / falta-mandato-loop) · f3 (baseline de flowcharts).

## REGRESIONES DE LA COMBINACIÓN (6) — ninguna sale en las ramas por separado; se arreglan en ramas desde integracion/lote
1. b6-cuota «no relanzó con fetched_at viejo» (test 7a, de apagar): el test borra el sello de throttle en la ruta VIEJA (`$QROOT/.claude/memory/.cuota-fetch-forzado`), pero con la fila 4 el sello vive en ${CLAUDE_CONFIG_DIR}/state/<cksum>/. El sello de la corrida anterior sigue ahí → throttled → no relanza. El test debe calcular la ruta con cortex_state_dir, igual que el hook.
2. d2 (dos asertos): prueban el detector de aliases de PowerShell (`-like` del EDITION, extracción edition/bite) que la fila 9 retiró de install-brain.ps1. Retirar esas baterías junto con el detector.
3. ref bidireccional NUEVA ×2: aviso-contexto ↔ estado-cerebro-comun y estado-cerebro-comun ↔ limpiar-impl-ramas (la lib nueva de la fila 4). Revisar si es ciclo real o si la lib solo define funciones (entonces va al allowlist con su porqué).
4. H18 «cross-repo no manejado»: el test espera el comportamiento viejo de cerrar-slice con --repo inexistente (avisar y seguir); la fila 7 lo cambió a error duro sin clon local (es su BAJO del backlog LOTE-F7). O el test se actualiza al contrato nuevo, o se adopta lo que propuse (con --forge explícito, avisar y seguir) y el test queda como está.

## Re-corrida sobre integracion/lote 9548b48 (cachy, ~21:10): 1418 PASS · 9 FAIL
Las 6 regresiones de la combinación desaparecieron. ✅
Quedan: 3 de la fila 14 (e6c4, e6c5, f3) y 6 que en la cachy fallan y, según tu corrida, en la Mac no: juez-comun (a·#2) y (a3·#2), verificar-cerebro drift sin dirección, A2/M4 --dry-run muta CLAUDE.md, arbol, f2. Que una prueba pase en la Mac y falle en Linux es una de dos cosas, y cada una se decide midiendo: (a) bug real en Linux (p. ej. el --dry-run que escribe, o el llavero de Linux en juez-comun) → se arregla; (b) la prueba depende del entorno → dice SKIP con el motivo, nunca FAIL ni PASS. arbol y f2 pueden ser parte de la fila 14 (catálogos y paridad de README/MEMORY): confírmalo al cerrarla. Corre la batería de esas 6 en la cachy (worktree /tmp/tb-integ ya está en 9548b48).

## Con la fila 14 mergeada (integracion/lote 5a4c437, cachy, mi worktree /tmp/tb-claudio): 1425 PASS · 2 FAIL
1. e6c5: «.svg RANCIO — 09-…svg:retirado-dod-verificar, 14-…svg:retirado-dod-verificar». El 09 y el 14 mencionan dod-verificar como retiro y el checker de .svg lo cuenta como si estuviera vivo. O el .svg commiteado no es el que genera el .dot actual (regenéralo y compáralo), o el checker de .svg no distingue la mención de retiro como sí lo hace el de .dot (f3-fix «mención histórica → silencio»). Tú lo reportaste verde en la cachy: corre exactamente `bash brain/test-brain.sh` en la cachy sobre 5a4c437 y mira por qué difiere.
2. f3-fix: «el fixture limpio dio ❌» — regresión de la fila 14: el fixture del test de verificar-charts-sync no trae .drawio y el check nuevo 1b (cada .dot debe tener su .drawio) lo tumba. El fixture debe incluir el .drawio (o generarlo), y hace falta un caso que pruebe que un .dot sin .drawio SÍ se caza.
