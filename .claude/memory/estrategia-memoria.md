# Estrategia de memoria del cerebro de Claude

> **Qué es esto.** Plan (NO ejecutado) para hacer el cerebro de Claude *más eficiente, más fluido, que
> no pierda el hilo y no olvide el proyecto*. Nace de la peinada de 2026-07-15 (Graphiti/Zep, Mem0,
> Letta, Cognee, Serena, Basic Memory, memory-tool nativa de Anthropic, "Compound Engineering" de
> Kieran Klaassen). Es una **decisión abierta**: aquí están las estrategias rankeadas por encaje real
> con NUESTRAS restricciones, cada una con su mecanismo y su criterio de adopción/rechazo.
>
> **Alcance = GLOBAL (todo el ecosistema del brain).** La memoria es un concern que aplica a todos los
> repos. Esta nota vive en el repo fuente del brain (`claude-brain`, source en `brain/`); al
> ACTUAR, los cambios de sustrato/normas se hacen en `brain/` y se propagan a los repos consumidores
> (plantilla, etc.) con `sincronizar-cerebro.sh`.
>
> **Este ES el plan del "MCP de memoria tipo graphify / knowledge-graph" (antes ítem #48 del backlog).**
> Unificado 2026-08-07 (unjordi: *"estos dos son LO MISMO"*): el grafo/MCP consultable NO es un proyecto
> aparte — es el **destino** de este plan, su **FASE 4** (el grafo temporal), y las guardas de diseño con
> que unjordi lo quiere + su **precondición dura** (cerebros HERMOSOS Y SÓLIDOS antes de conectar) viven
> ahora en esa Fase 4. Las Fases 0–3 son el CAMINO barato y reversible hacia él; el grafo es el escalón
> final "cuando duela", NO el punto de partida.

## Principios rectores (el filtro que descarta el 80% del hype)
Toda estrategia se juzga contra estas restricciones DURAS. Lo que las viole, se rechaza aunque gane benchmarks.
1. **El cerebro viaja por git y es idéntico en toda máquina/dev.** Repos compartidos, multi-OS
   (Mac + Windows-GitBash + Linux), multi-dev. Un estado por-máquina que no se clona ROMPE esto.
2. **"Clona y arranca"** — hoy: `git clone` + `bootstrap-claude.sh` y listo. Meter daemons/DBs por
   proyecto (Neo4j, FalkorDB) mata esa simplicidad y sube el costo de onboarding.
3. **Doc = realidad, versionada y auditable en un diff.** Un grafo en una DB opaca no se revisa como
   un `.md` ni se audita en un MR.
4. **Privacidad.** Nada de mandar código/notas del proyecto a un tercero (descarta cloud de Mem0/Zep).
5. **Toda norma nace con su mecanismo** (hook/skill/gate). Una estrategia sin forma de hacerse cumplir
   es un buen deseo, no un plan.

## Diagnóstico: qué YA tenemos vs. el hueco real
**Ya tenemos (y está alineado con lo que Anthropic mismo recomienda: memoria = archivos):**
- Índice `MEMORY.md` + notas por área · `estado-proyecto.md` (qué sigue) · `bitacora.md` (qué pasó,
  append-only `merge=union`) · `hilo-mental-actual.md` (el HILO, volátil per-dev).
- Skills `checkpoint` (vuelca el hilo) + `rehidratar-hilo` (lo relee) + `# Compact instructions`.
- Hooks `sesion-inicio` (reinyecta contexto al abrir/compactar) + `dod-verificar` + git-guards.
- El loop "compound" (aprender→escribir→releer) YA existe: cosecha de `lecciones-*` y gotchas.

**El ÚNICO hueco real:** **recuperación SELECTIVA a escala.** Hoy `MEMORY.md` se carga entero al
inicio y crece → escaneo lineal. No sabemos traer *solo la nota relevante* a demanda. Todo lo demás
("no perder el hilo", "no olvidar la tarea") ya lo resolvemos bien. Este plan ataca ESE hueco sin
romper los 5 principios.

---

## FASE 0 — Ganancias gratis (hoy, cero riesgo, cero infra)
El mejor ROI. No adopta ninguna herramienta; endurece lo que ya hacemos.

- **0.1 — Doblar el loop "compound".** Kieran Klaassen no vende nada que no tengamos; vende
  *disciplina*. Mecanismo: reforzar `cerrar-slice`/`checkpoint` para que SIEMPRE destilen 1 lección
  accionable a `lecciones-*` o un gotcha. Criterio: cada slice cerrado deja rastro reutilizable.
- **0.2 — Convención de recall explícito.** Documentar en `_PROTOCOLO.md` el patrón que Anthropic
  recomienda: "al empezar, lee memoria; al terminar, escríbela". Ya lo hace `sesion-inicio`; falta
  hacerlo norma escrita + medir que se cumple.
- **0.3 — Higiene de tamaño de `MEMORY.md`.** Regla: el índice se mantiene < ~200 líneas / 25KB (el
  límite que Claude Code carga). Cuando una nota crece, se parte por área. Mecanismo: check ligero
  (¿hook `aviso-contexto` extendido, o paso en `cerrar-slice`?).
- **Costo:** horas. **Riesgo:** nulo. **Decisión:** creo que esto se hace sí o sí, independiente del resto.

## FASE 1 — Recall selectivo SIN daemon (sobre nuestros propios .md)
Atacar el hueco real con lo mínimo, sin romper "clona y arranca".

- **1.1 — Índice/embedding local de las notas del cerebro.** Un skill (`recordar-relevante`) que, dado
  el tema del turno, hace match contra los `.md` de `.claude/memory/` y trae SOLO las 1–3 notas
  relevantes en vez de todo el índice. Empezar simple: match por keywords/títulos (grep estructurado);
  subir a embeddings locales solo si el keyword-match se queda corto.
- **1.2 — Links tipo `[[nota]]` entre notas** (ya usamos algo así en la memoria global). Convierte el
  cerebro en un grafo navegable *sin* DB: Claude sigue links a demanda. Mecanismo: convención en
  `_PROTOCOLO.md` + linter opcional de links rotos.
- **Costo:** bajo-medio (un skill + convención). **Riesgo:** bajo (todo sigue siendo `.md` versionado).
  **Criterio de éxito:** en un repo con memoria grande, el turno arranca cargando *menos* y *más
  relevante*. **Decisión abierta 1:** ¿keyword-match basta, o vale un embedding local (p. ej. un
  índice SQLite generado, gitignored, reconstruible)?

## FASE 2 — Spike de Basic Memory (evaluación reversible, NO compromiso)
El único MCP externo que **respeta nuestro sustrato**: markdown en disco + índice SQLite local +
se abre como vault de **Obsidian**. El markdown sigue versionado en git; el índice es por-máquina
pero **reconstruible** (no es estado que se pierda).

- **2.1 — Spike aislado** en un repo de prueba (NO la plantilla, NO el brain): apuntar Basic Memory a
  un folder de `.md`, ver si el recall selectivo + navegación por links + la GUI de Obsidian aportan
  sobre la Fase 1 hecha a mano.
- **Qué evaluar:** ¿aporta vs. Fase 1? ¿el índice SQLite estorba al "clona y arranca"? ¿la GUI de
  Obsidian ayuda a *pasear* el cerebro (para humanos)? ¿sobrevive multi-OS con GitBash en Windows?
- **Costo:** medio (setup MCP + tiempo de spike). **Riesgo:** bajo (aislado, reversible, no toca el
  cerebro real). **Criterio de adopción:** solo si supera claramente a la Fase 1 casera Y el índice
  por-máquina se puede reconstruir con un comando de bootstrap. **Criterio de RECHAZO:** si rompe
  "clona y arranca" o duplica lo que la Fase 1 ya da gratis.

## FASE 3 — Serena para navegar el CÓDIGO .NET (ortogonal a la memoria)
No es memoria: es "mapa del repo". Ataca el OTRO gran costo — quemar contexto explorando una solución
.NET grande con `grep`/lecturas de archivo completo. LSP a nivel símbolo, **soporta C#**, MIT, ~25k ⭐.

- **3.1 — Opt-in POR PROYECTO instanciado** (no en la plantilla base): `serena project index` + MCP.
  Preguntas estructurales ("¿quién llama a X?", "¿dónde vive el símbolo Y?") sin leer medio repo.
- **Costo:** medio (MCP + índice por proyecto). **Riesgo:** medio (daemon per-proyecto; NO va en el
  "clona y arranca" base — es opt-in del dev que lo quiera). **Criterio:** medir tokens ahorrados en
  un repo real grande (cps u otro). **Decisión abierta 2:** ¿lo documentamos como opción recomendada
  en la skill de instanciar, o queda como preferencia personal de cada dev?

## FASE 4 — El GRAFO/MCP de memoria (graphify / knowledge-graph, ex-#48) SOLO "cuando duela" — condicional
Es el destino del plan y el ítem que unjordi QUIERE: un MCP estilo grafo de conocimiento (graphify /
knowledge-graph, con sustrato temporal tipo **Graphiti**) para que pendientes, decisiones y hechos **de
verdad no se olviden** entre sesiones/compactaciones — memoria consultable y ligada, no notas sueltas que
se caen del chat (el dolor que originó la sesión de rescate). Memoria temporal real ("qué era verdad
*cuándo*", bi-temporal); Graphiti gana benchmarks (LongMemEval, ~15 pts sobre Mem0) pero pide
Neo4j/FalkorDB, es por-máquina y NO viaja por git. **Hoy es overkill** — por eso es la ÚLTIMA fase.

- **EL MIEDO DE UNJORDI = LA RESTRICCIÓN DE DISEÑO RECTORA (textual):** *"muero de miedo de que se
  asienten falsedades e inconsistencias y se rompa todo."* Válido y central: un grafo mal hecho AMPLIFICA
  justo lo que peleamos (confabulación del juez, pendientes caídos, drift de doc). Por eso NO se construye
  "a ver qué tal"; nace atado a estas guardas (son el core del diseño, no adornos):
  - **Grounded o no entra:** todo nodo/afirmación lleva PROVENANCE (commit, archivo:línea, o cita textual
    del usuario). Sin fuente verificable → no se asienta como hecho (a lo sumo "hipótesis sin confirmar").
    Es "doc = reflejo de la realidad" hecho mecanismo (principio 3).
  - **Detección de contradicción:** al escribir un hecho que choca con uno existente, NO se sobreescribe
    en silencio — se marca conflicto y se pide arbitraje ("una decisión no se queda en el chat").
  - **Confirmable/reversible por humano:** unjordi puede ver, corregir y BORRAR nodos; nada se cementa sin
    poder deshacerse. Append con historial, no verdad-absoluta mutable.
  - **Lo muerto muere:** un hecho revertido va al cementerio (🪦), no queda vigente (positivar-doc / cementerio).
  - **Arranca READ-mostly:** primero LEE/consulta lo que ya existe (bitácoras, estado, dashboard,
    cementerio) y lo liga; escribir hechos nuevos es el modo cauto que se habilita DESPUÉS, con las guardas
    de arriba probadas.
- **PRECONDICIÓN DURA (la tesis que une todo — unjordi, textual):** *"por eso estoy intentando dejar los
  cerebros de los repos HERMOSOS Y SÓLIDOS antes de conectarlos a un MCP que propague vicios internos raros
  con todas las memorias negativamente redactadas y llenas de contradicciones."* → El grafo NO se conecta
  hasta que los cerebros estén sanos. El programa de HIGIENE de cerebros es el camino crítico previo:
  positivar-doc (answer-first), desinflar-memorias, cementerio per-cerebro, **auditar-coherencia como GATE**
  (#44 — precondición dura), matar el drift, y el rescate de pendientes colgados. Métrica de "listo para
  grafo" por repo = pasa coherencia + sin lápidas vivas + memorias positivas + índice fiel.
- **Gatillo de reconsideración (no antes):** cuando (a) la memoria del proyecto sea tan grande que ni la
  Fase 1 ni Basic Memory den buen recall, Y (b) necesitemos de verdad "historia de hechos que cambian"
  (qué decisión estuvo vigente en qué fecha) más allá de lo que `bitacora.md` ya da, Y (c) la precondición
  de cerebros-sanos esté cumplida y medida.
- **Costo:** ALTO (infra + operación). **Riesgo:** ALTO (rompe principios 1 y 2 + el miedo fundado).
  **Estado:** IDEA delineada, NO construida (requiere diseño propio: ¿graphify existente vs uno propio?
  ¿esquema de nodos? ¿cómo se puebla desde las memorias actuales sin ensuciarse?). Archivada con gatillo +
  precondición explícitos; no se toca hasta que el dolor sea real y medido Y los cerebros estén sanos.

## Transversal — cómo sabremos si sirvió (métricas)
- Tokens cargados al inicio de sesión (¿bajan con recall selectivo?).
- Nº de veces que "se pierde el hilo" tras compact (ya bajo; que no suba).
- Tokens quemados explorando código (baja con Serena, si se adopta).
- Tiempo de onboarding de un clon (que NO suba — guardián del principio 2).

## Lo que NO haremos (y por qué)
- **Mem0 / Zep cloud:** manda datos del proyecto a un tercero → viola principio 4.
- **Letta / MemGPT:** "el agente ES su memoria" → rearquitectura total, incompatible con "cerebro
  autocontenido por repo".
- **Plugins de terceros que reemplacen el sustrato de archivos** (incl. el de Compound Engineering
  como paquete): robamos la IDEA (Fase 0), no el paquete — no queremos dependencia externa en el core.

## Decisiones abiertas para unjordi (resumen)
- **1** — Fase 1: ¿keyword-match basta, o vale un embedding local reconstruible?
- **2** — Fase 3: ¿Serena recomendado en la skill de instanciar, o preferencia per-dev?
- **General** — ¿Aprobamos arrancar por Fase 0 (gratis) + spike de Fase 2, y dejamos 3/4 condicionadas?

## Siguiente paso concreto
Ninguno hasta tu OK. Cuando decidas: Fase 0 se puede empezar hoy (cero riesgo); Fase 2 es un spike
aislado que no toca el cerebro real. Fases 3 y 4 quedan condicionadas a medición/dolor real.
