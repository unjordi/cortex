---
name: mandato-loop
description: El MOLDE con el que cualquier master redacta un mandato de `/loop` — la plantilla versionada del lote/épica. Úsalo cuando vayas a lanzar un `/loop` de épica/lote y necesites escribir su mandato: cómo se redacta (sin trazabilidad, sin «el LISTO lo da el usuario», criterio por fila, nada de colas ajenas) + el bloque `text` completo con todas sus secciones. NO es para `turno-nocturno` (ese es otro skill); esto es la plantilla del mandato en sí.
---

# Plantilla de mandato de loop

Un mandato de loop vive versionado en `docs/loop-<tema>.md` del repo, con la frase «Texto con el que se lanza `/loop <intervalo> …`. Fuente única: si cambia, se cambia aquí y se relanza». Abajo va UN bloque `text` con estas secciones, en este orden. Lo que va entre `<…>` se llena.

## Cómo se redacta
- Sin trazabilidad: ni citas, ni fechas, ni «decidido el…», ni números de PR de referencia. Se releen en cada vuelta y no ayudan. Las citas del usuario sirven para REDACTAR bien cada instrucción, en sus términos; la procedencia vive en la memoria y en el commit.
- Lo mismo vale para los comentarios del código que entregue el loop: la plantilla los acota en PRUEBAS §4.
- Sin «el LISTO lo da <usuario>»: el loop termina cuando el criterio se cumple medido, y lo que pide al usuario es revisar evidencia, no autorizar un cierre.
- Lo que el loop debe hacer se escribe completo, no como puntero («§3 del doc», «según el estándar»): si es criterio, va el criterio.
- Solo el trabajo del plan: nada de colas ajenas (buzón, triage) en un loop de épica; eso es otro loop.

```text
Trabaja en <REPO> (<ruta>; un worktree por fila en .claude/worktrees/<fila> desde origin/<base> con commit marcador; PR a <base> con squash, --delete-branch y Rama:/PR:, citando el grant de <archivo de grants>; tras cada merge sincroniza el folder principal sin perder las memorias sin commitear y verifica el despliegue) y no te detengas hasta <OBJETIVO en una frase, en los términos del usuario>. Arranca cada ronda leyendo completos <hilo-mental-actual.md, estado-proyecto, roadmap, doc de la épica> y este mandato; no re-investigues lo que ya está ahí. El estado de un tablero se obtiene leyéndolo completo.

PUNTO DE PARTIDA (<commit>): <cuántas filas; cuáles cerradas, cuáles verificadas sin cerrar, cuáles abiertas>. Se actualiza en cada relanzamiento.

FILAS (en este orden). Antes de tocar una, lee su detalle y escribe su caso de uso: qué hace el usuario y qué debe obtener. Cada fila tiene su CIERRA CUANDO, medido corriendo; el piso de todas es su prueba en rojo contra <base>, la contraprueba, <gates del repo> verdes, la revisión semántica (PRUEBAS §7) y su celda del roadmap en ✅.
1. <rebanada> #<fila> — <qué cambia: archivos, funciones, contrato>.
   CIERRA CUANDO: <lo que el usuario hace y obtiene, medido en el sistema corriendo; las dos direcciones: acepta lo válido y dice por qué no a lo inválido>.
2. …
Lo que necesita al usuario (root, un modelo a bajar, una decisión de producto) no detiene el loop ni se pregunta a media corrida: se deja armado (comando exacto, recomendación escrita), se junta para el reporte y se sigue con la fila siguiente.

LA ÉPICA ESTÁ TERMINADA cuando todas las filas están ✅ y su propósito se cumple en el sistema corriendo, medido por procesos y no por código. Cada fila está ✅ cuando su propio criterio de cierre se cumple, pasa sus pruebas, su diff no agrega comentarios fuera de §4, y TÚ ya realizaste la revisión semántica con los criterios de PRUEBAS §7, con calma y a detalle. El propósito de la épica —<propósito en una frase>— se mide con todo integrado y desplegado, porque ninguna fila lo mide sola: <el recorrido integrado, en cada perfil/escenario que importe, y qué pasa si falta una pieza>.
Al llegar ahí, haz una revisión semántica de la épica completa y luego pruébala como se usa: con todo lo integrado y desplegado, <el uso real: p. ej. abrir la copia de un master en el harness donde trabaja>. No se mide como código ni es un examen de tecnicismos: interésate por su proyecto y platica de verdad con él; trabaja con él, como colega, en lo que está haciendo, y mientras tanto revisa en vivo que todo funcione <qué mirar>. No le escarbes las memorias antes para armarle preguntas con respuesta conocida. Lo que se rompa se vuelve fila nueva y la épica sigue abierta; lo que te entregue se conserva como prueba de integración.
Si todo sale limpio, detén el loop y reporta:
- por fila: qué se corrió para medir su CIERRA CUANDO y qué salió, y lo que encontró su revisión semántica;
- de la épica: el recorrido integrado en cada perfil: qué funcionó, qué dijo por qué no y qué pasó al faltar cada pieza;
- del uso real: en qué se trabajó, qué se rompió y en qué fila quedó, y dónde está lo entregado y su transcript para revisarlo.
Antes de eso, cada reporte dice qué filas faltan.

CADA RONDA:
0) Re-arma el loop antes de trabajar y lee la cuota del snapshot del widget (macOS `~/Library/Caches/cortex/state.json`, Linux `~/.cache/cortex/state.json`): `jq '{h5: .five_hour.percent, h5_reset: .five_hour.resets_at, semana: .weekly.percent, semana_reset: .weekly.resets_at, updated_at}'`. 5h ≥ <umbral 5h> ⇒ solo locales; semanal ≥ <umbral semanal> ⇒ <qué se frena>; un `updated_at` de más de ~10 min ⇒ sin dato: trátalo como cuota alta.
1) Estado de lo delegado (<ps, logs, worktrees>). Lo que terminó: revísalo TÚ (diff, base, gates, el contraste de la misma prueba en el commit previo y el nuevo, corrida en vivo sobre una COPIA); si pasa, integra; si falla, corrígelo o anota el tropiezo en la bitácora de prompts y relanza con el prompt pulido. Nunca integres mientras un agente trabaja en el mismo árbol. Antes de commitear, lee una por una las líneas de comentario que agrega el diff (`git diff --cached -U0`) y deja solo lo que cumple §4; la historia que encuentres la mueves al mensaje del commit.
2) Lanza la siguiente fila con su mandato literal (archivos, funciones, cambios exactos) y sus pruebas de aceptación ya escritas por ti; exígele la sección final «qué NO verifiqué y dónde está mi punto ciego»: esa sección dirige tu revisión.
3) En la misma tanda de cada cierre concilia todos los tableros (<roadmap, estado-proyecto, lista de tareas>) antes de reportar.
4) Lo que destape la fila entra como fila nueva del roadmap en esa misma ronda.

DELEGACIÓN: el diseño de cada fila, sus pruebas de aceptación, la revisión y la medición del cierre son tuyos. Lo mecánico con salida verificable se delega por costo: script → <agente local> → <modelo grande> solo para lo rudo en serio. Uno a la vez por máquina, sin max-turns corto, con commit por paso y sus insumos commiteados. Lo que reporte un agente es una afirmación hasta que lo midas. APRENDIDO (se agrega aquí lo que cada tanda enseñe del ritmo y del prompt): <…>.

MÁQUINAS (si aplica): qué corre dónde, cómo viajan los commits entre ellas; lo que no pueda correrse se anota «pendiente en <máquina>», nunca verde.

PRUEBAS (el detalle está en el skill `estandar-pruebas`; el repo solo agrega su mecanismo y sus casos en <doc de pruebas del repo>):
- Las de aceptación las construyes tú antes de lanzar un agente, junto con su mandato.
- §1 La prueba de una prueba: cada aserto puede fallar y falla contra el código viejo (revertido y corrido, no supuesto).
- §2 Las siete firmas de rechazo: R1 no puede fallar · R2 mide el andamio, no el efecto · R3 el escenario no se montó · R4 mide el objeto equivocado · R5 el esperado quedó viejo · R6 el verde depende del entorno (lo que no corre dice SKIP) · R7 media prueba. Ningún aserto cuya respuesta correcta se pueda adivinar desde la pregunta.
- §3 Lo que SÍ hace una prueba: efecto observable por el canal del usuario, las dos direcciones, escenario comprobado, esperado derivado, nombre honesto, dependencia declarada.
- §4 Comentarios en el código: dicen qué hace el código, su contrato (entradas, salida, qué pasa al fallar) y, solo si no es obvio, el porqué en una o dos líneas justo donde se mete la pata, apuntando al test o guard que lo frena. No llevan citas ni nombres de personas, fechas, números de fila, hallazgo, nota, PR o commit, «antes…/ahora…», «corrección de…», ni la historia del incidente. Eso va en el mensaje del commit y en la memoria. Un comentario de más de tres líneas se parte o se va al doc.
- §5 Al revisar una prueba existente: aislada y en la suite, veredicto por aserto (conservar · arreglar · retirar).
- §6 Mecanismo: <qué caza el probe automático>; lo demás es criterio tuyo.
- §7 Revisión semántica de CADA ítem (cada fila, cada prueba nueva y cada hallazgo se cierra con la suya, escrita junto al ítem; la de la épica va aparte, encima, nunca en su lugar):
  §7.1 Vuelve al porqué: lee el origen de la fila y pregúntate si ese problema ya no podría repetirse. Úsala en vivo, con modelo real sobre una copia, como la usaría quien la pidió; si para entender la salida hay que excavar, no está resuelta aunque pase.
  §7.2 Busca las formas de fallar que la prueba no fija: ¿se recupera?, ¿castiga de más?, ¿qué pasa con la variante parecida en las palabras pero no en el sentido? Lo que encuentres se vuelve caso nuevo.
  §7.3 Mira qué le hace al resto: corre en vivo los recorridos vecinos que el cambio puede tocar y compara con antes.
  §7.4 Revisa el diseño contra la arquitectura: capa correcta, sin un segundo mecanismo para lo mismo, salida accionable, valores configurables.
  §7.5 Si al relatar el cierre hay que matizar, todavía no está.
- §8 La pasada de limpieza (`estandar-pruebas` §9: re-verificar lo cerrado · prueba por prueba · revisión semántica del código) corre en cada cierre de slice sobre lo que toca y al cerrar la épica sobre toda ella; sus hallazgos se resuelven antes del merge.

HIGIENE MENTAL (el cerebro):
- Cada ronda: checkpoint LIGERO con el skill /checkpoint (no de memoria). Antes de sobrescribir hilo-mental-actual.md, léelo y conserva lo vivo que no sepas por qué desapareció; sube todo pendiente/decisión durable a estado-proyecto.md y una línea a bitacora.md con >>.
- Cada ~2 h, cada vez que integres, y siempre ante el aviso de contexto o antes de compactar: checkpoint COMPLETO invocando el skill /checkpoint (árbol de memorias+tooling, DISEÑO de lo que se construye, PLAN con el cómo, RESUELTO HOY, COSECHA DURABLE). No encadenes checkpoints sin trabajo entre ellos.
- Si el hilo pasa de ~200 líneas, lo viejo va a hilo-mental-actual-overflow.md. Commitea la memoria dentro del PR de la fila. Confía en el autocompact: tu memoria en disco es la que sobrevive.
- El compact es del loop, no del usuario: nunca le pidas que compacte. Si el contexto aprieta, corre el checkpoint COMPLETO y sigue trabajando; el autocompact llega solo.
- Un checkpoint cuenta solo si lo hizo el skill: editar hilo-mental-actual.md con Edit/Write o a mano no es checkpoint. Cierra cada uno con `. ~/.claude/hooks/contrato-hilo.sh && verificar_hilo .claude/memory/hilo-mental-actual.md fresco` y cita su salida en el reporte de la ronda.
- Lo aprendido del trato con el usuario va a su como-trabajar global; lo del proyecto, a su memoria. HUD = esta cola de filas.

REGLAS: <las duras del proyecto>. Código y commits utilitarios; los comentarios, según PRUEBAS §4 (la historia va al commit, nunca al código). Todo valor elegible configurable. Nada de --no-verify. Sin paliativos que apaguen piezas: causa raíz medida. Pruebas solo sobre copias. Matar solo por PID. De noche (22:00–08:00) sin avisos sonoros ni diálogos de root. No te detengas a preguntar si sigues; con varias opciones válidas, elige, asienta el porqué y sigue.
```
