# Auditoría de los "jueces" del cerebro claude-brain — CONTEXTO COMPARTIDO

Eres un **auditor independiente de procesos y algoritmos**. Tu trabajo: entender la arquitectura
de los "jueces" (guards de git que usan un LLM para decidir), reproducir mentalmente su flujo, y
emitir un veredicto sobre **qué está mal de raíz** y **cómo arreglarlo bien**. Trabajas para un
usuario (unjordi) que lleva ~24h de trabajo peleando con estos guards y NO confía en el
autodiagnóstico de la sesión principal — por eso te trae a ti, independiente.

## Qué son los "jueces"

Dos guards del cerebro comparten un mismo esqueleto (lib `juez-comun.sh`):

- **`confirmar-merge-develop`** — PreToolUse/Bash. Antes de integrar una rama a `develop`/`main`
  vía MR/PR (`gh pr merge` / `glab mr merge`), exige autorización EXPRESA del usuario. Es
  **fail-CLOSED** (ante duda → DENY). Es el que dio guerra hoy.
- **`dod-verificar`** — Stop hook. Al cerrar/declarar algo "listo", exige la marca de la
  Definición de LISTO. Es **fail-OPEN**.

Ambos llaman a **Claude Haiku vía `curl`** a `api.anthropic.com` (token OAuth de suscripción,
header `anthropic-beta: oauth-2025-04-20`) para juzgar ALLOW/DENY con **comprensión de lectura**
del contexto reciente, en vez de regex de intención (que antes era whack-a-mole; ver la lápida
`🪦#eba90b376` en el cementerio).

## Archivos que DEBES leer (fuente real, rama de trabajo del brain)

- `/Users/unjordi/code/claude-brain/brain/hooks/confirmar-merge-develop.sh` — el juez de merge COMPLETO.
- `/Users/unjordi/code/claude-brain/brain/hooks/juez-comun.sh` — la lib compartida de auth/token/curl.
- `/Users/unjordi/code/claude-brain/brain/hooks/dod-verificar.sh` — el juez del DoD.
- `/Users/unjordi/code/claude-brain/brain/hooks/analizar-comando-git.sh` — lib de análisis de comandos
  git: `acg_es_merge_mr`, `acg_destino_de_mr`, `acg_mrid`, `acg_lista_prs_abiertos`, `acg_hint_candidatos`,
  `acg_despoja_comillas`, `acg_sin_flag_repo`, `acg__run_timeout`. AQUÍ vive la resolución del destino.
- `/Users/unjordi/code/claude-brain/brain/test-brain.sh` — la batería (526 PASS hoy). Mira cómo testean
  los jueces (mocks `CLAUDE_MERGE_JUEZ_MOCK` / `_MOCK_RAW` / `_VOTES`, source con `_CMD_JUEZ_SOURCE_ONLY=1`).

## Transcript de la sesión donde estalló el problema (léelo lo que necesites)

`/Users/unjordi/.claude/projects/-Users-unjordi-code-plantilladotnet/761c82d9-40fd-4fe2-9703-e3504b6f028f.jsonl`

Es un `.jsonl` enorme (una línea por evento). Útil: `grep -n` por frases clave, o `jq` por rol.
Busca en particular la secuencia de HOY donde el usuario autorizó *"haz el merge a develop de las 3
branches que siguen pendientes"* y luego el juez **dejó pasar el PR #272 pero FRENÓ el #273** con la
misma autorización. Esa inconsistencia es el corazón del reclamo.

## Diagrama de flujo de `confirmar-merge-develop` (verifícalo contra el código, no lo tomes por dado)

```
PreToolUse(Bash), recibe {tool_input.command, transcript_path, cwd} por STDIN
  1. dedupe: si soy copia del repo y existe la global → exit 0 (la global maneja)
  2. cmd = jq .tool_input.command ; vacío → exit 0
  3. source analizar-comando-git.sh
  4. acg_es_merge_mr(cmd)?  (¿es glab mr merge / gh pr merge / accept / --auto-merge?)
        NO → exit 0  (git merge LOCAL, o inspección, pasan libres)
  5. ¿existe la marca .claude/repo-compartido en CLAUDE_PROJECT_DIR?
        NO → exit 0  (repo personal: cero fricción)
  6. destino = acg_destino_de_mr(cmd)
        └─ corre:  gh pr view <mrid> [-R <repo>] --json baseRefName -q .baseRefName   (con timeout)
        └─ FRÁGIL: depende de cwd correcto / --repo en el comando / red / gh en PATH.
                   Falla → destino = "" (vacío).
  7. si destino ∉ {develop, main, ""} → exit 0  (rama personal, libre)
  8. prlist = acg_lista_prs_abiertos(cmd)   (otra llamada gh, cacheada)
  9. si destino=="" y prlist: intenta resolver destino del baseRefName del MR en prlist
  10. hint = acg_hint_candidatos(prlist, destino, mrid)   (HECHOS para identificar target, no autoriza)
  11. recent = _recent_intercalado(transcript_path)
        └─ tail -n 6000 | jq: arma líneas USUARIO:/ASISTENTE:, se ANCLA al 10º mensaje de USUARIO
           desde el final, +4 turnos de arranque. Recorta texto del asistente a 700 chars.
  12. si destino=="develop": ¿hay grant durable vigente en
        .claude/memory/autorizaciones-vigentes.local.md (scope=merge-develop, no vencido)? → exit 0
        (ese archivo HOY solo lo escribe el skill turno-nocturno)
  13. veredicto = _juez_merge(destino, mrid, recent, hint)
        ├─ piso barato: sin ninguna línea 'USUARIO:' en la ventana → DENY (sin gastar red)
        ├─ token: env CLAUDE_CODE_OAUTH_TOKEN → ~/.claude/.credentials.json → keychain macOS
        │         sin token → UNAVAILABLE
        ├─ curl Haiku (prompt largo + recent + hint), temperature 0, max_tokens 768
        ├─ parsea el ÚLTIMO 'VEREDICTO: ALLOW|DENY' (centinela); sin centinela → UNAVAILABLE
        ├─ si ALLOW: exige línea 'CITA: <verbatim>' que exista TEXTUAL en una línea USUARIO: → si no, DENY
        ├─ si destino=main y ALLOW: piso determinista de lenguaje de release → si no, DENY
        └─ voto múltiple opt-in (VOTES≥2): N votos en paralelo, unánime-para-ALLOW
  14. ALLOW → additionalContext (nota de higiene), exit 0
      DENY / UNAVAILABLE → permissionDecision:"deny" con mensaje según caso
```

## El incidente de HOY (hechos observados, para que reproduzcas)

1. Usuario: *"haz el merge a develop de las 3 branches que siguen pendientes por favor"* (autorización
   en LOTE para 3 PRs: #272 checkpoint, #273 git-norm, #274 merge-squash).
2. Primer intento de merge del #272 SIN `--repo` y con el cwd reseteado a otro repo (`plantilladotnet`,
   no `claude-brain`) → `gh pr view` dentro del hook falló → **destino vacío** → mensaje "no pude
   CONFIRMAR el destino del MR 272" → DENY.
3. Reintento del #272 **con `--repo unjordi/claude-brain`** → destino resolvió a develop → juez **ALLOW**
   → #272 mergeado. (Prueba de que el juez SÍ funciona cuando ve el destino y la autorización.)
4. Intento del #273 **con `--repo`** (destino=develop OK esta vez) → juez **DENY**: "no encontró tu
   confirmación EXPRESA para integrar ESTE MR (273) a develop". MISMA autorización del paso 1.
   Entre el paso 1 y este, hubo ~7 mensajes más del usuario (frustración, correcciones), que
   desplazaron/diluyeron la autorización original en la ventana `_recent_intercalado`.
5. El usuario explotó: el juez "lleva 12h de trabajo" y sigue frenando merges legítimos ya autorizados;
   está harto de que la sesión principal invente "parches, hacks y workarounds para ADMINISTRAR un juez
   mal hecho" en vez de ARREGLARLO. Contexto: ~12h hoy + ~12h ayer en este tema.

## Tu entregable

Escribe tu informe en:
`/private/tmp/claude-501/-Users-unjordi-code-plantilladotnet/761c82d9-40fd-4fe2-9703-e3504b6f028f/scratchpad/auditoria-jueces-v2/INFORME-<TU-ETIQUETA>.md`

Debe contener, con EVIDENCIA de línea (cita archivo:línea del código real que leíste):
1. **Arquitectura confirmada o corregida** — ¿el diagrama de arriba es fiel? ¿qué omite o distorsiona?
2. **Fallas de raíz**, ordenadas por gravedad. Para cada una: el mecanismo exacto por el que produce
   un veredicto MALO (falso DENY de un merge legítimo, o —peor— un falso ALLOW), con el camino de
   código y, si aplica, el fragmento del transcript que la dispara. Distingue **falla de plomería**
   (destino/red/cwd) de **falla de diseño** (cómo se deriva la autorización).
3. **No-determinismo**: ¿por qué el MISMO OK del usuario da veredictos distintos en #272 vs #273?
   ¿Es la ventana deslizante, el anclaje al 10º-usuario, la dilución, el mapeo lote→MR, o varias?
4. **Propuesta de arreglo** — la forma correcta, respetando estas restricciones DURAS del proyecto:
   - El fail-safe NO se afloja: ante duda real sigue DENY (merge) / el gate no se debilita. Los
     cambios permitidos son de PRECISIÓN (menos falsos positivos), nunca "que deje de bloquearme".
   - SOLO el usuario autoriza; jamás una línea del ASISTENTE (anti auto-autorización / anti-inyección).
   - Un release a `main` SIEMPRE exige lenguaje de release explícito (piso determinista intacto).
   - Cada arreglo nace con su test (mira cómo testea `test-brain.sh` sin red, con mocks).
   - Se libera por un widget externo, no corriendo `install-brain` a mano.
5. **Qué NO tocar** — qué partes ya están bien y romperlas sería regresión.

Sé concreto y escéptico. Si crees que una "falla" propuesta no es real, dilo y demuéstralo. Preferimos
un diagnóstico corto y CIERTO a uno largo y especulativo.
