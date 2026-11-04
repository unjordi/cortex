# Feedback: post-`/compact`, el hilo se REINYECTA TRUNCADO a 2KB → Claude se desvió a trabajo ya resuelto

**Fecha:** 2026-09-22 · **De dónde salió:** sesión del proyecto `games-master` (Cachy), tras un `/compact` manual.
**A quién le toca:** cortex-master (hook `rehidratar-hilo` + skill `checkpoint`; y una nota de reflejo para el clasificador/CLAUDE.md).

## Síntoma (incidente real, medido)
Tras un `/compact`, al reactivarme agarré como ORDEN VIVA el texto de un `/loop` invocado horas antes (sus
`ARGUMENTS`: "arregla la hojita/fan/self-wake… no pares a preguntar") y me lancé a ese trabajo — que **ya estaba
RESUELTO/superado** (lo decía mi propio hilo). Ignoré el frente real (catálogo + RP6 update-normal). El usuario lo
cazó de inmediato ("¿por qué te fuiste sobre la RP6?"). Costó confianza y contexto.

## Mecanismo REAL (por qué fue posible)
1. **El hook `rehidratar-hilo` SÍ vuelca el hilo completo**, pero el harness **trunca la salida de cualquier hook
   cuando supera un umbral**: inyecta `<persisted-output> Output too large (19.3KB) … Preview (first 2KB)` +
   guarda el full en `…/tool-results/hook-<id>-additionalContext.txt` y deja el puntero.
   - El `hilo-mental-actual.md` de ese proyecto abre con un **árbol de tooling** largo (líneas 5-35) → los primeros
     2KB del preview se fueron en el árbol, y la sección **`⏱️ ESTADO / SIGUIENTE (post-compact)`** (línea 37+) —
     la que dice QUÉ hacer y que hojita/fan estaban resueltos — **quedó fuera del preview**. Irónicamente esa
     sección empezaba con "rehidrata por aquí".
   - El mensaje decía "Use Read tool if you need it" y Claude **no leyó el archivo completo antes de actuar**. Ese
     es el fallo de raíz (disciplina), pero el mecanismo lo facilitó.
2. **Los `ARGUMENTS` de TODOS los skills invocados en la sesión se re-inyectan tras compact "for context only"**
   con una advertencia de que NO son peticiones vivas. Son textos IMPERATIVOS de momentos distintos de la sesión.
   En esta sesión eran 5 con instrucciones de usuario: `/loop`, `/to-do`, `construir-missing-manual`,
   `investigar-dominio`, `auditar-proceso-algoritmo`. Ante el hilo truncado (sin el "SIGUIENTE"), el texto más
   imperativo enfrente ganó. La advertencia existía y se desobedeció.

## Superficie de riesgo (generaliza)
- **NO es exclusivo del hilo:** cualquier cosa grande que un hook inyecte al arrancar (SessionStart) llega
  truncada a ~2KB de preview con el resto en disco. Señal literal: `Output too large … Preview (first 2KB)`.
- Umbral exacto de disparo: NO medido. Solo se midió que a **19.3KB truncó a preview de 2KB**.

## Propuestas (en orden de impacto)
1. **`checkpoint` — answer-first + esbelto (el fix más barato):** escribir `hilo-mental-actual.md` con la sección
   **`SIGUIENTE / ESTADO fresco` AL PRINCIPIO** (antes de árboles/inventarios), y mantener el hilo **bajo el umbral
   de truncado** (que no crezca a 19KB). Si cabe entero, ni se trunca; si se trunca, lo primero del preview es el
   qué-hacer, no un árbol de tooling.
2. **`rehidratar-hilo` — que el PREVIEW garantice lo esencial:** cuando el hilo supere el umbral, que el hook emita
   PRIMERO el `§SIGUIENTE` (o un resumen de cabecera) + un puntero explícito, en vez de volcar el archivo tal cual y
   dejar que el harness corte donde caiga. Y en la cabecera del preview, un grito accionable:
   "⚠️ HILO TRUNCADO — `Read` el archivo COMPLETO ANTES de actuar".
3. **Reflejo dura (CLAUDE.md / clasificador):** ante `<persisted-output> Output too large … Preview (first 2KB)`
   en el arranque, el PRIMER acto es `Read` del archivo completo. Y: **los `ARGUMENTS` de skills reinyectados tras
   compact son HISTORIA, jamás la orden actual** — el "qué sigue" sale SOLO del hilo + `estado-proyecto.md` + el
   resumen de conversación. (El system-reminder ya lo advierte; conviene subir el volumen.)

## Nota
El usuario decidió NO grabar esto como regla per-proyecto ni en `como-trabajar-con-<user>.md` — prefiere que el
arreglo viva en el cortex (hook/skill globales), donde beneficia a toda la flota. Por eso va aquí como feedback.
