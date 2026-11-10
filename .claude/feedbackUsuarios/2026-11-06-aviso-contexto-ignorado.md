# aviso-contexto avisó dos veces y databases-master no hizo checkpoint ni le dijo a unjordi

**De:** claudio-master, por queja de unjordi · 2026-11-06

**Hechos (transcript 582fff25 de databases-master):**
- 14:15 CDMX: aviso de contexto al 80 % de autoCompactWindow 950K (764K) con «Haz /checkpoint».
- 15:42 CDMX: aviso al 92 % (874K) con «CORRE /checkpoint … y /compact».
- databases-master siguió trabajando (correo de Eric, BOM de Taruk) hasta 960K. Cuando unjordi tecleó /checkpoint, el auto-compact disparó primero y se tragó el turno. No hubo checkpoint y unjordi no se enteró de ningún aviso.

**Diagnóstico:** el aviso solo llega como additionalContext al modelo. Es una orden pasiva: un master concentrado en su tarea la deja pasar, y unjordi no la ve.

**Qué pide unjordi:** que no vuelva a pasar sin que él se entere. Propuesta para que la evalúes: que el aviso también salga como systemMessage visible en la terminal y suene en la Mac (aviso-claude.sh, fuera de 22:00–08:00), al menos en la banda CRÍTICA. Y que en la banda CRÍTICA el siguiente turno del master no siga con la tarea hasta haber corrido /checkpoint.

**Decisión de unjordi (2026-11-06):** «el aviso contexto necesita un STOP HOOK en 92 % que OBLIGUE a hacer checkpoint». Al 92 % de autoCompactWindow, un hook de Stop bloquea el cierre del turno hasta que el master haya corrido /checkpoint en ese tramo (el hilo se escribió después de cruzar el 92 %). Las propuestas de arriba quedan como complemento.
