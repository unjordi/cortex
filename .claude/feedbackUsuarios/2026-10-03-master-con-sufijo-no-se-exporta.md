# exportar-sesion-master: un master que sigue en un id nuevo ("claudio-master (2)") deja de exportarse EN SILENCIO

**Fecha:** 2026-10-03 · **Origen:** sesión claudio-master en plantilladotnet (limpiando `claude-sessions`) · **Reporta:** unjordi ("llevas meses con ese nombre y no te cachó. ponle un feedback al cortex").

## Qué pasó (medido)
- claudio-master vivía en `fc94c4e1` (último registro 2026-09-30 13:03 local).
- La conversación continuó en un id NUEVO, `2cc11a7f`, cuyo primer registro es 2026-09-30 13:03 (el mismo minuto). Desde su 2ª línea el transcript trae `"customTitle":"claudio-master (2)"` (1,086 veces; ningún otro título).
- `brain/hooks/exportar-sesion-master.sh` solo reconoce un master nuevo con `case "$t" in *-master)`; "claudio-master (2)" no termina en `-master` → `is_master=0` → `exit 0` silencioso.
- `masters.json` seguía apuntando a `fc94c4e1` (congelada) y su `.jsonl.gz` en el Drive parecía "el claudio-master vigente".
- Resultado: del 2026-09-30 al 2026-10-03 la sesión master más activa (71 MB de transcript) NO tuvo ninguna copia en la carpeta de sesiones, y nada avisó. Se notó solo por una auditoría manual de `claude-sessions`.
- Workaround aplicado: alta manual de `{id: 2cc11a7f…, name: "claudio-master", target: "code/plantilladotnet"}` en `masters.json` (bajo `masters.json.lock`) → el fast-path por id lo exporta.

## Tres huecos
1. **Reconocimiento por título demasiado estricto.** El CLI agrega ` (N)` cuando el nombre ya existe (continuación/fork del mismo master). El patrón debería aceptar `*-master` seguido opcionalmente de ` (N)`, y registrar el `name` SIN el sufijo.
2. **El linaje no se sigue.** Cuando un master continúa en un id nuevo, `masters.json` se queda con el id viejo (muerto) como "vigente". Debería detectarse la sucesión (mismo name base + mismo target, id nuevo con actividad posterior) y reemplazar o marcar el viejo.
3. **Falla silenciosa sin vigilancia.** El contrato es fail-open y silencioso (correcto para el hook), pero falta un vigía: algo (SessionStart, el widget, `/to-do`) que diga "esta sesión se llama *-master… y NO está en masters.json / su export tiene >24 h de atraso".

## Propuesta (cada fix con su test)
- Test positivo: título `claudio-master (2)` → se exporta y se registra como `claudio-master`.
- Test negativo: título `mi-master-plan.md` / `master` a secas → no se exporta.
- Test de linaje: id nuevo con el mismo name base y target → `masters.json` termina con el id nuevo, no con ambos ni con el viejo.
- Test del vigía: sesión titulada `*-master` ausente del registro → aviso visible.
