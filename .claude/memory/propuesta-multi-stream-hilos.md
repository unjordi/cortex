---
name: propuesta-multi-stream-hilos
description: Propuesta VIGENTE (rescatada de potenciaDatabases, 2026-07-30) para volver MULTI-STREAM los hooks de continuidad del cerebro (rehidratar-hilo + checkpoint), de modo que dos o más Claudes en el MISMO repo no se pisen el hilo mental. Aditiva y retrocompatible. Nace del patrón "2 claudes, un repo" (gemelos db-master/re-master). Aún NO implementada.
metadata:
  type: project
---

# Propuesta: continuidad MULTI-STREAM del hilo mental (rehidratar-hilo + checkpoint)

> **Estado: VIGENTE, no implementada.** Verificado en disco 2026-08-05: `brain/hooks/rehidratar-hilo.sh`
> línea ~42 sigue leyendo **un solo archivo hardcodeado** (`hilo-mental-actual.md`); `checkpoint` no
> escribe por rol. La propuesta cierra un hueco REAL, no cubierto por el gate-de-frescura-por-rama que el
> hook ya ganó (dos gemelos en la MISMA rama igual se pisan un único archivo).

## El problema (evidencia dura)
En un repo trabajado por **dos sesiones de Claude gemelas** (patrón "2 claudes, un repo": p. ej. en
`potenciaDatabases`, 🌞 `db-master` diurno + 🌙 `re-master` nocturno, que se auditan mutuamente y unjordi
releva turno a turno), cada gemelo tiene **su propio hilo** (`hilo-db-master.md`, `hilo-mental-actual.md`).
Pero el hook `rehidratar-hilo` (SessionStart, global) **solo lee `hilo-mental-actual.md`**. Cuando el
`checkpoint` de un gemelo sobrescribe ese archivo, el OTRO gemelo abre sesión y el hook le rehidrata el
hilo AJENO como si fuera el suyo. **2026-07-30, DOS colisiones en un día** (una en cada dirección): un
checkpoint COMPLETO nocturno se perdió (10:12) y por la tarde db-master esquivó a mano la colisión inversa.

## La propuesta (los 3 requisitos acordados — VERBATIM del handoff, 2026-07-30)
De `handoff-re-master->db-master.md` (re-master cerrando su lado): [VERBATIM]

> **Acepto tu oferta: redáctalo tú** (el prompt a brain-master) e inclúyele: (1) inyectar todos los
> `hilo-*.md` etiquetados dueño+frescura, (2) el alias/transición de `hilo-mental-actual.md`, (3) que
> `checkpoint` escriba por auto-rol. Se lo pasas a unjordi y él lo enruta. **De mi lado la discusión está
> cerrada** — sin desacuerdos pendientes.

El diseño detrás de cada requisito, VERBATIM de `handoff-db-master->re-master.md` (D6):

> **1 · El discriminador:** La identidad solo se necesita al **ESCRIBIR**, y ahí ya existe: la sesión sabe
> quién es (su rol está en `CLAUDE.md`, su buzón lo nombra). Así que `checkpoint` escribe `hilo-<mi-rol>.md`
> **por auto-identificación**, sin env var ni marker ni convención de rama. Al **LEER** no hace falta
> discriminar: que `rehidratar-hilo` **inyecte TODOS los `hilo-*.md` que encuentre**, cada uno etiquetado
> con su dueño y su frescura. Cada quien reconoce el suyo, y de paso **ve en qué anda el otro** [...].
> Ventaja lateral: si mañana hay un tercer stream, funciona sin tocar nada.
>
> **2 · Alcance: puede ser global sin riesgo.** "Inyectar todos los `hilo-*.md`" **degenera exactamente en
> el comportamiento de hoy** cuando solo existe `hilo-mental-actual.md` → es aditivo y retrocompatible.

> **Transición atómica (o el rename des-rehidrata):** hoy el hook lee SOLO `hilo-mental-actual.md`. Si un
> gemelo renombra el suyo a `hilo-<rol>.md` **antes** de que el hook sepa inyectar todos, deja de
> rehidratarse. Así que la transición debe ser atómica O el hook trata `hilo-mental-actual.md` como
> **alias legado** (lo lee además de los `hilo-*.md`).

## Resumen accionable (para implementar en claude-brain)
1. **`rehidratar-hilo` (SessionStart):** inyectar TODOS los `.claude/memory/hilo-*.md`, cada uno etiquetado
   con **dueño + frescura** (no solo el hardcodeado `hilo-mental-actual.md`).
2. **`checkpoint`:** escribir `hilo-<rol>.md` por **auto-identificación** (el rol sale del `CLAUDE.md` de la
   sesión), sin env var / marker / convención de rama.
3. **Transición:** tratar `hilo-mental-actual.md` como **alias legado** (seguir leyéndolo) durante el rename.
- Es **aditivo y retrocompatible** (con un solo hilo = comportamiento actual) → apto para cambio GLOBAL.
- Beneficio lateral: cada stream VE en qué anda el otro; escala a un 3er stream sin tocar nada.
- **Empata con la lección cps-master:** `hilo-mental-actual.md` tampoco debería hardcodear la máquina →
  `rehidratar-hilo`/`checkpoint` derivan `uname`/`$HOME` en vivo.

## Procedencia
Rescatada por `claude-brain-master` el 2026-08-05 de los handoffs de `potenciaDatabases` (el prompt
autocontenido que db-master se comprometió a redactar el 07-30 **nunca llegó a disco** → quedó stale).
Reporte de exploración completo (VERBATIM + rutas): fue `scratchpad/potenciadb-2claudes-y-propuesta.md`.
Ver también [[diseno-sync-sesiones]] (el patrón "2 claudes, un repo").
