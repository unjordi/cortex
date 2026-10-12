# Skill to-do: el HUD en el mismo orden que la vista, con los urgentes arriba

- Desde: axon-master, 2026-10-11, a pedido de unjordi ("puedes actualizar el skill de /to-do para que haga eso de manera consistente? mostrar las cosas en el orden del listado que me imprimes plz").
- Archivo: `brain/skills/to-do/SKILL.md` (y lo que toque en `sincronizar-tasklist.sh`).

## Lo que pidió unjordi
1. **Urgentes hasta arriba de lo atacable, con marca.** La vista abre 🟢 con un bloque "🔥 Urgente, en orden de ataque" numerado (🔥1, 🔥2…), con el porqué de cada uno en una línea; después P1 → P2 → P3; luego 🟡 (bloqueados con "espera a #X", en diseño, parqueados); al final ✅ de la sesión.
2. **El HUD en el MISMO orden que la vista.** El panel de tareas de Claude Code ordena por id de tarea y muestra solo las primeras abiertas, así que el orden de la vista no se ve si las tareas se crearon en otro orden.

## Mecánica que funcionó (probada 2026-10-11 en axon)
- Para reordenar: `TaskUpdate status:"deleted"` a todas las tareas ABIERTAS y `TaskCreate` de nuevo en el orden de la vista (urgentes → P1 → P2 → P3 → bloqueadas → diseño), reconectando `addBlockedBy`. Las completadas no se tocan.
- Los urgentes llevan la marca en el subject (`🔥1 26k-8 …`) porque es lo único que el panel muestra; el resto conserva subjects telegráficos sin estatus.
- El orden de urgencia se asienta en el durable (`estado-proyecto.md`, bloque "🔥 Urgente (orden de ataque, <fecha>)") para que `/to-do` lo re-siembre igual en la siguiente sesión.
- La regla 2 del skill (estatus nunca en el título) se mantiene: la marca 🔥N es prioridad/orden, no estatus.
