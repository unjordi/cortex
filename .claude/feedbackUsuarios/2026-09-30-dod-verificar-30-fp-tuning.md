# dod-verificar: 30 falsos positivos en el corpus → toca la pasada de tuning de precisión

**Fecha:** 2026-09-30 · **Origen:** sesión master en plantilladotnet (coordinando el checklist de heimdall) · **Reporta:** unjordi ("ese hook no está stale? … si no, hay que reportarlo en un feedback al cortex").

## Qué pasó
Stop hook bloqueó el cierre de un turno de ESTATUS: "La tarea 03 quedó integrada en DevelopUnjordi (cf8406a) y la verifiqué en el testbed local". Eso es un hecho de git (merge local a la mini-develop — la norma dice que ese cruce no pasa por candado) + verificación técnica en vivo. No declara LISTO.

## No es drift
`plantilladotnet/.claude/hooks/dod-verificar.sh` == `~/.cortex/brain/hooks/dod-verificar.sh` == `cortex/brain/hooks/dod-verificar.sh` (último cambio 3732826, 2026-09-18, PR #440). Es el comportamiento vigente.

## Por qué importa
- `docs/guards-falsos-positivos.md` ya trae **30** FP de dod-verificar (la norma pide proponer tuning a los ~5).
- Cada FP obliga a reescribir el estatus con léxico de "preview/verificado técnicamente" aunque el contenido ya fuera honesto → fricción sin valor y desgaste de confianza en el guard.

## Propuesta (precisión, no aflojar)
- Mirar el OBJETO del verbo de cierre: "quedó integrada en <mini-develop>/<rama>", "quedó commiteado", "quedó en el backlog" son hechos de git/doc, no claims de entregable.
- Distinguir "integrado a la MINI" (sin candado) de "integrado a develop/main".
- Cada fix con su test (caso positivo: "quedó listo" sigue bloqueando; caso negativo: "quedó integrada en DevelopUnjordi" no bloquea).
- Usar el corpus completo de 30 casos como batería de regresión.

## Actualización 2026-10-01 — ROLLBACK local por decisión de unjordi
5 falsos positivos en un día (reportes de resultados MEDIDOS — `rclone check`, `zpool import`, un log con "LISTO" — leídos como cierre de entregable; y un `ls`/`du` leído como QA visual). unjordi: *"puedes instalarte el hook anterior de dod? no aguanto esta regresión"*. Se reinstaló en `plantilladotnet/.claude/hooks/dod-verificar.sh` la versión PREVIA al sync `38d0fe2` (= `38d0fe2^`, 316 líneas, compatible con el `juez-comun.sh` actual), SIN commitear. Ojo: `aviso-drift-cerebro` puede re-sincronizarla al abrir sesión en la mini con `.claude/` limpio. El arreglo durable es aquí en cortex: revertir o afinar el cambio de dod-verificar de `3732826` (PR #440) con este corpus.

## Actualización 2026-10-01 (tarde) — el bloqueo VISUAL (B2) también da falsos positivos, y es ANTERIOR al sync
Con el rollback a `38d0fe2^` ya instalado (md5 `2eafc253…`, verificado contra `git show 38d0fe2^:`), los FP de CIERRE (resultados medidos leídos como "LISTO") desaparecieron — eso sí lo introdujo `3732826`/PR #440. Pero el B2 (QA visual a ciegas) SIGUE disparando en falso, y existe igual en ambas versiones: toma el verbo "ver" sobre SALIDA DE COMANDOS como observación de pantalla. Casos 2026-10-01:
- "se ve la raíz del C: … y el Escritorio de Sabrina" → era `mount`/`ls`/`du` sobre un share SMB montado.
- "el contenedor ve Pelis, Series y unjordi" → era `docker exec … ls /tank`.
Propuesta: B2 solo debería disparar cuando el claim visual es sobre una UI/pantalla/render ("en Chrome", "la página", "el diálogo", "se ve como el mockup", "en pantalla"), no sobre el sujeto de un comando ("el contenedor ve", "smbstatus ve", "ls muestra"). Mismo corpus: `docs/guards-falsos-positivos.md`. Tests: positivo (claim de UI sin tool de navegador → bloquea) y negativo (estos dos → no).
