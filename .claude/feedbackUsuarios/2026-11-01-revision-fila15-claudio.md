# Revisión §7 de la fila 15 (claudio-master, 2026-11-01 ~17:35) — fix/apagar-widget-apaga-todo a79c7d2

## ALTO — el plasmoide de KDE no carga
main.qml queda con DOS `Component.onCompleted` en el MISMO objeto raíz (PlasmoidItem): uno nuevo en la línea ~169 (lee la marca de apagado) y el que ya agregó 3966389 en la ~671 (`systemctl --user start cortex.timer` + `collectionPaused = false` + forceRefresh). Medido en la cachy con qml6 6.12: un QtObject con un solo `Component.onCompleted` carga; con dos, «Did not load any objects» y rc=2. qmllint no lo marca, así que «qmllint sin errores nuevos» no lo prueba. Aunque cargara, el de la 671 arranca el timer y pone la pausa en false en cada arranque: deshace justo la pausa que la fila quiere preservar.
Arreglo: un solo onCompleted que lea la marca y, solo si NO está, haga start del timer y forceRefresh. Prueba que carga de verdad (qml6 con el archivo real, o plasmoidviewer en la cachy) y las dos direcciones: con la marca queda en pausa y sin timer; sin la marca, timer activo y lectura.

## MEDIO — en Windows «apagar» no sobrevive el reinicio
La fila nace de que apagar y reiniciar vuelva a prender todo. En Windows ⏻ sale, pero la clave Run lo relanza en el próximo login: es el mismo síntoma que se arregló en macOS. «Es preferencia del usuario» no aplica: el usuario la expresó al apagar. ⏻ debe quitar la clave Run (o desactivar el autostart) y abrir la app a mano debe restaurarla. La marca de apagado también sirve ahí, si algún hook la lee en Windows.

## BAJO — las dos ramas del lote chocan
retiro-cerebro-por-repo + apagar-widget-apaga-todo dan conflicto en brain/hooks/aviso-contexto.sh (la línea del `if ! _snap_fresca`: una agrega `&& ! _widget_apagado`, la otra cambia el comentario a $STATE). Lo resolví en una copia local para probar; en la integración real tiene que resolverse en una de las ramas (merge de la otra), con la suite corrida sobre el resultado.

## ✅ verificado en vivo (copia integrada, HOME/config en sandbox)
aviso-contexto: sin marca, viejo → lanza el fetch; sin marca, corrió hace 10 min sin datos → avisa «sin datos» y no lanza; con marca, en los dos casos → no lanza y calla. macOS: ⏻ es el único camino de salida en la UI (apagarYSalir); el logout no deshabilita. No apagué el widget real de unjordi para probar el disable: queda para su QA de uso.

## QA tras 5452b10 (claudio-master, ~18:30, cachy, plasmoidviewer offscreen, XDG_CACHE_HOME en sandbox, `systemctl` falso en PATH que registra las llamadas)
- Carga sin errores QML, con y sin la marca. ✅
- Con la marca: no llama `systemctl --user start cortex.timer`. ✅
- MEDIO — sin la marca, el arranque NO es determinista: en 3 corridas de 20 s, solo 1 llamó `start cortex.timer` (y por tanto forceRefresh); las otras 2 no lo llamaron. Con una sonda (un `systemctl PROBE` antes del `test -f` y otra en onNewData) sí disparó: onCompleted → onNewData «RUNNING» → start. Así que la lógica está bien, pero el onNewData de pauseStateSource no siempre llega (o llega antes/sin stdout). Hay que encontrar la causa raíz (¿un primer newData sin stdout que hace el disconnect antes de la salida? ¿el executable engine coalescea?) y medirlo con N corridas, no con una. El efecto en uso: al abrir sin pausa a veces no hay lectura inmediata y el timer no se re-asegura (si estaba enabled, systemd lo arranca igual al login, así que el daño es menor, pero «abrir carga todo su herramiental» no se cumple siempre).
Reproducir: `systemctl` falso que hace `echo "$*" >> log`, `PATH=<dir>:$PATH XDG_CACHE_HOME=<tmp sin marca> QT_QPA_PLATFORM=offscreen timeout 20 plasmoidviewer -a <src/plasmoid>`, contar `start cortex.timer` en el log en 5 corridas.
La fila 15 no está ✅.

## Re-medición en la sesión Plasma REAL de la cachy (claudio-master, ~19:20) — 6677ed6
plasmoidviewer en Wayland real (WAYLAND_DISPLAY=wayland-1, QT_QPA_PLATFORM=wayland), systemctl falso con hora, sin marca, 5 corridas con tope de 30 s: 5/5 llamaron `start cortex.timer`, a los 11.3 / 6.8 / 5.9 / 7.6 / 1.8 s de abrir. Con la marca: 0 llamadas. Lo que yo vi como «intermitente» era el arranque lento (hasta 11 s) cortado por mi tope de 15-20 s, sumado al harness offscreen que no bombea el loop (lo de tu nota). Retiro el MEDIO: fila 15 ✅. Queda el QA de uso de unjordi (pausar, reiniciar plasmashell, que siga en pausa).
