# Revisión de la ronda hasta f841c41 (claudio-master, 2026-11-01 ~16:40)

Leídos: 6aebf21, 5ca2d86, b84f105 (fixes de los hallazgos 1, 4, 5 y 6: bien, por lista exacta y por estructura), cd2fc8c (fila 4) y f841c41 (regresiones de la suite).

- cd2fc8c fila 4: bien. Sellos bajo ~/.claude/state/<cksum del ROOT>/, con mkdir antes de escribir y fail-open.
  BAJO: los sellos viejos que ya quedaron dentro de los repos (`.claude/memory/.cuota-fetch-forzado`, `.contexto-aviso*`, `.ramas-huerfanas-estado`; plantilladotnet los tiene sin trackear) nadie los retira. Que `--limpiar-repo` también los quite, o que el hook borre el sello viejo de $MEM al escribir el nuevo.
- f841c41: el arreglo de drift-widget, con `arrlit` en vez del rango de sed, está bien. El aserto de paridad T4, `grep -q 'install GLOBAL existe' "$E2EPAR"`, mide la redacción de la salida y no el efecto. El efecto es que un destino sin install global BLOQUEA y uno con install global pasa. Probar las dos direcciones (aprovecha que la (2) ya monta el escenario).

## Revisión semántica §7 de lo entregado (copia integrada: retiro-cerebro-por-repo 3bdbb73 + apagar-widget-apaga-todo, sobre un clon de plantilladotnet)
- Fila 1 en vivo: `--limpiar-repo` PLAN no muta nada; `--apply` quita los 12 hooks del cerebro, su cableado y el sello, CONSERVA un hook propio (`mi-merge-develop-guard.sh`) metido en la MISMA entrada de settings.json, no toca la memoria (md5 igual), barre el sello viejo y deja respaldo. ✅
  MEDIO: 4 skills del cerebro (cerrar-slice, checkpoint, orquestar-fanout, reconstruir-contexto) quedan como «DIFIERE — revísala a mano». Difieren porque son COPIAS VIEJAS del cerebro, no porque el proyecto las haya cambiado. Así sobreviven las copias por-repo que driftean, que es justo lo que la fila retira. Propuesta: si el contenido coincide con ALGUNA versión histórica de brain/skills/<sk> (git log de cortex), es copia del cerebro y se retira; solo se reporta la que no coincide con ninguna.
  BAJO: queda `.claude/hooks/dashboard_cerebro.template.md` (del cerebro, fuera del MANIFEST): ¿se retira también?
- Filas 2 y 4 en vivo (hook aviso-contexto de la copia integrada, HOME y config en sandbox): fetched_at viejo → lanza el fetch; fetched_at hace 10 min sin datos → avisa «sin datos» y NO lanza; misma sesión → calla; otra sesión → avisa una vez; sellos solo en ~/.claude/state/<cksum>/, repo limpio. ✅
  BAJO: el comentario de aviso-contexto.sh:187 dice «throttle de 5min (sello en MEM)»; ya vive en $STATE.
  MEDIO (choque entre filas 2 y 15, §7.3): con el widget APAGADO el fetcher no corre, fetched_at envejece y, a los 30 min, el hook de CUALQUIER sesión de Claude vuelve a lanzar ~/.local/bin/cortex-fetch (cada 5 min por el throttle). «Apagar apaga todo» se rompe por la puerta de atrás. La fila 15 debe dejar una marca determinista de «apagado» (la escribe el widget al salir con ⏻ y la borra al abrir), y aviso-contexto no lanza el fetch con esa marca (ni el aviso «sin datos»: con el widget apagado no hay lectura que esperar). Probar las dos direcciones.
- Fila 10: la skill reproduce la plantilla tal cual + el §4 nuevo. ✅ BAJO: el `description:` trae trazabilidad («merge de arsenal loop-epic-0.1 + axon …»), lo mismo que «Cómo se redacta» pide quitar.
- Fila 3: verificada por código (por estructura) y por la suite; no la corrí en vivo contra un transcript real.
