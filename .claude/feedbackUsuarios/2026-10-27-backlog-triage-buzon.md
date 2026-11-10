# Backlog del buzón de cortex — triage de 85 notas (+2 adjuntos)

Base de código: `cortex-develop/` = origin/develop a218cd9. Rutas `archivo:línea` relativas a esa carpeta. Pruebas de sandbox en `salida/sandbox/` (HOME falso, repos desechables; nada fuera de `salida/`).
Veredictos: RESUELTO · PARCIAL · ABIERTO · SUPERADO · INFORMATIVA · SIN-REPRO. «[SIN VERIFICAR]» = no se pudo medir con lo disponible.

Hallazgo de método (corrige el encargo): las 8 notas con `.ATENDIDO` NO están todas cerradas de verdad — `2026-10-21-norma-entorno-maquina-alcance` (4 copias viejas siguen vivas), `2026-10-21-revision-tiers-both` (gitleaks `--repo` por subcadena sigue abierto) y `2026-10-21-tiers-hooks-repo-a-global` (parte 4 sin ítem en el backlog) dejan residuo; van como PARCIAL con su ítem.

## 1. Tabla de triage (una fila por nota, orden cronológico)

| # | Nota | Queja (1 línea) | Veredicto | Evidencia | Ítem |
|---|---|---|---|---|---|
| 1 | 2026-09-22-rehidratacion-hilo-truncado-post-compact | Post-compact el hilo llega truncado a 2 KB y Claude actúa sobre ARGUMENTS viejos | RESUELTO | `brain/hooks/rehidratar-hilo.sh:327-360` (faro «HILO TRUNCADO» + §SIGUIENTE extraído), `brain/skills/checkpoint/SKILL.md:135` (SIGUIENTE answer-first) | — |
| 2 | 2026-09-24-aviso-contexto-estado-sin-regla-de-ignore | El estado de `aviso-contexto` (`.contexto-aviso.d/`) ensucia el repo; el brain no siembra ignore | ABIERTO | `brain/hooks/aviso-contexto.sh:43-49` escribe en `$ROOT/.claude/memory/`; nada en `brain/*.sh` toca `.gitignore`; estado A5 «PARCIAL» (solo el `.gitignore` de cortex) | B-08 |
| 3 | 2026-09-24-aviso-drift-cerebro-compara-contra-espejo-rezagado | El aviso de drift acusa «editado en vivo» por mtime contra un espejo `~/.cortex` rezagado; su remedio revertiría trabajo | ABIERTO | `brain/hooks/drift-cerebro-comun.sh:289,346` deciden con `-nt` (mtime); `:397-400` remedio «re-corre install-brain»; `install-brain.sh:412` el sello es un contador, no un SHA | B-03 |
| 4 | 2026-09-24-checkpoint-piso-entre-checkpoints | Falta piso entre checkpoints (9 en 5 h) | RESUELTO | `brain/skills/checkpoint/SKILL.md:58-69` (piso 30 min con `stat` del mtime del hilo); estado A6 | — |
| 5 | 2026-09-24-contexto-residente-del-cerebro-y-presupuesto-del-listado-de-skills | Peso residual del cerebro; topar `description` a ~250; `@aliases` importado dos veces | PARCIAL | Sin cap en `brain/test-brain.sh` (grep `description`+largo = nada); estado A9 pending (16 skills > 250); inventario anclado = decisión de unjordi (no reabrir) | B-29 |
| 6 | 2026-09-24-dod-verificar-el-fix-de-timeouts-no-llego-a-las-copias-por-repo | El fix de timeouts de dod-verificar no llegó a 5 de 6 copias por-repo | PARCIAL | Invariante solo sobre la copia del brain `brain/test-brain.sh:5085-5100`; `drift-cerebro-comun.sh:80-108`: rama PERSONAL no compara hooks tier `repo` (siempre `personal-clean`) | B-02 |
| 7 | 2026-09-24-entorno-maquina-guard-mira-working-tree | `entorno-maquina-guard` escanea el working tree, no lo que entra al commit | PARCIAL | Núcleo RESUELTO `brain/hooks/entorno-maquina-guard.sh:56-73` (solo staged; sandbox `emg-test.sh` S1-S5 OK). Residuo: commit con pathspec (`-- ruta`) sigue avisando por lo staged ajeno (S6, AVISA) — coincide con el FP del corpus 2026-10-23 | B-30 |
| 8 | 2026-09-24-proteger-fuente-candado-os-permisos | Respaldar `proteger-fuente-cerebro` con candado de permisos de OS (usuario `claude`) | ABIERTO | `brain/hooks/proteger-fuente-cerebro.sh` sigue advisory; sin rastro en estado-proyecto; idea de unjordi, diseño multi-OS | B-17 (Q6) |
| 9 | 2026-09-24-seed-resolver-no-puentea-mismo-folder-distinto-mount-root | `seed.sh` no siembra un master cuyo repo es una carpeta de Drive con otro mount root | ABIERTO | `brain/sesiones-master/seed.sh:44-60` `resolve_target` solo `$HOME/<rel>`; `:75-80` une todos los `masters-*.json` ordenados y el primero gana (cachy antes que mac); estado A8/N8 pending | B-10 |
| 10 | 2026-09-24-skills-de-AV-sin-uso-en-esta-maquina-informativo | 3 skills de unjordi con 0 usos | INFORMATIVA | La propia nota: no son del brain | — |
| 11 | 2026-09-28-aviso-contexto-hardcodea-ventana-200k | Falso 80/92 % por ventana 200K fija y numerador que ignora imágenes | PARCIAL | Denominador RESUELTO `brain/hooks/aviso-contexto.sh:65-101` (sin evidencia de ventana = silencio; `[1m]`/modelo listado = 1M). Numerador: [SIN VERIFICAR] — el hook toma el último `usage` de la API (que ya cuenta imágenes); no se reprodujo | B-14 |
| 12 | 2026-10-01-games-master-detector-firma-y-falsos-positivos | NUCLEO_RE incompleto + lote de FP (no-sudo, gate-steam, merge-develop-guard con grant permanente, git-branch-guard, proteger-arbol) | PARCIAL | `brain/verificar-firma-canonica.sh:119` NUCLEO_RE ya incluye andamio/overflow y el archivo de grants; no-sudo/pkexec/gate-steam no están en `brain/` (solo `docs/candidatos/`); git-branch-guard retirado; proteger-arbol y sync-upstream en filas 19 y 17. Los 5 FP de merge-develop-guard con el grant permanente citado (2026-09-27, 09-28, 10-01 x3) son la MISMA raíz que la fila 86 (el grant vive en el cwd, el guard lo busca en el repo destino) | B-04 |
| 13 | 2026-10-02-barrer-ramas-gitignore-hook-state | `barrer-ramas`/`aviso-contexto` escriben estado sin ignorar → CD de odysseus rojo 6/6 | ABIERTO | Igual raíz que #2; `brain/hooks/limpiar-impl-ramas.sh:125` `.ramas-huerfanas-estado` in-repo; barrer-ramas ya escribe su stamp fuera (estado A5) | B-08 |
| 14 | 2026-10-02-dod-verificar-falso-positivo-tooling-interno | dod-verificar frena el estatus de tooling interno cuyo QA es el dogfood del dev | ABIERTO | `brain/hooks/dod-verificar.sh:128-133` el prompt del juez no distingue tooling interno; cambia un control de supervisión | B-06 (Q3) |
| 15 | 2026-10-03-barrer-ramas-borra-mini-develop-con-nombre-propio | El barrido borró la mini `epic-benchmarks-fixes` re-sembrada | RESUELTO | `brain/hooks/ramas-zombie.sh:492` `bz_protegida` protege `epic/* epic-* integracion/* integracion-*` (el comentario de `limpiar-impl-ramas.sh:22` sigue diciendo solo `Develop*`) | B-25 (comentario) |
| 16 | 2026-10-03-masters-contexto-irrepetible-y-equipo | Norma: contexto del master irrepetible, delegar por costo, masters = equipo | SUPERADO | Genérico ya en `brain/norms/global-claude-md.md:184-190`; el trato personal va a `como-trabajar-con-unjordi` (ya está, visible en el contexto de la Mac) | — |
| 17 | 2026-10-03-merge-develop-guard-sync-upstream | No hay vía para integrar un sync de upstream con `--merge` | RESUELTO | `brain/hooks/merge-develop-guard.sh:388-457` `_es_sync_upstream_autorizado`; tests `brain/test-brain.sh:331,381` | — |
| 18 | 2026-10-05-guard-sudo-falso-positivo-heredoc | Guard sudo y git-branch-guard frenan texto en heredoc | SUPERADO | sudo/pkexec: no está en `brain/`; git-branch-guard retirado (`brain/hooks/MANIFEST`, estado 2026-10-21) | — |
| 19 | 2026-10-05-proteger-arbol-y-barrer-ramas-squash-via-mini | Squash vía mini no se reconoce como integrado | RESUELTO | `brain/hooks/ramas-zombie.sh:9-20,315-328` señal (e) `Rama:`; cerrar-slice escribe un `Rama:` por sub-rama (`test-brain.sh:4251-4266`) | — |
| 20 | 2026-10-07-limpiar-worktrees-squash-y-glab-repo | (1) ramitas integradas a rama-churn squasheada quedan «vivas»; (2) `glab mr create --repo` desde otro cwd falla | PARCIAL | (1) RESUELTO `ramas-zombie.sh:332-360` presencia por contenido + `test-brain.sh:3869-3883`. (2) ABIERTO: `cerrar-slice.sh` solo pasa `-R` al merge; `SKILL.md:108` sin cwd | B-28 |
| 21 | 2026-10-07-revisor-datos-personales | Guard de datos personales en git | SUPERADO | estado-proyecto:223 (B7 FUERA por ahora, unjordi no lo eligió) | — |
| 22 | 2026-10-09-barrer-ramas-worktree-recien-creado | El barrido borra el worktree de un agente recién arrancado | RESUELTO | `brain/hooks/limpiar-impl-worktrees.sh:62-84,127` (0 commits propios + reflog solo «Created» + árbol limpio = ACTIVO) | — |
| 23 | 2026-10-09-cerrar-slice-wait-ci-no-espera-con-gh | `--wait-ci` con gh mergea con CI pendiente | RESUELTO | `brain/skills/cerrar-slice/cerrar-slice.sh:259-310` (ROJO/INDET/PENDIENTE abortan) | — |
| 24 | 2026-10-09-ci-develop-rojo-shellcheck-sc2148 | CI rojo por SC2148 | RESUELTO | `control-gui-remota-por-ssh/{linux/lib-linux-ssh-env.sh,mac/lib-mac-ssh-env.sh}:2` `# shellcheck shell=bash` | — |
| 25 | 2026-10-09-entorno-maquina-fuente-unica | install-brain resiembra el detallado `entorno-esta-maquina.md` | RESUELTO | `brain/install-brain.sh:436-442` siembra solo `~/.claude/entorno-maquina.md` (LEAN) | — |
| 26 | 2026-10-10-aviso-drift-guards-tier-repo | El aviso marca como sobrantes hooks tier `repo` | RESUELTO | `drift-cerebro-comun.sh:83-110` (solo tier `both` con copia global y no dependencia de un repo-hook); `.ATENDIDO` 10-21 | — |
| 27 | 2026-10-10-dod-verificar-ok-mid-turn | dod no ve el OK escrito a media vuelta | RESUELTO | `brain/hooks/dod-verificar.sh:217-229` (B3 `queued_command` humano). Residuo menor `ACG_MR_TIMEOUT=6s` [SIN VERIFICAR] | — |
| 28 | 2026-10-11-guard-pgrep-f-autokill | Guard que frene `pkill -f` | SUPERADO | estado-proyecto:222 (B6 FUERA por decisión de unjordi, cita textual) | — |
| 29 | 2026-10-11-ramas-zombie-senal-e-sin-containment | (e) borra trabajo post-squash | RESUELTO | `ramas-zombie.sh:287-300,374` (e) acotada por contenido | — |
| 30 | 2026-10-11-to-do-orden-hud-y-urgentes | HUD en el orden de la vista + 🔥 urgentes | ABIERTO | `brain/skills/to-do/SKILL.md` sin esa mecánica; estado N6 pending | B-26 |
| 31 | 2026-10-14-checkpoint-borrador-compact | Entregar el borrador de `/compact` al cerrar checkpoint | RESUELTO | `checkpoint/SKILL.md:292-311` (sobre su contenido, ver #62) | — |
| 32 | 2026-10-14-despertar-master-y-masters-json | `/despertar-master` + `masters.json` rancio | PARCIAL | `coordinar-claudes/despertar-master.sh` existe; `masters.json` duplicado/rancio = estado N8 | B-10 |
| 33 | 2026-10-15-462-verificado-kde-mac | Verificación de no-regresión del #462 | INFORMATIVA | — | — |
| 34 | 2026-10-15-auditoria-utilitario-cortex | Auditoría «estrictamente utilitario» (213 KB) | PARCIAL | 1ª pasada hecha (`4777871`); persisten fechas/incidentes: `analizar-comando-git.sh` 13 líneas, `merge-develop-guard.sh` 12, `test-brain.sh` 253, `global-claude-md.md` 6; la 2ª pasada no está en estado-proyecto | B-25 |
| 35 | 2026-10-15-b8-migracion-import-identidad | Falta migrar el `@import` de identidad | RESUELTO | `brain/hooks/aviso-drift-cerebro.sh:57-81` (siembra en `CLAUDE.local.md` + `.git/info/exclude`); residuo ver #55 | B-13 (residuo) |
| 36 | 2026-10-15-estado-epica-desde-memoria-de-claudio | Volcado de bitácora/decisiones de la épica | INFORMATIVA | Accionables ya cubiertos: stat GNU `analizar-comando-git.sh:715-726`, roster `sesiones-master/publicar-roster.sh` | — |
| 37 | 2026-10-15-limpieza-utilitario-en-curso | Estado de la limpieza utilitaria + 2ª pasada + flowcharts de orquestar-fanout | PARCIAL | Ver #34 | B-25 |
| 38 | 2026-10-15-merge-develop-guard-destino-sin-resolver-otro-repo | DENY aun con OK literal (prompt con imagen rompe jq) | RESUELTO | `analizar-comando-git.sh:905-925` (prompt array); mensajes honestos `merge-develop-guard.sh:672,701` | — |
| 39 | 2026-10-15-merge-develop-guard-ignora-grant-en-vivo | Freno en vivo con grant vigente (caché de destino en Linux) | RESUELTO | `analizar-comando-git.sh:715-726` GNU-primero; mensaje `merge-develop-guard.sh:701`. El despliegue a la flota (release + widget) es operativo | — |
| 40 | 2026-10-15-reconstruir-contexto-uso-real-claudio | 12 hallazgos del primer uso de reconstruir-contexto | PARCIAL | Resueltos: `reconstruir-contexto/SKILL.md:72-117` ventana previa, `:136` por SID, filtros isMeta/isCompactSummary, grep muerto retirado, paso 2 por repo del tema `:78-84`, test `test-brain.sh:6910`. Sin verificar: tope de `tool_use` y fixture del fallback manual | B-32 |
| 41 | 2026-10-15-rehidratar-hilo-cuelga-tras-compact | rehidratar-hilo 100 % CPU minutos | RESUELTO | `rehidratar-hilo.sh:56-65` watchdog 8 s fail-open (stdio a /dev/null) | — |
| 42 | 2026-10-15-vigilar-master-falso-colgado-por-metadatos | `pr-link` cuenta como último evento | RESUELTO | `coordinar-claudes/vigilar-master.sh:7-18` solo assistant/user/system | — |
| 43 | 2026-10-15-vigilar-master-falso-colgado-tras-compact-idle | Tras compact en idle da COLGADO falso | ABIERTO | `vigilar-master.sh:18` cuenta `user isCompactSummary` y `system informational/compact_boundary` como evento vivo | B-19 |
| 44 | 2026-10-15-widget-no-refresca-al-cambiar-de-cuenta | El widget no refresca al cambiar de cuenta | RESUELTO | `macos/Sources/Cortex/AppDelegate.swift:83-99` (30 s), `windows/src/Cortex/QuotaService.cs:415-433`, `src/plasmoid/contents/ui/main.qml` | — |
| 45 | 2026-10-16-limpiar-worktrees-sucio-con-submodulo | «SUCIO» con 0 archivos en repos con submódulo | ABIERTO | `limpiar-impl-worktrees.sh:99-110`: `worktree remove` sin `--force` falla por submódulo y se reporta sucio | B-12 |
| 46 | 2026-10-19-corpus-diagnostico | Causas de los FP vivos del corpus (no-bypass, proteger-arbol, drift, barrer) | RESUELTO | `no-bypass-deploy.sh:82,93` (ancla de intérprete, `~/`, `$HOME/`; sandbox: `ls foo.sh install.sh` calla, `bash -lc ./install.sh` avisa); `proteger-arbol.sh:113-121,198`; `ramas-zombie.sh:492` | — |
| 47 | 2026-10-19-git-branch-guard-cd-a-worktree | Push de ramita tras `cd <wt>` frenado | SUPERADO | git-branch-guard retirado; la lib que sobrevive ya resuelve `for…do cd wt` (sandbox `t1.sh`: rc=1 = no toca base) | — |
| 48 | 2026-10-19-gitleaks-reglas-cadena-conexion.toml | Adjunto: reglas gitleaks de cadena de conexión | RESUELTO | `.gitleaks.toml` de cortex trae `cadena-conexion` | — |
| 49 | 2026-10-19-revision-1-git-branch-guard | H1 cd-keyword, H2 clon desde worktree, H3 `ssh://host:puerto` | RESUELTO | sandbox `t1.sh`; `analizar-comando-git.sh:368-371` (git-common-dir), `:351` (`ssh://[^/]+/`) | — |
| 50 | 2026-10-19-revision-2-merge-develop-guard | H4 juez niega OK claro; H5 OK multilínea | RESUELTO | H4: pre-filtro determinista RECHAZADO por unjordi (estado:19 «no confío nada en lo determinista»); H5 `merge-develop-guard.sh:398-406` | — |
| 51 | 2026-10-19-revision-3-secret-scan | H6 `ds_safe_re` deja pasar secretos con «Prueba…» | SUPERADO | secret-scan/detectar-secretos retirados (`brain/hooks/MANIFEST:102-103`, autorizado por unjordi); gitleaks lo reemplaza | — |
| 52 | 2026-10-19-revision-4-proteger-arbol | H7 regla (c) calla cuando el separador es punto y coma u OR (`;`, `\|\|`) | RESUELTO | `proteger-arbol.sh:113-121` (c) solo con `&&` | — |
| 53 | 2026-10-19-revision-5-dod-verificar | H8 OK con imagen tumba el texto de usuario; H9 cierre de etapa | RESUELTO | `dod-verificar.sh:221-229` (array), `:133` (etapa/fase) | — |
| 54 | 2026-10-19-revision-6-destructivo | H10 resumen de «remotas sin local» no cuadra | ABIERTO | `limpiar-impl-ramas.sh:199-252`: AVANZÓ / no se pudo consultar / no se pudo borrar no suman a ningún contador | B-21 |
| 55 | 2026-10-19-revision-7-continuidad | H11 vigilante retiene stdout 8 s; H12 master `-3000` no se exporta | PARCIAL | H11 RESUELTO `rehidratar-hilo.sh:65`; H12 ABIERTO `exportar-sesion-master.sh:74-80` | B-20 |
| 56 | 2026-10-19-revision-8-drift | H13 escribe en `CLAUDE.local.md` trackeado; H14 retiro mudo de `conocimiento-propio.md` | ABIERTO | `aviso-drift-cerebro.sh:78-81` sin `git ls-files --error-unmatch`; `:61` solo `.local` | B-13 |
| 57 | 2026-10-19-revision-9-skills | H15 despertar relanza master retomado por título; H16 texto roto/«Verificado» sin fecha | PARCIAL | H15 RESUELTO `despertar-master.sh:87-96` (`_pids_master` por id o título). H16 ABIERTO: `control-gui-remota-por-ssh/win/win-ssh-screenshot.ps1:26` frase sin dato | B-33 |
| 58 | 2026-10-19-revision-10-resto | H17 no-bypass-deploy no reconoce `~/` ni `$HOME/` | RESUELTO | `no-bypass-deploy.sh:93`; sandbox: `bash ~/x/install-brain.sh` avisa | — |
| 59 | 2026-10-20-revision-candidatos-integracion | H18 gate gitleaks escanea el cwd, no la rama del MR | RESUELTO | `cerrar-slice.sh:50-100`; los «restos del retiro» (`agregar-hook-cerebro`, `auditar-coherencia`) ya no mencionan secret-scan | — |
| 60 | 2026-10-21-aviso-drift-sobrantes-incluye-tier-repo | Duplicado de #26 | RESUELTO | `.ATENDIDO`; `drift-cerebro-comun.sh:83-110` | — |
| 61 | 2026-10-21-checkpoint-compact-sin-eco | El `/compact` sugerido repite el hilo; `verificar_hilo` no mide si el §SIGUIENTE cabe | ABIERTO | `checkpoint/SKILL.md:292-311` aún manda marcador+cola+citas; `hooks/contrato-hilo.sh:19-81` valida pie/frescura, no bytes del §SIGUIENTE; estado:43 sin hacer | B-07 |
| 62 | 2026-10-21-coordinar-sin-vigilantes | Sin Monitor/vigilar para masters que reportan | RESUELTO | `.ATENDIDO` 69ede3d; `coordinar-claudes/SKILL.md:59-65` | — |
| 63 | 2026-10-21-norma-entorno-maquina-alcance | Precisar «jamás en el repo de un proyecto ni en tu slug» | PARCIAL | Norma/guard/install OK (c2d5664) pero siguen 4 copias viejas: `macos/Sources/Cortex/PopoverView.swift:1405`, `src/plasmoid/contents/ui/main.qml:1041`, `windows/src/Cortex/PopupForm.cs:1997`, `como-trabajar-con-usuario.example-barebones.md:14` | B-24 |
| 64 | 2026-10-21-ok-retirar-git-branch-guard | OK de unjordi: retirar git-branch-guard y simplificar merge-develop-guard | RESUELTO | `.ATENDIDO` (9eec6fc…0c36bbb); `hooks/MANIFEST` lápida; `global-claude-md.md:126` --auto gobernado por el juez | — |
| 65 | 2026-10-21-propuesta-estado-proyecto-en-todos-lados | Diseño: estado-proyecto.md fuera de un repo | RESUELTO | Decidido 2026-10-22 (fila 75, `estado-proyecto-y-rehidratar`); implementado `rehidratar-hilo.sh:80-113` | — |
| 66 | 2026-10-21-revision-tiers-both | Revisión de 12 commits (tiers, worktrees, merge-guard, no-bypass, proteger-arbol, gitleaks) | PARCIAL | Todo RESUELTO salvo gitleaks `--repo`: `cerrar-slice.sh:70` `case "${url%.git}" in *"$REPO"*)` subcadena sin anclar ni minúsculas | B-22 |
| 67 | 2026-10-21-revision-widget-auth | Relogin sin terminal; footers | PARCIAL | `.ATENDIDO` d4ccfd1; residuo: etiqueta «estimado local» con `basis` nulo: `QuotaModel.swift:445`, `limites.js:133`, `main.qml:2004`, `QuotaService.cs:198` | B-23 |
| 68 | 2026-10-21-tiers-hooks-repo-a-global | Tiers + estado en todos lados + revisar hardcoding de dod-verificar | PARCIAL | Partes 1-3 hechas (`.ATENDIDO`); parte 4 (hardcoding de dod-verificar, «luego lo revisamos») sin ítem en estado-proyecto | B-34 |
| 69 | 2026-10-21-verificar-hilo-no-ve-write-fallido | `verificar_hilo` da OK sobre hilo viejo | RESUELTO | `contrato-hilo.sh:19-81` flag «fresco» (42bdcfa) | — |
| 70 | 2026-10-21-widget-cuenta-vs-estimado | Widget muestra estimado que contradice la última lectura; estados de token | RESUELTO | `src/bin/cortex-fetch:28-145` `AUTH_STATE ok/expiring/expired`; relogin `PopoverView.swift:703`, `limites.js:22`, `main.qml:3584` | — |
| 71 | 2026-10-22-agentes-catalogo-dinamico | Lista de agentes del catálogo hardcodeada y sin paridad macOS/Windows | ABIERTO | `src/plasmoid/contents/ui/main.qml:1213`, `src/gnome-extension/lib/catalogo-cerebro.js:85`; no está en estado-proyecto | B-23 |
| 72 | 2026-10-22-andamio-checkpoint-truena | `checkpoint-mecanico.js --self --ensure` truena con error de Node en la cachy | SIN-REPRO | La nota no trae el error; en la Mac (Node v26) regenera OK (sandbox `h3`) | B-18 |
| 73 | 2026-10-22-barrido-no-reconoce-integracion-por-epica | 19 ramas integradas dentro de épicas quedan «vivas»; dry-run cuenta mal | RESUELTO | `ramas-zombie.sh:332-360` + `test-brain.sh:3869-3883`; un `Rama:` por sub-rama `test-brain.sh:4251-4266`; dry-run `limpiar-impl-worktrees.sh:131-137` | — |
| 74 | 2026-10-22-coordinar-timer-de-respaldo | `notify_when_idle` no despierta: timer de respaldo + transcript como señal | RESUELTO | `coordinar-claudes/SKILL.md:44-45` | — |
| 75 | 2026-10-22-estado-proyecto-y-rehidratar | Decisiones: sembrar estado-proyecto.md solo en `.claude/` de proyecto | RESUELTO | `rehidratar-hilo.sh:80-113` | — |
| 76 | 2026-10-22-gate-auditoria-antes-de-integrar | Decisión: auditoría Sonnet antes del merge de la épica | INFORMATIVA | Decisión de proceso de unjordi; sin código | — |
| 77 | 2026-10-22-inventario-ramas-sin-integrar | Inventario verificado de lo que falta integrar | PARCIAL | Ya en el código: NUCLEO_RE, `publicar-roster.sh`, `proteger-fuente-cerebro.sh:16` (B), `install-brain.sh:57` CLAUDE_CONFIG_DIR, docs de auditoría, `install.sh:542-566` version.json. [SIN VERIFICAR] `cortex-wt-quota` (8 archivos sin commit en el worktree de unjordi; `equiv_session_cost_usd` solo en `macos/`) | B-36 |
| 78 | 2026-10-22-presencia.py | Adjunto: script de medición de presencia por contenido | INFORMATIVA | Herramienta de #73 (ya en la señal (p)) | — |
| 79 | 2026-10-23-barrido-borra-worktree-de-agente-vivo | El barrido borró el worktree de un agente vivo (cachy) | RESUELTO | `limpiar-impl-worktrees.sh:62-84,127`; el incidente fue en la cachy con lib vieja (despliegue pendiente). [SIN VERIFICAR] worktree anidado `.git-worktrees/` | — |
| 80 | 2026-10-23-compact-por-screen-paste | `/compact` largo por `screen paste` no dispara | ABIERTO | `coordinar-claudes/SKILL.md:48` solo `stuff "$MSG"`; falta la receta de trozos de 200 + `\r` | B-27 |
| 81 | 2026-10-23-repo-publico-nuevo | Hito: publicar cortex desde repo nuevo (gates, idioma, distribución sin clonar) | ABIERTO | Decisión de unjordi 2026-10-23 no presente en estado-proyecto (grep) — «ninguna decisión solo en el chat» | B-31 |
| 82 | 2026-10-26-decisiones-post-merge-470 | Release siempre pide confirmación; grant por pedido; unificar `seven_day`/`weekly` | PARCIAL | Release ya pide (`merge-develop-guard.sh` piso de main); grant: `proteger-autorizaciones.sh:1-30` y `turno-nocturno/SKILL.md:144-154` aún niegan que el agente lo escriba; `cortex-fetch:215,261,271` mezcla nombres | B-05 (Q2), B-35 |
| 83 | 2026-10-27-barrido-escribe-bitacora-de-worktree | El barrido escribe la bitácora del worktree donde corrió el merge | ABIERTO | `limpiar-impl-worktrees.sh:38,46` y `limpiar-impl-ramas.sh:37-38`: `BITA="$ROOT/…"` con ROOT = toplevel del cwd (un worktree) | B-09 |
| 84 | 2026-10-27-bloqueos-del-clasificador-auto-mode | Bloqueos del clasificador que terminan en el usuario | ABIERTO | Server-side; no hay siembra de `permissions.allow` (`grep permissions brain/install-brain.sh` = nada); la preferencia (1) ya está en `como-trabajar` | B-16 (Q5) |
| 85 | 2026-10-27-limpiar-personal-descablea-hook-vecino | `--limpiar-personal` descablea `dod-verificar` que comparte entrada con el hook retirado | ABIERTO | `brain/sincronizar-cerebro.sh:152-158` filtra por ENTRADA completa. REPRO sandbox `dewire-test.sh`: el settings queda `{}`. Más 3 FAIL de test-brain por aislamiento (`test-brain.sh:1655,2050`) | B-01, B-11 |
| 86 | 2026-10-27-merge-develop-guard-no-lee-grant-permanente | Grant permanente vigente no se honra con cwd = carpeta de Drive | ABIERTO | `merge-develop-guard.sh:471-479,636` el grant solo se busca en el clon del repo destino; el grant ni tiene campo de repos (prosa) | B-04 (Q1) |
| 87 | 2026-10-27-proteger-autorizaciones-falsos-positivos | 5-7 FP del guard de grants (python/glob/menciones) | PARCIAL | Sandbox `pa-test.sh` sobre develop: FP1 FP3 FP6 FP7 PASAN, TP1-TP4 FRENAN; el caso glob `memory/*.md` + `open(f,'w')` sigue frenando (por diseño 2026-10-23) | B-15 (Q4) |

## 2. Backlog consolidado (deduplicado, por severidad)

Convención: «Test» = escenario de DOS direcciones (rechaza/hace lo inválido y acepta/respeta lo válido) que debe FALLAR contra a218cd9. «Aceptación» = comprobable sin unjordi. Ningún ítem afloja un candado salvo los marcados «requiere unjordi».

### CRÍTICO

**B-01 · `--limpiar-personal` / `--prune-orphans` descablean los hooks hermanos de la misma entrada del settings** — CRÍTICO
- Notas: #85 (2026-10-27-limpiar-personal-descablea-hook-vecino). Cita: ninguna textual; pedido «dejar la nota, no arreglarlo desde axon».
- Causa raíz: `brain/sincronizar-cerebro.sh:152-158` (`dewire_hook`): `.value |= [ .[] | select(([.hooks[]?.command]|join(" "))|test($pat))|not) ]` descarta la ENTRADA completa (matcher) si cualquiera de sus comandos casa; los hermanos de esa entrada se van con ella, y luego se borran entradas/eventos vacíos y la clave `hooks`. Llamadores: `:203, :271, :422, :431`.
- Reproducido en sandbox (`salida/sandbox/dewire-test.sh`, extrae la función real): `Stop[0].hooks=[dod-verificar, recordar-cosechar]`, retirar `recordar-cosechar` → settings queda `{}`; `dod-verificar` apagado en silencio.
- Arreglo (mecanismo): quitar SOLO el comando: `.hooks[ev] |= map(.hooks |= map(select((.command // "")|test($pat)|not))) | map(select((.hooks|length)>0))`; luego eliminar eventos vacíos y `.hooks` vacío. Además el resumen del comando debe listar «cableado retirado de: <hook>» por cada comando quitado y «hermano conservado: <hook>».
- Test (dos direcciones), contra un `settings.json` con `Stop[0].hooks=[dod-verificar, recordar-cosechar]` y otro con `PreToolUse` mixto: (a) retirar `recordar-cosechar` → `dod-verificar` SIGUE cableado y `recordar-cosechar` no; (b) retirar el único hook de una entrada → la entrada y el evento desaparecen; (c) un hook ausente no cambia el archivo byte a byte. Falla hoy en (a).
- Aceptación: `bash brain/test-brain.sh` con los 3 casos en rojo contra a218cd9 y verde con el fix; correr `sincronizar-cerebro.sh <repo-sandbox> --limpiar-personal --apply` y verificar con `jq` que `dod-verificar` permanece.
- ¿Requiere unjordi? No (precisión de un instalador, no un candado). Dependencias: ninguna; B-11 evita falsos FAIL del mismo banco.

### ALTO

**B-02 · Los hooks tier `repo` de repos PERSONALES no tienen ninguna vía de refresco ni de detección de obsolescencia; el invariante de timeouts solo mira la copia del brain** — ALTO
- Notas: #6 (2026-09-24-dod-verificar-el-fix-de-timeouts…). Cita: ninguna textual.
- Causa raíz: `brain/hooks/drift-cerebro-comun.sh:80-108` (rama PERSONAL): solo flaggea `both` sobrantes y devuelve `personal-clean`; nunca compara un hook tier `repo` (dod-verificar) contra la fuente. Solo los repos con marca `repo-compartido` pasan por el dry-run del sync (`:128-140`). `brain/test-brain.sh:5085-5100` verifica `CLAUDE_DOD_JUEZ_TIMEOUT` vs `_DOD_HARNESS_TIMEOUT_MINIMO` en el archivo del brain, donde nunca falla.
- Efecto medido por la nota: juez con crédito 20 s dentro de un harness de 15 s en cps/fluxcore/plantilladotnet → el Stop espera 15 s y no dictamina (fail-open).
- Arreglo: (1) en la rama PERSONAL, para cada `.sh` tier `repo` presente comparar con `cmp -s` contra `brain/hooks/<h>` y emitir `STATUS=personal-stale` con el comando exacto `sincronizar-cerebro.sh <repo> --only <h> --apply` (solo avisa, no escribe: es un repo personal); (2) invariante de coherencia sobre la COPIA DESPLEGADA: nuevo chequeo en `verificar-cerebro.sh` (o en el mismo `drift`) que lee, por repo, el `timeout` que su `settings.json` cablea para `dod-verificar` y el `CLAUDE_DOD_JUEZ_TIMEOUT:-N` de su copia, y avisa si N ≥ timeout.
- Test: repo personal desechable con un `dod-verificar.sh` viejo (`:-20`, settings `timeout:15`) → avisa `personal-stale` y la incoherencia de timeouts; con copia idéntica a la fuente y `:-10` → silencio. Falla hoy en ambos (devuelve `personal-clean`).
- Aceptación: `bash brain/hooks/aviso-drift-cerebro.sh` en el repo sandbox imprime el aviso con el comando; tras `--only dod-verificar --apply` queda en silencio.
- ¿Requiere unjordi? No. La re-siembra de los repos de otros masters (cps, fluxcore, pisamrp_4.6, axon) es operativa y de cada master (no meterles mano): dejar nota en sus buzones. Dependencias: ninguna.

**B-03 · aviso-drift decide la DIRECCIÓN del drift por mtime y su remedio puede destruir trabajo** — ALTO
- Notas: #3 (2026-09-24-aviso-drift-cerebro-compara-contra-espejo-rezagado). Cita: ninguna textual.
- Causa raíz: `brain/hooks/drift-cerebro-comun.sh:289` (skills) y `:346` (hooks): `[ "$inst" -nt "$src" ]` ⇒ «EDITADO EN VIVO»; el mtime de un archivo instalado lo pone el instalador. `:397-400` remedio «re-corre install-brain» desde `resolve_brain_dir` (`:52`, `~/.cortex`), que puede ir detrás de `origin/develop`. `install-brain.sh:412` sella un contador (`PREFIJO.COUNT`), no el commit.
- Arreglo (mecanismo determinista, sin red): `install-brain.sh` estampa además el SHA de la fuente instalada (`~/.claude/.brain-source-sha`, y el mismo sello por-repo en `sincronizar-cerebro.sh`). El drift decide por CONTENIDO: si `inst` ≠ `src` y el blob de `inst` coincide con alguna versión histórica del archivo en `git -C $BRAIN_DIR log --format=%H -- <ruta>` (comparar `git hash-object inst` con `git rev-parse <c>:<ruta>`), el mensaje es «tu instalación es una versión ANTERIOR (commit X); la fuente avanzó» (remedio: actualizar por el widget/updater); si no coincide con ninguna → «editado en vivo». Además, si `git -C $BRAIN_DIR rev-parse @{u}` existe y `rev-list --count HEAD..@{u}` > 0 (último fetch), anteponer «tu espejo está N commits detrás de origin; actualízalo antes de instalar».
- Test: (a) fuente = commit 2 de un repo-espejo, instalado = blob del commit 1 con mtime POSTERIOR → dice «anterior», NO «editado en vivo»; (b) instalado con una línea que no existe en ningún commit → «editado en vivo»; (c) espejo con upstream N commits adelante → advierte rezago. Falla hoy en (a).
- Aceptación: reproducir con el sandbox de 3 copias de la nota (instalado más nuevo por mtime pero contenido histórico) y obtener el mensaje correcto.
- ¿Requiere unjordi? No (aviso, no candado). Dependencias: ninguna.

**B-04 · merge-develop-guard no honra un grant permanente cuando el cwd no es el repo destino** — ALTO (obliga a escalar al usuario)
- Notas: #86 (2026-10-27-merge-develop-guard-no-lee-grant-permanente) y los 5 FP de grant permanente citados en #12 (2026-10-01-games-master…): misma raíz, recurrente desde 2026-09-27. Cita (el grant del usuario): «deberías tener el OK permanente y completo para todos los merges a develop en TODOS los repos de armada y rp6 que toques [...] DEJA DE PEDIRMELO!!»
- Causa raíz: `brain/hooks/merge-develop-guard.sh:471-479` fija `TARGET_ROOT` al clon del repo de `--repo`; `:636` lee el grant SOLO de `$TARGET_ROOT/.claude/memory/autorizaciones-vigentes.local.md`. El grant del caso vive en `<cwd>/.claude/memory/` (carpeta de Drive no-git) y nombra los repos en prosa libre (sin campo estructurado) ⇒ se cae al juez, que solo ve la ventana viva. Es consecuencia de la decisión 5 del 2026-10-21 (alcance = repo de `--repo`), que fue de claudio-master, no de unjordi.
- Arreglo propuesto: formato de grant con campo `repos=org/a,org/b` (opcional; ausente = comportamiento actual) y lookup adicional en `$CLAUDE_PROJECT_DIR/.claude/memory/autorizaciones-vigentes.local.md` honrado SOLO si `repos=` nombra el slug resuelto de `--repo`, con destino confirmado `develop` y el veto de cita existente (`_grant_cita_verificada`). `main` jamás.
- Test: pasa: grant en `CLAUDE_PROJECT_DIR` no-git con `repos=` que nombra el slug, vigente, destino develop; frena: slug no nombrado, grant vencido, destino `main`, grant sin cita verificable, grant sin `repos=` en un cwd distinto del repo. El caso que pasa debe fallar contra a218cd9.
- Aceptación: banco `correr-merge-develop-guard.sh` (`brain/tests/corpus-fp/`) con los 5 casos y juez stub.
- ¿Requiere unjordi? SÍ — amplía de dónde se acepta autoridad para un merge (Q1). Dependencias: B-05 (misma superficie de grants).

**B-05 · Que Claude escriba el grant cuando unjordi se lo pide** — ALTO (cambio de política sobre un candado)
- Notas: #82 (2026-10-26-decisiones-post-merge-470). Cita: «el permiso del merge no quiero TENER que escribirlo yo, si te lo pido debería ser suficiente. Por qué queremos más trabas???»
- Causa raíz: `brain/hooks/proteger-autorizaciones.sh:1-30` (por diseño el agente no escribe `autorizaciones-vigentes*`; solo el humano con `!`) y `brain/skills/turno-nocturno/SKILL.md:144-154` (le presenta el one-liner `!`).
- Arreglo propuesto: un script de depósito `brain/skills/turno-nocturno/depositar-grant.sh` que Claude invoca y que (1) exige `--cita "<texto literal>"`, (2) verifica con el MISMO veto de cita (`_grant_cita_verificada`) que esa cita está en un mensaje HUMANO reciente que contiene un verbo de autorización explícito, (3) escribe el grant con `scope=merge-develop`, `vence_epoch`, `repos=` (B-04), (4) imprime el grant escrito. `proteger-autorizaciones` deja pasar SOLO ese script (identificación por ruta + hash del script, no por env ajustable). La cita del grant en un mensaje humano real sigue como control (palabras del propio unjordi).
- Test: pasa: cita literal presente en mensaje humano con «autorizo/permiso» → grant escrito; frena: cita ausente/parafraseada, cita solo en turno del asistente, escritura directa `echo >>` por otro camino, `scope=merge-main`. Contra a218cd9 el script no existe y el `echo >>` sigue bloqueado (el caso «pasa» falla).
- ¿Requiere unjordi? SÍ — cambia ESE control (Q2): su cita cubre la intención, pero la norma «Integridad de los guardarraíles» pide su OK sobre el mecanismo concreto. Dependencias: B-04.

**B-06 · dod-verificar: estatus de tooling interno cuyo QA es el dogfood del dev** — ALTO
- Notas: #14 (2026-10-02-dod-verificar-falso-positivo-tooling-interno). Cita: «No le andes dando la razón al hook cuando nomás chilla por aburrición… el QA es tuyo NO MÍO.» (y «QA de tooling interno = prueba funcional (él no lo invoca)», de `como-trabajar`).
- Causa raíz: `brain/hooks/dod-verificar.sh:128-133` el juez solo clasifica cierre de ENTREGABLE sin distinguir tooling interno; MARCA exige palabras del usuario (`:137-138`).
- Arreglo propuesto: marca DECLARADA POR EL HUMANO por repo, `.claude/qa-interno` (versionada; lista globs de rutas), de modo que un cierre cuyo turno toque SOLO rutas listadas cuente la «prueba funcional acordada de antemano» de la norma LISTO (1) cuando el turno cite el run/probe; el hook agrega al prompt la lista y la regla. Sin la marca, comportamiento actual.
- Test: pasa: repo con marca, turno que edita `src/memory/**` y cita `probe verde + axon run` → sin freno; frena: mismo turno SIN cita del run; frena: turno que toca una ruta fuera de la lista; frena: repo sin marca.
- ¿Requiere unjordi? SÍ — afloja dod-verificar (Q3). Dependencias: ninguna.

### MEDIO

**B-07 · checkpoint: el `/compact` sugerido es un eco del hilo y `verificar_hilo` no comprueba que el §SIGUIENTE quepa en el preview** — MEDIO
- Notas: #61 (2026-10-21-checkpoint-compact-sin-eco), #31. Cita: «el texto sugerido para compact es demasiado verbose Y redundante con el hilo… para que ese texto no redunde y sea útil para el compact en vez de un eco del checkpoint»; «el skill REVISA que lo que se escribe QUEPA en la rehidratación del postcompact? o deja que todo se trunque?».
- Causa raíz: `brain/skills/checkpoint/SKILL.md:292-311` ordena marcador+cola+citas+decisión (lo que el hilo ya carga y el hook reinyecta); `brain/hooks/contrato-hilo.sh:19-81` (`verificar_hilo`) valida pie y frescura, no tamaño. Estado:43 lo lista 📘 sin hacer.
- Arreglo: (1) reescribir el paso del borrador: ≤3 líneas = puntero al hilo + estado vivo EXTERNO que el hilo no carga + qué NO hacer; sin hechos, decisiones ni citas; regla de corte (si todo ya está en el hilo, `/compact` sin argumentos); (2) `verificar_hilo` mide los bytes del §SIGUIENTE y falla si `bytes > 2048 − bytes_del_faro − margen` (constante compartida con `rehidratar-hilo.sh:327-360`, `REHIDRATAR_FARO_BYTES`); avisa si el bloque completo superará el preview.
- Test: §SIGUIENTE de 3 líneas (~300 B) pasa; §SIGUIENTE de 2 KB falla con mensaje que nombra los bytes; borrador con cita textual → el skill lo rechaza en su paso de verificación (grep de `[user:`/comillas en el borrador).
- Aceptación: `contrato-hilo.sh` con los dos fixtures; contra a218cd9 el de 2 KB devuelve rc=0.
- ¿Requiere unjordi? No (lo pidió él y es un skill, no un candado). Dependencias: ninguna.

**B-08 · El estado de proceso de los hooks viaja dentro del repo (`.claude/memory/.contexto-aviso.d/`, `.ramas-huerfanas-estado`, logs del barrido) y ensucia el árbol** — MEDIO
- Notas: #2, #13 (2026-09-24-aviso-contexto-estado…, 2026-10-02-barrer-ramas-gitignore-hook-state). Cita: «si lo escribe barrer-ramas en cada merge, debería estar gitignoreado desde un principio».
- Causa raíz: `aviso-contexto.sh:43-49` y `limpiar-impl-ramas.sh:125` escriben bajo `$ROOT/.claude/memory/` (tracked); el brain no siembra ignore (`grep -i gitignore brain/*.sh` solo toca `CLAUDE.local.md`). Rompió el CD de odysseus 6/6 veces y 4 marcadores se commitearon en potenciaDatabases. Diseño ya aprobado en estado A5/N1: mover a `~/.claude/state/<cksum-ROOT>/`.
- Arreglo: ejecutar el slice A5 `fix/estado-fuera-de-repos` con migración (copiar el estado viejo una vez, borrar el residuo), y como red mientras tanto sembrar idempotente `.claude/memory/.contexto-*` + `.ramas-huerfanas-estado` + `.barrer-ramas/` en `.git/info/exclude` desde `aviso-drift-cerebro.sh` (mismo patrón que el de `CLAUDE.local.md`, `:67-77`).
- Test: repo con el hook corrido → `git status --porcelain` vacío (falla hoy: marcador untracked); el estado migrado conserva «ya avisé» (no reavisa); un repo con marcadores ya trackeados → el aviso lo reporta (no los borra solo).
- ¿Requiere unjordi? No (diseño aprobado por claudio; A5). Dependencias: B-09 comparte la ruta de bitácora.

**B-09 · El barrido post-merge escribe la bitácora del WORKTREE donde corrió el merge y dice «sin mergear a develop» de ramas que van a una épica** — MEDIO
- Notas: #83 (2026-10-27-barrido-escribe-bitacora-de-worktree).
- Causa raíz: `limpiar-impl-worktrees.sh:38,46` y `limpiar-impl-ramas.sh:37-38`: `ROOT=$(git rev-parse --show-toplevel)` ⇒ `BITA="$ROOT/.claude/memory/bitacora.md"` es el del worktree del cwd; el worktree queda sucio (rebase y `worktree remove` se niegan). El texto «sin mergear a develop» ignora que la rama integra a su base real (épica).
- Arreglo: `BITA` bajo el worktree PRINCIPAL (`MAIN_WT`, ya calculado en `limpiar-impl-worktrees.sh:45`; en ramas, `dirname $(git rev-parse --git-common-dir)`); y en la nota, medir «integrada» contra la base real de la rama (la del PR o `CLAUDE_INTEGRACION_BASE`).
- Test: merge simulado desde un worktree → el bloque «[worktrees pendientes tras barrido]» aparece en la bitácora del principal y `git -C <wt> status --porcelain` queda vacío (falla hoy); rama cuyo PR va a `epic/x` ya integrada a esa base no sale como «sin mergear a develop».
- ¿Requiere unjordi? No. Dependencias: B-08.

**B-10 · seed.sh: no siembra masters de carpetas de Drive con otro mount root; precedencia de roster ciega al host; masters.json duplicado/rancio** — MEDIO
- Notas: #9, #32 (+ estado A8, N8). Cita: «tal vez sería buena idea armar un skill de /despertar-master…», «ese masters.json está bien chafa», y su decisión 2026-10-14 «sí, así va!» (roster por máquina curado a mano, opción A).
- Causa raíz: `seed.sh:44-60` `resolve_target` solo resuelve `$HOME/<rel>` (un `target` absoluto como `/run/media/…/Juegos` jamás existe bajo `$HOME`); `:75-80` une TODOS los `masters-*.json` ordenados y gana el primero (`masters-cachy.json` antes que `masters-mac.json`), así que en la Mac manda el target de la cachy. La premisa de la opción (c) de la nota (root de Drive vía `CLAUDE_SESSIONS_DRIVE`) es falsa en la Mac (estado A8); pero la opción (a) ya existe de facto con la decisión del 2026-10-14.
- Arreglo (sin elegir nada nuevo): (1) `seed.sh` procesa PRIMERO `masters-$(hostname -s).json` (override `CLAUDE_SEED_HOST`) y solo después los de otros hosts, de modo que el target de ESTA máquina gane; (2) `resolve_target` acepta un target absoluto existente; (3) un id con target no resoluble pero con un hermano resoluble en otro host se siembra con el resoluble; (4) N8: `publicar-roster.sh` deja una entrada viva por nombre (la sesión más reciente reemplaza a la anterior) y retira las rancias.
- Test: dos hosts con el mismo id y targets distintos, ejecutado como host A → siembra en la ruta de A (falla hoy: gana el primero alfabético); target absoluto existente → se siembra; target inexistente en ambos → «omito» con motivo; nombre repetido → una sola entrada.
- ¿Requiere unjordi? No (se apoya en su decisión del 2026-10-14). Dependencias: ninguna.

**B-11 · test-brain.sh no aísla HOME/PATH: 3 FAIL espurios en la cachy** — MEDIO
- Notas: #85 (sección «3 FAIL»).
- Causa raíz: `test-brain.sh:2050,2063,2075,2086,1993` hacen `unset CLAUDE_CONFIG_DIR` sin fijar `HOME` a un fixture, y `juez-comun.sh:56-58` (`_juez_token_de_archivo`) lee `$HOME/.claude/.credentials.json` REAL ⇒ en Linux suma un canal (3 curls, no 2). `:1655` `env -i PATH=/usr/bin:/bin` presupone que no hay `glab` en `/usr/bin` (en Arch sí lo hay). [SIN VERIFICAR en la cachy; lectura de código y del banco.]
- Arreglo: en cada subshell de esos casos exportar `HOME="$FAKEHOME"` (ya existe, `:37`); para PATH-augment construir un `bin` privado con symlinks solo a las utilidades necesarias (sin glab/gh).
- Test: correr la suite con `~/.claude/.credentials.json` real presente y un `glab` en `/usr/bin` → los 3 casos pasan; contra el código actual fallan en esa máquina. Cada caso con control positivo.
- ¿Requiere unjordi? No. Dependencias: ninguna (desbloquea la confianza en B-01).

**B-12 · limpiar worktrees: «SUCIO» con 0 archivos en repos con submódulo** — MEDIO (bajo)
- Notas: #45 (2026-10-16-limpiar-worktrees-sucio-con-submodulo).
- Causa raíz: `limpiar-impl-worktrees.sh:99-110` `git worktree remove` sin `--force` falla con «working trees containing submodules cannot be moved or removed»; el script lo interpreta como sucio y además anota un «pendiente» con 0 archivos.
- Arreglo: si el `remove` falla Y `git status --porcelain` del worktree = 0 Y `git submodule foreach --quiet --recursive 'git status --porcelain'` = 0 (y cabeza de cada submódulo = la registrada), reintentar con `--force` (seguro: nada que perder); en cualquier otro caso mantener SUCIO.
- Test: worktree con submódulo limpio e integrado → se borra (falla hoy); con un cambio en el submódulo → se conserva y dice cuántos archivos; con un cambio en el árbol → se conserva.
- ¿Requiere unjordi? No. Dependencias: ninguna.

**B-13 · aviso-drift: el auto-@import escribe sobre un `CLAUDE.local.md` TRACKEADO y se perdió el respaldo `conocimiento-propio.md`** — MEDIO (bajo-medio)
- Notas: #56 (revision-8 H13/H14), #35 (residuo).
- Causa raíz: `aviso-drift-cerebro.sh:67-81` solo mira `check-ignore`; en un archivo trackeado el `info/exclude` no tiene efecto y se hace `>>` ⇒ ` M CLAUDE.local.md` listo para colarse en un repo compartido. `:61` ya no lee `conocimiento-propio.md` (retiro mudo).
- Arreglo: si `git ls-files --error-unmatch CLAUDE.local.md` tiene éxito → no tocar y emitir un aviso de una línea con la línea a pegar a mano; documentar el retiro de `conocimiento-propio.md` (sin `.local`) en el MANIFEST de memoria o conservar el respaldo (decisión de bajo riesgo: conservar el respaldo).
- Test: repo con `CLAUDE.local.md` versionado y sin import → `git status --porcelain` vacío tras la sesión + aviso (falla hoy: ` M`); repo con `.local` ignorado → un solo import idempotente (ya pasa).
- ¿Requiere unjordi? No. Dependencias: ninguna.

**B-14 · aviso-contexto: numerador inconsistente con `/context` (imágenes)** — MEDIO [SIN VERIFICAR]
- Notas: #11 (2026-09-28-aviso-contexto-hardcodea-ventana-200k). Cita (mala señal): «es en serio que aviso-contexto REGRESÓ a un error tan trivial?!».
- Causa raíz: denominador RESUELTO. Numerador: `aviso-contexto.sh` toma el último `usage` (input+cache) tras el último `isCompactSummary` (`:~50-60`); no se pudo reproducir el 161K vs 560K. Hipótesis: el `usage` del último mensaje no incluye lo que el cliente cuenta en `/context` (imágenes de `claude-in-chrome`) o el `tail -n 400` cayó en un tramo con `usage` previo a las capturas.
- Arreglo: primero DIAGNOSTICAR: con el transcript de esa sesión (heimdall-net, 2026-09-28) comparar `usage` del último `assistant` con el total de `/context`; si es real, medir la brecha por tipo de bloque y añadir un `AVISO_CONTEXTO_BIAS_IMAGENES`/estimación documentada; si no, cerrar con el resultado.
- Test: fixture `.jsonl` con un `usage` bajo y N bloques `image` → el hook declara «medición incierta (imágenes)» y NO escala a «/compact YA»; transcript sin imágenes → igual que hoy.
- ¿Requiere unjordi? No. Dependencias: ninguna.

**B-15 · proteger-autorizaciones frena un intérprete cuyo glob incluye el archivo de grants pero no lo escribe** — MEDIO
- Notas: #87 (2026-10-27-proteger-autorizaciones-falsos-positivos).
- Causa raíz/medición (sandbox `salida/sandbox/pa-test.sh` sobre a218cd9): FP1, FP3, FP6, FP7 (heredoc a otros `.md`, menciones del nombre) YA PASAN; TP1-TP4 (python `open(...,'a')`, `>>`, `tee`, `sed -i` al grant) frenan; sigue frenando `glob.glob("memory/*.md")` + `open(f,"w")`, que el diseño del 2026-10-23 cubre a propósito («indirección por glob»).
- Arreglo (solo si unjordi lo elige): dejar pasar el glob salvo que el patrón case LITERALMENTE con `autorizaciones-vigentes`; el bloqueo se mantiene si el destino resuelve al archivo por ruta literal.
- Test: pasa el comando del glob; frena `glob("autorizaciones-vigentes*")`+`open(w)`; frena los TP1-TP4.
- ¿Requiere unjordi? SÍ — afloja un candado (Q4). Dependencias: B-05.

**B-16 · Bloqueos del clasificador de auto-mode que terminan en el usuario** — MEDIO
- Notas: #84 (2026-10-27-bloqueos-del-clasificador-auto-mode). Cita: «no puedo pasar más tiempo solventando los bugs del clasificador», «puedes pelearte tú con tu clasificador en vez de pedir que me involucre?».
- Estado: (1) la preferencia ya está en `como-trabajar` (trato personal, no del brain); el aprendizaje de reintentar sin reformular ya está en el corpus (`guards-falsos-positivos.md:190`); (2) la siembra de `permissions.allow` no existe (`grep permissions brain/install-brain.sh` vacío) y es configuración de seguridad; (3) no hay norma de «no escalar un bloqueo del clasificador».
- Arreglo propuesto: (2) `install-brain.sh --con-allow-memoria` OPT-IN que, con confirmación interactiva, agrega a `~/.claude/settings.json` solo `Read(<HOME>/.claude/projects/**)` y `Edit(<HOME>/.claude/projects/*/memory/**)` (nada de `Bash(ssh …)`), con respaldo y des-siembra en `uninstall-brain.sh`; (3) una línea en la norma «Integridad de los guardarraíles»: un bloqueo del clasificador se reintenta/rodea por otra vía legítima y se reporta en una línea; solo se escala si es el único camino.
- Test: instalar sobre HOME falso con la opción y respuesta «sí» → exactamente esas dos reglas, idempotente, y `uninstall` las retira; sin la opción → settings sin cambios; respuesta «no» → sin cambios.
- ¿Requiere unjordi? SÍ (Q5): toca permisos de seguridad y una norma dura. Dependencias: ninguna.

**B-17 · Candado de permisos de OS para la fuente del cerebro** — MEDIO (diseño)
- Notas: #8 (2026-09-24-proteger-fuente-candado-os-permisos). Cita: idea de unjordi («sólida»).
- Estado: `proteger-fuente-cerebro.sh` sigue advisory; sin rastro en el backlog.
- Opciones y recomendación en Q6. Dependencias: ninguna.
- Test (si se aprueba): en HOME falso/Linux, con el usuario `claude` dueño de `~/.cortex/brain` y el usuario normal sin `w`, un `Edit` del agente a un hook intocable falla con EACCES (falla hoy: edita); el updater oficial sigue pudiendo escribir (acepta).

**B-18 · `checkpoint-mecanico.js --self --ensure` truena con error de Node en la cachy** — MEDIO [SIN REPRO]
- Notas: #72 (2026-10-22-andamio-checkpoint-truena; 164 bytes, sin el error).
- Medición: en la Mac (Node v26.4.0) regenera OK con un transcript sintético (`salida/sandbox/h3`); no hay sintaxis moderna sospechosa (`grep` de `toSorted/groupBy/structuredClone/…` vacío). Sin el mensaje de error no se puede diagnosticar.
- Arreglo: (1) `process.on('uncaughtException')` que imprima `checkpoint-mecanico: <mensaje> (node <ver>)` a stderr y salga 0 (un andamio roto no debe tumbar el checkpoint; el skill ya trata la ausencia del andamio como degradación); (2) pedirle a axon-master el `node --version` y el texto del error en la cachy.
- Test: invocar con `--self` sin transcript resoluble → mensaje claro y rc 0 (hoy: traza cruda).
- ¿Requiere unjordi? No. Dependencias: ninguna.

### BAJO

**B-19 · vigilar-master: COLGADO falso tras un compact en idle** — BAJO. Nota #43. Causa: `coordinar-claudes/vigilar-master.sh:18` toma como último evento `user` con `isCompactSummary` o `system` `informational`/`compact_boundary`; el fin de turno solo reconoce `turn_duration|stop_hook_summary|away_summary` (`:22`). Arreglo: excluir `isCompactSummary` y `subtype=="informational"` del selector y tratar `compact_boundary` como fin de turno. Test (`vm_estado_de` es sourceable con `_CMD_VIGILAR_SOURCE_ONLY=1`): fixture user/compact_summary → system/compact_boundary → system/informational con 20 min → `quieto` (hoy `colgado`); fixture `user/tool_result` + `attachment` sin respuesta a 20 min → `colgado`. Sin unjordi. (Hoy solo es fallback: SKILL §3 ya no lo usa por defecto.)

**B-20 · exportar-sesion-master: un master con sufijo propio (`claudio-master-3000`) no se exporta, y falla en silencio** — BAJO. Notas #55 (H12). Causa: `exportar-sesion-master.sh:74-80` `_master_base` solo acepta `*-master` y `*-master (N)`. Arreglo (decisión de bajo riesgo, tomada aquí): aceptar `*-master-<alfanumérico>` y `*-master-<alfanumérico> (N)` y, si el título termina en `-master*` pero no casa, escribir una línea `exportar-sesion-master: título '<x>' parece master pero no casa el patrón` a stderr una vez. Test: `claudio-master-3000`, `x-master (2)`, `x-master-12 (3)` → exporta con base canónica; `normalita`, `masterplan` → no. Sin unjordi. Si el sufijo `-3000` es un nombre que él quiere cambiar, el ajuste del patrón no estorba.

**B-21 · limpiar-ramas: el resumen de «remotas sin local» no cuadra** — BAJO. Nota #54 (H10). Causa: `limpiar-impl-ramas.sh:199-252` solo cuenta `rem_borradas` y `rem_cons`; AVANZÓ/no se pudo consultar/no se pudo borrar/no existe se imprimen pero no suman. Arreglo: contadores `rem_avanzo`, `rem_noconsulta`, `rem_nodel`, y resumen `examinadas = borradas + conservadas + avanzaron + sin-consulta + …` (regla «sin tope silencioso»). Test: 3 remotas (integrada, con trabajo, avanzada) → el resumen suma 3 y nombra la avanzada (hoy suma 2). Sin unjordi.

**B-22 · cerrar-slice: gitleaks `--repo` casa por subcadena y sin distinguir mayúsculas** — BAJO. Nota #66. Causa: `cerrar-slice.sh:70` `case "${url%.git}" in *"$REPO"*)`. Arreglo: anclar al final (`*[/:]"$REPO"`) y comparar en minúsculas. Test: `--repo unjordi/PowerScripts` contra origin `…/unjordi/PowerScripts-viejo.git` → NO casa (hoy casa); `Unjordi/powerscripts` contra `…/unjordi/PowerScripts.git` → casa (hoy no). Sin unjordi.

**B-23 · Widgets: etiqueta «estimado local» con basis nulo, catálogo de agentes hardcodeado y sin paridad macOS/Windows** — BAJO. Notas #67, #71. Causas: `QuotaModel.swift:445`, `limites.js:133`, `main.qml:2004`, `QuotaService.cs:198` (con `basis` retirado `cost`, nulo = «sin dato», no «estimado»); `main.qml:1213` `brainAgentNames` y `catalogo-cerebro.js:85` `agentNames` hardcodeados (cita del usuario: «intégralo y mete al backlog hacerlos dimánmicos»). Arreglo: etiqueta «sin dato»; catálogo de agentes derivado de `~/.claude/agents`, `<repo>/.claude/agents` y la lista del CLI en UNA definición (`widget-spec`), con tier Agentes en macOS y Windows. Test: snapshot con `basis` nulo → «sin dato»; agregar un `.md` a `~/.claude/agents` → aparece sin tocar código. Sin unjordi.

**B-24 · Cuatro copias de la norma de entorno con el texto viejo «jamás en un repo»** — BAJO (doc=realidad). Nota #63. Causa: `macos/Sources/Cortex/PopoverView.swift:1405`, `src/plasmoid/contents/ui/main.qml:1041`, `windows/src/Cortex/PopupForm.cs:1997`, `como-trabajar-con-usuario.example-barebones.md:14`. Arreglo: reescribir a «jamás en el repo de un proyecto ni en tu slug» y añadir al `test-brain` un grep que falle si reaparece la frase vieja fuera de `.claude/feedbackUsuarios/`. Test: `git grep -n "jamás en un repo" -- macos src windows "*.example-barebones.md"` vacío (falla hoy: 4 hits). Sin unjordi.

**B-25 · Limpieza «estrictamente utilitaria»: 2ª pasada pendiente + comentario obsoleto de limpiar-impl-ramas** — BAJO. Notas #34, #37, #15. Estado: 1ª pasada hecha (`4777871`); faltan los archivos excluidos (guards, `test-brain.sh`, `checkpoint-mecanico.js`, skills checkpoint/rehidratar/reconstruir) y los flowcharts `04`/`12` de `orquestar-fanout` (skill retirado). Medido: fechas/incidentes en `analizar-comando-git.sh` (13), `merge-develop-guard.sh` (12), `test-brain.sh` (253 líneas), `global-claude-md.md` (6). `limpiar-impl-ramas.sh:22` dice «Develop*» pero `bz_protegida` protege también `epic/*`, `integracion/*`. Arreglo: 2ª pasada solo de texto (comentarios y mensajes), gate = suite sin subir FAIL; mover el porqué a memoria/bitácora; las lápidas del MANIFEST son datos y se quedan. Test: mismo número de PASS/FAIL antes y después + un chequeo que cuente fechas ISO en comentarios de los guards (informativo, no bloqueante). Sin unjordi (lo pidió él el 2026-10-15; no cambia lógica).

**B-26 · skill to-do: HUD en el orden de la vista + 🔥 urgentes** — BAJO. Nota #30 (estado N6). Cita: «puedes actualizar el skill de /to-do para que haga eso de manera consistente? mostrar las cosas en el orden del listado que me imprimes plz». Arreglo: portar a `brain/skills/to-do/SKILL.md` la mecánica probada en axon (recrear tareas abiertas en el orden de la vista, marca `🔥N` en el subject, orden asentado en el durable). Test (fixture de TaskList + `estado-proyecto.md` con bloque «🔥 Urgente»): el orden de creación coincide con la vista; el estatus nunca va en el título. Sin unjordi.

**B-27 · coordinar-claudes: receta para `/compact` por screen** — BAJO. Nota #80. Cita: ninguna textual. Causa: `coordinar-claudes/SKILL.md:48` solo documenta `stuff "$MSG"`; un texto largo por `readbuf`/`paste` no dispara el slash. Arreglo: documentar (y ofrecer `despertar-master.sh --compact "<texto>"`) el envío en trozos de 200 caracteres con `stuff` seguido de `stuff $'\r'`. Test: función de troceo con un texto de 700 caracteres → 4 trozos, ninguno > 200, concatenados = original. Sin unjordi.

**B-28 · `glab mr create --repo <otro>` desde el cwd de otro repo falla** — BAJO. Nota #20. Causa: `glab` (no cerrar-slice) agrega un remoto y sale 3; `cerrar-slice.sh` solo pasa `-R` al merge y `SKILL.md:108` no fija el directorio. Arreglo: en el skill, la receta de abrir MR corre `git -C <clon> …`/`cd <clon>` (resolviendo el clon por `acg_clon_local_de_slug`) y un `--abrir` en `cerrar-slice.sh` que lo haga. Test: con cwd en otro repo, `cerrar-slice.sh --abrir --repo org/x` abre el MR del clon de x (hoy: error de remoto). Sin unjordi.

**B-29 · Presupuesto del listado de skills: tope de `description` y `@aliases-activos.md` duplicado** — BAJO. Nota #5 (estado A9). Causa: sin test; ~16 skills > 250 caracteres (checkpoint 1056, canonizar 1041…). Arreglo: recortar las descripciones a enrutado (el detalle va al cuerpo) y entonces añadir el test de tope (nace con su mecanismo); que `install-brain` avise si el import que inyecta ya existe a mano en la sección personal. Test: el cap-test falla con una description de 400 caracteres y pasa con 240; el aviso de import duplicado se emite con un `CLAUDE.md` que ya trae `@aliases-activos.md` a mano. Sin unjordi (inventario anclado de potenciaDatabases = decisión suya, no tocar).

**B-30 · entorno-maquina-guard: commit con pathspec avisa por lo staged ajeno** — BAJO. Notas #7 (+ corpus 2026-10-23). Causa: `entorno-maquina-guard.sh:58-64` usa `git diff --cached` aun cuando el comando es `git commit … -- <ruta>` (git solo comitea esas rutas). Reproducido: sandbox `emg-test.sh` S6 AVISA donde debía CALLAR. Arreglo: si el comando trae `--` + rutas (o `-o/--only`), limitar `staged` a esas rutas. Test: S6 calla; S3 (staged real) sigue avisando; S2 (`-a`) sigue avisando. Sin unjordi.

**B-31 · Persistir el hito «cortex se publica desde un repo nuevo»** — BAJO (registro). Nota #81. Cita: «confío en claude. y es responsabilidad de cada quién saber que los modelos LLM no son perfectos ni omniscientes.» Estado: la decisión (repo público nuevo, árbol curado con manifiesto, sin historia, distribución sin clonar, español+inglés, modelo de amenaza = errores del agente) vive solo en la nota y en un Excel de la Mac; no está en `estado-proyecto.md` («ninguna decisión se queda solo en el chat»). Arreglo: añadir a `estado-proyecto.md` una sección «Siguiente hito» con las decisiones y sus gates, y desglosarlos en ítems 📝 (manifiesto de publicación, script de release sin historia, chequeo de datos personales/secretos, distribución por plataforma, idioma). Test: n/a (registro); aceptación = grep de «repo público» en estado-proyecto. Sin unjordi.

**B-32 · reconstruir-contexto: residuos sin verificar** — BAJO. Nota #40 [SIN VERIFICAR]. Pendiente de comprobar: tope de salida de `tool_use` en el parser (`checkpoint-mecanico.js`) y un fixture `.jsonl` (compact_boundary, isCompactSummary, isMeta, task-notification, dos sesiones en el mismo slug, fuera de git) con asertos sobre lo que extrae el fallback manual del skill. Arreglo: añadir el fixture al banco `b-rc` (`test-brain.sh:11389` hoy mide plomería). Test: el fixture falla contra el fallback viejo (`ls -t`) y pasa con el actual. Sin unjordi.

**B-33 · control-gui-remota-por-ssh: texto roto y «Verificado» sin fecha** — BAJO. Nota #57 (H16). Causa: `control-gui-remota-por-ssh/win/win-ssh-screenshot.ps1:26` «el ultimo test real de HW de este kit fue (screenshot…» sin el dato; el barrido de fechas dejó «Verificado» sin fecha en `SKILL.md` y los `.ps1`. Arreglo: restaurar la fecha SOLO donde es una afirmación de verificación (la fecha es el dato) y completar la frase; la semántica de `-Window` de ese script. Test: `pwsh` parse-check de los `.ps1` y un grep que falle con «fue (» sin cierre. Sin unjordi.

**B-34 · Revisar el hardcoding de dod-verificar** — BAJO. Nota #68 (parte 4). Cita: «no sé por qué tiene tanto hardcoding, pero luego lo revisamos». Sin ítem en estado-proyecto. Arreglo: inventario de constantes y listas de léxico del hook (`dod-verificar.sh:70-140`) clasificadas en configurables/derivables/justificadas, siguiendo la norma E1/E2 del estado (defaults que inventan = «no sé»). Test: cada constante elegible tiene override por env documentado y un caso del banco que la cambia. Sin unjordi (es revisión; cualquier aflojamiento iría por B-06).

**B-35 · `seven_day` vs `weekly`** — BAJO. Nota #82. Cita: unjordi los ha visto confundirse varias veces; «unificar el nombre al unificar el fetch». Causa: `src/bin/cortex-fetch:215,261,271` lee `seven_day` del API y guarda `weekly`. Arreglo: un solo nombre canónico (`weekly`) con alias de lectura retrocompatible en los consumidores (`delegacion-comun`, widgets) y documentado en `widget-spec`. Test: snapshot con solo `seven_day` (viejo) y con `weekly` (nuevo) → mismos números en los tres consumidores. Sin unjordi.

**B-36 · Worktree `cortex-wt-quota` (8 archivos sin commit): confirmar si sigue haciendo falta** — BAJO [SIN VERIFICAR]. Nota #77. Mide `equiv_session_cost_usd` solo en `macos/bin/cortex-fetch` y `macos/Sources/…`; `delegacion-comun`, KDE y Windows no lo traen. Arreglo: revisar el worktree del usuario contra develop; si algo falta, rescatarlo por commit; si se superó (carry-forward de OAuth, `cortex-fetch:28-145`), descartarlo. Test: n/a (inventario). Sin unjordi.

## 3. Notas cerrables (el mantenedor puede crear el `.ATENDIDO` ya)

Formato: `<nota>.md.ATENDIDO` + la línea de justificación (copiable). 42 notas nuevas; 4 ya tienen `.ATENDIDO` y se confirman; 4 tienen `.ATENDIDO` con residuo real; los 2 adjuntos (`.toml`, `.py`) se cierran con su nota madre (#48 con #51/#59, #78 con #73).

### 3a. Cerrables ahora (RESUELTO / SUPERADO / INFORMATIVA)

- `2026-09-22-rehidratacion-hilo-truncado-post-compact.md.ATENDIDO` — RESUELTO: `brain/hooks/rehidratar-hilo.sh:327-360` (faro «HILO TRUNCADO» + §SIGUIENTE extraído), `brain/skills/checkpoint/SKILL.md:135` (SIGUIENTE answer-first)
- `2026-09-24-checkpoint-piso-entre-checkpoints.md.ATENDIDO` — RESUELTO: `brain/skills/checkpoint/SKILL.md:58-69` (piso 30 min con `stat` del mtime del hilo); estado A6
- `2026-09-24-skills-de-AV-sin-uso-en-esta-maquina-informativo.md.ATENDIDO` — INFORMATIVA: La propia nota: no son del brain
- `2026-10-03-barrer-ramas-borra-mini-develop-con-nombre-propio.md.ATENDIDO` — RESUELTO: `brain/hooks/ramas-zombie.sh:492` `bz_protegida` protege `epic/* epic-* integracion/* integracion-*` (el comentario de `limpiar-impl-ramas.sh:22` sigue diciendo solo `Develop*`)
- `2026-10-03-masters-contexto-irrepetible-y-equipo.md.ATENDIDO` — SUPERADO: Genérico ya en `brain/norms/global-claude-md.md:184-190`; el trato personal va a `como-trabajar-con-unjordi` (ya está, visible en el contexto de la Mac)
- `2026-10-03-merge-develop-guard-sync-upstream.md.ATENDIDO` — RESUELTO: `brain/hooks/merge-develop-guard.sh:388-457` `_es_sync_upstream_autorizado`; tests `brain/test-brain.sh:331,381`
- `2026-10-05-guard-sudo-falso-positivo-heredoc.md.ATENDIDO` — SUPERADO: sudo/pkexec: no está en `brain/`; git-branch-guard retirado (`brain/hooks/MANIFEST`, estado 2026-10-21)
- `2026-10-05-proteger-arbol-y-barrer-ramas-squash-via-mini.md.ATENDIDO` — RESUELTO: `brain/hooks/ramas-zombie.sh:9-20,315-328` señal (e) `Rama:`; cerrar-slice escribe un `Rama:` por sub-rama (`test-brain.sh:4251-4266`)
- `2026-10-07-revisor-datos-personales.md.ATENDIDO` — SUPERADO: estado-proyecto:223 (B7 FUERA por ahora, unjordi no lo eligió)
- `2026-10-09-barrer-ramas-worktree-recien-creado.md.ATENDIDO` — RESUELTO: `brain/hooks/limpiar-impl-worktrees.sh:62-84,127` (0 commits propios + reflog solo «Created» + árbol limpio = ACTIVO)
- `2026-10-09-cerrar-slice-wait-ci-no-espera-con-gh.md.ATENDIDO` — RESUELTO: `brain/skills/cerrar-slice/cerrar-slice.sh:259-310` (ROJO/INDET/PENDIENTE abortan)
- `2026-10-09-ci-develop-rojo-shellcheck-sc2148.md.ATENDIDO` — RESUELTO: `control-gui-remota-por-ssh/{linux/lib-linux-ssh-env.sh,mac/lib-mac-ssh-env.sh}:2` `# shellcheck shell=bash`
- `2026-10-09-entorno-maquina-fuente-unica.md.ATENDIDO` — RESUELTO: `brain/install-brain.sh:436-442` siembra solo `~/.claude/entorno-maquina.md` (LEAN)
- `2026-10-10-aviso-drift-guards-tier-repo.md.ATENDIDO` — RESUELTO: `drift-cerebro-comun.sh:83-110` (solo tier `both` con copia global y no dependencia de un repo-hook); `.ATENDIDO` 10-21
- `2026-10-10-dod-verificar-ok-mid-turn.md.ATENDIDO` — RESUELTO: `brain/hooks/dod-verificar.sh:217-229` (B3 `queued_command` humano). Residuo menor `ACG_MR_TIMEOUT=6s` [SIN VERIFICAR]
- `2026-10-11-guard-pgrep-f-autokill.md.ATENDIDO` — SUPERADO: estado-proyecto:222 (B6 FUERA por decisión de unjordi, cita textual)
- `2026-10-11-ramas-zombie-senal-e-sin-containment.md.ATENDIDO` — RESUELTO: `ramas-zombie.sh:287-300,374` (e) acotada por contenido
- `2026-10-14-checkpoint-borrador-compact.md.ATENDIDO` — RESUELTO: `checkpoint/SKILL.md:292-311` (sobre su contenido, ver #62)
- `2026-10-15-462-verificado-kde-mac.md.ATENDIDO` — INFORMATIVA: —
- `2026-10-15-b8-migracion-import-identidad.md.ATENDIDO` — RESUELTO: `brain/hooks/aviso-drift-cerebro.sh:57-81` (siembra en `CLAUDE.local.md` + `.git/info/exclude`); residuo ver #55
- `2026-10-15-estado-epica-desde-memoria-de-claudio.md.ATENDIDO` — INFORMATIVA: Accionables ya cubiertos: stat GNU `analizar-comando-git.sh:715-726`, roster `sesiones-master/publicar-roster.sh`
- `2026-10-15-merge-develop-guard-destino-sin-resolver-otro-repo.md.ATENDIDO` — RESUELTO: `analizar-comando-git.sh:905-925` (prompt array); mensajes honestos `merge-develop-guard.sh:672,701`
- `2026-10-15-merge-develop-guard-ignora-grant-en-vivo.md.ATENDIDO` — RESUELTO: `analizar-comando-git.sh:715-726` GNU-primero; mensaje `merge-develop-guard.sh:701`. El despliegue a la flota (release + widget) es operativo
- `2026-10-15-rehidratar-hilo-cuelga-tras-compact.md.ATENDIDO` — RESUELTO: `rehidratar-hilo.sh:56-65` watchdog 8 s fail-open (stdio a /dev/null)
- `2026-10-15-vigilar-master-falso-colgado-por-metadatos.md.ATENDIDO` — RESUELTO: `coordinar-claudes/vigilar-master.sh:7-18` solo assistant/user/system
- `2026-10-15-widget-no-refresca-al-cambiar-de-cuenta.md.ATENDIDO` — RESUELTO: `macos/Sources/Cortex/AppDelegate.swift:83-99` (30 s), `windows/src/Cortex/QuotaService.cs:415-433`, `src/plasmoid/contents/ui/main.qml`
- `2026-10-19-corpus-diagnostico.md.ATENDIDO` — RESUELTO: `no-bypass-deploy.sh:82,93` (ancla de intérprete, `~/`, `$HOME/`; sandbox: `ls foo.sh install.sh` calla, `bash -lc ./install.sh` avisa); `proteger-arbol.sh:113-121,198`; `ramas-zombie.sh:492`
- `2026-10-19-git-branch-guard-cd-a-worktree.md.ATENDIDO` — SUPERADO: git-branch-guard retirado; la lib que sobrevive ya resuelve `for…do cd wt` (sandbox `t1.sh`: rc=1 = no toca base)
- `2026-10-19-revision-1-git-branch-guard.md.ATENDIDO` — RESUELTO: sandbox `t1.sh`; `analizar-comando-git.sh:368-371` (git-common-dir), `:351` (`ssh://[^/]+/`)
- `2026-10-19-revision-2-merge-develop-guard.md.ATENDIDO` — RESUELTO: H4: pre-filtro determinista RECHAZADO por unjordi (estado:19 «no confío nada en lo determinista»); H5 `merge-develop-guard.sh:398-406`
- `2026-10-19-revision-3-secret-scan.md.ATENDIDO` — SUPERADO: secret-scan/detectar-secretos retirados (`brain/hooks/MANIFEST:102-103`, autorizado por unjordi); gitleaks lo reemplaza
- `2026-10-19-revision-4-proteger-arbol.md.ATENDIDO` — RESUELTO: `proteger-arbol.sh:113-121` (c) solo con `&&`
- `2026-10-19-revision-5-dod-verificar.md.ATENDIDO` — RESUELTO: `dod-verificar.sh:221-229` (array), `:133` (etapa/fase)
- `2026-10-19-revision-10-resto.md.ATENDIDO` — RESUELTO: `no-bypass-deploy.sh:93`; sandbox: `bash ~/x/install-brain.sh` avisa
- `2026-10-20-revision-candidatos-integracion.md.ATENDIDO` — RESUELTO: `cerrar-slice.sh:50-100`; los «restos del retiro» (`agregar-hook-cerebro`, `auditar-coherencia`) ya no mencionan secret-scan
- `2026-10-21-propuesta-estado-proyecto-en-todos-lados.md.ATENDIDO` — RESUELTO: Decidido 2026-10-22 (fila 75, `estado-proyecto-y-rehidratar`); implementado `rehidratar-hilo.sh:80-113`
- `2026-10-21-widget-cuenta-vs-estimado.md.ATENDIDO` — RESUELTO: `src/bin/cortex-fetch:28-145` `AUTH_STATE ok/expiring/expired`; relogin `PopoverView.swift:703`, `limites.js:22`, `main.qml:3584`
- `2026-10-22-barrido-no-reconoce-integracion-por-epica.md.ATENDIDO` — RESUELTO: `ramas-zombie.sh:332-360` + `test-brain.sh:3869-3883`; un `Rama:` por sub-rama `test-brain.sh:4251-4266`; dry-run `limpiar-impl-worktrees.sh:131-137`
- `2026-10-22-coordinar-timer-de-respaldo.md.ATENDIDO` — RESUELTO: `coordinar-claudes/SKILL.md:44-45`
- `2026-10-22-estado-proyecto-y-rehidratar.md.ATENDIDO` — RESUELTO: `rehidratar-hilo.sh:80-113`
- `2026-10-22-gate-auditoria-antes-de-integrar.md.ATENDIDO` — INFORMATIVA: Decisión de proceso de unjordi; sin código
- `2026-10-23-barrido-borra-worktree-de-agente-vivo.md.ATENDIDO` — RESUELTO: `limpiar-impl-worktrees.sh:62-84,127`; el incidente fue en la cachy con lib vieja (despliegue pendiente). [SIN VERIFICAR] worktree anidado `.git-worktrees/`

### 3b. Ya cerradas con `.ATENDIDO` y confirmadas por esta auditoría

- `2026-10-21-aviso-drift-sobrantes-incluye-tier-repo.md` — confirmada (`.ATENDIDO`; `drift-cerebro-comun.sh:83-110`)
- `2026-10-21-coordinar-sin-vigilantes.md` — confirmada (`.ATENDIDO` 69ede3d; `coordinar-claudes/SKILL.md:59-65`)
- `2026-10-21-ok-retirar-git-branch-guard.md` — confirmada (`.ATENDIDO` (9eec6fc…0c36bbb); `hooks/MANIFEST` lápida; `global-claude-md.md:126` --auto gobernado por el juez)
- `2026-10-21-verificar-hilo-no-ve-write-fallido.md` — confirmada (`contrato-hilo.sh:19-81` flag «fresco» (42bdcfa))

### 3c. Cerradas con `.ATENDIDO` pero con RESIDUO real — anexar la línea y NO darlas por totalmente atendidas

- `2026-10-21-norma-entorno-maquina-alcance.md.ATENDIDO` — añadir: «residuo abierto → B-24 (Norma/guard/install OK (c2d5664) pero siguen 4 copias viejas: `macos/Sources/Cortex/PopoverView.swift:1405`, `src/plasmoid/contents/ui/main.qml:1041`, `windows/src/Cortex/PopupForm.cs:1997`, `como-trabajar-con-usuario.example-barebones.md:14`)»
- `2026-10-21-revision-tiers-both.md.ATENDIDO` — añadir: «residuo abierto → B-22 (Todo RESUELTO salvo gitleaks `--repo`: `cerrar-slice.sh:70` `case "${url%.git}" in *"$REPO"*)` subcadena sin anclar ni minúsculas)»
- `2026-10-21-revision-widget-auth.md.ATENDIDO` — añadir: «residuo abierto → B-23 (`.ATENDIDO` d4ccfd1; residuo: etiqueta «estimado local» con `basis` nulo: `QuotaModel.swift:445`, `limites.js:133`, `main.qml:2004`, `QuotaService.cs:198`)»
- `2026-10-21-tiers-hooks-repo-a-global.md.ATENDIDO` — añadir: «residuo abierto → B-34 (Partes 1-3 hechas (`.ATENDIDO`); parte 4 (hardcoding de dod-verificar, «luego lo revisamos») sin ítem en estado-proyecto)»

### 3d. Se cierran al integrar su ítem (PARCIAL/ABIERTO → `.ATENDIDO` con el hash del fix)

Cada nota PARCIAL o ABIERTO de la tabla (§1) se cierra cuando su ítem B-xx entre a develop con su test; la línea de cierre es «ATENDIDO por <hash>: <ítem> — verificado con el test <nombre>». No se cierran antes.

## 4. Preguntas para unjordi (todas juntas; cada una con opciones y recomendación)

Solo las que no se pueden resolver con precisión + test. Ninguna bloquea el resto del backlog (B-01 … B-03, B-07 … B-14, B-18 … B-36 se pueden hacer ya).

**Q1 — B-04 · Grant permanente guardado en el `.claude/` del cwd (carpeta de Drive) y no en el repo destino.** El guard hoy solo busca el grant en el clon del repo de `--repo` (`merge-develop-guard.sh:636`), por eso games-master (cwd = carpeta de Drive) choca en cada merge de `armada-rp6` aunque tu grant de 2026-10-01 es explícito («todos los repos de armada y rp6… DEJA DE PEDIRMELO!!»).
- (a) Honrar también el grant del `.claude/memory/` del cwd SI trae `repos=org/a,org/b` que nombra el repo del merge, con destino develop, vigencia y veto de cita; `main` jamás. **← recomendada** (cambio mínimo al mecanismo actual).
- (b) No tocar el guard: el grant debe vivir en cada clon destino (games-master mantiene copias).
- (c) Un grant único por máquina (`~/.claude/memory/…`) con `repos=` (globs). Más limpio para grants que cruzan repos, pero es un segundo lugar de autoridad.

**Q2 — B-05 · Que Claude deposite el grant cuando se lo pides.** Dijiste: «el permiso del merge no quiero TENER que escribirlo yo, si te lo pido debería ser suficiente». Hoy `proteger-autorizaciones` y `turno-nocturno` lo impiden (solo tú, con `!`). Cambiar ESE control requiere tu OK sobre el mecanismo:
- (a) Script `depositar-grant.sh` que exige la cita literal, la verifica en un mensaje HUMANO reciente con verbo de autorización y escribe el grant; `proteger-autorizaciones` deja pasar solo ese script. **← recomendada** (conserva «solo el humano decide» sin que teclees nada).
- (b) Mantener `!`, pero que Claude te entregue SIEMPRE el comando ya armado (cita, vigencia, repos) listo para pegar.
- (c) Relajar el hook para permitir la escritura cuando el turno trae un «autorizo» tuyo (más laxo: el hook no verificaría la cita).

**Q3 — B-06 · dod-verificar frena el estatus de tooling interno cuyo QA es el dogfood del dev.** ¿Cómo declaramos qué es «tooling interno»?
- (a) Un archivo `.claude/qa-interno` por repo, escrito por ti (globs de rutas), que activa la regla «prueba funcional acordada de antemano» de la norma LISTO solo cuando el turno cita el run/probe. **← recomendada** (la decisión es tuya y versionada).
- (b) Que el juez lo deduzca por heurística (módulos puros, `axon run`, probes): más cómodo, más falsos negativos.
- (c) Sin cambio: el dev dice «verificado técnicamente» (esa redacción ya pasa).

**Q4 — B-15 · proteger-autorizaciones y el glob.** Con la versión de develop los FP por menciones y heredocs ya pasan; queda frenado un script que recorre `memory/*.md` y escribe solo los que contienen cierto texto (el glob incluye el archivo de grants).
- (a) Mantener el bloqueo (decisión del 2026-10-23: cubre globs) y registrar el FP como aceptado.
- (b) Dejar pasar el glob salvo que el patrón nombre literalmente el archivo de grants. **← recomendada** (tu modelo de amenaza: errores del agente, no evasión; el caso real es un script legítimo).
- (c) Permitir cualquier glob.

**Q5 — B-16 · Bloqueos del clasificador de auto-mode que te llegan.** ¿Qué hacemos del lado del cerebro?
- (a) Opt-in en `install-brain` (con tu confirmación) que siembra SOLO `Read(~/.claude/projects/**)`, más una línea en la norma «Integridad de los guardarraíles»: un bloqueo del clasificador se reintenta/rodea por otra vía legítima y se reporta en una línea. **← recomendada** (no se siembra `Edit` sobre la memoria: el bloqueo por «Instruction Poisoning» protege justo la memoria que gobierna a Claude).
- (b) Solo la norma, sin tocar `settings.json`.
- (c) Sembrar también `Edit(~/.claude/projects/*/memory/**)` y `Bash(ssh …)` como propuso databases-master (más cómodo, abre el hueco que el clasificador cuida).

**Q6 — B-17 · Candado de OS para la fuente del cerebro (usuario `claude` dueño de lo intocable).**
- (a) No por ahora: queda como idea registrada; el hook advisory + el chequeo de rutas bastan para errores.
- (b) Usuario dedicado `claude` + `sudo -u claude` en el updater: protege de verdad, pero cuesta mucho en macOS/Windows y complica el updater.
- (c) Opt-in ligero: bandera de inmutabilidad de archivos intocables (`chflags uchg` en macOS; en Linux solo con root) que impide edición accidental por las tools del agente, y el updater oficial la quita/pone; sin usuario nuevo. Protege errores (tu modelo de amenaza), no evasión. **← recomendada**, empezando por macOS y midiendo contra el updater antes de decidir Linux.

## 5. Patrones transversales (raíz de diseño compartida)

1. **Razonar sobre el AMBIENTE en vez del SCOPE AUTORITATIVO de la acción** (ya nombrado en la nota #3; reaparece en B-03 mtime vs commit de origen, B-04 cwd vs repo destino, B-09 bitácora del cwd/worktree, B-22 `--repo` por subcadena, B-30 index completo vs pathspec, B-12/B-13). Arreglo de fondo: UNA función en la lib compartida (`analizar-comando-git.sh`) que resuelva `{repo, clon, rama, rutas afectadas}` por git en el chokepoint, y que todo guard/barrido la consuma; un lint de `test-brain.sh` que falle si un hook usa `$PWD` o `git rev-parse --show-toplevel` sin pasar por ella (cada hallazgo lo cubre con su test; el lint evita la reaparición).
2. **Estado de proceso de los hooks dentro del repo** (B-08, B-09; A5/N1 diseñado y aprobado desde el 2026-10-12, sin ejecutar). Arreglo de fondo: helper único `estado_dir()` → `~/.claude/state/<cksum-ROOT>/` con migración; test que corra todos los hooks en un repo y exija `git status --porcelain` vacío.
3. **Los arreglos nacen en el brain y no llegan a la flota** (B-02, B-03; incidentes #6, #39, #79 corrieron sobre copias viejas — la cachy con lib del 22-sep, 5 de 6 repos con el dod viejo). Arreglo de fondo: sellar el SHA de lo instalado (B-03), detectar obsolescencia de hooks tier `repo` también en repos personales (B-02) y que el updater del widget verifique tras actualizar («esta máquina corre a218cd9 / develop va en X»). Corolario: durante esta auditoría las copias INSTALADAS de `proteger-autorizaciones` y `git-branch-guard` frenaron comandos míos que solo mencionaban sus palabras clave, mientras que las versiones de develop pasan los mismos comandos (sandbox `pa-test.sh`).
4. **Pruebas que miden plomería o dependen del entorno real** (B-11: HOME real con credenciales, `glab` real en `/usr/bin`; b-rc mide cableado; ya en estado F1-F4). Arreglo de fondo: el arnés fuerza `HOME`/`PATH`/`CLAUDE_CONFIG_DIR` de sandbox para TODA la suite (no caso por caso) y falla si un caso lee fuera.
5. **Decisiones/estado sin ítem durable** (B-31 hito de publicación, B-34 hardcoding de dod, 3 notas con `.ATENDIDO` y residuo). Arreglo de fondo: la regla de cierre de una nota del buzón pasa por `cerrar-slice` (§ pendiente: «lo que no se hizo va a estado-proyecto con ID») y `.ATENDIDO` solo se escribe con el ID del residuo si lo hay.
6. **Guards que casan TEXTO en vez del comando que se ejecuta** (menciones/heredocs en proteger-autorizaciones, no-bypass-deploy, git-branch-guard, no-sudo). La mayoría ya está arreglada en develop; el residuo (glob, pathspec) es B-15/B-30. Arreglo de fondo: un parseo común de «segmentos ejecutables y destinos de escritura» (ya existe `acg_segmentos_ejecutables`) como única fuente, con el corpus de FP como banco de regresión de TODOS los guards que lo usan.

## 6. Correcciones al estado-proyecto y al encargo (medido)

- Estado desfasado: **N5** figura «pending» pero `verificar-firma-canonica.sh:119` ya trae el NUCLEO_RE ampliado; **A4** figura «HECHO» pero `_master_base` no cubre el patrón `-master-<sufijo>` (B-20); **A8** parte de una premisa que la decisión del 2026-10-14 (roster por máquina) ya cambió y su causa concreta es la precedencia alfabética de hosts (B-10); **N6/A9/N1/A5** siguen pending y coinciden con B-26, B-29, B-08.
- El encargo decía que las 8 notas con `.ATENDIDO` se tratan como cerradas salvo residuo: 4 se confirman (aviso-drift-sobrantes, coordinar-sin-vigilantes, ok-retirar-git-branch-guard, verificar-hilo) y 4 tienen residuo real (norma-entorno-maquina-alcance, revision-tiers-both, revision-widget-auth, tiers-hooks-repo-a-global).
- Premisa del encargo confirmada: git-branch-guard, secret-scan y detectar-secretos están retirados (`brain/hooks/MANIFEST:102-104`); sus quejas son SUPERADAS salvo donde la lib compartida sigue viva (verificado: H1-H3 de la revisión 1 ya resueltos en `analizar-comando-git.sh`).

## 7. Falsos positivos observados durante esta auditoría (para `docs/guards-falsos-positivos.md`; yo no podía escribir fuera de `salida/`)

- 2026-10-27 · proteger-autorizaciones (copia instalada en la Mac) · `cat > script.sh <<EOF` cuyo contenido eran comandos de PRUEBA (`echo x >> …<archivo de grants>`) como DATO, para probar el propio guard · el heredoc solo escribe un script de prueba; el guard casó el texto, no un destino de escritura. (La versión de develop a218cd9 pasa los comandos de mención: `salida/sandbox/pa-test.sh` FP6/FP7.)
- 2026-10-27 · proteger-autorizaciones (copia instalada) · script que escribía una tabla `.md` con la palabra «autorizaciones» en el contenido · pre-filtro por token demasiado ancho.
- 2026-10-27 · git-branch-guard (copia instalada; el guard está retirado en develop) · comando de prueba `bash -c "… git <push> …"` con el texto como dato en un `for` · era una cadena de prueba, no un push (frenó mi sandbox de `acg_push_toca_base`).

## 8. Sin verificar (resumen)

- B-14: el numerador de `aviso-contexto` (imágenes) — no reproducible sin el transcript de la sesión de heimdall-net.
- B-18: el error de Node de `checkpoint-mecanico.js` en la cachy — la nota no lo trae.
- B-11: el diagnóstico de los 3 FAIL de la cachy se basa en lectura de `test-brain.sh`/`juez-comun.sh`; no se corrió la suite allí.
- B-32: tope de `tool_use` y fixture del fallback manual de reconstruir-contexto.
- B-36: contenido del worktree sin commit `cortex-wt-quota` (está en la máquina de unjordi).
- Fila 27: `ACG_MR_TIMEOUT=6s` para `glab api` (no medido).
- Fila 79: el worktree anidado `.git-worktrees/` del `axon run` (el incidente fue en la cachy con la lib vieja); el código actual protege la rama recién nacida por `rev-list` + reflog, no por proceso vivo.
- Filas 26/46: la comparación «criterio por contenido» de proteger-arbol tras squash no se releyó; la decisión vigente (L11, `proteger-arbol.sh:187-199`) conserva el aviso cuando la base local va por delante.
- No se corrió `test-brain.sh` completo (no es seguro fuera de un sandbox dedicado); todo lo ejecutado fue en `salida/sandbox/` con HOME falso: `t1.sh` (push desde worktree), `dewire-test.sh` (B-01), `pa-test.sh` (B-15), `emg-test.sh` (B-30), `h2` (no-bypass-deploy), `h3` (andamio).

## 9. Decisiones de unjordi sobre la sección 4 (2026-10-27, relevadas por claudio-master)
- Q6/B-17: DESCARTADO [user: "no me gista ni una ni otra, suena a más gates"].
- Q5/B-16: sin sembrar permisos en install; solo la norma [user: "no sé por qué necesitamos hacer tanta maroma para que puedas hacer lo que te pido"].
- Q1/B-04: precisión, sin pregunta. El destino ya se resuelve por git (decisión del 2026-10-21); el guard además lee el grant del .claude/memory de la sesión cuando nombra el repo resuelto. Solo develop.
- Q2/Q4: en espera. unjordi sobre proteger-autorizaciones: [user: "no me cae bien. ni recuerdo haberlo pedido y cada día me cae peor"]. Nació de la auditoría R1–R7 de #470, no de un pedido suyo. Pendiente: confirmar si se retira.
- Q3: abierta.
- **Q2/Q4 decididas por claudio-master con delegación expresa** [user 2026-10-27: "¿Retiro proteger-autorizaciones? te lo dejo a tu juicio"]: SE RETIRA proteger-autorizaciones (tier retirado en el MANIFEST + desinstalación en las máquinas y las copias por-repo). Claude escribe el grant cuando unjordi se lo pide (decisión del 2026-10-26; ajustar turno-nocturno §5 y quitar el one-liner `!`). Queda el control que unjordi sí conservó: merge-develop-guard honra el grant solo si su `cita=` casa con un mensaje HUMANO real (_grant_cita_verificada), sin cambios a ese chequeo. B-05 y B-15 se cierran con este retiro.
- **Q3/B-06 decidida** [user 2026-10-27: "¿Dejamos dod-verificar sin cambio? a mí me suena a parche"]: no hay archivo de marca nuevo ni redacción para esquivar el hook. dod-verificar aplica el acuerdo que ya existe: «QA de tooling interno = prueba funcional (él no lo invoca)» (como-trabajar) = la «prueba funcional acordada de antemano» de la condición (1) de LISTO. El juez recibe esa regla: si el cambio es tooling que el usuario no invoca (hooks, harness, scripts y módulos del dev) y en el turno hay un tool_result con la corrida funcional real (no un test de plomería), el cierre cumple (1). Prueba en las dos direcciones: pasa un cierre de tooling interno con la corrida real en el turno; frena el mismo cierre sin corrida, uno que solo cita «tests verdes» y un cierre de una feature que el usuario usa.

## 10. Revisión del 2026-10-28 (claudio-master) — 3 notas que el triage no vio + estado de los buzones
Venían trackeadas en develop y entraron al ff de hoy; el triage de ayer solo leyó lo untracked de la Mac. En la cachy no hay notas nuevas desde ayer; sus 5 ya están en la Mac.

- **2026-10-03-master-con-sufijo-no-se-exporta** — PARCIAL, se sube a **ALTO** (es B-20 / A4-residuo, con evidencia viva):
  - hueco 1: `exportar-sesion-master.sh:74-77` ya quita ` (N)`, pero solo si la base termina en `-master`;
  - hueco 2 (linaje en masters.json): SUPERADO por la Opción A del 2026-10-14 (`:31`, el hook no escribe masters.json);
  - **medido hoy:** la sesión de claudio-master se llama «claudio-master-3000 (2)» (id 1ec79b0c) y **no tiene ninguna copia en ~/claude-sessions** (0 archivos con su id). La sesión principal de unjordi no se está respaldando;
  - hueco 3 (vigía que avise «eres *-master y no te exportas»): ABIERTO.

  Arreglo: aceptar `*-master-<sufijo>` y `*-master-<sufijo> (N)`, con test en las dos direcciones (`mi-master-plan.md` no exporta), y el vigía.
- **2026-10-19-hilo-stale-al-rehidratar-desde-axon** (punto 1; los puntos 2 y 3 son de axon) — PARCIAL, MEDIO:
  - `rehidratar-hilo.sh:215-240` marca obsoleto por otra rama o por mtime > 12 h;
  - no compara la fecha del hilo contra la última línea de `bitacora.md` ni contra la mtime de `estado-proyecto.md`, que es el caso de la nota (el hilo del 08-06 con trabajo posterior en la misma rama).

  Arreglo: si la bitácora o el estado son más nuevos que el hilo → «⚠️ HILO STALE (hilo X < bitácora Y): manda estado-proyecto». Test con fixture de fechas.
- **2026-10-20-limpiar-personal-dejaria-sin-dod-y-ruido-del-statusmessage** — PARCIAL, BAJO:
  - punto 1: RESUELTO por la excepción N4 y el `.ATENDIDO` de aviso-drift-sobrantes (los tier `repo` ya no salen como sobrantes);
  - punto 2: en brain/ ya nadie cablea `statusMessage`, pero los `settings.json` por-repo existentes lo conservan. Medido: plantilladotnet trae `"DoD: verificando evidencia antes de cerrar"` y `"Guard: norma de git"` (este último es de git-branch-guard, que se va con el retiro en los repos compartidos).

  Arreglo: que `sincronizar-cerebro --apply` quite el `statusMessage` de las entradas que cablea.
- **recordar-cosechar (lo que arregló axon-master):** #471 y #472 ya están en develop a218cd9. Medido hoy: las copias global Mac, global cachy, plantilladotnet, AdminGastos y pisamrpclaude = develop. Lo otro que tuvo que arreglar ahí mismo fue B-01 (`--limpiar-personal` descableó `dod-verificar` en axon; lo recableó con `--only`). Ya está en la rama `fix/buzon-dewire-hook`.

## 11. Reorden por IMPACTO EN EL TRABAJO DE LOS CLAUDES (y por eso en unjordi) (2026-10-28) — manda sobre la severidad técnica
[user 2026-10-28: "el criterio es cómo te afecta a ti, y por eso me afecta a mí!"] Lo que frena, confunde o hace repetir trabajo a los Claudes (merges frenados, avisos en falso, el widget que miente sobre la cuota, el /compact que repite el hilo) se lo cobra a unjordi en tiempo y cuota.
[user 2026-10-28: "no sabía que habían mandado para el final las cosas que más me joden"; "ni siquiera estoy seguro de que esos pendientes realmente sean todos válidos!"]
La severidad del auditor midió el daño técnico (pérdida de datos, guard que deja pasar). Para ordenar el trabajo manda la fricción diaria de los Claudes. **Antes de tocar cada ítem, revalidarlo contra develop actual**; el triage es del 27-oct y varios ya podrían estar resueltos.
1. Widget: mide mal al despertar (nota del 28-oct) + B-23 (estimado sin dato real) + B-35 (`seven_day`/`weekly`) + updater que no instala desde develop.
2. B-07: borrador de /compact sin eco (unjordi lo pidió el 21-oct).
3. Fricción en los merges: B-04 (grant desde otra carpeta; MEDIDO VIVO el 28-oct: pisamrp_4.6 desde cwd plantilladotnet → freno, con `cd` literal → honra), B-28 y B-22.
4. Avisos en falso: B-30.
5. B-26: to-do en orden + 🔥.
Después, el resto por severidad.
- **B-18 revalidado el 28-oct: NO reproduce.** En la cachy, `node ~/.cortex/bin/checkpoint-mecanico.js --self --ensure` da rc 0 y escribe el andamio. La causa probable era el `ls`→eza bajo zsh, que la skill ya rodea con su `for`, y desde hoy Claude corre bash en la cachy. Se cierra como RESUELTO. Nota aparte: en la cachy el .js solo está en `~/.cortex/bin` (238313a, 19-oct) y no en `~/.local/bin`; se actualiza con el próximo install.
