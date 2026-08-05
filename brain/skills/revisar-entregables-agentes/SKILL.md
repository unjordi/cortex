---
name: revisar-entregables-agentes
description: Verificar lo que un agente/subagente ENTREGA contra la realidad — nunca relatar su reporte como verdad sin comprobarlo. Úsalo cada vez que un agente reporta (sobre todo antes de decirle al usuario "ya quedó" o de construir encima de su trabajo).
---

# Revisar lo que entregan los agentes (no creerles a ciegas)

> Regla dura: **NO relates el reporte de un agente al usuario como verdad, ni construyas encima, sin
> haber verificado sus afirmaciones concretas contra la realidad tú mismo.** Lo verificado se relata
> como verificado; lo no verificado se etiqueta como "según el agente, sin verificar aún".

## Por qué existe (la lección)
Un reporte de agente es una AFIRMACIÓN, no un hecho. Creerle sin verificar tiene DOS costos:
1. **Errores que se propagan** — el agente confabula, sobre-afirma ("verificado ✓") o se equivoca en
   un detalle, y tú lo relatas al usuario como cierto → el usuario descubre que no era. (Pasó en vivo.)
2. **Nunca mejoras tus prompts** — si solo le crees, no ves *cómo se tropezó*; y es justo en cómo
   tropieza donde está la señal de qué refinar en la manera de invocarlo. Revisar SIEMPRE = terapia
   con datos de más de una corrida, no anécdota.

## El bucle de revisión (por cada agente que reporta)
1. **Extrae las afirmaciones concretas y comprobables** del reporte (números, "escribí X en Y",
   "N items coinciden", "mismo tamaño/CRC", "0 errores", "appids canónicos 78/78", "corre").
2. **Verifica cada una contra la fuente real** — barato tú mismo, sin pedirle QA al usuario:
   - *"Escribí/edité el archivo Z"* → **léelo**. ¿Existe la sección? ¿Se rompió/truncó el resto?
     ¿El contenido dice lo que el agente afirma?
   - *"N coinciden / mismo tamaño / cuenta = K"* → **re-mídelo** con un comando barato (find/stat/
     grep/parse). No aceptes el número; reprodúcelo.
   - *"Cambié estado vivo (vdf/colección/config)"* → **re-lee el estado** y confirma el cambio +
     que no rompió lo de al lado. Verifica el backup existe.
   - *"Corre / funciona / se ve"* → si es afirmación visual/funcional, o lo compruebas por una vía
     programática (proceso, log, exit code), o lo etiquetas como NO verificado (no lo declares LISTO).
3. **Muestrea lo caro.** Si verificar TODO es carísimo (p.ej. 300 items), verifica una muestra
   representativa (primeros/últimos/aleatorios por índice) + los invariantes (conteos, totales) y
   DILO ("verifiqué N de M + los totales"). Nunca finjas cobertura total.
4. **Clasifica el resultado:** CONFIRMADO (lo comprobé) · CORREGIDO (encontré y arreglé un error) ·
   REFUTADO (la afirmación era falsa → no se relata como hecho, se re-trabaja).
5. **Cierra el bucle de prompt.** Anota *cómo tropezó* (dejó "?" por un caso que el prompt no cubría,
   sobre-afirmó, malinterpretó el alcance) y qué refinar en el prompt la próxima vez. Si el mismo
   tropiezo se repite entre agentes → apunta a `~/.claude/memory/` o al estado del proyecto.

## Barato vs caro — heurística
- **Barato (hazlo siempre):** re-contar con un parse, `stat`/`find -printf %s`, `grep -c`, leer el
  archivo que dijo haber escrito, `diff` contra un backup. Segundos.
- **Caro (muestrea + invariantes):** re-ejecutar toda la búsqueda del agente, verificar 300 archivos
  uno por uno. Muestra + totales, y dilo.

## El caso REBUILD/REEMPLAZO: el DIFF DE PRESERVACIÓN (lo que un rebuild SILENCIA)
Cuando el entregable **REEMPLAZA un archivo existente** (un agente reescribe un CLAUDE.md, un README, una
config "desde cero"), el modo de falla NO es una afirmación falsa — es la **OMISIÓN SILENCIOSA**: el
rebuild suelta contenido real y no lo dice (no hay un "✓" que verificar). El bucle de arriba no lo caza
porque el agente no AFIRMA lo que dejó fuera. Antídoto OBLIGATORIO antes de aplicar el reemplazo:
1. **`diff` viejo → nuevo** y enumera TODO lo que el rebuild QUITÓ (secciones, punteros, datos, comandos, advertencias).
2. **Clasifica cada cosa quitada:**
   - **basura temporal/obsoleta botada correctamente** (changelog fechado, estado viejo, duplicación) —
     PERO verifica que su contenido vigente viva YA en su casa durable (estado-proyecto/memoria), no lo asumas.
   - **conocimiento REAL** (un gotcha, una corrección, un puntero, una advertencia destructiva, un dato que
     no se regenera) → NO se pierde: se **preserva/reubica** a su casa durable, o el rebuild se corrige/rechaza.
3. **Punteros del NUEVO:** cada `[[wikilink]]`/"ver memoria X"/"§Y" que el rebuild introduce debe EXISTIR (colgados = mentira nueva).

> **Por qué es paso DURO (caso real 2026-08-02):** un rebuild de agente del `CLAUDE.md` de powerscripts botó
> —bien— un changelog fechado, PERO también soltó la corrección `caddy-proxy`/`~/.ssl` que vivía SOLO en ese
> archivo (las memorias tenían el nombre viejo). Sin el diff de preservación se hubiera perdido la corrección
> y las memorias seguirían mintiendo. unjordi lo cachó porque confié en el rebuild sin correr ESTE paso.

## Qué NO hacer
- ❌ Copiar el reporte del agente al usuario como si fuera tu verificación.
- ❌ Declarar "LISTO/quedó" con base en el "✓" del agente (verde de agente ≠ verificado — mismo
  espíritu que "verde técnico ≠ LISTO").
- ❌ Poner al USUARIO a hacer el QA de tu agente (screenshot/reabrir algo) cuando podías leer el
  archivo y comprobarlo tú en medio segundo. Ese es el anti-patrón que originó este skill.
- ❌ Construir la siguiente fase encima de un entregable sin verificar su base.

## Relación con otras normas
Es la mitad "confía-pero-verifica" del modelo de delegación (la otra mitad, el consentimiento de costo
y el fan-out, vive en las normas globales de orquestación). Complementa la Definición de LISTO:
"verde de agente" es un peldaño, no el cierre.
