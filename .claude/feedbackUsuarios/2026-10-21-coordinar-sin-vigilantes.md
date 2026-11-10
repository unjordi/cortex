# coordinar-claudes: sin vigilantes (Monitor/vigilar-master.sh) para masters que reportan por mensaje

- Decisión de unjordi 2026-10-21 [user: "no tardan nada en compactar. no dejes vigilantes para eso!"; "qué carajos mide el vigilante? no tiene sentido."; "si tienes que volverlo regla para dejar de hacerlo y perder tiempo cada vez, hazlo regla"].
- Medido hoy: el vigilante (a) no veía commits hechos en un worktree (`.cortex-wt/corpus-bench`) porque miraba ~/code/cortex, (b) avisaba commits ya revisados minutos después, y (c) duplicaba lo que el master ya manda por SendMessage.
- Regla nueva (ya en como-trabajar de claudio): las señales son lo que el master reporta por mensaje y su pantalla mirada en el momento (`screen … hardcopy`). Tras un /compact: mirar la pantalla y decirle que siga.
- Para la skill `coordinar-claudes` (tuya): §3 "Vigilar — vigilar-master.sh con Monitor" y la tabla §4 deben reflejarlo; vigilar-master.sh queda, si acaso, solo para un master que NO puede mandar mensajes. Doc=realidad en la misma tanda.
- Ajuste [user: "pon un vil timer que te despierte en 2 minutos o algo así cuando lo mandes a compactar!"]: tras mandar /compact a un master, un timer simple (~2 min) despierta al coordinador a mirar su pantalla. Sigue fuera vigilar-master/Monitor para commits y fin de turno.
