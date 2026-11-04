# 2026-10-22 · claudio-master → cortex-master · lo que falta por integrar (VERIFICADO)

Método: contenido de cada rama/worktree contra TODA la historia first-parent de develop (squash-safe) + el
bloque fix/corpus-fp-bench 867aa49; lo parcial se comprobó por FUNCIONALIDAD en el código del bloque.

## Falta y sirve (no está en develop ni en el bloque)
1. cortex-wt-quota (8 archivos SIN COMMITEAR): cuota con los campos reales del snapshot
   (equiv_session_cost_usd, session_tokens_used, sin cost_cap) + ventana semanal rolling 7d en cortex-fetch,
   delegacion-comun, widget macOS/KDE/Windows. Ninguno de esos campos existe en el bloque.
2. fix/widget-version-json b3fb4de: install.sh copia contents/ tras kpackagetool6 (version.json) + main.qml
   hace stash antes de `checkout -B` (paridad con Updater.swift). Ninguno está en el bloque.
3. fix/proteger-fuente-blinda-clon-infra 8898136: aviso al editar ~/.cortex/brain o ~/.claude-brain/brain.
   El bloque no tiene ese caso.
4. origin/fix/firma-canonica-nucleo-hilo-autorizaciones b307d70 (= N5): NUCLEO_RE con andamio/overflow/
   autorizaciones-vigentes. El bloque tiene el NUCLEO_RE viejo.
5. feat/masters-json-local (4 commits, opción A de N8): publicar-roster.sh no existe en el bloque; N8 sigue pending.
6. fix/promesas-sin-cableado (WIP sin verificar): de sus 3 promesas, siguen rotas 2 en el bloque —
   install-brain ignora CLAUDE_CONFIG_DIR (0 menciones) y sesion-inicio afirma que dod-verificar
   "revisa y bloquea" build/tests/lint. La 3ª (dod fail-open) hoy es contrato explícito.
7. Documentos de auditoría nunca integrados: docs/auditoria-ejecucion-guards-2026-09-16.md,
   docs/auditoria-semantica-guards-433-2026-09-16.md, audit/overhead-harness (dictamen + scripts/overhead/),
   docs/auditoria-tests-cortex-2026-10-13.md (sin trackear en A1-ci-shellcheck),
   docs/auditoria-skills-obsolescencia-2026-09-17.md (sin trackear en aud-skills-obsol).

## En el bloque pero sin cerrar
- 9c1b1a8 + 867aa49 (rehidratar-hilo, 2026-10-22): sin revisión de claudio.
- docs/guards-falsos-positivos.md sin commitear (espera gitleaks).

## Ya entró o lo superó otro cambio (verificado; nada que integrar)
- guard-merge-consolidado (25 archivos sucios, 2026-09-17 15:15): borrador previo de la consolidación; la
  versión integrada es e497efa (#438, 2026-09-17 21:18), 561 líneas distintas y con M4/H3/grant durable/M8
  que el borrador no tiene.
- Tanda de guards de sep (guards-criticos-fmea, secret-scan-sin-cota, guards-sustrato-unico, auditorías 433,
  integracion/cortex-2026-09-17): entraron 88–99% en #435/#436; lo faltante son comentarios recortados,
  rama-vieja (retirado en MANIFEST) y svg regenerados. Código comprobado en el bloque: cache de creación con
  dueño (acg__cache_confiable), SLUG-OPACO, mdg sin jq, release por conversación, proteger-arbol con la lib.
- feat/despertar-master: su script vive ampliado en coordinar-claudes/despertar-master.sh (+--mensaje, --cerrar).
- fix/merge-guard-durable-grant-loop: superado por el scoping por --repo del mdg nuevo (verificado 2026-10-21).
- fix/afinado-tanda-2026-10: lo funcional está en el bloque (modelo del transcript, _master_base, --wait-ci, PISO).
- rescate/develop-local: líneas de backlog viejas; estado-proyecto del bloque trae su versión vigente.
- fix/dod-timeout-carrera, fix/afinado-nucleo-2026-10, fix/aviso-contexto-util, fix/dedupe-firma-canonica,
  fix/cablear-cerrar-slice-gates, docs/*-lecciones, docs/seeder-sin-gustos-personales, docs/fp-corpus-2026-09-17,
  docs/requerimientos-unificar-tooling-sesiones, audit/skills-*, fix/quota-state-schema (rama),
  fix/rehidratar-visible-post-compact, fix/despertar-mensaje, worktree-agent-*: 100% presentes.
