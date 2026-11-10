# Limpieza utilitaria de cortex — la está haciendo claudio-master (no es tu cola)

unjordi pidió que claudio-master hiciera la limpieza de la auditoría (2026-10-15-auditoria-utilitario-cortex.md) para no distraerte. La auditoría sale de tu cola.

- Rama: `chore/limpieza-utilitario-2026-10` desde `epic/afinado-2026-10` @ b848056. Worktree `.cortex-wt/limpieza`. Un agente Sonnet, una sección a la vez y un commit por sección: normas → widgets → hooks → skills → bin e instaladores.
- Solo texto: comentarios, prosa de los skills, mensajes impresos y textos de la UI. No toca la lógica.
- Archivos EXCLUIDOS para no chocar contigo: los que cambia `fix/afinado-guards-2026-10` (analizar-comando-git, detectar-secretos, dod-verificar, merge-develop-guard, proteger-arbol, ramas-zombie, tests-locales/test-merge-sync-upstream, test-brain.sh), más `bin/checkpoint-mecanico.js` (lo tienes sin commitear en la épica) y los skills reconstruir-contexto, checkpoint y rehidratar-hilo. Esos van en una segunda pasada cuando tus ramas entren a la épica.
- Gate: la suite no puede subir sus FAIL respecto a la línea base. Al terminar, claudio-master revisa los diffs y te avisa para que la juntes a la épica cuando te convenga. No la empuja a origin.

## Decisión de cierre de la épica
DECISIÓN unjordi 2026-10-15: la prueba en vivo de los guards va AL TERMINAR la mini-épica afinado-2026-10: se integra a develop, se instala desde develop en la cachy y en la Mac, y ahí se prueba en vivo con él [user: "terminando esta mini epic lo instalamos desde develop en la cachy y mac, y lo probamos en vivo"].

## TERMINADA — lista para tu merge LOCAL a la épica
- Rama `chore/limpieza-utilitario-2026-10` @ `4777871`, base `b848056`. 7 commits, 132 archivos, −2620/+2041. Suite 1404 PASS · 0 FAIL en cada sección y al final. Residuos medidos con grep: 458 → ~40, casi todos legítimos (lápidas del MANIFEST que son datos, URLs del repo, el header `anthropic-beta`, ejemplos de formato de fecha, "lección" como concepto).
- `4777871` además: norma nueva «Delegar a agentes: UNO secuencial por default» (reemplaza «Orquesta: delega lo paralelizable») y **retira `orquestar-fanout`** (lápida en skills/MANIFEST, refs en skills/README/MEMORY.md/install-brain/3 widgets, leyenda y SVG regenerados, test s5 ajustado). Lo pidió unjordi: "hay que robustecer bonito la regla en el CLAUDE.md global que se siembra con el cortex y deprecar ese skill".
- Tu épica avanzó (49da88f, 9cf90f0…) desde b848056. Espera conflictos SOLO de texto; si chocan en tus archivos, gana tu lógica y se re-aplica la limpieza del comentario.

## Te queda a ti
1. Segunda pasada sobre los archivos excluidos cuando entren tus guards: analizar-comando-git, detectar-secretos, dod-verificar, merge-develop-guard, proteger-arbol, ramas-zombie, tests-locales/test-merge-sync-upstream, test-brain.sh (440 líneas con candidatos), checkpoint-mecanico.js, y los skills checkpoint, rehidratar-hilo y reconstruir-contexto. Mapas en tu buzón: 2026-10-15-auditoria-utilitario-cortex.md.
2. `src/term-broker/**` no se tocó: su PROCEDENCIA.md dice que es copia byte a byte de axon. Si se limpia, es en axon.
3. Los flowcharts `04-delegacion-orquestar-fanout` y `12-orquestar-fanout-sin-ninera` (y una mención en el 07) dibujan el proceso del skill retirado: rehacerlos para la norma nueva o retirarlos (decisión tuya de docs).
