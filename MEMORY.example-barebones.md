# Memoria del proyecto ‹PREFIJO› — handoff portable

> Contexto durable para continuar en cualquier máquina/sesión (va versionado en el repo).
> **Léeme primero**, luego salta a la nota relevante. El contrato de arquitectura es `AGENTS.md`.
> Cada nota abajo trae su **estado**, no solo su tema.

## 📍 Dónde estamos — hilo vigente y backlog
- **HILO VIGENTE →** `hilo-mental-actual.md` (se sobrescribe: la foto de "qué hago AHORA"; puede no existir).
- **Estado + backlog vivo →** [estado-proyecto.md](estado-proyecto.md) — HECHO (anclado a commit) / PENDIENTE / FUERA-POR-DECISIÓN. **Aquí empiezas siempre.**
- **Fase:** ‹una línea con la fase real del proyecto; el detalle vivo vive en estado-proyecto.md, NO se duplica aquí›.

<!-- OPCIONAL, solo si el proyecto lo tiene DE VERDAD (no inventar puertos/URLs):
## 🚦 Pipeline / entornos — ‹rama · frontend · BD · gate por entorno›
Tabla de entornos con su gate. Omítela si el proyecto no tiene un pipeline verificado. -->

> **El índice de abajo está agrupado POR PREFIJO de archivo** (`dom-`/`dev-`/`ux-`/`qa-` + el núcleo
> sin prefijo). Sección = prefijo = orden del folder → una sola taxonomía, cero drift. El prefijo
> delata el tema; cada nota abre con su respuesta y su estado (answer-first).

## 🧭 Núcleo (memorias sin prefijo) — estado, backlog, bitácora, aprendizajes, cómo trabajar
> El estado vigente vive arriba en **📍 Dónde estamos**.
- [Estado del proyecto](estado-proyecto.md) — el HUB vivo (hecho/pendiente/fuera-por-decisión). Empieza aquí.
- [Bitácora](bitacora.md) — journal append-only, una línea por slice (`merge=union` → sin conflictos en paralelo).
- ‹aprendizajes.md · como-trabajar-‹usuario›.md · backlog-‹tema›.md — si aplican›

## 🗄️ dom- · dominio y datos
> Arquitectura/dominio formal = `AGENTS.md`. Aquí, el dominio FINO. Léelo antes de tocar el modelo.
- [dom-‹tema›](dom-‹tema›.md) — ‹respuesta-primero: qué es + su ESTADO + "léelo antes de …"›.

## 🛠️ dev- · desarrollo e infra
- [dev-‹tema›](dev-‹tema›.md) — ‹git/CI/deps/correr-en-local/tooling: respuesta + ESTADO›.

## 🎨 ux- · diseño
- [ux-‹tema›](ux-‹tema›.md) — ‹principios/identidad/componentes de UI: respuesta + ESTADO›.

## ✅ qa- · calidad
- [qa-‹tema›](qa-‹tema›.md) — ‹hallazgos/planes de QA: respuesta + ESTADO›.

<!--
CONTRATO DE ESTA FIRMA (por qué así):
- Es el DETALLE 1:1 de la 🖋️ FIRMA del `CLAUDE.md` (firma-árbol) + el índice de memorias por tema.
- Convención de nombres: prefijos `dom-`/`dev-`/`ux-`/`qa-` + NÚCLEO sin prefijo
  (estado-proyecto · bitacora · aprendizajes · como-trabajar-‹usuario› · backlog-‹tema› · hilo-mental-actual · MEMORY).
- El índice se agrupa POR PREFIJO (= orden del folder) → cero drift entre índice y archivos.
- INVARIANTE: cada archivo real (salvo `*.local.md` gitignored) está indexado, y cada enlace resuelve a un archivo real (1:1).
- Answer-first: cada línea abre con la RESPUESTA y el ESTADO de la nota, no con su historia.
- FIDELIDAD: no inventes secciones/pipelines/datos que el proyecto no tenga verificados.
- Instancia canónica de referencia: el `MEMORY.md` de cps.
-->
