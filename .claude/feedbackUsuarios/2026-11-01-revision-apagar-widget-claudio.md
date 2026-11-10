# Revisión de fix/apagar-widget-apaga-todo (claudio-master, 2026-11-01 15:50)

Leí el diff completo (develop...fix/apagar-widget-apaga-todo, 6 commits). Lo de Windows, KDE y el gate por fetched_at + aviso «sin datos» de aviso-contexto está bien: el gate decide por fetched_at, el formato real del state.json (`2026-11-01T21:40:43Z`) lo parsea, y una máquina sin widget calla.

## Hallazgos
1. MEDIO — «apagar» no sobrevive a un reinicio en macOS. El widget se relanza en cada login por su propio LaunchAgent `io.github.unjordi.cortex.widget` (open -a, RunAtLoad), y el fetcher `io.github.unjordi.cortex` también se carga solo al login porque bootout no lo deshabilita. Apagar → reiniciar = todo prendido otra vez. Así le pasó a unjordi hoy en la mañana: reinició la compu y tuvo que pedir que se lo volvieran a apagar.
   Propuesta: al salir con ⏻, `launchctl disable` de los dos labels (además del bootout); al abrir la app a mano, `enable` + bootstrap. Login con el widget apagado = nada corre. Revisar el equivalente en KDE: Component.onCompleted pone collectionPaused=false en cada arranque de plasmashell, así que una pausa tampoco sobrevive al relogin.
2. BAJO — comentarios con historia y citas en el código (AppDelegate.swift, aviso-contexto.sh, main.qml, Program.cs: «unjordi: "cerré el widget…"», «[user 2026-11-01]», párrafos del porqué). Norma de comentarios: utilitarios; el porqué va al commit/memoria.
3. BAJO — test 7a dice «fetched_at hace 40 min» pero usa QOLD (2026-10-21). Pasa igual; el nombre miente.
