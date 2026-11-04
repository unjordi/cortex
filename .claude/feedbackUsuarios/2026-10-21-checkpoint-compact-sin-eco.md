# checkpoint: el texto sugerido para /compact no debe ser un eco del hilo (claudio-master, 2026-10-21)

Pedido de unjordi [user: "el texto sugerido para compact es demasiado verbose Y redundante con el hilo, plz enfila en sus pendientes una sugerencia de modificación ... para que ese texto no redunde y sea útil para el compact en vez de un eco del checkpoint"].

## Caso real (otra sesión, RP6)
El checkpoint entregó un `/compact` de ~10 líneas que repite lo que el hilo ya trae: la regla de Jordi, la separación medido/emulado/inferido, los hechos del día (OTA, ramoops.ko, Tiny Tina, espacio libre) y el siguiente paso. El hilo se rehidrata solo tras el compact (rehidratar-hilo); repetirlo en el /compact solo engorda el resumen y no agrega nada.

## Sugerencia (para la skill checkpoint, paso que arma el borrador del /compact)
El texto del /compact lleva SOLO lo que el hilo no puede cargar, en ≤3 líneas:
1. Una línea fija: "El hilo está en <ruta>; léelo COMPLETO al retomar." (nada de "preserva el hilo tal cual": el compact no lo toca, el hook lo reinyecta).
2. El ESTADO VIVO EXTERNO de este instante que el hilo no registra o que cambia en minutos: procesos colgados, un equipo a medio paso, algo que hay que deshacer al volver (p. ej. "la RP6 está en el menú del ABL por USB-C con un `fastboot getvar all` colgado; sal con `fastboot reboot`").
3. Lo que NO se debe hacer al retomar, solo si no está ya en el hilo.
Prohibido en el texto: repetir hechos, decisiones, reglas o el plan que ya viven en el hilo; citas textuales del usuario (unjordi no las pidió); "conserva literal X" de algo que el hilo ya conserva.
Regla de corte: si cada línea candidata ya está en el hilo, el /compact va sin argumentos o solo con la línea 1.

Ejemplo, el caso de arriba reescrito:
/compact El hilo está en .claude/memory/hilo-mental-actual.md; léelo completo al retomar. Estado vivo: la RP6 está en el menú del ABL por USB-C con un `fastboot getvar all` colgado; sal con `fastboot reboot` desde la Mac.

Relacionado (pendiente previo): que el "siguiente paso" del hilo no diga "hacer compact".

## Y además: que lo escrito QUEPA en la rehidratación (pregunta de unjordi)
[user: "el skill REVISA que lo que se escribe QUEPA en la rehidratación del postcompact? o deja que todo se trunque?"]
Medido 2026-10-21 en claudio-master: NO lo revisa. La skill lo recomienda ("ESBELTO", §SIGUIENTE de 2-5 líneas, overflow a ~200 líneas marcado [SIN CONFIRMAR]), pero `verificar_hilo` (contrato-hilo.sh) solo valida el pie: un hilo de 12,2 KB pasa con rc=0 aunque el hook lo reinyectó como 14-15 KB y el harness lo cortó a 2 KB de preview. El §SIGUIENTE de ese hilo mide 2471 bytes (un párrafo, no 2-5 líneas) y nada lo detectó; en el preview, el faro del hook ocupa 535 bytes antes de él.
Mecanismo propuesto (que el contrato FALLE, no solo recomiende):
1. `verificar_hilo` mide el §SIGUIENTE en bytes y falla si no cabe en el preview junto con el faro (presupuesto = 2048 − bytes del faro, con margen; hoy ≈ 535 B de faro → §SIGUIENTE ≤ ~1 200 B).
2. Mide el hilo completo: si la salida que el hook va a emitir supera el límite del preview, avisa que se va a truncar y que lo que no esté en §SIGUIENTE solo se verá con Read (el diseño reconstruir-contexto post-compact ya da la orden de leerlo).
3. Reemplaza el "~200 líneas [SIN CONFIRMAR]" por el límite medido en BYTES del preview del harness.
4. Tests en las dos direcciones: un §SIGUIENTE de 3 líneas pasa; uno de 2 KB falla.
