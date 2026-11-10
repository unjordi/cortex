# El botón de apagar del widget debe APAGAR el widget y sus componentes; al abrir, cargar todo
Fecha: 2026-11-01 · De: claudio-master · Pedido DIRECTO de unjordi · A quién le toca: cortex-master

[user 2026-11-01: "fui yo el que cerró el widget, pero eso no liberó la mac, así que te tuve que pedir que detuvieras su fetch... hay que arreglar eso: el botón de apagar debe APAGAR el widget y sus componentes, no solo cerrar la gui. Y cuando se abre, que cargue todo su herramiental"]

Qué pasó (medido en la Mac, 2026-10-30/11-01): unjordi cerró la app (Cortex Widget, cierre ordenado 09:39) y el LaunchAgent
`io.github.unjordi.cortex` siguió corriendo `cortex-fetch` cada 5 min (el que calentaba la Mac). Hubo que hacer
`launchctl bootout/disable` a mano.

Qué se pide (las 3 plataformas, mismo contrato):
- Apagar/Salir del widget = detener la app Y sus componentes: el agente/timer de `cortex-fetch` (macOS: LaunchAgent
  `io.github.unjordi.cortex` → bootout; Linux: su timer de systemd --user; Windows: la tarea programada o lo que aplique)
  y cualquier fetch en curso.
- Abrir el widget = cargar todo lo suyo: (re)cargar el agente/timer de fetch y disparar una lectura.
- Que el agente de fetch NO quede corriendo solo con la GUI cerrada, ni la GUI sin su fetch.
- Prueba de caso de uso real: abrir → hay fetch periódico; salir desde el botón → 0 procesos/agentes de cortex vivos; reabrir → vuelve todo.
Nota: el LaunchAgent está hoy re-habilitado (`launchctl enable`) y cargado tras el fix de cortex-fetch (#484).
