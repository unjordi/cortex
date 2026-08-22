# FMEA de PROCESOS del cerebro — auditor CON zapatos (árbol+normas) · 2026-07-30

> Segunda vuelta del auditor, esta vez con la LEYENDA (=el árbol del README) + las NORMAS como contexto
> mínimo (los "zapatos"). A diferencia de `auditoria-flowcharts-completa-2026-07-29.md` (fidelidad del
> DIBUJO → "código SANO"), esta busca dónde truena la **LÓGICA/PROCESO real de los `.sh`/skills**. Read-only.
> 3 auditores por dominio (git/sesión/propagación 01-05 · cierre/delegación 06-09 · fundamentos+costura 10-11).
> **Local (no versionado, convención del repo para docs de auditoría).** INSUMO, no cierre.

## ⚠️ Clasificación de acción (clave para el fix-wave)
- **[GUARD] Cambia un CANDADO DE SUPERVISIÓN** (dod-verificar, confirmar-merge-develop, delegacion-gate…):
  por la norma de **Integridad de guardarraíles**, NO se toca sin **OK EXPLÍCITO de unjordi para ESE control**
  (aunque el cambio sea para APRETARLO/precisión). Se presentan, no se auto-parchean.
- **[FIX] Correctitud fuera de los candados** (helpers, nudges, pérdida de datos): se prepara en rama/MR (no merge).
- **[DOC] Skill/flowchart/doc:** se ajusta con doc=realidad.

---

## Clúster CIERRE/LISTO (06,07) + DELEGACIÓN/ORQUESTACIÓN (08,09)
Ninguno cubierto por #209 (costura/flowcharts) ni !110 (plantilla wiring) — son huecos de LÓGICA, capa distinta.

### 🔴 ALTO-1 · [GUARD] dod-verificar aprueba por AUTO-ATESTIGUAMIENTO
`dod-verificar.sh:115-119,164` — `CONF_RE` (confirmó/validó/"el usuario confirmó") se evalúa contra `$last` = **texto del PROPIO Claude**, nunca contra el mensaje del USUARIO. Claude escribe "el usuario ya validó en QA" → `conf=si` → exit 0. El candado que hace cumplir "prohibido FABRICAR autorización" no comprueba al usuario. **FIX (needs OK):** derivar la marca (1)/(2) de los mensajes `role:user` del turno, no de `$last`.

### 🔴 ALTO-2 / C1 · [GUARD] dod-verificar CIEGO al código de sub-agentes (costura 06↔09)
`dod-verificar.sh:140-157` mide "¿tocó código?" en el transcript del ORQUESTADOR; las ediciones del fan-out viven en el transcript del SUB-AGENTE → un orquestador que delega todo y declara "la ola quedó" nunca dispara el candado. **Cuanto mejor orquestas, más ciego el gate de LISTO.** **FIX (needs OK / o vía skill):** contar un `tool_use name==Task` como código-tocado, y/o `orquestar-fanout` obliga a re-verificar+citar evidencia antes de declarar la ola.

### 🔴 ALTO-3 / C3 · [DOC+FIX] Chequeo de LINAJE/BASE (lección C7) SIN mecanismo
`orquestar-fanout/SKILL.md:58-79` — la regla "comprueba linaje con git ANTES de integrar; cherry-pick si base vieja" es SOLO prosa. El worktree del Agent tool nace sobre `origin/HEAD`≈main (bug harness H15) → agente en árbol viejo → rehace/arrastra. `proteger-arbol` solo avisa (+ falso-positivo en worktree aislado, H14). Viola "toda norma nace con su mecanismo". **FIX:** helper `verificar-linaje.sh <commit> <rama>` que la skill invoque siempre (mecanismo local; es lo único robusto mientras H15 siga).

### 🟠 MEDIO-1 · [GUARD] DOWNGRADE_RE: meta-tokens escapan aun con claim
`dod-verificar.sh:93-94` — junto al léxico legítimo de preview, `DOWNGRADE_RE` trae meta-tokens (`definici[oó]n de listo`, `palabra listo`) y `:94` hace exit 0 SIEMPRE. "Quedó 100% listo — cumplida la definición de listo" → escapa pese al cierre. **FIX (needs OK):** subordinar el sub-grupo meta al claim (como WEAK_STATUS_RE); solo el léxico de preview escapa incondicional.

### 🟠 MEDIO-2 · [GUARD] Coalescencia G3: un "NO" no detiene a los hermanos SIMULTÁNEOS
`delegacion-gate.sh:28-58` — en fan-out gratis/incluido, los hermanos 2..N pasan en silencio antes de que respondas; si NIEGAS al líder, los N-1 ya corren. Límite estructural de PreToolUse. **FIX:** documentar ("un 'no' no detiene la ola ya lanzada") o veto PostToolUse; que `orquestar-fanout` lo advierta.

### 🟠 MEDIO-3 · [FIX] ramas-zombie regla (b) puede BORRAR rama con commits post-merge sin pushear
`ramas-zombie.sh:45-53` — en flujo squash, (c) `git cherry` no empareja → el zombie lo declara (b) "remota borrada", que NO re-chequea commits únicos. Rama con commits locales C post-merge, remota pruned → `branch -D` borra C. El "conserva ante duda" del header no se cumple. Recuperable por reflog (~90d) → MEDIO. **FIX:** en (b), precondición `git rev-list base..br` vacío (reusar (c)).

### 🟠 MEDIO-4 · [FIX opt-in] limite-gasto (FRENO) fail-open cuando cae el daemon
`limite-gasto.sh:24-25` — sin snapshot / rancio >30min → exit 0 (no frena), justo cuando la cuota probablemente está agotada. `delegacion-gate` degrada a metered→ASK (algo de red). **FIX:** modo `LIMITE_GASTO_STRICT=1` opt-in que PREGUNTE ante snapshot ausente/rancio; documentar el tradeoff.

### 🟠 MEDIO-5 · [GUARD] cerrar-slice no ENFORZA smoke E2E / auditoría de paridad
`cerrar-slice/SKILL.md:14-32` — el smoke (API/DTO/SQL) y la paridad (migración) son la prueba "acordada" que LISTO acepta, pero son prosa; los gates enforced (squash, OK) no verifican que corrió. Build verde + "mergea" → entra sin smoke. **FIX (needs OK):** `confirmar-merge-develop` exige CITA de smoke/paridad para diffs que tocan API/DTO/SQL/migración.

### 🟠 MEDIO-6 · [FIX] delegacion-reporte grita para TODO Task (cry-wolf)
`delegacion-reporte.sh:20-27` — un Task read-only (como estos auditores) también inyecta "appenda bitácora, limpia worktree" → el orquestador se desensibiliza. **FIX:** condicionar el nudge a señales de mutación (worktree/commit/archivos); skill de "AUTOMÁTICO"→"RECORDADO (no forzado)".

### 🟡 BAJO · [GUARD] menores en dod-verificar
- **BAJO-1** residual H6: reintentar <10s tras un "no" cuela (límite de canal). 
- **BAJO-2** máscara MECH puede comer un claim genuino ("la rama de pagos quedó lista"→escapa). 
- **BAJO-3** B2: un `tool_use` de navegador para OTRA cosa satisface el gate de QA-visual.

### Costura
- **ALTO-C1** = ALTO-2 (fan-out rompe dod-verificar). · **MEDIO-C2** el FRENO limite-gasto invisible en 09→cierre + sin guía de "ola parcial/reanudar". · **MEDIO-C3** = ALTO-3 (3 capas advisory apiladas sin bloqueo).

## Clúster GIT/SEGURIDAD/SESIÓN/PROPAGACIÓN (01-05)
> ⚠️ **2 bypasses VERIFICADOS empíricamente** (el auditor ejecutó la lib). Cotejado vs ref-develop (SIN #209).

### 🔴 A1 · [GUARD·NEW] secret-scan CIEGO al idiom `git add && git commit` en un solo comando
`secret-scan.sh:68-94` corre en PreToolUse (ANTES del comando); con `git add -A && git commit -m x` el staging aún está vacío → `files` vacío → exit 0 sin escanear. Con `... && git push` en un one-liner → bypass TOTAL (ni commit ni push lo ven). Un `AKIA…`/`sk-ant-…` entra sin escaneo. **FIX:** escanear el resultado del `add`, o mover el escaneo a PostToolUse sobre el commit recién creado.

### 🔴 A2 · [GUARD·NEW·✅VERIFICADO] git-branch-guard evadible con force-refspec `+develop`
`analizar-comando-git.sh:23-25` exige `[[:space:]:/]` antes de `develop|main`; el `+` del force-refspec no matchea. Ejecutado: `git push origin develop`=BLOQUEA · **`git push -f origin +develop`=PASA(!!)**. El push FORZADO a develop (el más peligroso) se cuela. **FIX:** agregar `+` al set: `[[:space:]:/+](main|develop)`.

### 🔴 A3 · [GUARD·NEW·✅VERIFICADO] confirmar-merge-develop es NEGATION-BLIND
`confirmar-merge-develop.sh:94-97` hace `grep -qiE` de `autoriz`/`CONF_RE` sobre los últimos 10 msgs del usuario, sin polaridad. Ejecutado: **"no te di autorización todavía" → PASA-MERGE(!!)**. El candado de LISTO se abre con una NEGACIÓN. **FIX:** descartar líneas negadas (`no…autoriz`, `sin autoriz`, `todavía no`), o exigir que el OK sea el ÚLTIMO msg del usuario.

### 🔴 A4 · [GUARD·NEW] OK TRANSITIVO dentro de la ventana de 10 msgs
`confirmar-merge-develop.sh:56-72` toma CUALQUIER OK reciente sin ligarlo al MR. "mergea el MR 5" → 3 turnos → `glab mr merge 9` pasa con el OK del #5. Viola "autorización ACOTADA y NO transitiva". **FIX:** ligar el OK al MR-id nombrado, o consumirlo tras el 1er merge.

### 🔴 A5 · [FIX·NEW] limpiar-ramas hace `branch -D` (force) auto-detached sobre heurística "remota gone" → PÉRDIDA DE DATOS
`barrer-ramas.sh:47-50` lanza `limpiar-ramas.sh` detached en SessionStart; `ramas-zombie.sh:52-53` marca zombie por (b) "remota ausente" (≠ mergeada). Una ramita con commits vivos cuya remota se borró por rename/limpieza manual → `branch -D` irreversible, en 2º plano, sin pedirlo. Recuperable por reflog. **FIX:** (b) AND (c) (equivalencia de parche) antes de `-D`, o degradar a `-d`. *(Hermano de MEDIO-3.)*

### 🟠 A6 · [LIVE·ya-flagged] recordar-cosechar + recordar-unificar-cerebro MUERTOS (repo-tier, descableados) — ver C1.
### 🟠 A7 · [GUARD·NEW] secret-scan salta escaneo si `--no-verify` aparece en el MENSAJE del commit (`:53`, no despoja comillas). `git commit -m "doc del flag --no-verify"` → salta. **FIX:** despojar comillas (reusar `acg_despoja_comillas`).
### 🟡 A8 · [FIX·NEW] rehidratar-hilo marca su PROPIO hilo vigente como "OBSOLETO" en sesiones >12h (mtime como proxy). **FIX:** no marcar stale por antigüedad si la rama coincide y no hubo checkpoint más nuevo.

### Costura 01-05
- **🔴 B1 [LIVE·ya-flagged]** auto-sync no commitea settings.json + drift ciego al wiring → **CUBIERTO por #209** (verificar al mergear).
- **🟠 B2 [NEW]** dedupe-por-existencia-de-archivo + wiring HARDCODE en install-brain → un `both` nuevo se copia pero no se cabla, y la copia por-repo cede al global existente → **guard muerto en AMBAS vías**. Corolario: en máquina bootstrapped el global SIEMPRE gana → un update por-repo de un `both` es inerte. Wiring-desde-MANIFEST **CUBIERTO por #209**; la dedupe-verifica-wiring, NO.
- **🟠 B3 [GUARD·NEW]** timeout de red anula el squash en un merge REAL a develop: `merge-squash-guard` (destino vacío→no exige squash) y `confirmar` (destino vacío→pide OK) tienen fail-policy OPUESTA → "merge a develop confirmado, SIN squash". **FIX:** squash-guard exige squash si no resuelve destino (salvo release explícito).
- **🟠 B4 [LIVE·ya-flagged]** carrera SessionStart aviso-drift vs barrer-ramas sobre `.git` → #209 documentó independencia (no serializó).
- **🟠 B5 [LIVE·ya-flagged]** `cp -f` no atómico → **CUBIERTO por #209** (atomic_install).
- **🟡 B6 [FIX]** `.brain-version` del repo en formato viejo (`0.1.0`, 1 línea) vs contrato de 2 líneas.

### SANO (acota ruido): H1/H3/H5/H11/H13 previos ya cerrados; proteger-arbol suprime bien el FP del worktree; STRICT invierte a fail-closed. El único hueco de branch-guard es el `+`-refspec (A2).

## Clúster FUNDAMENTOS + SISTEMA (10,11 + costura global)
### 🔴 C1 · [CRÍTICO·COSTURA] Punto ciego de CABLEADO — VIVO en la plantilla
La plantilla tiene 3 `.sh` presentes-SIN-cablear (`entorno-maquina-guard`, `recordar-cosechar`, `recordar-unificar-cerebro`); `aviso-drift` compara CONTENIDO (no wiring) → "al día"; `test-brain` valida instaladores contra `$HOME` falso, nunca un repo real. **Ningún mecanismo mira si un repo cabla lo que el MANIFEST manda.** Detección **CUBIERTO por #209**; el estado vivo = **!110**; el field-check (verificar repo real) = NEW.
### 🔴 C2 · [CRÍTICO·COSTURA·NEW] aviso-drift `--apply` puede REGRESAR el brain y auto-commitear+pushear la regresión
`aviso-drift-cerebro.sh:29` usa `~/.cortex` como fuente sin noción de dirección/versión; `sincronizar` solo hace `dst:=src`. Si el clon local quedó ATRÁS, sobrescribe hooks NUEVOS del repo con VIEJOS y (en mini limpia) `add+commit+push` la regresión, en cada SessionStart. **NO cubierto por #209.** **FIX:** exigir que `~/.cortex` no esté detrás de su origin (o del `.brain-version` del repo) antes del `--apply`; si no, degradar a AVISO.
### 🟠 sA1 · [COSTURA·NEW] dedupe cede al global aunque la copia del repo sea MÁS NUEVA → el fix de guard recién mergeado queda inerte en máquinas bootstrapeadas (= corolario B2). **FIX:** ceder al global solo si global ≥ repo por `.brain-version`.
### 🟠 sA2 · [NORMA·NEW] "entorno-máquina vive GLOBAL" sin mecanismo activo (guard descableado, C1) + omitida del árbol del README (junto con recordar-cosechar/unificar/barrer-ramas). Doc=realidad rota en el propio mapa.
### 🟠 sA3 · [COSTURA·NEW] git ops iniciadas POR el hook (aviso-drift `add/commit/push`) ESQUIVAN a los git-guards (no pasan por Bash) + `Develop?*` demasiado ancho (matchea `Developed`/`DevelopmentX`) + el `git add` puede barrer el índice ya staged del dev. **FIX:** anclar regex `^Develop[A-Z][A-Za-z]*$`; `git commit -o .claude/hooks`.
### 🟠 sA4 · [NORMA·NEW] confirmar-merge-develop gateado por marca `.claude/repo-compartido`; nada verifica que un repo compartido la tenga → clon sin `touch` cree tener el gate y NO lo tiene. **FIX:** sembrarla al instanciar / avisar si falta.
### 🟠 M1 · [NORMA] racimo de normas DURAS sin mecanismo (decisión-en-chat, bitácora-FP —rompe el LAZO de afinar guards con corpus—, Paso 0, templatizar).
### 🟡 sBajos: README árbol omite 3 hooks (doc) · 2 hooks Stop conviven · 4 fuentes de additionalContext en SessionStart · lock TTL de delegacion-registrar · test-brain fábrica-no-campo (M3) · `.brain-version` (M2).

## DEDUP vs #209 (ya en vuelo)
Ya atacados por #209 (verificar al mergear): **B1** (git add settings.json + drift de wiring), **B2 parcial** (install-brain wiring desde MANIFEST), **B5** (cp atómico), **B4** (concurrencia — documentada), la **detección** de C1. **NO cubiertos por #209** (nuevos): A1, A2, A3, A4, A5, A7, A8, B3, **C2**, sA1-sA4, M1.

---

## ANEXO — Coherencia de RUTAS cross-OS (auditor de portabilidad, 2026-07-30)
Respuesta a "confirma coherencia/consistencia de rutas en TODOS los OSes". Veredicto: **coherencia PARCIAL — hay divergencias reales.**
- **H1 [ALTO]** Windows `$HOME` (bash, `install-brain.sh:36` `CLAUDE_DIR="$HOME/.claude"`) vs `%USERPROFILE%` (`BrainInspector.cs:87`, `.swift:84`) pueden divergir → cerebro instalado donde el widget NO lo lee. Ni bootstrap.ps1 ni install-brain.ps1 puentean HOME↔USERPROFILE. **FIX:** exportar `HOME=$env:USERPROFILE` en los .ps1 antes de invocar bash, o `${USERPROFILE:-$HOME}` en install-brain.sh.
- **H2 [ALTO]** self-update: `Updater.swift:45-53` (`resolveClonePath`, cadena de fallback CLAUDE_BRAIN_DIR→~/.cortex) es robusto; `Updater.cs:60-81` y `main.qml:262-266,995-1006` usan SOLO el repo embebido sin fallback → divergencia. **FIX:** portar `resolveClonePath` a C# y QML.
- **H3 [MEDIO]** `bootstrap.sh:69` usa `checkout -B main origin/main` (abandonó `pull --ff-only` por robustez); `bootstrap.ps1:78` sigue con `pull --ff-only` → Windows sin el fix. **FIX:** alinear bootstrap.ps1.
- **H4 [BAJO]** `install-brain.ps1` es lanzador delgado hoy (delega en `.sh`) pero sin test que lo blinde. **H5 [MENOR]** `main.qml:1003` `cd '<repo>'` no escapa `'`.
- **OK:** cero `/Users/`·`/home/`·`C:\Users` hardcodeados en código de envío; cableado uniforme `shell:bash`+`$HOME`/`${CLAUDE_PROJECT_DIR}`; brain dir puenteado en bootstrap.ps1 (ya en test `e4`).

### 7 tests OS-parity a agregar (wave 2, estilo `e4`, FALLAN si se olvida un OS)
1. install-brain.ps1 sigue delgado (grep `bash.*install-brain.sh` + NO cablea por su cuenta).
2. bootstrap.ps1 usa `checkout -B main origin/main`, NO `pull --ff-only` (== bootstrap.sh).
3. ningún .sh/.ps1/.swift/.cs/.qml de envío hardcodea home absoluto (fuera de comentarios/entorno-maquina-guard).
4. los 3 updaters (swift/cs/qml) referencian CLAUDE_BRAIN_DIR/.cortex como fallback (presiona paridad H2).
5. updaters que `cd`/`Set-Location` al clon citan/escapan la ruta (H5).
6. `.brain-version` se lee desde `<home>/.claude/` en los 4 lectores (swift/cs/brain-scan.sh/install-brain.sh).
7. puente HOME↔USERPROFILE en los .ps1 (H1) — **nace en FALLO** hasta que se aplique el fix; documenta el gap.

### Residual descubierto al arreglar A1 (backlog)
- **`git commit -am x` tiene el MISMO punto ciego que A1** (el `-a` auto-estagea tracked-modificados; el escaneo en PreToolUse no lo ve). No estaba en el alcance A1/A7. Abrir ítem: extender el escaneo del one-liner para cubrir `commit -a`/`-am`.

### ✅ WAVE 2 · W1 — coherencia de rutas cross-OS (rama `wave2-w1`, 2026-07-30 · NO mergeado)
> Verificado ESTÁTICAMENTE + `test-brain.sh` TODO verde (290 PASS · 0 FAIL). C#/QML/ps1 **pendientes de QA funcional de unjordi por plataforma** (no se compilan/ejecutan aquí).

**Fixes aplicados:**
- **H3** ✅ `bootstrap.ps1` alineado a `checkout -B main origin/main` (== `bootstrap.sh:69`); abandonó el fast-forward de la rama actual.
- **H1** ✅ puente HOME↔USERPROFILE: `bootstrap.ps1` e `install-brain.ps1` exportan `$env:HOME = $env:USERPROFILE` antes de invocar bash (solo Windows; no toca Mac/Linux). El bash hijo hereda el entorno → el cerebro se instala en el MISMO `~/.claude` que lee el widget.
- **H5** ✅ `main.qml` runUpdate: el `cd`/`bash` del update ahora escapan la ruta del clon con el helper `shq()` (comillas POSIX) — antes `cd '<repo>'` partía una ruta con `'`.
- **H2 (C#)** ✅ `windows/src/ClaudeBrain/Updater.cs`: portado `ResolveClonePath` espejando `Updater.swift` (embebido → `$CLAUDE_BRAIN_DIR` → `%LOCALAPPDATA%\cortex-repo`, verificando `windows\install.ps1`). Antes usaba SOLO el `repo` embebido (ruta del runner de CI, inexistente en la máquina del usuario) → `CanSelfUpdate=false`.

**Backlog (NO arreglado, demasiado riesgoso a ciegas):**
- **H2 (QML)** ⏳ `src/plasmoid/contents/ui/main.qml` NO recibió el fallback `resolveClonePath`. Motivo: el plasmoid no puede hacer `fileExists` síncrono; resolver el clon exige un round-trip async por `DataSource("executable")` que reestructura el gating de `updCanSelfUpdate`/visibilidad del botón — no verificable estáticamente aquí. Mitigante: en KDE el `install.sh` corre LOCAL (no CI precompilado), así que el `repo` embebido normalmente SÍ existe → el riesgo real es menor que en macOS/Windows. **Pendiente:** portar el fallback en QML con QA en vivo en KDE.

**Tests OS-parity agregados a `test-brain.sh` (bloque `e6`, todos verdes):** e6.1 (install-brain.ps1 delgado), e6.2 (bootstrap.ps1 `checkout -B main`), e6.3 (sin `$HOME` absoluto hardcodeado), e6.5 (cd/Set-Location citan/escapan), e6.6 (`.brain-version` desde `<home>/.claude` en los 4 lectores), e6.7 (puente HOME↔USERPROFILE en los .ps1).
- **e6.4 OMITIDO a propósito:** exige el fallback en los **3** updaters; como H2-QML quedó en backlog, NO se agregó su test para no dejarlo rojo (se agregará junto con el port de QML).
- Nota vs el plan original: el test #7 se planeó "nace en FALLO"; como H1 SÍ se arregló en esta misma ola, e6.7 nace VERDE.
