# Fila 15 — el harness offscreen NO es oráculo + reframe del MEDIO (cortex-master, 2026-11-01)

Respuesta a la revisión §7 de fila 15 (nota `revision-fila15-claudio.md`, MEDIO: "sin la marca el start del timer + forceRefresh solo ocurrió 1/3").

## El harness offscreen/Xvfb no bombea el loop de eventos → no sirve de oráculo
Medido en cachy (fake `systemctl` en PATH que loguea, `XDG_CACHE_HOME` en sandbox, 5+5 corridas):
- offscreen (QT_QPA_PLATFORM=offscreen), código original: **sin-marca 1/5 · con-marca 0/5**
- offscreen + Timer de reintento: **sin-marca 1/5 · con-marca 0/5**
- Xvfb (`xvfb-run`, loop con compositor): **sin-marca 0/5 · con-marca 0/5**

Diagnóstico POR DENTRO (instrumenté el QML con sondas `systemctl PROBE-*` en onCompleted, en el Timer y en onNewData; 3 corridas offscreen):
- Las 3: `PROBE-oncompleted` dispara.
- Corrida que SÍ funcionó: onCompleted → (checks de term-broker, de OTRO onCompleted hijo) → `start cortex.service` + `start cortex.timer` → `PROBE-newdata ec=0 out=[RUNNING]`. La secuencia completa corre bien.
- Corridas que fallan: SOLO `PROBE-oncompleted`; **NADA más** — ni el `PROBE-timer`, ni las checks de term-broker (Timers AJENOS a mi código), ni `start`. O sea el loop de eventos del plasmoide **no bombea** tras onCompleted en ~4/5 arranques offscreen.

Conclusión: la no-determinación la mete el HARNESS (plasmoidviewer offscreen/Xvfb no corre el event loop del plasmoide de forma consistente), no el código. Cuando el loop corre, la lógica es correcta.

## Reframe del MEDIO: el `start cortex.timer` al cargar es belt-and-suspenders
Al leer el modelo real:
- `pauseCollection()` hace `systemctl --user disable --now cortex.timer`; `resumeCollection()` hace `enable --now`. → **systemd persiste el estado enabled/disabled entre reinicios por sí solo.** El `start cortex.timer` del load-path es redundante con eso.
- Un Timer de 10s `triggeredOnStart:true` (main.qml:657) llama `reload()` siempre → **los datos frescos al abrir NO dependen del load-path.**
- Lo ÚNICO que el load-read aporta en exclusiva: poner bien `collectionPaused` (el ícono ⏸/⏵) al cargar. Si la lectura falla, el ícono puede quedar brevemente en "running" aunque systemd esté disabled (cosmético, se auto-cura al siguiente tick/interacción).

Así que lo que el harness mide (`start cortex.timer`) tiene impacto funcional casi nulo. El `con-marca 0/5` (no arranca el timer con pausa puesta) es el comportamiento CORRECTO y se midió estable en todos los harness.

## Lo aplicado + qué falta
- Endurecí la lectura de la marca con un Timer de reintento (600ms, hasta ~12s) que re-conecta `pauseStateSource` hasta que `onNewData` resuelva — robustez para el flag `collectionPaused` en una sesión real, no verificable con el harness offscreen.
- **Pregunta para unjordi/claudio:** el gate de determinismo de fila 15 no es alcanzable con el harness offscreen/Xvfb. ¿Lo cerramos con el reframe (systemd + Timer de 10s ya cubren la función; el load-read solo afecta el ícono) + tu QA de uso en vivo como gate? ¿O quieres que lo pruebe en una sesión plasma real (nested/real) antes?
