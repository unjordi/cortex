# Decisiones de unjordi tras el merge de #470 (2026-10-26)

- Release a main: SIEMPRE pide confirmación (cualquier repo).
- Permiso durable de merge: "el permiso del merge no quiero TENER que escribirlo yo, si te lo pido debería ser suficiente. Por qué queremos más trabas???" → cuando unjordi le pide a Claude dejar el permiso, Claude lo escribe. Revisar proteger-autorizaciones y turno-nocturno §5 (hoy niegan que el agente escriba el grant y le presentan el one-liner `!`). La cita del grant en un mensaje humano real sigue como control.
- seven_day vs weekly: el API de uso trae `seven_day` y el state.json lo guarda como `weekly`; unjordi los ha visto confundirse varias veces. Unificar el nombre al unificar el fetch (siguiente hito).
- unjordi revisará TODO el contenido de #470 con detalle antes del release a main.
