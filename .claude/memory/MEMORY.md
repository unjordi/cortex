# Memory Index — claude-brain

> Cerebro de Claude Code de ESTE repo (`github.com/unjordi/claude-brain`).
> Es la fuente de verdad única (código + memoria/skills viajan juntos por el repo).
> Tras `git clone` en otra máquina: corre `bash .claude/bootstrap-claude.sh` una vez.
> Memorias personales/sensibles → `*.local.md` (gitignored, no viajan al equipo).
>
> **→ Empieza por `CLAUDE.md` (el ÁRBOL): qué instala este brain.** Este archivo es el **DETALLE de cada skill
> del producto** (abajo) + el **conocimiento de desarrollo** de este repo (widget, ecosistema, sync…).

## 💡 Catálogo de skills del producto (`brain/skills/` — el detalle de cada uno)
> Fuente única = `brain/skills/<nombre>/SKILL.md`. El árbol del `CLAUDE.md` muestra una vista curada; ESTA es la lista COMPLETA.

**Auditar / consolidar un cerebro**
- **`consolidar-cerebro`** — meta-orquestador de la campaña: dupla → positivar → desinflar → loop de convergencia → cierre con la FIRMA (convención CLAUDE+MEMORY). Orquesta, no reinventa.
- **`auditar-suficiencia-operativa`** — ¿ALCANZA la doc para HACER las tareas sin romper ni re-investigar? deriva tareas reales de 4 canteras, ✅/⚠️/❌ con archivo:línea, RE-audita tras arreglar. Mitad OPERABILIDAD de la dupla.
- **`auditar-coherencia-cerebro`** — fan-out read-only sobre el propio cerebro (guards+flowcharts+doc): evasiones/huecos/drift, verificado por EJECUCIÓN, loop hasta converger. Mitad CONSISTENCIA de la dupla.
- **`auditar-proceso-algoritmo`** — auditor experto read-only (procesos industriales + análisis de algoritmos) sobre un flujo/algoritmo (app o el propio brain): individual→colectivo, hallazgos priorizados. Se alimenta de flowcharts (`diagramar`).
- **`revisar-entregables-agentes`** — verificar lo que un agente ENTREGA contra la realidad; nunca relatar su "listo" como verdad sin comprobarlo.

**Cierre de trabajo / git**
- **`cerrar-slice`** — ritual de cierre: verifica (build/tests/lint), memoria al día, confirma con el usuario, ramita → MR → develop con resumen curado.
- **`cosechar-sesion`** — cosecha LOCAL al cerrar el día: revisa TU transcript y extrae los aprendizajes genuinos a memoria.
- **`unificar-cerebro`** — reconciliación SEMANAL: junta aprendizajes+memorias de las minis de los devs hacia develop sin perder nada.

**Continuidad del hilo / compactar**
- **`checkpoint`** — vuelca el estado efímero (el HILO) a memoria durable para compactar/cerrar sin perderlo. DOS niveles (ligero / COMPLETO).
- **`rehidratar-hilo`** — retoma el HILO tras un /compact o corte: anuncia de qué íbamos y continúa desde el "siguiente paso" (gemelo del hook homónimo).

**Orquestación / delegación**
- **`orquestar-fanout`** — fan-out sin niñera: worktrees aislados, 2 archivos de estado (bitácora `>>` + estado-proyecto), auto-reporte y limpieza al cerrar.
- **`turno-nocturno`** — protocolo del turno de noche: eco del contrato, decide-dentro-de-la-cerca, grants durables a disco, checkpoint cada ~2h.

**Memorias / docs**
- **`positivar-doc`** — reescribe answer-first: "ESTO SÍ" (método correcto) ANTES del "ESTO NO" (anti-patrón/gotcha); preserva el 100%.
- **`desinflar-memorias`** — adelgaza un árbol de memorias sin perder lecciones: narrativa → su lección en su lugar; mitos descartados → `⚰️ Lápidas` AL FINAL.
- **`investigar-dominio`** — investigar a fondo un dominio de negocio antes de modelarlo, de fuentes reales (no inventar/suponer).

**Diagramas / visual**
- **`diagramar`** — diagrama según su DESTINO: `.dot`→`dot2yed`→yEd (editar a mano) · Mermaid en `.md` versionado (verse en GitHub). Un diagrama entregable nunca queda como widget efímero.
- **`zoom-screenshot`** — leer/transcribir capturas cuyo texto fino es ilegible entero: recorta y amplía regiones con ffmpeg antes de leer.

**Instanciar un cerebro**
- **`claude-proyecto-autocontenido`** — el cerebro vive en `<proyecto>/.claude/` (memoria+skills+hooks), autocontenido, viaja por git; bootstrap del OS lo enlaza.

## 📚 Conocimiento de desarrollo de este repo (widget + brain)
- [Claude Brain Widget](claude-brain.md) — qué es y dónde vive (este repo, fuente única); fuente de datos (endpoint OAuth `/usage` + ccusage); look FelixDes (naranja, icono speedometer); popup de 3 pestañas (Límites/Resumen/Modelos); gotchas de iteración en KDE y de la bandeja; replicación multi-OS (macOS con paridad completa desde 2026-07-04, Windows por construir); **POLÍTICA de release 2026-07-26**: cada push a `main` reconstruye TODOS los assets precompilados (sin filtro `paths:`) — antídoto al loop de auto-update por asset rancio
- [Tema KDE opaco](kde-tema-opaco.md) — fork local "CachyOS Nord (opaco)" para bajar la transparencia de los widgets de KDE (0.81→0.97); revertir con `plasma-apply-desktoptheme CachyOS-Nord-round`
- [Árbol del Cerebro — sync](arbol-cerebro-sync.md) — la jerarquía de la pestaña Cerebro está DUPLICADA en 4 lugares (README + brainTiers de macOS/Linux/Windows) + lógica de estado por GUI que casa NOMBRES; tocar uno = tocar los 4 o se divergen (doc <= realidad). Diferencia de medio legítima: por-repo va indentado en README, con ◈ en el widget.
- [Ecosistema Claude (KB viva)](ecosistema-claude.md) — todo lo aprendido sobre el ecosistema Claude (CLI, chat, API, hooks, cuotas, sesiones) al construir el brain; CRECE con cada hallazgo. Semilla: auth GLOBAL a la máquina (switch de cuenta transparente a la sesión viva), el mensaje "cannot determine safety of Bash" = quota agotado (NO Bash roto), PreCompact no inyecta additionalContext, transcripts por-máquina no viajan.
- [Estrategia de memoria](estrategia-memoria.md) — PLAN (no ejecutado, en el backlog): 5 fases para hacer el cerebro más eficiente/fluido sin perder el hilo (0 gratis · 1 recall selectivo sin daemon · 2 spike Basic Memory · 3 Serena para código .NET · 4 Graphiti condicional) + qué NO haremos (Mem0/Zep cloud, Letta) + decisiones abiertas.
- [Feedback: correr comandos sin modificar](feedback_correr-comandos-sin-modificar.md) — al QAear un mecanismo documentado (instalador, one-liner del README), córrelo LITERAL; verifica el estado real antes de "optimizar" con flags/env (2026-07-15: una copia redundante ya existente costó menos que debuggear mi desvío).
