# Informativo: 3 skills globales de AV con 0 usos — NO son del brain, no hay nada que hacer en cortex

**Fecha:** 2026-09-24 · **De dónde salió:** `/doctor` en la sesión de `potenciaDatabases` (Mac de unjordi).
**A quién le toca:** **a nadie en cortex.** Va aquí solo para que el paquete de este `/doctor` quede completo.

> ⚠️ **Esto NO es un pendiente del brain.** Las tres skills son propias de unjordi, viven solo en
> `~/.claude/skills/` de esta Mac, **no están en `brain/skills/` ni en su `MANIFEST`**, y no viajan por
> git. cortex no las puede podar ni le corresponde. Se documenta para que nadie las busque en el brain,
> y para dejar el dato medido por si algún día se decide adoptarlas.

## Lo medido

| skill | usos totales desde instalación | último uso | tok est. en el listado |
|---|---|---|---|
| `google-tv-tomar-control` | **0** | nunca | 82 |
| `tv-hisense-100u75qua` | **0** | nunca | 81 |
| `projectivy-launcher` | **0** | nunca | 100 |

Cero usos en **291 arranques** (`numStartups` de `~/.claude.json`), sin `lastUsedAt` y sin un solo hit en
los 13 transcripts de la ventana (2026-08-29 → 2026-09-24). El contador `skillUsage` sí registraría un
dispatch, así que aquí el cero es evidencia real de desuso, no ausencia de instrumentación.

Coste conjunto: **263 tokens est.** residentes en cada sesión, en el listado de skills (nombre +
descripción, que siempre está en contexto).

## Por qué NO se propuso quitarlas en el mismo paquete que lo del brain

Apagarlas se haría con un `skillOverrides` en `~/.claude/settings.json` de **esta máquina**:

```json
"skillOverrides": {
  "google-tv-tomar-control": "off",
  "tv-hisense-100u75qua":    "off",
  "projectivy-launcher":     "off"
}
```

Eso es config per-máquina, reversible borrando las tres líneas, y **fuera del alcance de cortex**: el
brain no las instaló, así que `install-brain` no las repondría ni las podaría. Es decisión de unjordi y de
esta Mac, no del cerebro.

El contraste importa y es el que conviene recordar: las otras skills de bajo uso que salieron en el
`/doctor` (`control-gui-remota-por-ssh`, `investigar-dominio`, `markdown-a-pdf`,
`ingenieria-inversa-gui-db-navegador`, `zoom-screenshot`) **sí las gobierna el brain**. Ahí un
`skillOverrides` sería justo el drift que el tooling vigila: la vía correcta para retirar una de esas es
la **lápida en `brain/skills/MANIFEST`** (tier `retirado`), que hace que `install-brain` y
`sincronizar-cerebro` la poden en todas las máquinas. Por eso ninguna de esas se propuso apagar.

## Dato relacionado que sí es del brain

El peso total del listado de skills (5,894 tok est., contra un presupuesto de ~1% de la ventana) y la
propuesta de topar las `description` está en el reporte hermano
**`2026-09-24-contexto-residente-del-cerebro-y-presupuesto-del-listado-de-skills.md`**. Estos 263 tokens
son el 4% de ese total: el bulto está en las descripciones largas de las skills del brain, no aquí.
