# Loop del lote de integración de cortex

Texto con el que se lanza `/loop <mandato de abajo>` (sin intervalo: se autoregula). Fuente única: si cambia, se cambia aquí y se relanza.

```text
Trabaja en cortex (~/code/cortex; una rama por fila desde origin/develop, en su worktree de .cortex-wt/<fila>; SIN PR: todo se integra junto en un solo lote cuando claudio-master lo revise; tras cada push sincroniza el folder principal sin perder las memorias sin commitear) y no te detengas hasta dejar listo para integrar, en un solo lote, todo lo que falta para que el usuario quede contento de propagar cortex a su equipo. Arranca cada ronda leyendo completos .claude/memory/hilo-mental-actual.md, .claude/memory/estado-proyecto.md, las notas del buzón que nombra cada fila y este mandato; no re-investigues lo que ya está ahí.

PUNTO DE PARTIDA (develop deeb2a5): en ramas del lote ya están fix/widget-verdad-al-despertar, fix/apagar-widget-apaga-todo, docs/buzon-sync-cachy-2026-11-01 y fix/retiro-dod-verificar. Abiertas: las filas de abajo.

FILAS (en este orden). Antes de tocar una, lee su detalle y escribe su caso de uso: qué hace el usuario y qué debe obtener. Cada fila tiene su CIERRA CUANDO, medido corriendo; el piso de todas es su prueba en rojo contra develop, la contraprueba, test-brain y shellcheck verdes, los builds de los widgets que toque y la revisión semántica (PRUEBAS §7).
1. Retiro del cerebro por-repo — quitar de cada repo las copias de hooks del cerebro y su cableado en .claude/settings.json (plantilladotnet, cps, fluxcore y los demás que las tengan, cada uno por su flujo de git); el instalador des-cablea de cualquier settings un hook marcado `retirado`; retirar sincronizar-cerebro.sh y sus flags, la rama por-repo de aviso-drift-cerebro, los tiers both/repo con su dedupe y la marca repo-compartido; sesion-inicio y recordar-cosechar quedan globales; reescribir las normas «Cerebro por-repo = CORREO» y «Tiers», el lenguaje «repo-scoped» de sesion-inicio/install-brain y el CLAUDE.md de plantilladotnet. El aviso de drift de la copia GLOBAL se queda.
   CIERRA CUANDO: en una COPIA de plantilladotnet, una sesión que termina un turno ya no corre ningún hook del repo (dod-verificar no dispara) y los guards globales sí; un repo nuevo clonado sin .claude/hooks funciona igual con el cerebro global; correr el instalador sobre un settings que todavía cablea un hook retirado lo deja limpio y no toca entradas ajenas.
2. aviso-contexto — el aviso «sin datos: la última lectura falló» sale cuando el fetch corrió hace menos de 30 min y no trajo datos.
   CIERRA CUANDO: con un state.json de fetched_at reciente y stale, el hook avisa una vez y no lanza el fetch; con fetched_at de más de 30 min lo lanza una vez; dos sesiones a la vez producen un solo fetch.
3. merge-develop-guard — el freno «no pude LEER la conversación» solo sale si de verdad hay un mensaje humano que el parseo no pudo leer; los tool_result no cuentan como mensaje humano.
   CIERRA CUANDO: un transcript sin ningún mensaje humano en la ventana da el freno «no hay autorización»; uno con un mensaje humano que el parseo no entiende da «no pude leer»; uno con OK válido pasa.
4. Estado de los hooks fuera del repo — los sellos de aviso-contexto (.cuota-fetch-forzado, .contexto-aviso.*) y de las ramas huérfanas (.ramas-huerfanas-estado) se escriben bajo ${CLAUDE_CONFIG_DIR:-~/.claude}/state/<cksum del repo>/, no en <repo>/.claude/memory/.
   CIERRA CUANDO: tras una sesión con varios comandos en una COPIA de un repo, `git status` no muestra ningún archivo nuevo creado por hooks, y el throttling y las bandas siguen funcionando.
5. Barrido de ramas — al inicio hace un `git fetch --prune` acotado (timeout) con el agente ssh de la sesión gráfica; si no pudo, lo dice en el resumen («no pude actualizar origin; N ramas sin juzgar») en vez de conservar callado.
   CIERRA CUANDO: en una COPIA con develop local atrasado y una rama ya integrada en origin, el barrido la reconoce como integrada; sin red, el resumen dice que no pudo actualizar y cuántas ramas quedaron sin juzgar.
6. despertar-master — reconoce como viva una sesión de fondo (ejecutable …/versions/<x.y.z> o bg-pty-host con --resume <id>); `--cerrar` la cierra de verdad; `--mensaje … --no-esperar` respeta el no-esperar.
   CIERRA CUANDO: con una sesión de fondo corriendo, `--lista` la da como viva, `despertar` no lanza una segunda, y `--cerrar` termina con 0 procesos de esa sesión; otra sesión con distinto id no se toca.
7. cerrar-slice — con `--repo <slug>` decide GitHub/GitLab por el origin del clon local de ese slug (no por el directorio actual) y corre el gate de gitleaks desde ese clon; su --help y su SKILL.md dicen la verdad (la traza Rama:/PR: se agrega sola; menos de 12 palabras solo avisa; el guard ya no bloquea el mensaje).
   CIERRA CUANDO: desde un repo GitLab, `cerrar-slice.sh --repo <slug-de-github> --id N --dry-run` arma el comando de gh y corre gitleaks en el clon correcto; desde uno GitHub con slug de GitLab, lo inverso.
8. Widget de Windows — aviso de login vencido/sin cuenta/por vencer con su botón de re-login, y marca «sin refrescar» cuando la lectura es la preservada, con el mismo texto que macOS y KDE.
   CIERRA CUANDO: con un estado de credenciales vencidas el popup muestra el aviso y el botón abre el login; con la API caída muestra la última lectura marcada «sin refrescar»; dotnet build 0 errores 0 warnings. Lo que no pueda correrse en Windows real se anota «pendiente en Windows», nunca verde.
9. Instalador — install-brain deja de generar aliases-activos.md y su @import, retira los existentes, y la plantilla del entorno ya no los menciona.
   CIERRA CUANDO: en un HOME de prueba con aliases-activos.md y su @import, correr el instalador los quita y deja intacto el resto del CLAUDE.md global.
10. Skill mandato-loop — skill global con la plantilla de mandato de loop (.claude/feedbackUsuarios/2026-11-01-plantilla-mandato-loop.md) tal cual: «Cómo se redacta» + el bloque text. No va dentro de turno-nocturno.
    CIERRA CUANDO: la skill aparece en el catálogo de los widgets y el instalador la copia; su texto coincide con la nota.
11. Flowcharts 09 y 13 — ya no citan dod-verificar ni el cerebro por-repo.
    CIERRA CUANDO: el parity-check de los flowcharts pasa y un grep de dod-verificar/repo-compartido en docs/flowcharts solo encuentra menciones de retiro.
12. Estado y buzón — la decisión del núcleo único del widget queda en estado-proyecto como decisión (épica para después del lote); el stash corpus-FP-mac-pendiente se reconcilia contra develop sin duplicar líneas; cada nota del buzón atendida por estas filas queda .ATENDIDO con su fila.
    CIERRA CUANDO: `git stash list` ya no tiene ese stash, docs/guards-falsos-positivos.md no tiene líneas duplicadas, y cada nota citada arriba tiene su .ATENDIDO.
13. Skills del cerebro por-repo (canonizar-cerebro, verificar-firma-canonica, reubicar-master) — quitarles TODO uso de sincronizar-cerebro.sh y de hooks/copias por-repo del cerebro (ya retirados); lo que SIGUE vigente se conserva: la firma-canónica (CLAUDE.md/MEMORY.md como firma-árbol) y la MEMORIA del proyecto, que sí vive en cada repo. canonizar-cerebro deja de sembrar/sincronizar guards por-repo; reubicar-master deja de mover copias por-repo del cerebro (la memoria del proyecto sí viaja). verificar-firma-canonica deja de depender de brain/hooks/RETIRED para podar copias por-repo.
    CIERRA CUANDO: un grep de `sincronizar-cerebro`/hooks-por-repo en brain/skills/{canonizar-cerebro,reubicar-master} y en brain/verificar-firma-canonica.sh solo encuentra menciones de retiro; correr verificar-firma-canonica sobre una COPIA de un repo instanciado no intenta sincronizar ni podar hooks por-repo, y sigue verificando la firma + la memoria del proyecto; los SKILL.md describen la realidad nueva (solo cerebro global).
14. Diagramas de flujo del proyecto — regenerar TODOS los de docs/flowcharts/ con el MCP de draw.io (skill diagramar: draw.io es el estándar) para que reflejen el cerebro como queda al cerrar este lote: sin dod-verificar, sin cerebro por-repo, con el apagado del widget y el fetch condicionado. Esta fila va AL FINAL, cuando las demás ya estén ✅, porque dibuja el estado combinado. Cada diagrama queda como .drawio editable + su exportación, junto a su leyenda y las normas que aplica; los .dot/.svg viejos se retiran solo si el .drawio los reemplaza por completo, y gen-charts.sh / verificar-arbol-sync.sh / CONVENCIONES.md quedan al día con el formato nuevo.
    CIERRA CUANDO: cada flujo del cerebro tiene su .drawio que abre en draw.io y su exportación; recorrer cada diagrama contra el código del lote combinado no encuentra una caja, flecha o hook que no exista ni uno que falte; el parity-check del árbol pasa; un grep de dod-verificar, sincronizar-cerebro y repo-scoped en docs/flowcharts solo encuentra menciones de retiro.
Lo que necesite al usuario (un OK que el clasificador exija en tu sesión, un paso en Windows real) no detiene el loop ni se pregunta a media corrida: se deja armado (texto exacto que debe escribir, comando, recomendación), se junta para el reporte y se sigue con la fila siguiente.

EL LOTE ESTÁ TERMINADO cuando todas las filas están ✅ y su propósito se cumple con las ramas del lote combinadas sobre develop en una rama de prueba: cortex instala limpio, los guards que quedan funcionan, el widget no calienta la máquina y dice la verdad, y ningún repo carga cerebro propio. Cada fila está ✅ cuando su propio criterio de cierre se cumple, pasa sus pruebas, y TÚ ya realizaste la revisión semántica con los criterios de PRUEBAS §7, con calma y a detalle. El propósito del lote se mide con todo combinado e instalado en una COPIA del entorno (HOME de prueba): instalar, abrir una sesión en una copia de plantilladotnet, trabajar unos turnos con merges y commits, cerrar y abrir el widget, y ver qué corre.
Al llegar ahí, haz una revisión semántica del lote completo y luego pruébalo como se usa: con todo combinado e instalado en la copia, trabaja de verdad en algo del backlog de plantilladotnet unos turnos, y mientras tanto revisa en vivo que ningún hook frene en falso, que no aparezcan archivos de hooks en el repo y que el widget no deje procesos al cerrarse. Lo que se rompa se vuelve fila nueva y el lote sigue abierto.
Si todo sale limpio, detén el loop y reporta a claudio-master (SendMessage) para su revisión de diffs antes de integrar:
- por fila: rama, commits, qué se corrió para medir su CIERRA CUANDO y qué salió, y lo que encontró su revisión semántica;
- del lote: el recorrido combinado: qué funcionó, qué frenó y qué quedó corriendo;
- lo que necesita al usuario, con el texto o comando exacto.
Antes de eso, cada reporte dice qué filas faltan.

CADA RONDA:
0) Re-arma el loop antes de trabajar y lee five_hour.percent de ~/Library/Caches/cortex/state.json: ≥85 % ⇒ solo agentes locales.
1) Estado de lo delegado (worktrees en .cortex-wt, procesos, logs). Lo que terminó: revísalo TÚ (diff, base, gates, la misma prueba en el commit previo y en el nuevo, corrida en vivo sobre una COPIA); si pasa, súbelo a su rama; si falla, corrígelo o anota el tropiezo y relanza con el prompt pulido. Nunca dos agentes en el mismo árbol.
2) Lanza la siguiente fila con su mandato literal (archivos, funciones, cambios exactos) y sus pruebas de aceptación ya escritas por ti; exígele la sección final «qué NO verifiqué y dónde está mi punto ciego»: esa sección dirige tu revisión.
3) En la misma tanda de cada cierre concilia estado-proyecto.md, el bloque espejo y la lista de tareas antes de reportar.
4) Lo que destape una fila entra como fila nueva en esa misma ronda.

DELEGACIÓN: el diseño de cada fila, sus pruebas de aceptación, la revisión y la medición del cierre son tuyos. Lo mecánico con salida verificable se delega por costo: script → axon local → un modelo grande solo para lo rudo en serio. Uno a la vez por máquina, con commit por paso. Lo que reporte un agente es una afirmación hasta que lo midas.

MÁQUINAS: la Mac corre todo lo de macOS y bash; KDE/Linux se prueba en la cachy por ssh (agente ssh de la sesión gráfica); Windows no hay: lo que no pueda correrse ahí se anota «pendiente en Windows», nunca verde.

PRUEBAS:
- Las de aceptación las construyes tú antes de lanzar un agente, junto con su mandato.
- §1 Cada aserto puede fallar y falla contra el código viejo (revertido y corrido, no supuesto).
- §2 Firmas de rechazo: no puede fallar · mide el andamio y no el efecto · el escenario no se montó · mide el objeto equivocado · el esperado quedó viejo · el verde depende del entorno (lo que no corre dice SKIP) · media prueba. Ningún aserto cuya respuesta se pueda adivinar desde la pregunta.
- §3 Una prueba mide el efecto observable por el canal del usuario, en las dos direcciones, con escenario comprobado, esperado derivado, nombre honesto y dependencia declarada.
- §4 Comentarios utilitarios, sin historia ni trazabilidad.
- §5 Ninguna prueba toca el ~/.claude real ni datos reales: HOME de prueba y copias.
- §7 Revisión semántica (una fila se cierra con esto, no con el verde):
  §7.1 Vuelve al porqué: lee el origen de la fila y pregúntate si ese problema ya no podría repetirse. Úsala en vivo sobre una copia, como la usaría quien la pidió.
  §7.2 Busca las formas de fallar que la prueba no fija: ¿se recupera?, ¿castiga de más?, ¿qué pasa con la variante parecida en las palabras pero no en el sentido?
  §7.3 Mira qué le hace al resto: corre los recorridos vecinos que el cambio puede tocar y compara con antes.
  §7.4 Revisa el diseño: capa correcta, sin un segundo mecanismo para lo mismo, salida accionable, valores configurables.
  §7.5 Si al relatar el cierre hay que matizar, todavía no está.

HIGIENE MENTAL:
- Cada ronda: checkpoint LIGERO con el skill /checkpoint. Antes de sobrescribir hilo-mental-actual.md, léelo y conserva lo vivo; sube pendientes y decisiones a estado-proyecto.md y una línea a bitacora.md con >>.
- Cada ~2 h, al cerrar cada fila y ante el aviso de contexto: checkpoint COMPLETO. No encadenes checkpoints sin trabajo entre ellos.
- Si el hilo pasa de ~200 líneas, lo viejo va a hilo-mental-actual-overflow.md. Confía en el autocompact: tu memoria en disco es la que sobrevive.
- Lo aprendido del trato con el usuario va a su como-trabajar global; lo del proyecto, a su memoria.

REGLAS: nunca push a develop ni a main; nada de PR ni merge: la integración del lote la hace claudio-master tras leer cada diff, con el OK del usuario. Release a main congelado. Código, comentarios y commits utilitarios. Todo valor elegible configurable. Nada de --no-verify. Sin paliativos que apaguen piezas: causa raíz medida. Pruebas solo sobre copias. Matar solo por PID. De noche (22:00–08:00) sin avisos sonoros ni diálogos de root. Si el clasificador frena un cambio a un guard, no lo rodees: déjalo armado con el texto exacto que el usuario debe escribir en tu sesión y sigue con otra fila. No te detengas a preguntar si sigues; con varias opciones válidas, elige, asienta el porqué y sigue.
```
