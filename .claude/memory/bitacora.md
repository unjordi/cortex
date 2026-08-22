---
name: bitacora
description: Journal append-only de cortex — una línea por slice cerrado. merge=union → sin conflictos en paralelo.
type: project
---

# Bitácora de cortex (append-only)

> **Una línea por slice cerrado, agregada AL FINAL** (append). Formato:
> `- AAAA-MM-DD · rama/PR · quién · qué quedó cerrado`.
>
> Este archivo usa **`merge=union`** (ver `.claude/.gitattributes`): cuando varias sesiones/agentes
> añaden líneas en ramas paralelas, git conserva las de **todos** sin marcar conflicto. Por eso:
> **NO reordenes ni edites líneas viejas — solo agrega al final.** El resumen curado de lo ABIERTO
> vive en `backlog-desarrollo.md` (gitignored, dev privado); esto es el log cronológico conflict-free
> de lo YA CERRADO (nace 2026-08-07, B4: antes el backlog dobla como journal mezclando "qué pasó" con
> "qué sigue" — las líneas de abajo son la siembra inicial, destiladas de sus ✅ HECHO/CERRADO).

- 2026-07-15 · widget macOS · claude+unjordi · fix #146: auto-update del widget roto por el precompilado — `Updater.resolveClonePath` ahora usa el clon LOCAL de instalación (`$HOME/.cortex`) en vez del `repo` embebido en build-time del runner de GitHub, que no existía en la Mac del usuario (`canSelfUpdate=false`).
- 2026-07-18 · macos/install.sh · claude+unjordi · fix #154: `install.sh` (macOS) ahora reinicia la instancia viva (pkill + relanza vía LaunchAgent de autoarranque) al actualizar — antes el `.app` nuevo bajaba a disco pero el binario viejo seguía corriendo en memoria.
- 2026-07-18 · aviso-drift-cerebro · claude+unjordi · Anti-drift construido (#157 v1 + #159 v2): hook GLOBAL de SessionStart que detecta drift del cerebro por-repo vs el brain global (diff-aware, reusa `sincronizar-cerebro.sh` en dry-run) y auto-sincroniza cuando `.claude/` está limpio y estás en tu mini-develop.
- 2026-07-18 · main 55652f2 (#147-#152) · claude+unjordi · Paquete "turno nocturno" CONSTRUIDO Y RELEASEADO completo: skill `turno-nocturno` (contrato+autorización durable con vencimiento+relanzador+preflight) + fix de precisión de `confirmar-merge-develop` (autorización durable a disco, vocabulario "empuja/mete todo a develop") + normas nuevas (re-citar un OK vigente es legítimo · ninguna decisión se queda solo en el chat · post-compact se EXCAVA antes de contestar · paso 0 de toda tarea grande = inventario de lo que ya existe) + mockups de Claude siempre a archivo versionado.
- 2026-08-05 → 2026-08-07 · fix/juez-fast-path (worktree, sin mergear) · claude+unjordi · Robustez del juez de intención (Haiku) — causa raíz confirmada: la lentitud/timeout (~50s → UNAVAILABLE → fail-safe DENY) era el HARNESS de `claude -p`, no el modelo. Fix validado: `curl` directo a la Messages API con el token OAuth de suscripción (keychain), ~1.3s, espejado a `dod-verificar`; batería LIVE completa verde (merge 24/24 · dod 33/33).
- 2026-08-07 · (verificación in-hook, sin rama) · claude+unjordi · B2 / PARQUEADO#3 CERRADO: el juez in-hook SÍ alcanza el token OAuth vía keychain en subproceso — verificación doble (`security find-generic-password` reproducido en subproceso + evidencia viva: autorizó los merges #278/#280/#281/#282). La "causa raíz confirmada" de 2026-08-06 sobre bloqueo offline quedó rancia; no se invierte en blindar offline ni se documenta "mergea en la web" como escape.
- 2026-08-05 · #263 (86c6d7b) · claude+unjordi · `docs/flowcharts/verificar-arbol-sync.sh` portabilizado (ya en develop): dejó de usar `find -printf` (GNU-only), que daba un FAIL espurio solo en macOS (BSD find) contando 0 skills y reportando falso drift.
- 2026-08-07 · #282 + #278 · claude+unjordi · Flowcharts 03–11 con leyenda-árbol (`gen-leyenda-arbol.sh --inject`, re-render, `.dot`/`.svg` des-ignorados) + `docs/referencia-cli-claude-code.md` (516 líneas, la tesis del ecosistema Claude CLI/OAuth/curl-juez que destrabó el fix del juez) mergeados a develop.
- 2026-08-08 · feat/reconstruir-firma-canonica (worktree, sin mergear) · claude+unjordi · #71 mecanismo NO-destructivo para reconstruir/enforzar la firma-árbol canónica en cerebros INSTANCIADOS: detector determinista `brain/verificar-firma-canonica.sh` (flaggea secciones ausentes en CLAUDE.md, memorias sin prefijo dom-/dev-/ux-/qa-/núcleo, invariante MEMORY↔archivos roto, hooks retirados en la prosa; `--strict`=gate para #44) + skill humano-en-el-loop `canonizar-cerebro` (destila el prototipo de fluxcore: reprefija con git mv, dedup con rescate, reescribe CLAUDE+MEMORY, verifica 1:1). Batería `g5` en test-brain.sh (verde, 641 PASS). 5-catálogos del árbol en sync (README+MEMORY+3 widgets). Verificado contra fluxcore/cps (pasan) y plantilladotnet (drift correctamente cazado).
