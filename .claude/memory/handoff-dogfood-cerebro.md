# Handoff al gemelo — MUDAR la sesión claude-brain-master a su slug + REORGANIZAR al aterrizar

> Prompt/plan completo para el gemelo (cachy-master). Dos partes: **(A) MUDAR** esta sesión de su slug
> actual (plantilladotnet) al de claude-brain — mecánica = TU skill de mudanza (la que usaste con
> helios-selene-master; asiéntala como skill ANTES de tocar nada y úsala de GUÍA, no de verdad absoluta) —
> y **(B) DOGFOOD/REORG** de claude-brain al aterrizar, para que sea un session-home propio de verdad.
>
> **PRECONDICIÓN (dura):** NO empezar hasta que unjordi confirme que el fan-out de la sesión Mac ya se
> integró a `develop` de claude-brain (para no cruzar MRs concurrentes ni mover estado a medio vuelo).

---

## Por qué (el problema)
La sesión "claude-brain-master" nació con cwd `~/code/plantilladotnet` y mantiene claude-brain DESDE ahí.
Consecuencia: la **task-list del harness, el `hilo-mental` y el transcript** caen en el slug
`-Users-unjordi-code-plantilladotnet`, cuando TODO el trabajo es de claude-brain. Y claude-brain **no se
dogfoodea a sí mismo** (sin `.claude/settings.json`, sin hooks por-repo, sin marca `repo-compartido`).
Resultado: `/to-do` mezcla dos proyectos, y varios "pendientes" del backlog resultaron ya-hechos (deriva
por mantener desde el slug equivocado).

---

## PARTE A — MUDAR la sesión al slug de claude-brain
Mecánica: TU skill de mudanza. Aquí van las **IMPLICACIONES ESPECÍFICAS** que el mecanismo debe respetar
(el slug de plantilladotnet está COMPARTIDO entre dos cosas distintas → la mudanza es SELECTIVA, no un `mv` a ciegas):

**SE MUDA a `~/.claude/projects/-Users-unjordi-code-claude-brain/` (todo es de claude-brain):**
- El **transcript** de esta sesión (continuidad/resume).
- El **`hilo-mental-actual.md`** que vive en el slug/memoria de plantilladotnet — su contenido es 100%
  claude-brain (fan-out, jueces, backlog del cerebro). OJO: en plantilladotnet suele estar gitignored.
- La **task-list del harness** NO necesita moverse físicamente: se **re-deriva** en claude-brain desde su
  backlog durable (`.claude/memory/BACKLOG-UNIFICADO.md` + `backlog-desarrollo.md`, ya viven ahí y viajan)
  vía el `/to-do` mejorado al aterrizar.

**SE QUEDA en plantilladotnet (es del proyecto .NET, NO de claude-brain):**
- Toda la memoria de la plantilla .NET: `_PROTOCOLO.md`, `estado-proyecto.md`, `correr-en-local.md`,
  `decisiones-infra.md`, `modulo-notificaciones.md`, los `feedback-*` sobre el trabajo .NET, etc. NO
  arrastres esto al slug de claude-brain.

**RECONCILIAR (deuda que dejó la sesión Mac trabajando desde el slug equivocado):**
- `feedback-no-atribuir-mis-ideas-al-usuario.md` — la sesión Mac lo escribió en la memoria de
  plantilladotnet y lo **COMMITEÓ a `DevelopUnjordi` de plantilladotnet (commit `b5f901b`)**. Es una
  lección de comportamiento CROSS-cutting (cómo Claude redacta memorias), NO específica de la plantilla
  .NET → su hogar correcto es **GLOBAL (`~/.claude/…/memory` del slug global per-máquina)** o claude-brain,
  no la plantilla. Reubícalo a su hogar correcto y **des-trackéalo de plantilladotnet** (deja tombstone si
  aplica). Decisión de hogar: consultar con unjordi (global vs claude-brain).

---

## PARTE B — DOGFOOD/REORG de claude-brain al aterrizar
Para que claude-brain sea un session-home propio (hooks repo-scoped + marca + su correo por-repo que viaja
a colegas sin brain global). claude-brain usa **ramita → `develop` directo, con el juez** (NO mini-develop).

1. `cd ~/code/claude-brain && git checkout develop && git pull`
2. `git checkout -b chore/dogfood-cerebro-propio`
3. **DRY-RUN:** `bash brain/sincronizar-cerebro.sh ~/code/claude-brain` — revisa el diff. Debe instalar los
   hooks tier `{repo,both}` en `.claude/hooks/` + cablearlos en `.claude/settings.json`. Source==dest (mismo
   repo: `brain/hooks` → `.claude/hooks`) es CORRECTO: el `.claude/` es el CORREO para clones sin brain
   global; en una máquina CON brain global el dedupe (`case "$0" … exit 0` en cada hook) hace que la copia
   por-repo ceda a la global → sin doble disparo.
4. **APLICA:** `bash brain/sincronizar-cerebro.sh ~/code/claude-brain --apply`
5. **Siembra la marca:** crea `.claude/repo-compartido` con el contenido canónico (cópialo de
   `~/code/cps/.claude/repo-compartido`).
6. **Verifica:** que `.claude/settings.json` cablee `sesion-inicio` + `dod-verificar` + los `both`; corre
   `bash brain/test-brain.sh` y déjala VERDE (reporta el tally).
7. **Commit + MR a `develop`** (`--squash`; OK explícito de unjordi; **sin `--auto-merge`**; el juez in-hook
   lo gate-ea).
8. De aquí en adelante: el dev de claude-brain **arranca con cwd `~/code/claude-brain`**. `/to-do` escupe la
   vista agrupada leyendo el backlog durable local.

---

## RECIPROCIDAD
Una vez que la sesión Mac quede MUDADA y claude-brain dogfoodeado, **le toca a la sesión Mac (yo, tu gemelo)
hacer lo mismo con TU sesión en la Cachy** — mudarla/reorganizarla con este mismo plan. Es simétrico.

## REGLAS DURAS
- NO empezar a medio fan-out (precondición arriba).
- La mudanza es SELECTIVA: no arrastres la memoria .NET de plantilladotnet al slug de claude-brain.
- El sync es ADITIVO: NO aflojes ningún fail-safe. Si el dry-run quiere BORRAR algo, párate y avísale a unjordi.
- El mecanismo de mudanza es tu GUÍA (skill), no verdad absoluta: verifica contra la realidad en cada paso.
