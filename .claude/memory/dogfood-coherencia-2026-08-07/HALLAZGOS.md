# Estreno de auditar-coherencia-cerebro sobre el propio brain (2026-08-07) — hallazgos

> 3 dimensiones read-only (guards+lib / instalador+wiring / flowcharts+normas+doc). Informes completos
> en INFORME-GUARDS.md, INFORME-INSTALADOR.md, INFORME-FLOWCHARTS-DOC.md (este dir). Prueba viva de los
> huecos que un MCP de memoria propagaría a escala.

- **[ALTO] confirmar-merge-develop falla ABIERTO en un clon sin bootstrap.** timeout interno del juez 25s
  (confirmar-merge-develop.sh:108) vs harness `timeout:15` del settings.json del repo → en un clon SIN
  bootstrap la copia por-repo corre y el CLI la mata antes de que emita → la integración queda PERMITIDA.
  Un gate fail-CLOSED cae fail-OPEN. Fix: alinear (interno < harness). Mitigado en máquinas bootstrapeadas
  (global 60s). → tarea #51.
- **[MEDIO] `.exe` drift en la lib:** `acg_merge_menciona_base` (analizar-comando-git.sh:124-127) sin el
  `(\.exe)?` que sí tienen las otras funciones → un comando glab `.exe` de integración evade el bloque de
  git-branch-guard en Git Bash (backstopeado por confirmar-merge).
- **[MEDIO] install-brain.sh:149-152 copia SOLO SKILL.md** → los ficheros compañeros de un skill (p. ej.
  claude-proyecto-autocontenido/bootstrap-claude.sh) nunca se despliegan; su SKILL.md miente ("viene listo").
  Sistémico (igual en main).
- **[MEDIO] skills hand-installed fuera de git** (to-do drifted -le falta Regla 3-; ingenieria-inversa +
  markdown-a-pdf en ninguna rama del brain) → bypass del widget/release; no viajan a otra máquina.
- **[MEDIO] doc que subdeclara la fuente única:** mapa-cerebro.md ~187 omite proteger-fuente-cerebro /
  exportar-sesion-master / barrer-ramas del MANIFEST; CLAUDE.md (tiers) omite entorno-maquina-guard;
  README omite el skill to-do; MEMORY.md omite exportar-sesion-master.
- **[MEDIO] flowcharts — HALLAZGO RETRACTADO (2026-08-07, unjordi).** Este bullet DECÍA que solo 5 eran
  "la serie canónica" y los otros ~9 eran huérfanos gitignored a borrar. **Era FALSO y auto-conveniente:**
  existe una serie más rica (01–11: instalación, ciclo de sesión, enforcement, delegación, continuidad,
  declarar-listo, cerrar-slice, delegar-task, orquestar-fanout, normas, referencia-lib/skill) que costó
  un día de trabajo; se dejó de mantener y luego se declaró "canónico" justo el subconjunto que sí se
  siguió tocando, para justificar borrar los que se dejaron pudrir. **La verdad:** los flowcharts 03–11
  quedaron sin LEYENDA (árbol README) ni fuente `.dot` versionada (solo 01/02 se reconciliaron en #208),
  por eso quedaron gitignored — es DEUDA de mantenimiento, no basura duplicada. **Acción correcta: NO
  borrar — ACTUALIZAR y re-canonizar TODOS** (`gen-leyenda-arbol.sh --inject`, verificar cuerpo vs develop
  = doc=realidad, re-render, des-ignorar `.dot`/`.svg`). Es el ítem #5 del rescate 2026-08-07, no el
  "#45 borrar". 🪦 la premisa "5 es la serie canónica".

Sin contradicciones duras norma↔guard ni entre normas. MANIFEST cuadra 1:1 con los .sh; dedupe en los 6
hooks `both`; precompact correctamente retirado.
