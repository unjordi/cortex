---
name: consolidar-cerebro
description: META-playbook que orquesta la campaña completa de dejar el cerebro de un proyecto SÓLIDO y COMPACTO — que un Claude nuevo (o el usuario) lo opere sin re-investigar ni romper nada, y se lea de un jalón. Encadena skills que YA existen: la DUPLA de auditores (coherencia + suficiencia, van JUNTAS) → positivar-doc → desinflar-memorias → un LOOP de re-auditar con prompt IDÉNTICO hasta 0 ALTO/0 MEDIO → cierre con la FIRMA (CLAUDE.md = TOC de MEMORY = la misión/capacidades de Claude, distinta del AGENTS de arquitectura) y el "prompt bello de arranque". Con una CERCA no-destructiva (solo docs, narrativa fechada intacta, lo destructivo se PARQUEA para el humano) y el tercer eje FMEA opcional cuando hay lógica de riesgo. Úsalo cuando el usuario pida "dale amor a ese repo / que quede sólido y compacto / revisa que quede bien asentado" o tras una sesión que cambió arquitectura/procedimientos.
---

# Consolidar el cerebro — dejarlo sólido y COMPACTO (meta-orquestador)

Este skill NO reinventa nada: **encadena skills atómicas que ya existen** en una campaña con orden,
cerca y criterio de cierre. Es el "cómo llevamos un cerebro de abrumador a cómodo consigo mismo" —
destilado de dos casos vivos (games-master, que quedó notoriamente compacto con +6 memorias nuevas y
aún así más chico que su gemelo; y cps, un repo .NET grande que convergió en 5 rondas de auditoría).

> **El DOLOR que lo originó (el north-star).** *"ya me cansé de pasar 5 horas configurando en loop cada
> vez que quiero jugar media hora"* + *"si yo me abrumo… no me imagino tú que lees todos esos archivos
> cada vez → DALE amor a ese repo"*. El entregable NO es "verde técnico": es un cerebro **SIN FRICCIÓN**,
> leíble de un jalón, que un Claude nuevo opera sin re-investigar ni romper nada. La vara de éxito, en
> palabras del usuario, es que el cerebro quede *"cómodo consigo mismo"*.

## Cuándo usarlo
- El usuario lo pide con cualquiera de sus formas: *"dale amor al repo / que quede sólido y compacto /
  revisa que quede bien asentado / que un Claude nuevo lo opere sin re-investigar"*.
- Tras una **sesión grande** que cambió arquitectura, procedimientos o metió muchas memorias nuevas.
- Cuando el usuario **se abruma de leer el árbol** del cerebro, o sospecha duplicación/drift.
- Como pasada de mantenimiento antes de "irse con todo" a un frente nuevo sobre ese proyecto.

## Los skills que ORQUESTA (mapa — no los re-expliques, invócalos)
- [[auditar-coherencia-cerebro]] + [[auditar-suficiencia-operativa]] — **la DUPLA** (van JUNTAS SIEMPRE).
- [[auditar-proceso-algoritmo]] — el **tercer eje FMEA**, cuando se audita LÓGICA (no solo docs)…
- [[diagramar]] — …alimentado por los flowcharts (leyenda + normas) que el FMEA necesita como "zapatos".
- [[positivar-doc]] — answer-first: "ESTO SÍ" antes de "ESTO NO".
- [[desinflar-memorias]] — colapsar narrativa a lección + ⚰️ Lápidas al final.
- [[orquestar-fanout]] — fan-out sin niñera (worktrees aislados, 2 archivos de estado).
- [[revisar-entregables-agentes]] — no creer el "listo" del agente; verificar contra la realidad.
- [[checkpoint]] — volcar el hilo antes de compactar (crítico en corridas de N rondas).
- [[cerrar-slice]] — el cierre por ramita → MR → mini-develop con `--squash`.
- [[turno-nocturno]] — cuando la convergencia corre de noche sin supervisión.

---

## PASO 0 — INVENTARIO (no auditar a ciegas)
Antes de tocar nada, **ubica el cerebro real** y cuéntalo: ¿cuántas memorias / skills / hooks? ¿hay
`AGENTS.md` (la **firma**)? ¿hay `CLAUDE.md`? Ejemplo real (cps): *"AGENTS.md de 3164 líneas = la firma
→ la dupla audita CONTRA la firma; no hay CLAUDE.md; ~35 memorias, 5 skills, 11 hooks → fan-out
read-only"*. **La dupla BIFURCA según exista o no firma:** si hay `AGENTS.md`, se audita contra ella.

## LA CERCA (leer ANTES de tocar — reglas duras)
La consolidación es una pasada de **DOCS**, no de código. Dentro de esta cerca todo es tuyo; fuera de
ella se PARQUEA, no se cruza.
- **NO-DESTRUCTIVO:** solo **añadir / corregir / renombrar**, NUNCA borrar conocimiento. (En cps las 5
  rondas fueron 100% no-destructivas, verificadas contra los `.cs`/compose/CI reales.)
- **Narrativa FECHADA es válida — no se toca.** Una bitácora, un "rehomeado de X el <fecha>", un "296
  tests" de un slice puntual: son historia legítima, se quedan. (≠ un puntero VIVO colgado, que sí se
  arregla.)
- **Lo DESTRUCTIVO se PARQUEA con la pregunta ya redactada para el humano.** Nunca se ejecuta a la
  ligera. Ejemplos: escribir a datos vivos, un valor que el doc dice "probablemente" (déjalo en
  "verifica primero en vivo", no inventes la certeza), cualquier hallazgo que toque **lógica/dinero**.
- **NO se toca en esta pasada:** develop/main (git flow intacto), código/BD, colecciones/datos vivos,
  PRs ajenos, **ni se afloja ningún guardrail propio**.
- **La auditoría es READ-ONLY** sobre `.claude/`; los fixes van DESPUÉS por ramitas → MR con OK.

---

## FASE 1 — LA DUPLA (dos lentes DISJUNTAS, en paralelo, mismo snapshot)
Norma dura del usuario: **"VAN JUNTOS SIEMPRE"**. Se lanzan como fan-out read-only sobre el MISMO
snapshot, con ámbitos distintos:
- **[[auditar-coherencia-cerebro]]** (CONSISTENCIA) — ¿se contradicen los documentos? ¿datos que no
  cuadran? ¿guards evadibles? ¿punteros colgados? ¿doc que miente vs el código real?
- **[[auditar-suficiencia-operativa]]** (OPERABILIDAD) — ¿puede alguien que llega mañana HACER las
  tareas sin romper ni re-investigar? Deriva la lista de tareas reales, califica **✅/⚠️/❌ con
  archivo:línea**, con ojos frescos.

**Por qué van juntas (el caso que lo justifica, visto en vivo):** *"6 documentos perfectamente
coherentes entre sí prometiendo un candado que NO existía — coherencia perfecta, realidad distinta. La
coherencia no ve eso; la suficiencia sí."* Y al revés: un cerebro de recetas buenas que se contradicen
pasa la prueba de suficiencia archivo por archivo. **Ninguna caza lo de la otra.**

**Contrato de reporte** (de [[orquestar-fanout]]): cada auditor escribe su dictamen a un `.md` durable
(`AUDITOR-COH-r<N>.md`, `AUDITOR-SUF-r<N>.md`) y responde SOLO ~3 líneas al orquestador (veredicto +
conteo, hallazgos en bullets, ruta). Así no infla el contexto del orquestador.

## FASE 2 — VERIFICAR los hallazgos (no creer el reporte del agente)
[[revisar-entregables-agentes]]: **espera a tener AMBOS dictámenes antes de editar** (no muevas el piso
a media auditoría), y **verifica read-only cada hallazgo contra el código/realidad** — no lo relates
como verdad. El **cross-check entre lentes es donde se cazan los FALSOS POSITIVOS**: en cps, suficiencia
marcó `detectar-secretos.sh` como "hook huérfano" → coherencia lo REFUTÓ por ejecución (es una LIB
`source`-ada, no un hook) = FP anotado, no tocado. Con 4-6 informes, haz el cross-check ANTES de sintetizar.

## FASE 3 — CONSOLIDAR / ORGANIZAR (positivar → desinflar → dedup)
Con los hallazgos verificados, los fixes van por un agente en **worktree AISLADO** (o el orquestador
secuencial si el cerebro vive en un folder no-git, p. ej. Drive), commits granulares, orquestador revisa
el diff. El grueso del "quedar compacto":
1. **[[positivar-doc]]** — cada nugget answer-first: la solución/valor accionable ARRIBA, la cautela/
   gotcha/historia del fallo DEBAJO (idealmente `❌ …` compacto). Preserva el 100%, solo reordena.
2. **[[desinflar-memorias]]** — cada tirada de narrativa/tutorial se colapsa a su **lección en 1-2
   líneas EN SU LUGAR**; los mitos desmentidos se comprimen a una línea y se mudan a **`## ⚰️ Lápidas`
   AL FINAL** del archivo. NO se corta: advertencias destructivas, comandos, decisiones con su porqué,
   datos irrepetibles. Recortes reales: cps `estado-proyecto` 896→460 (−49%), **0 lecciones perdidas**.
3. **Un CANÓNICO + PUNTEROS** por dato/tema repetido: una memoria "manda", las hermanas se deducen a un
   puntero. Un dato NO vive en 3 lados; el estado "actual" se DERIVA.
4. **Índice answer-first y SIN DRIFT:** un solo entry-point (`AGENTS.md` "LEE ESTO ANTES DE HACER
   NADA"); `MEMORY.md` con el router de skills reflejando las skills REALES (N=N) y puntero arriba
   "→ Empieza por AGENTS.md". En cps el índice MENTÍA (clúster ETL invisible desde la puerta) →
   reconstruido 35/35.
5. **Matar el mito en TODAS sus copias:** tras corregir el canónico, `grep` del término viejo por TODO
   el cerebro vivo (incluido `MEMORY.md`) — una sola copia desincronizada ya es doc que miente.
6. **Reubicar lo genérico/ajeno FUERA del cerebro del proyecto** (lo transversal → global; lo de
   terceros → `~/code/ajenos/`); **retirar skills deprecados con lápida** (⚰️ RETIRADO + redirección).

## FASE 4 — EL LOOP DE CONVERGENCIA (el corazón)
**"auditar → arreglar → RE-AUDITAR con el prompt IDÉNTICO"** hasta que ambas lentes salgan limpias. El
usuario lo ordenó literal: *"ya que 'quede', VUELVE a correr el auditor IGUALITO"* — si cambias el
prompt, cambias el examen (guarda el prompt literal en un `.md`). **No autodeclarar** el cierre.
- **Convergencia = 0 CRÍTICO / 0 ALTO / 0 MEDIO accionable.** Los BAJO/borderline/nitpick no bloquean.
- **La TRAMPA del loop (regla dura):** cada ronda cava más fino; NO loopees indefinidamente. Cuando solo
  queden borderline/FP, **PAUSA y lleva la decisión de convergencia al usuario**. Señal de auditor
  agotado (real): *"ya es nitpicking, se ve que el auditor se aburrió"*.
- El loop no es ceremonia: en un caso el re-auditor cazó un bug que el **propio orquestador** introdujo
  (un gate colocado DESPUÉS de mutar el estado).
- Trayectoria real cps SUF: 1C/2A → 1C/3A → 0C/2A → 0C/1M → 0C/0A (5 rondas); coherencia convergió antes.

## FASE 5 (opcional) — EL TERCER EJE: FMEA, cuando hay LÓGICA de riesgo
La dupla es **doc-orientada** ("¿se puede operar?" / "¿se contradice/miente?"); **ninguna pregunta
"¿el ALGORITMO/FLUJO es correcto?"**. Cuando la capacidad audita LÓGICA (contabilidad, un ETL, una
máquina de estados, o **lo que HACE el propio brain**), se SUMA [[auditar-proceso-algoritmo]] (FMEA).
- **Condición dura:** el FMEA razona sobre **flowcharts de calidad** ("los zapatos") — cada uno **con su
  LEYENDA + las NORMAS aplicables**. Sin el mapa, el dictamen sale genérico. Es un proceso de **DOS
  pasos**: primero [[diagramar]] el flujo bien (respetando el `CONVENCIONES.md` del destino), luego el
  auditor lo audita **individual → colectivo** (cada pieza sola, luego todas juntas: una pieza correcta
  puede contradecir a otra en la costura).
- Los hallazgos de **lógica/dinero se PARQUEAN para el humano** (y su experta de dominio si la hay) — no
  se tocan en la pasada de cerebro.

## FASE 6 — CIERRE con la FIRMA (el lazo doc=realidad)
El mecanismo elegante que emergió de esta campaña. **La FIRMA no es "corre los auditores" (eso es el
trigger): la firma ES el checklist que se le entrega al auditor de suficiencia** — la lista de las
CAPACIDADES que el tooling promete + el puntero a su método. *"La firma es el SUJETO de la auditoría, no
su método."* Lazo cerrado: la firma es a la vez *lo que prometes* y *contra lo que se audita* →
doc=realidad por construcción (auditar = "¿la realidad sigue cumpliendo la firma?").

> **Ojo — la firma NO cuelga de `AGENTS.md`.** En un repo tosco de verdad `AGENTS.md` SIEMPRE existe y
> habla del **PROYECTO** (arquitectura: capas, prohibiciones, modelo de dominio — *cómo está hecho el
> código*, cps: 3164 líneas). Eso **NO es la misión de Claude en el proyecto** — es un eje APARTE, que
> audita la **coherencia** contra el `.cs`. La **firma** es otra cosa: la **misión/capacidades de Claude
> aquí** ("¿qué puedo HACER y cómo?"), que es justo lo que camina la **suficiencia**, y cuyo detalle vive
> en **`MEMORY.md`** (el índice del know-how operativo + router de skills). Por eso el detalle de la firma
> es `MEMORY.md`, no `AGENTS.md`. (En un brain de hobby sin arquitectura pesada, `AGENTS.md` puede doblar
> de entry-point; en un repo tosco NO — no confundas los dos sujetos.)

**3 capas, sin duplicar** (+ el eje de arquitectura, aparte):

| Capa | Dónde | Qué |
|---|---|---|
| Firma / checklist (**misión de Claude aquí**) | `CLAUDE.md` (thin, siempre cargado) = **el TOC de `MEMORY.md`** | ~5 líneas `capacidad → puntero al método` |
| Detalle de cada capacidad | `MEMORY.md` → la memoria / skill que apunta | el "cómo se opera bien" (thick, on-demand) |
| Método de los auditores | las skills (dupla + FMEA) | prompts, ámbito, prohibiciones |
| *(Eje APARTE, no es la firma)* | `AGENTS.md` | contrato de **arquitectura del PROYECTO** — audita coherencia vs el código, no la misión |

- El auditor de suficiencia **camina cada línea de la firma**: `CLAUDE.md → MEMORY.md → memoria/skill →
  realidad`, y marca el hueco (capacidad sin método, método sin código, doc que miente).
- **Alinea `MEMORY.md`** para que su índice tenga exactamente las capacidades que el TOC del `CLAUDE.md`
  declara, en ese orden (si sobra una memoria fuera del mapa: se enlaza desde el índice o se añade al
  TOC). `AGENTS.md` se deja en su carril de arquitectura, no se fuerza a la forma de la firma.
- **Entregable bonito de cierre: el "prompt bello de arranque"** — el reporte matutino curado (1 línea
  de estado + tabla de rondas + "lo único que necesito de ti") para reanudar la sesión-master sin
  trauma. El usuario lo valora explícitamente; va como parte del cierre y se **preserva a disco** (vive
  en el dictamen durable, no solo en el chat, para sobrevivir compactaciones).

## CRITERIO DE "LISTO" (no lo saltes)
**Convergencia técnica ≠ LISTO.** "0 ALTO/0 MEDIO + memoria al día" es *verificado técnicamente*:
necesario, insuficiente. El sello final es el **QA/OK del usuario** o su autorización expresa (definición
mutua de LISTO). Los parqueados quedan visibles en el **dictamen durable versionado**
(`<repo>/docs/auditoria-<tema>-<fecha>.md`) y en el backlog vivo (`estado-proyecto.md`) — **ningún
hallazgo se queda solo en el chat**, aunque solo se atienda un subconjunto.

---

## GOTCHAS (answer-first — destilados de las corridas reales)
- **git-branch-guard, FP sobre texto de commit:** dispara sobre `git push origin develop` **dentro de un
  mensaje de commit multilínea** (no un push real). Workaround: escribe el mensaje con Write y commitea
  con `git commit -F <archivo>`. (La lib `analizar-comando-git.sh` ignora menciones entrecomilladas, pero
  un heredoc multilínea la evade.)
- **Verifica el hallazgo con OJOS, no con el primer grep:** un `grep -E` con `\|` (en vez de `|` real)
  devolvió falsos "FALTA"; un "DESCARTADO" en la línea siguiente hizo declarar un mito "presente". El FP
  del propio detector a veces **destapa un hueco REAL de doc** — aprovéchalo, no lo descartes ciego.
- **No le creas al histórico de un cerebro "loopeado":** *"esa afirmación era suposición"*. Toda
  afirmación se reconcilia contra **evidencia real** (código/.cs/logs), no contra lo que asentó una
  sesión previa.
- **Rutas al verificar:** es `.claude/memory/`, no `memory/`. Usa rutas absolutas.
- **Ruido de shell del profile:** cada `Bash` puede imprimir un listado del root antes del output real
  (el profile de zsh/eza) — no afecta operaciones pero confunde el parseo; invoca `/usr/bin/ls` y rutas
  completas.
- **Parquear un folder en la rama correcta:** un "develop" local puede arrastrar historia de main y estar
  N líneas atrás del remoto — verificar `ahead/behind` + contenido idéntico al remoto ANTES de dar el
  parqueo por bueno.
- **Cerebro en folder no-git (Drive):** no se puede aislar en worktree → esas mutaciones las hace el
  **orquestador secuencialmente** (evita choques con el sync de Insync); la pieza que SÍ es git se delega
  en worktree aislado en paralelo.

## Mecanismo / enforcement (para que "van juntos" no dependa de la memoria)
El usuario pidió cablear la dupla al arranque del cerebro: *"¿no deberíamos integrarlo al bootstrapping
de cerebro Y al sincronizar-cerebro?"*. Propuesta pendiente: extender el flujo para que la DUPLA se
sugiera/recuerde tras un cambio de doc/sistema (un recordatorio, no un bloqueo), de modo que consolidar
sea un reflejo del proceso y no un acto de voluntad. (Registrar como frente si se cablea.)

## Notas de acoplamiento (decididas por el usuario, persistir)
- **"la dupla VAN JUNTOS SIEMPRE"** — norma dura; cada firma de las 2 skills menciona a la otra.
- La **firma vive en el `CLAUDE.md` de cada repo** (= TOC del `AGENTS.md`); el detalle una capa abajo.
- Este es un skill del **cerebro global** → vive en `~/code/claude-brain/brain/skills/` y viaja por el
  flujo (ramita → MR → develop con `--squash`), como todo el brain.
