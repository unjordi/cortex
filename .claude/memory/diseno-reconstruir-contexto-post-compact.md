# Diseño — reconstruir-contexto en el post-compact y al retomar (2026-10-19)

> Decidido por unjordi con claudio-master. Pendiente de implementar (backlog: estado-proyecto.md §1).

## Pedido
[user: "quiero que sea parte del post-compact / session-start"] · [user: "no, quiero que corra DESPUÉS del límite feo de 2kb"] · [user: "después de un compact y también al retomar una sesión, plz. Basta con que el hook dé la orden. a lo que ya funciona PLZ no le muevas, que lo que ya hace el hook, se quede así"]

## Diagnóstico
El harness muestra de la salida de un hook SessionStart solo un preview de ~2 KB; el resto queda en un archivo aparte (`<persisted-output>`). Medido 2026-10-19 en claudio-master: tras el compact, `rehidratar-hilo` emitió 17,6 KB → lo que venía después del corte no se vio. La reconstrucción no cabe en el hook: la tiene que hacer la sesión con sus tools.

## Contrato
- `rehidratar-hilo.sh`, con `source` = `compact` o `resume`: antepone UNA primera línea con la orden de correr el skill `reconstruir-contexto` ANTES de actuar o planear. Todo lo demás que el hook ya emite (faro de truncado de A7, §SIGUIENTE, hilo, andamio, avisos) se queda IGUAL.
- `startup` (sesión nueva) y `clear`: sin cambio.
- Sin hilo ni andamio: sigue el aviso actual; la orden se antepone igual (es justo el caso donde más falta hace).
- Fail-open como hoy: si algo falla, el arranque sigue.
- `reconstruir-contexto` no cambia: ya resuelve por sid y saca el tramo previo con `checkpoint-mecanico.js --self --ventana previa` (medido: 0,12 s, 6,6 KB sobre un transcript de 11 MB).

## Invariante verificable
Con un hilo grande (salida > 2 KB) y `source=compact` o `resume`, la primera línea de la salida es la orden y cae dentro de los primeros 2 KB; con `startup`, la salida es byte a byte la de antes.

## Qué NO es
- No es achicar ni reordenar la salida del hook (descartado: "a lo que ya funciona PLZ no le muevas").
- No es que el hook haga la reconstrucción ni genere archivos: solo da la orden.
- No es preservar citas textuales del usuario como objetivo ([user: "yo ni quería mis citas textuales!"]). Lo que falló el 2026-10-19 fue el prompt de `/compact` de claudio ("conserva íntegro el hilo" + citas textuales), que no contó con el corte de 2 KB del rehidratado.

## Tests (uso real, deben fallar contra 52d2d8c)
1. Hilo de >2 KB, `source=compact` → la 1ª línea es la orden y está en los primeros 2 KB.
2. Igual con `source=resume`.
3. `source=startup` → salida idéntica a la de 52d2d8c.
4. Junto con H11 (mismo archivo): el EOF del stdout llega en <1 s (`.claude/feedbackUsuarios/2026-10-19-revision-7-continuidad.md`).
