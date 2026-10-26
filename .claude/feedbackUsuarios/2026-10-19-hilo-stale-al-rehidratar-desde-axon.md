> Reenviado por axon-master (2026-10-19): el punto 1 (hilo-mental viejo al rehidratar) es del hook `rehidratar-hilo` / norma de checkpoint del cerebro, no del harness axon (en /v1 axon no fija el hilo: el modelo lo leyó por su cuenta). Los puntos 2 y 3 los atiende axon (ROADMAP #26h-13, #26h-14).

# 2026-10-19 · El hilo-mental fijado puede estar viejo · el resumen de compactación trae rutas de otra máquina y un bloque condensado vacío

**Reportado por:** Claude (sesión cps, Linux `/home/unjordi/code/cps`), por encargo de unjordi ("todos los feedbacks para el axon-master van a su buzón").

## 1. Rehidratar del `hilo-mental-actual.md` sin comprobar si sigue vigente

**Qué pasó:** al retomar tras el compact, rehidraté desde `.claude/memory/hilo-mental-actual.md`. Su fecha era **2026-08-06**, pero la memoria del repo tenía trabajo posterior:
- `dev-flujo-de-trabajo-cps.md` dice "Renombrado… 2026-08-17".
- `bitacora.md` registra la reconciliación de `:450`/`:451` después de esa fecha.

Con la fecha de hoy (2026-10-19), el hilo ya no reflejaba el estado real. Además, del hilo saqué como pendiente propio "decidir qué hacer con `gen_recarga`" (opciones A/B/C). El hilo marcaba eso como contexto archivado. El pendiente real era avanzar el pipeline 📁 fuente → 🧪 LAB → 🔎 pre-prod → 🚀 prod con unjordi presente.

**Por qué importa:** el hilo se sobrescribe solo cuando alguien corre `checkpoint`. Si entre dos checkpoints hubo sesiones que solo escribieron en `bitacora.md` / `estado-proyecto.md`, el hilo queda viejo y nada lo marca. El modelo lo toma como "lo que hago AHORA".

**Esperado (propuesta mecánica, la puede hacer el harness):**
- Al rehidratar, fijar siempre la sección ⭐ de `estado-proyecto.md` y las últimas N líneas de `bitacora.md`. La bitácora es append-only, así que su antigüedad no la hace mentir. No fijar solo el hilo.
- Comparar la fecha del hilo con la fecha de la última línea de `bitacora.md`, y la mtime de `estado-proyecto.md`. Si el hilo es más viejo, inyectar un aviso explícito: `⚠️ HILO STALE (hilo AAAA-MM-DD < bitácora AAAA-MM-DD): manda estado-proyecto.md ⭐`.

## 2. El resumen de compactación cita rutas de OTRA máquina

**Qué pasó:** el resumen post-compact cita rutas `/Users/unjordi/code/cps/...` (Mac) y un transcript en `/Users/unjordi/.claude/projects/-Users-unjordi-code-cps/...jsonl`. Esta sesión corre en Linux, en `/home/unjordi/code/cps`. Si el modelo intentara leer el transcript o los archivos con esas rutas, fallaría o leería otra cosa.

**Esperado:** que el resumen que se reinyecta se re-ancle al cwd de la sesión actual. Si no se puede, que avise que viene de otra máquina, para que el modelo traduzca las rutas en vez de asumirlas.

## 3. El bloque `[resumen]` condensado llega vacío o con el comando como objetivo

**Qué pasó:** además del resumen largo, llegó un bloque `== RESUMEN DE CONTEXTO (condensado) ==` con `OBJETIVO: <command-name>/compact</command-name>…` (el marcado del comando local, no el objetivo real), `TAREAS: (sin tareas)` y `ESTADO: (sin resumen)` en código/tests/git.

**Esperado:** que el condensador ignore los mensajes `<local-command-caveat>` / `<command-name>` al extraer el objetivo, y tome el último pedido real del usuario. Si no hay nada que condensar, que omita el bloque en vez de mandarlo vacío.
