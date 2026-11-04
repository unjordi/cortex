# Feedback: `aviso-contexto` REGRESÓ a hardcodear la ventana en 200K → falso positivo al 56% real

**Fecha:** 2026-09-28 · **De dónde salió:** sesión del proyecto `heimdall-net` (QA UI en vivo, Opus 4.8, ventana de 1M).
**A quién le toca:** cortex-master (hook `aviso-contexto` — cálculo del % de contexto).

## Síntoma (incidente real, medido)
El hook imprimió, en PostToolUse, dos veces:

1. `📊 Contexto ~80% de tu ventana 200K (161K) — cerca del compact … Haz /checkpoint … considera /compact`
2. `🚨 Contexto ~92% de tu ventana 200K (184K) — RAYANDO el compact … CORRE /checkpoint … /compact YA`

La sesión corría en **Opus 4.8 con ventana de 1M**. `/context` al momento del "92%" reportaba **56% (560k/1m)** con ~407k libres. Los `161K/184K` reales son **~16-18%** de la ventana, no 80/92%.

## Efecto
Actué sobre la alarma: presioné al usuario con `/checkpoint` + `/compact` sin necesidad, y caí en "anunciar-y-parar" (decir 'hago checkpoint' y no hacerlo). El usuario lo cazó: *"56%!? por qué andas presionando por compact?!"* y luego *"es en serio que aviso-contexto REGRESÓ a un error tan trivial?!"* (regresión — ya se le había dado feedback antes, ver `2026-09-24-aviso-contexto-estado-sin-regla-de-ignore.md`).

## Mecanismo REAL
El hook asume la ventana en **200K hardcodeado** y calcula `% = tokens_usados / 200000`. En modelos con ventana mayor (Opus 4.8 = **1M**) eso sobre-estima el % por ~5×, disparando urgencia de compact temprano (aquí al 16-18% real).

## SEGUNDO defecto: el NUMERADOR tampoco mide bien
No es solo el denominador (200K). El hook reportó **161K/184K usados**, pero `/context` en la misma sesión mostró **560K reales (56%)** — y la categoría dominante era **`claude-in-chrome__computer` con 522K (52%)**, es decir los **screenshots**. Aun descontando que el hook disparó un poco antes, 161-184K es inconsistente con cientos de K ya consumidos por imágenes. **El numerador NO está pesando las imágenes / tool-results** (parece contar solo texto del transcript, o un subconjunto) → subestima el uso real por ~3×. [probable, por la brecha medida; no inspeccioné el hook a pedido del usuario.]

O sea el hook falla en LOS DOS lados de la fracción: denominador fijo en 200K y numerador que ignora el peso de imágenes.

## Fix propuesto
1. **Denominador:** derivar la ventana del **modelo activo** (o del `total tokens` que ya expone `/context`), NO asumir 200K. Opus 4.8 = 1M.
2. **Numerador:** contar el uso REAL incluyendo imágenes/tool-results (idealmente reusar la MISMA fuente que `/context`, que sí los cuenta: 560K/522K de screenshots), no solo el texto.
Con ambos corregidos, el % es fiable; los umbrales (80/92%) recién ahí significan algo.

## Nota
Registrado también en `docs/guards-falsos-positivos.md` (2026-09-28). El `/checkpoint` que hice igual sirve como higiene; lo indebido fue la URGENCIA inventada.
