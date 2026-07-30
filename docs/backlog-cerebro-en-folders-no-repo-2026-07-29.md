# Backlog/diseño: aplicar el cerebro a folders que NO son repos git

> **Origen:** destilado de una sesión monumental (2026-07-29) reparando/reorganizando el proyecto
> **games-master** (`/run/media/.../GoogleDrive/Juegos/`), que es el caso canónico de "cerebro en un folder
> NO-git": biblioteca personal de juegos/emulación, single-user, en Google Drive, sincronizada a 3 máquinas
> (Cachy/Deck/RP6). Este memo es material para el ítem de backlog "hacer que el cerebro sirva a folders no-repo".
> **Estado:** borrador de diseño (NO commiteado a develop por el que lo escribió; intégralo por el flujo normal).

## El problema, en una línea
El cerebro está optimizado para **repos de CÓDIGO, en equipo, en git, en `~/code`**. Un folder personal
en Drive sin git hereda TODO ese andamiaje git-flow **sin recibir su valor** — y le FALTA lo que sí
necesitaría. Resultado observado: fricción sin protección + ausencia del único gate que ayudaría.

## Lo OBSERVADO en games-master (síntomas reales)
1. **Guardarraíles git-flow disparan en falso / son ruido.** `git-branch-guard`, `merge-squash-guard`,
   `confirmar-merge-develop`, `barrer-ramas`, etc. corren en cada sesión aunque `git rev-parse` falle
   (no es repo). Son fail-open (no bloquean) pero condicionan reflejos y meten ruido cognitivo.
2. **`dod-verificar` (Stop) NO estaba cableado** (es tier `repo`, y el folder no tenía `settings.json`) →
   cascada de claims "LISTO" sin freno. Norma sin mecanismo.
3. **`dod-verificar` también da FALSOS POSITIVOS** de "cierre" sobre lenguaje de estatus/espera, y su rama
   de "auditoría de paridad de MIGRACIÓN" se enganchó con la palabra "migración" usada como REFACTOR
   (ver `~/.claude/memory/guards-falsos-positivos.md`). Candidato a tuning de precisión.
4. **Skills/memorias se acumulan y aturden.** El `MEMORY.md` curado se ve bonito pero el folder crudo tenía
   redundancia (3-4 docs de Steam solapados y hasta contradictorios), skills genéricos/de-terceros mal
   ubicados, y un `.git` de terceros clonado DENTRO de Drive (bomba de corrupción de sync).
5. **El appid/#9463 (dominio) NO es el punto** — el punto de proceso: el mapa de RIESGOS del template
   (push a main, secretos, gasto API) ≠ el mapa de riesgos del proyecto (romper estado físico volátil de
   Steam/consola). El gate que HARÍA falta (no editar config viva sin cerrar la app) estaba AUSENTE.

## Lo que FUNCIONÓ (soluciones aplicadas — patrones reutilizables para el brain)
1. **`AGENTS.md` como punto de entrada ÚNICO** ("LEE ESTO ANTES DE HACER NADA"): reglas de operación
   duras + router de skills, arriba. Answer-first a nivel DOCUMENTO. CLAUDE.md y MEMORY.md apuntan ahí →
   una sola fuente, cero drift. **Propuesta: template de AGENTS.md para brains no-repo.**
2. **Declarar "este proyecto NO es git"** explícito en el contrato + tratar los git-guards como ruido —
   PERO con una **excepción**: `aviso-drift-cerebro` SÍ importa en un cerebro en Drive multi-máquina
   (drift = copias "conflicted"/stale entre máquinas es riesgo REAL). El drift NO es concepto solo-git.
3. **Poka-yoke POR-FOLDER de dominio** en vez de guardas git: `settings.json` propio del repo con un
   `PreToolUse` que bloquea la acción REALMENTE peligrosa del dominio (aquí: escribir `shortcuts.vdf`/
   colecciones con Steam abierto), fail-open, con escape a conciencia. **El gate correcto = el del riesgo
   REAL del proyecto, no el del template.**
4. **Tooling con red de seguridad + tests** (libs reusables, validador, `test_*.py`) en su propia carpeta
   con nombre honesto — no scripts inline que driftean.
5. **Higiene de ubicación:** genéricos/meta → cerebro GLOBAL (`~/.claude/skills/`); terceros → `~/code/ajenos`
   (nunca `.git` bajo Drive); dominio → el folder. `1 tema = 1 archivo canónico + punteros` (dedup lossless
   estilo `positivar-doc`, conservando 100%).
6. **doc=realidad al mover:** al reubicar algo, actualizar el índice (MEMORY.md/AGENTS.md) en la MISMA tanda;
   bitácora append-only para el histórico (no reescribir el pasado).
7. **Marcar confianza de cada dato** `[DOC]/[EXP]/[SUPUESTO]` — un `[SUPUESTO]` fosilizado como ley
   (appid "determinista") costó una noche.

## PROPUESTAS concretas para el claude-brain (el backlog)
- **P1 — "Modo/perfil non-git" (o detección):** que los git-guards (`git-branch-guard`, `merge-squash-guard`,
  `confirmar-merge-develop`, `barrer-ramas`, `rama-vieja`) hagan **no-op silencioso** cuando
  `git rev-parse --is-inside-work-tree` falle. Cambio de PRECISIÓN (no afloja nada — solo no dispara donde no
  hay git). Elimina el ruido #1 sin perder protección. (Requiere OK de Jordi — toca guardas de supervisión.)
- **P2 — `dod-verificar` per-folder:** que un folder no-repo pueda cablear `dod-verificar` fácil (o que sea
  tier `both`), para que "LISTO" tenga mecanismo también fuera de un repo-plantilla. + el tuning de precisión
  de sus falsos positivos (estatus vs cierre; "migración"=refactor).
- **P3 — Drift-para-Drive:** un mecanismo de drift adecuado a un cerebro sincronizado por Drive (no git):
  detectar copias "conflicted"/stale entre máquinas y avisar/reconciliar. `aviso-drift-cerebro` es el gancho
  natural, pero su lógica es git-based hoy.
- **P4 — Template `AGENTS.md` + estructura para brain no-repo:** entry-point único, router de skills, "no es
  git", dónde vive el tooling/genéricos/terceros. Que `install-brain`/bootstrap lo siembre en modo "folder".
- **P5 — Poka-yoke de dominio como patrón de primera clase:** guía para que un folder declare "la acción
  peligrosa de MI dominio" y el brain le dé el `settings.json`+hook por-folder (fail-open, con escape).
- **P6 — Higiene/anti-acumulación:** un paso (skill) que audite redundancia/staleness/misplacement de
  skills+memorias de un folder (el "dale amor al repo" de hoy, sistematizado).

## Punteros
- Bitácora detallada del caso: `Juegos/.claude/memory/bitacora.md` (entradas 2026-07-28/29).
- Auditoría de calidad + de afirmaciones: `Juegos/.claude/projects/auditoria-*-2026-07-2*.md`.
- Ejemplos vivos de los patrones: `Juegos/AGENTS.md`, `Juegos/.claude/hooks/gate-steam-edicion.sh`,
  `Juegos/.claude/skills/steam-tooling/`.
- Falsos positivos de guards: `~/.claude/memory/guards-falsos-positivos.md`.
