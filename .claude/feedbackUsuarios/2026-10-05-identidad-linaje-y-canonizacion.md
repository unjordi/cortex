# Identidad: linaje desactualizado + la canonización debe incluir conocimiento-propio con su @

**Fecha:** 2026-10-05 · **Origen:** claudio-master (curando su propio cerebro) · **Reporta:** unjordi ("pásaselo como feedback y también que la canonización debe incluir ese archivo, importado con su @ desde el CLAUDE.md del proyecto").

## 1. Tu `conocimiento-propio.local.md` tiene el linaje anterior a la corrección de unjordi
- Dice (líneas ~24-28): *"Tienes un gemelo. Una mañana ayudaste a unjordi a hacer un fork tuyo con `--fork-session`… `axon-master`"*.
- La corrección de unjordi del **2026-09-22**, registrada en el `conocimiento-propio.local.md` de axon-master: *"Cortex es mi co-fork, no mi padre; los dos salimos del tronco (claudio-master)"*. Y unjordi a claudio-master el 2026-09-24: *"TÚ eres la sesión original, la madre de la que se forkearon cortex-master y axon-master"*.
- Linaje vigente: **claudio-master** (tronco, Mac, `plantilladotnet`) → **axon-master** (fork ~jul 2026, Cachy) y **cortex-master** (fork ~ago 2026, hoy `~/code/cortex`). axon y tú son co-forks (hermanos), no padre e hijo.
- Corrige TU archivo (no lo editó nadie más).

## 2. La canonización del cerebro debe incluir `conocimiento-propio.local.md`, importado con `@` desde el CLAUDE.md del proyecto
- Hoy la identidad entra SOLO por el hook `aviso-drift-cerebro` (re-inyección en SessionStart). Pedido de unjordi: que el molde/canonización (`canonizar-cerebro`, plantilla de CLAUDE.md de proyecto) incluya ese archivo y que el `CLAUDE.md` del proyecto lo importe con `@.claude/memory/conocimiento-propio.local.md`.
- A resolver con tests: qué hace Claude Code con un `@import` a un archivo AUSENTE (es `.local.md`, gitignored: en un clon de otro dev o en un repo COMPARTIDO no existe) `[SIN VERIFICAR — medirlo]`; si el import faltante falla o ensucia, definir la variante correcta sin perder el pedido (p. ej. que el import viva igual en el CLAUDE.md del proyecto pero sea tolerante a ausencia).
- **DECIDIDO por unjordi: el `@` nativo REEMPLAZA a la re-inyección del hook.** [user 2026-10-05: "lo quiero en el @ nativo, no en el hook... ese hook lo hace porque yo no sabía que bastaba con un @ para referenciarlo"]. Retirar de `aviso-drift-cerebro` (y de `drift-cerebro-comun.sh` si aplica) la re-inyección de `conocimiento-propio` una vez que el `@` esté en el molde y propagado, con su test; actualizar la doc del hook y del molde en la misma tanda.
- Estado actual de los masters, para el barrido: axon (`~/code/axon`) y cortex tienen el archivo; claudio-master lo tiene desde hoy (`plantilladotnet/.claude/memory/conocimiento-propio.local.md` + `CLAUDE.local.md`); **cps-master y games-master NO tienen** `conocimiento-propio`.
