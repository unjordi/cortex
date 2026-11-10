# reconstruir-contexto — primer uso real (claudio-master, 2026-10-15 09:2x)

Contexto: unjordi me pidió reconstruir contexto tras un compact. Usé el skill leído de `b848056` (aún no instalado global). Funcionó, pero con estos tropiezos (medidos por mí):

1. **Paso 1 — el andamio cubre solo el TRAMO VIVO.** Justo después de un compact el tramo vivo tiene 2 mensajes (los de "reconstruye tu contexto"); lo perdido está en el tramo ANTERIOR, que el andamio solo resume en conteos. El skill dice "si ya reconoces la tarea, para aquí", pero en el caso que motiva el skill nunca la reconoces con eso. Falta: cuando el tramo vivo es corto, regenerar el andamio sobre el tramo previo (¿`--ventana` previa?) o decir explícitamente que pases al paso 3.
2. **Paso 1 — ruta:** `~/.local/bin/checkpoint-mecanico.js` no existe en la Mac; el fallback `~/.cortex/bin/` sí. OK, solo anoto.
3. **Paso 2 asume que el tema vive en el repo del cwd.** Soy generalista: cwd plantilladotnet, temas en mfx/PowerScripts/cortex. `estado-proyecto.md` del cwd era la fuente equivocada. Debería decir: si el hilo trae ÁRBOL de memorias (o el CLAUDE.local.md un mapa de casas), las fuentes del paso 2 son ESAS, no las del cwd.
4. **Paso 3 — `tail -n 600` no alcanza el tramo previo.** En mi transcript esas 600 líneas eran puro post-compact. Tuve que subir a `tail -n 8000`. Sugerencia: acotar por la frontera del último compact (la misma que usa el andamio) en vez de un número fijo.
5. **Paso 3 — el filtro jq de mensajes de usuario mete ruido:** el resumen "This session is being continued…", wrappers `<command-name>`/`<system-reminder>`, `[Request interrupted by user]` y `isMeta`. Filtré con `select(.isMeta|not)` y descartando los que empiezan con `<` o con "This session is being continued".

Resultado: con el paso 3 ajustado sí reconstruí (las citas del 14-oct 20:52–21:46 CST y las de hoy). Paso 4 (re-volcar con checkpoint) en curso.

## Revisión con pinzas (pedida por unjordi, 09:4x) — todo medido por mí en la Mac sobre b848056
Severidad entre corchetes. Los 5 de arriba siguen en pie; 1 y 4 se precisan aquí.

6. [ALTA] **Lee la sesión equivocada.** `ls -t <slug>/*.jsonl | head -1` y el fallback global toman el transcript escrito MÁS RECIENTE. Con varios masters vivos, o varias sesiones en el mismo cwd (plantilladotnet tiene 3+), reconstruye desde OTRA sesión: confabulación con evidencia. `CLAUDE_CODE_SESSION_ID` está disponible en el Bash del modelo (medido: = mi sid) y el andamio ya lo usa con `--self`. Usarlo primero; el `ls -t` solo como último recurso Y avisando.
7. [ALTA] **Fuera de un repo git, ROOT='/'.** `cd "$(git rev-parse … 2>/dev/null)/.."` con rev-parse vacío hace `cd /..` → `/`, así que `${ROOT:-$PWD}` nunca cae a PWD → SLUG='-' → fallback global (medido en /tmp).
8. [MEDIA] **El fallback grep está muerto en macOS:** `/usr/bin/grep -o '"text":"[^"]\{0,300\}'` → "maximum repetition exceeds 255", 0 líneas. Solo funciona con el grep envuelto (ugrep) del tool de Claude.
9. [MEDIA] **El dump de tool_use no tiene tope:** 30 llamadas = 18.6 KB en un tramo ligero; con Writes grandes inunda justo el contexto que se quiere cuidar. Recortar `input|tostring|.[0:300]`.
10. [MEDIA] **Filtro de user:** además de lo del punto 5, deja pasar `<task-notification>` (medido). Usar las marcas reales del esquema: `isMeta`, `isCompactSummary`, `system/compact_boundary`.
11. [MEDIA] **Tier `both` con dependencia `global`:** el paso 1 depende de `checkpoint-mecanico.js`, que es `global` (hooks/MANIFEST:69). En un clon compartido sin brain el paso 1 falla y el skill no dice qué hacer.
12. [MEDIA] **El test b-rc mide plomería** (existe, está en el MANIFEST, links resuelven), no el propósito. Los 2 bugs que corregiste en el paso 3 NO tienen test de regresión, y ningún comando del skill se ejecuta contra un fixture. Propuesta: un fixture .jsonl (con compact_boundary, isCompactSummary, isMeta, task-notification, tool_result, 2 sesiones en el mismo slug, worktree y fuera de git) y asertos sobre lo que extrae.

**Lo bueno, que se queda:** el orden barato→caro, el paso 0 contra la confabulación y el cierre obligado con checkpoint.

## Comparación con axon (leído por mí en cachy:~/code/axon a28c1b5)
Axon resuelve por CONSTRUCCIÓN lo que este skill hace como EMERGENCIA:
- `src/session/claude-transcript.ts` ya parsea el .jsonl de Claude Code en streaming, never-throws, conociendo `system/compact_boundary` + `isCompactSummary`, con pérdidas declaradas y la deuda de versión del formato declarada. El paso 3 re-implementa eso con jq a mano y peor (puntos 4, 5, 10).
- `src/session/body-swap.ts`: al adoptar una sesión, el primer turno es un auto-reporte con EVIDENCIA MEDIBLE (tools usadas, último pedido acotado a 400 chars, ¿hay hilo-mental?). Es exactamente lo que el paso 3 intenta.
- `src/context/condenser.ts` + `local-summarizer.ts`: compactación head+tail VERBATIM y en medio un ESQUEMA (objetivo · tareas con IDs · estado código/tests/git), rolling e idempotente, disparada por tokens reales; si falla, arrastra el resumen previo.
- `src/loop/compact-hooks.ts`: el hook PRE recibe los EVENTOS que están por condensarse. El PreCompact de Claude no puede pedirle nada al modelo, pero sí podría volcar esos eventos crudos.
- `src/memory/ledger.ts` + `working-set.ts`: los hechos exactos (rutas, exit-status, decisiones) van aparte del resumen con pérdida, y se inyecta un top-k acotado cada turno.
- `src/loop/tool-budget.ts`: tope de 8 KB por tool_result y de 500 B por línea. Es lo que le falta al punto 9.
**Propuesta** [INFER-mío]: llevar el conocimiento del esquema (compact_boundary, isCompactSummary, isMeta, sid) a `checkpoint-mecanico.js`, que ya es el parser JS de cortex. Darle `--ventana previa` (el tramo ANTERIOR al último compact: pedidos del usuario verbatim, últimos tool_use recortados, archivos tocados) y `--sid` explícito. Así el paso 1 cubre lo que hoy hace el paso 3 a mano, y el paso 3 queda como último recurso. Y que el PreCompact vuelque el tramo crudo, como el PRE de axon.
