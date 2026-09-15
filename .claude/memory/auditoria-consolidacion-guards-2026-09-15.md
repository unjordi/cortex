# Auditoría de consolidación — los git-guards comparten el defecto del toolkit WG (2026-09-15)

> **Origen.** unjordi, al ver el dictamen de diseño de un toolkit ajeno: *"me huele mucho a que está
> pasando lo mismo que con los túneles wg y tal vez deberían ser uno solo"*. Se lanzaron **tres lentes
> en paralelo** (proceso/algoritmo, semántica, y un barrido mecánico en axon) más una auditoría dedicada
> a la familia de git-guards. Este documento es la síntesis; los dictámenes completos están enlazados.

## Veredicto: la hipótesis SE SOSTIENE, pero ACOTADA — y la respuesta NO es "uno solo"

**Sí es el mismo defecto de los túneles.** El paso crítico —*"¿este texto es código real, y contra qué
repo se juzga?"*— está **copiado a mano en 7 lugares, con 3 políticas de despoje de comillas y 6 de
incertidumbre**, y `analizar-comando-git.sh` (la lib "canónica") cubre **solo una parte**. Ésa es la
forma exacta del defecto que se midió en el toolkit WG: N implementaciones a mano del mismo paso, más
una unificación a medias que **esconde** la divergencia en vez de resolverla.

**Pero no se colapsan los cinco en uno.** La conclusión del auditor es:
- **UN SOLO SUSTRATO** para los cinco (un parser, una política de incertidumbre, un formato de mensaje).
- **FUSIONAR SOLO DOS**: `merge-squash-guard` + `confirmar-merge-develop`, que hoy **se contradicen**
  sobre el mismo comando con el mismo destino irresoluble — uno autoriza el release y el otro lo bloquea
  ordenando `--squash`, que es la acción **contraria** a la norma de release.
- **Lo demás se queda separado, a propósito**: un guard que falla no debe tumbar a los otros, los tiers
  del MANIFEST viajan distinto (global / por-repo / both), y se perdería la granularidad para desactivar
  uno solo.

**Nueve familias YA convergieron de verdad** y se declaran cerradas — no tocar: drift-cerebro/
repo-compartido, consentimiento de costo, límite de gasto, `ramas-zombie.sh`, el núcleo de
`dod-verificar.sh`, MANIFEST↔instalador↔test-brain, las 6 skills de auditoría (mismo criterio de
severidad), `hud-stale.sh`, `no-bypass-deploy.sh`.

## CRÍTICOS

1. **`secret-scan` escanea el repo EQUIVOCADO.** Mira `CLAUDE_PROJECT_DIR`, no el repo que el comando
   toca. Un secreto en staging alcanzado por `git -C otro`, por `cd otro &&` o por un cwd distinto
   **pasa sin escanear**. No tiene backstop server-side que lo respalde.
2. **`eval "…"` / `bash -c "…"` / `sh -c '…'` / `xargs … bash -c` derriban los CINCO guards a la vez**
   (push a base, merge sin OK, merge sin squash, escaneo de secretos), porque el despoje de comillas
   trata todo span entrecomillado como **dato inerte**.

## ALTOS

- **El gate de autorización está APAGADO en 13 de 16 repos** — solo `cps`, `fluxcore` y
  `plantilladotnet` llevan la marca; quedan fuera `cortex`, `axon`, `mfx_infraestructuradigital` y
  `pisamrpclaude`. Y **el 100% de sus disparos en campo fueron fallos de PARSEO**, no la regla de alcance.
- **`merge-squash-guard` y `confirmar-merge-develop` concluyen OPUESTO** sobre el mismo comando y el
  mismo destino irresoluble (ver arriba).
- **El piso determinista de `main` no corre cuando el destino sale vacío** — se desactiva justo en la
  condición que el corpus declara universal, dejando el gate de máxima consecuencia solo en manos del LLM.
- **Un fallo de ENTORNO revoca una autorización que el usuario YA escribió a disco**: el grant durable
  ni siquiera se abre si el destino no resuelve.
- **`test-brain.sh` da 1011 PASS · 0 FAIL con todos estos defectos vivos.** Es el **mismo defecto de
  falsos verdes** del toolkit WG, ahora en el arnés que debía protegernos.
- **Seis escapes tipo "intégralo en la web de GitLab"** (4 en `confirmar-merge`, 2 en
  `git-branch-guard`) — violan de frente la norma dura anti-vein-popper.
- **FP de heredoc en el trío de git**: bloqueó comandos read-only del propio auditor, y **bloquea el acto
  de registrar un falso positivo**, que es el único oráculo de afinamiento que tenemos.

## El hallazgo que desatora todo

Las tres "incógnitas" de campo **SÍ son decidibles con señales que el hook ya tiene**. La clave: **el
destino del MR/PR SÍ viaja por el CLI al CREARLO** (`--base` / `--target-branch`) — y hoy se **descarta**
en vez de cachearse por id. Cachearlo elimina la dependencia de red que hace fallar al juez al integrar,
que es la causa de todos los frenos en falso de estos días.

## Corrección a una entrada del corpus

La entrada del **2026-09-14** de `docs/guards-falsos-positivos.md` (retractación del FP del 13-sep)
acierta en la **lección** —*nunca uses variables de shell en flags que un hook inspecciona*— pero **erra
en el mecanismo**: con `--repo "$R"`, `_explicit_repo` captura **`--squash` como si fuera el slug** y
`acg_target_remote` devuelve el valor **con comillas**. No era "veía el literal `$R` y gateaba por
incertidumbre". Corregir esa entrada conservando ambas versiones (el corpus es append-only: un corpus que
borra sus errores esconde justo el caso que confundió al operador).

## De la lente SEMÁNTICA — promesas que el cableado no cumple

Sin críticos ni patrón sistémico. Los huecos son de grano fino, y casi todos de la misma clase:
**vocabulario de candado que corre por delante del cableado**, o soluciones ya construidas que **nunca se
propagaron**.

- `install-brain.sh:55,58` **hardcodea `$HOME/.claude` ignorando `CLAUDE_CONFIG_DIR`**, que
  `juez-comun.sh` y `test-brain.sh` ya tratan como resuelto ⇒ instalación **100% silenciosa y
  no-funcional** para quien use esa variable.
- `sesion-inicio.sh:31` **le dice a cada sesión** que `dod-verificar` "revisa" build/tests/lint/memoria.
  **El hook nunca lo hace**: solo exige la marca citada. Eso se inyecta en CADA arranque.
- `dod-verificar.sh` **falla ABIERTO y en silencio** ante error de red/jq/token: el candado de LISTO se
  apaga sin dejar rastro. Y su piso léxico (`:86-90,104`) deja pasar cierres genuinos que evitan las
  palabras-gatillo, sin que el juez LLM llegue a evaluarlos (falso negativo reproducido).
- `canonizar-cerebro/SKILL.md:3` se declara "paso estructural dentro de `consolidar-cerebro`" — y
  `consolidar-cerebro` **nunca la menciona** (0 grep).
- `orquestar-fanout` / `delegacion-reporte.sh` prometen un cierre **"AUTOMÁTICO"** que en código es
  **solo un recordatorio**.
- `contrato-hilo.sh::verificar_hilo()` **solo se dispara por prosa, nunca por hook** (corroborado por 3
  pasadas independientes).
- `entorno-maquina-guard.sh` agrega el chequeo de Rosetta **sobre todo el diff** (falso negativo
  reproducido).
- `no-bypass-deploy.sh` **no cubre `helm` ni `kubectl`** pese a que la norma los cita.
- `juez-comun.sh` aplica **dos estándares de "OK"** entre sus backends Anthropic y Ollama.
- La "GARANTÍA" de barrido de contenido de `checkpoint`/`turno-nocturno` **no tiene ni una función que la
  verifique**.

## De la lente de PROCESO

- El primitivo *"¿este Bash es un push real o texto citado?"* tiene **5+ copias a mano**:
  `entorno-maquina-guard.sh:31`, `rama-vieja.sh:14`, `no-bypass-deploy.sh:39`, `recordar-dashboard.sh:15`
  reimplementan el sed que ya existe como `acg_despoja_comillas()` en `analizar-comando-git.sh:33`.
- **`proteger-arbol.sh` YA tiene el parche de heredoc** (líneas 16-27) **con sus tests dedicados**
  (`test-brain.sh:1730-1742`) — y **nunca se propagó** ni a la lib canónica ni a los otros cuatro. Es la
  prueba de que el fix existe y el sistema no lo distribuyó.
- **La divergencia ya empezó**: `rama-vieja.sh` y `recordar-dashboard.sh` perdieron el ancla
  `([[:space:]]|$)` que sí tiene `acg_es_push()`, aun con el prefijo de dequote copiado idéntico.
- La cláusula de dedupe doble-cableado está copiada **byte-idéntica en 8 hooks `both`** sin **ningún test
  que la vigile** como invariante.

## Dictámenes completos

- `~/.claude/jobs/fc94c4e1/tmp/auditoria-guards-git-unificacion.md` — el principal. **11 mecanismos
  M1–M11 con sus tests** en el formato del arnés existente. **Ninguno afloja un gate** (M5 y M7 APRIETAN).
- `~/.claude/jobs/fc94c4e1/tmp/consolidacion-lente-semantica.md`
- `~/.claude/jobs/fc94c4e1/tmp/consolidacion-lente-proceso.md`
- `~/code/axon/out/consolidacion-cerebro.md` (en cachy, barrido mecánico)

## Regla que gobierna la aplicación

Estos son **controles de SUPERVISIÓN de Claude**. La norma de *Integridad de los guardarraíles* aplica
entera: los cambios son de **PRECISIÓN / ENDURECIMIENTO**, nunca "para que deje de bloquearme", y cada
uno **nace con su test**. unjordi autorizó explícitamente esta tanda (2026-09-15).
