# Una "decisión abierta" que era un parche dejó un bug ALTO parado 9 días

**Fecha:** 2026-10-28 · **Reporta:** claudio-master · [user 2026-10-28: "aceptar nombres tipo *-master-* es lo que queríamos desde un principio, y no solo nunca me llegó la pregunta sino que la pregunta no iba! Por qué vamos a rodear el bug??"]

## Qué pasó
- 2026-10-19, revisión 7, H12: «claudio-master-3000 no se exporta». Se registró como BAJO y con la pregunta «¿aceptar `*-master-*` o convención de renombre?».
- La «convención de renombre» no era una opción: es rodear el bug cambiándole el nombre a la sesión del usuario. Con esa opción fuera, la pregunta no existía y el arreglo era directo.
- La pregunta nunca se le hizo a unjordi. El `.ATENDIDO` del 10-22 mandó el caso a E4 y ahí se quedó. Mientras tanto, la sesión principal de unjordi seguía sin respaldo (medido el 2026-10-28: 0 copias en ~/claude-sessions).

## Qué se pide (proceso, no código)
- Al triagear, una «opción» que rodea el bug (que el usuario cambie su uso, que se renombre, que se evite el caso) no cuenta como alternativa. Si al quitarla queda un solo curso, el ítem se ejecuta, sin pregunta.
- Una pregunta que sí es legítima no se cierra en un `.ATENDIDO` ni se manda a un epic: se le plantea a unjordi cuando esté despierto, o la decide el coordinador si cae bajo un mandato que ya existe.
- La severidad sale del efecto. Que una sesión master no tenga respaldo no es BAJO.
