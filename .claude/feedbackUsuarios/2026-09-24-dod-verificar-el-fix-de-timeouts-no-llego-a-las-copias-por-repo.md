# Feedback: el fix de timeouts de `dod-verificar` (16-sep) NO llegó a 5 de las 6 copias por-repo

**Fecha:** 2026-09-24 · **De dónde salió:** `/doctor` en la sesión de `potenciaDatabases` (Mac de unjordi).
**A quién le toca:** cortex-master (hook `dod-verificar` + su invariante en `test-brain.sh`).

> ✅ **Verificado en disco**: grepeé el crédito del juez en cada copia desplegada y el `timeout` cableado
> en cada `settings.json`. La telemetría de timeouts sale de 13 transcripts (2026-08-29 → 2026-09-24).
> Lo marcado `[INFER]` es hipótesis mía, no medición.

## Primero, la buena noticia: el fix FUNCIONA

El `CONTRATO DE COHERENCIA DE TIMEOUTS` del 2026-09-16 (bajar el crédito del juez de 20s a 10s, por debajo
de los 15s del harness) resolvió la carrera. Mi telemetría lo confirma **independientemente** de la de
agosto que cita el propio comentario del hook:

| día | corridas de `dod-verificar` | timeouts | mediana |
|---|---|---|---|
| 2026-08-05 | 31 | **31** | 15,016 ms |
| 2026-08-06 | 32 | **32** | 15,025 ms |
| 2026-08-10 | 1 | 1 | 15,045 ms |
| 2026-08-11 | 3 | 1 | 4,358 ms |
| 2026-08-12 | 2 | 2 | 962,851 ms |
| 2026-08-24 | 1 | **0** | 3,992 ms |
| 2026-08-31 | 1 | **0** | 2,999 ms |
| 2026-09-03 | 1 | **0** | 2,441 ms |

67 de 72 timeouts, **todos del 5 al 12 de agosto**. Desde el 24-ago resuelve en 2.4–4.0 s, cero timeouts.
(Caveat honesto: son solo 3 corridas post-agosto y las tres son ANTERIORES al fix del 16-sep — o sea que
miden la recuperación, no el fix. No hay ninguna corrida post-16-sep en los transcripts que tengo.)

## El problema vivo: el fix se quedó en el brain

`test-brain.sh:3962-3966` hace cumplir el invariante leyendo **`$DODSH`, la copia del BRAIN**. Nadie
verifica las copias ya desplegadas en `<repo>/.claude/hooks/`. Resultado medido hoy:

| repo | `timeout` del harness (`settings.json`) | `CLAUDE_DOD_JUEZ_TIMEOUT` de su copia | fecha de la copia | ¿carrera? |
|---|---|---|---|---|
| `pisamrpclaude` | 15 | **10** | 2026-09-22 | ✅ al día |
| `cps` | 15 | **20** | 2026-09-21 | 🔴 **sí** |
| `fluxcore` | 15 | **20** | 2026-09-09 | 🔴 **sí** |
| `plantilladotnet` | 15 | **20** | 2026-09-07 | 🔴 **sí** |
| `pisamrp_4.6` | 15 | *la variable no existe* — **79 líneas** vs 363 del brain | 2026-09-08 | 🔴 copia muy vieja |
| `axon` | `default` | **20** | 2026-09-09 | 🟡 sin carrera (harness > 20), pero desactualizado |

Referencia: `~/.cortex/brain/hooks/dod-verificar.sh` y `~/code/cortex/brain/hooks/dod-verificar.sh` → ambos `:-10`, 363 líneas.

**En 3 repos la carrera original sigue exactamente igual de viva que en agosto**: juez con crédito de 20 s
dentro de un harness que lo mata a los 15 s. Y son justo los repos donde más se trabaja.

`cps` es el caso que más dice: su copia es del **21-sep**, cinco días DESPUÉS del fix, y aun así trae `:-20`.
`[INFER]` — el sync por-repo no vino del brain al día, o el hook quedó fuera del conjunto que ese sync
refresca. No lo comprobé; vale la pena mirarlo porque explica cómo se repone el drift solo.

## Por qué importa

Es el modo de falla que el propio comentario del hook nombra: *"que los dos números puedan driftear en
silencio"*. Y el efecto es doble:

- **15 s de espera muerta** al cerrar cada turno en `cps`, `fluxcore` y `plantilladotnet`, y
- como `dod` es **fail-OPEN**, el timeout no bloquea: **el candado que hace cumplir la definición de LISTO
  no está dictaminando nada** en esos 3 repos. Un guard que agota su timeout no vigila, solo cobra peaje.

## Dirección del fix

1. **Re-desplegar el hook** a los 5 repos rezagados por la vía oficial del sync por-repo (no a mano).
2. **Mover el invariante de `test-brain.sh` un nivel afuera:** hoy verifica la coherencia *dentro del
   archivo del brain* (`CLAUDE_DOD_JUEZ_TIMEOUT` vs `_DOD_HARNESS_TIMEOUT_MINIMO`), que es donde nunca
   falla. El chequeo que hubiera atrapado esto compara **la copia desplegada de cada repo contra el
   `timeout` que ese mismo `settings.json` cablea**. Candidato natural: `drift-cerebro-comun.sh` en el
   `SessionStart`, que ya mira las copias por-repo — ahí el dato está a la mano y el aviso llega al repo
   afectado.
3. `pisamrp_4.6` con 79 líneas contra 363 no es un drift de un número: es una copia de otra era. Conviene
   ver si el sync lo alcanza o si ese repo quedó fuera del conjunto.
