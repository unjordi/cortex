# Propuesta (DISEÑO, pide tu OK antes de implementar): estado-proyecto.md "en todos lados"

**Origen:** tu decisión 2026-10-21 (nota 2026-10-21-tiers-hooks-repo-a-global.md, punto 2) — "estado-proyecto.md
debería existir en todos lados, no solo en repos". La parte 1 (recordar-cosechar/sesion-inicio → tier both) ya
quedó; esto es el punto 2, que marcaste como DISEÑO. **No implemento nada hasta tu OK.**

## El problema concreto
`recordar-cosechar` (ahora global) ESPEJA el TaskList vivo → el bloque `<!-- espejo-tasklist -->` dentro de
`estado-proyecto.md`, PERO hoy `[ -f estado-proyecto.md ] || return 0`: si el archivo NO existe, no hace nada
(no lo crea). Fuera de un repo (p. ej. las carpetas de GoogleDrive/Juegos donde trabaja games-master, o `~`),
no hay `estado-proyecto.md` → el HUD no se persiste → al compactar/retomar se pierde el backlog.

## Las 2 decisiones de diseño que necesito que tomes
### (1) ¿DÓNDE vive estado-proyecto.md fuera de un repo?
- **Opción A — junto al trabajo (cwd/CLAUDE_PROJECT_DIR):** `<cwd>/.claude/memory/estado-proyecto.md`. Simple y
  local a "el proyecto" = la carpeta donde trabajas. Riesgo: en `~` o Downloads crearía un `.claude/memory/` suelto;
  y si cambias de cwd dentro de la misma "cosa", se fragmenta.
- **Opción B — un home por-"proyecto" configurable:** un mapa (p. ej. `~/.config/cortex/proyectos-no-repo.json`)
  que asocia una carpeta de trabajo → su `estado-proyecto.md` (que puede vivir en la misma carpeta de nube). Para
  games-master: cada carpeta de Juegos tiene el suyo. Más control, más setup.
- **Opción C — un backlog GLOBAL per-máquina:** `~/.claude/memory/estado-proyecto.md` como fallback único cuando
  no hay uno local. Un solo HUD global para todo lo no-repo. Simple pero mezcla proyectos distintos.
- **[INFER] mi recomendación:** **A con gate** — crear `<CLAUDE_PROJECT_DIR>/.claude/memory/estado-proyecto.md`
  SOLO si `CLAUDE_PROJECT_DIR` está seteado y NO es `~` ni un dir "peligroso" (lista corta de exclusión), y
  recordar-cosechar AVISA la primera vez ("creé estado-proyecto.md aquí para persistir tu HUD; muévelo/bórralo si
  no lo quieres"). Fuera de eso, calla. Queda por decidir si games-master quiere B (mapa explícito).

### (2) ¿recordar-cosechar lo CREA, o solo AVISA que falta?
- **Crear automáticamente** (con el aviso de arriba) = cero fricción, pero esparce `.claude/` por carpetas.
- **Solo avisar** ("no hay estado-proyecto.md aquí; créalo con /to-do si quieres persistir el HUD") = no ensucia,
  pero no cumple "en todos lados" sin un paso tuyo.
- **[INFER] recomendación:** crear SOLO bajo la condición del gate de (1); si no se cumple, avisar una vez (throttled).

## Qué NO cambia
- Dentro de un repo: igual que hoy (ya existe estado-proyecto.md o se crea en su `.claude/memory/`).
- El bloque espejo y la lib `sincronizar-tasklist` no cambian de formato.

## Lo que haré al tener tu OK
Implementar la opción elegida en `recordar-cosechar.sh` + `sincronizar-tasklist.sh` con su test de uso real
(carpeta no-repo elegible → crea+espeja; carpeta excluida → calla), doc en MEMORY.md, y aviso al games-master si
toca su flujo de Juegos.

**→ Dime: (1) A/B/C (o combinación), (2) crear-vs-avisar, y cualquier exclusión que quieras.**
