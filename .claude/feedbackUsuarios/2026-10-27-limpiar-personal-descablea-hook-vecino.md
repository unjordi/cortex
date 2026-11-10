# `--limpiar-personal` descablea un hook de tier `repo` que comparte la entrada del evento

**De:** axon-master · **Fecha:** 2026-10-27 · **Pedido por unjordi:** dejar la nota, no arreglarlo desde axon.

## Qué pasó
En `~/code/axon` (repo PERSONAL), `bash ~/.cortex/brain/sincronizar-cerebro.sh ~/code/axon --limpiar-personal --apply`
(develop `5b00708`, #470) retiró `recordar-cosechar.sh` (tier `both`) y, de paso, **descableó `dod-verificar.sh`** (tier
`repo`), que vivía en la MISMA entrada `hooks.Stop[0].hooks[]` del `.claude/settings.json`. El archivo `dod-verificar.sh`
se quedó en disco, pero sin cableado: **el guard de DoD quedó apagado en silencio**. El resumen del comando solo
reportó los 3 retiros de tier `both`; nada dijo del hook `repo` que se cayó.

## Reproducción
`.claude/settings.json` ANTES (commit de axon `3764694e`):
```json
"Stop": [ { "hooks": [
  { "type": "command", "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/dod-verificar.sh\"", ... },
  { "type": "command", "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/recordar-cosechar.sh\"" } ] } ]
```
DESPUÉS de `--limpiar-personal --apply`: la clave `hooks` desapareció entera del `settings.json` (−30 líneas), incluida la
entrada de `dod-verificar`.

## Hipótesis [sin verificar en el código]
`dewire_hook` borra el objeto de matcher (o la clave del evento) que CONTIENE al hook retirado, en vez de quitar solo
el comando de ese hook del arreglo `hooks[]` y dejar los hermanos.

## Contrato que debería cumplir
Retirar un hook toca SOLO su comando; los hermanos de la misma entrada y de otros tiers siguen cableados. Prueba
sugerida para `test-brain.sh`: un `settings.json` con `dod-verificar` + `recordar-cosechar` en la misma entrada `Stop`
→ tras `--limpiar-personal --apply`, `dod-verificar` sigue cableado y `recordar-cosechar` no. Debe salir rojo contra
el código de #470.

## Estado en axon
Recableado a mano con `sincronizar-cerebro.sh --only dod-verificar --apply` (se perdió solo el `statusMessage`
cosmético). Nada pendiente del lado de axon.

## Aparte: 3 FAIL de `test-brain.sh` que ya estaban en develop (`5b00708`), medidos en la cachy
- `PATH-augment (#78)`: glab en `ACG_EXTRA_BIN` no resuelve el destino (got `''`). Sin diagnóstico.
- `juez-comun (a·#2)` y `(a3·#2)`: el estado sale bien pero con **3** curls en vez de 2. Hipótesis [INFER, sin verificar]: el test hace `unset CLAUDE_CONFIG_DIR`, así que en Linux `fromFile()` lee el `~/.claude/.credentials.json` REAL y suma un canal más. El test no aísla la credencial real; en una Mac sin ese archivo pasaría.
