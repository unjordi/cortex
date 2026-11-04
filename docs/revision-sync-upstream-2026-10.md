# Revisión del porte sync-upstream a `merge-develop-guard` (2026-10-14)

> Hermano del commit de PORT (`7e3eedd`, `feat(merge-guard): PORTA tal cual…`). El porte trajo el parche
> **VERBATIM** desde la cachy (Jordi: *"tráiganlo sin reconstruirlo PERO revísenlo!"*); ESTA es la revisión
> con criterio de guard. Autorización del cambio: Jordi 2026-10-03 (*"autorizo modificar merge-develop-guard
> para permitir --merge en syncs de upstream"*), re-confirmada en vivo vía claudio. **No se afloja el candado**:
> la excepción waivea SOLO el `--squash`; el merge sigue pasando por el juez de autorización (PASO 3b).

## Qué hace el parche (resumen)
`_es_sync_upstream_autorizado()` exime del `--squash` a un merge de MR que es un **sync de upstream**: el PR
trae un merge-commit cuyo **2º padre aporta commits que `develop` no tiene** (historia ajena, `ahead_by>0`),
va con `--merge`, con `--repo <slug>` explícito, y hay una línea **USUARIO** que nombra `--merge`/`sin squash`
anclada a ESE PR. Falla **cerrado**. En el squash-check, si `destino=develop` y la excepción aplica, setea
`_warn_ctx` y **cae al juez** (en vez del DENY por falta de `--squash`).

## Las 5 preguntas (criterio de guard) — respondidas con evidencia medida

### 1. ¿`ahead_by` sin red / falla cerrado?
**Falla CERRADO, correcto.** La función exige RED para 3 cosas: `gh api …/pulls/$mrid` (base.ref),
`…/pulls/$mrid/commits` (padres) y `…/compare/develop...$sha` (`ahead_by`). Cada una va con `|| return 1`
(o `|| continue` en el loop, y `return 1` al agotarlo). Cualquier ausencia de red/`gh`/respuesta vacía →
`return 1` = **NO exento** = el DENY por falta de squash **se mantiene** (el lado seguro). La excepción solo
dispara con **evidencia POSITIVA** (`ahead_by>0` real sobre un 2º padre divergente). Costo aceptado: offline
un sync legítimo NO puede saltar el squash — es el fail-closed correcto.

### 2. ¿Misma ventana que el juez?
**Sí.** El escaneo de la línea USUARIO usa `acg_recent_intercalado "$2"` — la MISMA función (misma ventana
`tail -n 6000`) que arma la ventana del juez de autorización. Si la autorización cae FUERA de la ventana
(corrida larga, lección H3 del propio guard), la excepción falla-cerrado (exige squash) — consistente con el
juez. La excepción es un match DETERMINISTA de texto, ADEMÁS del juez (no lo reemplaza).

### 3. ¿Trabajo propio disfrazado de `--merge`?
**Resistente por construcción.** El gate anti-disfraz es `ahead_by>0` sobre el **2º padre de un merge-commit
real** del PR, verificado contra el repo VIVO. Un PR de feature normal (trabajo propio, squash/rebase) **no
tiene** ese merge-commit con 2º padre divergente → el chequeo falla → exige squash. Medido: casos "#39 normal
+ --merge + frase" y "sync SIN --merge" → `deny-squash` correctos. Además **defensa en profundidad**: la
excepción NO hace `exit` — cae a PASO 3b, así que el merge SIGUE necesitando el ALLOW del juez de
autorización. Disfrazar exigiría fabricar un PR que de verdad contenga historia ajena mergeada Y una frase
real del usuario — en cuyo punto ya no es disfraz, es un sync autorizado.

### 4. ¿Tests en ambas direcciones + Linux/Mac?
**Ambas direcciones nominalmente (1 positivo + 4 negativos), PERO el test está PODRIDO y no es hermético —
hallazgo principal.** Medido hoy contra el guard portado (evitando el dedupe):
- Negativos (4/4) **PASAN**: SIN frase → deny · SIN `--merge` → deny · PR normal #39 → deny · frase de OTRO
  PR → deny.
- Positivo (sync #40 + `--merge` + frase) **FALLA**: da `deny-squash` donde se esperaba `pasa-squash`.
  **Causa: fixture pudrido, NO bug del guard.** El PR #40 de `unjordi/armada-rp6` ya se **MERGEÓ** → su
  historia de upstream YA está en `develop` → los ~85 segundos-padres dan `ahead_by=0` → la excepción no
  dispara (correctamente: ya no hay historia ajena que preservar). El test se pudre con el PROPIO merge que
  prueba.
- **No corre en CI**: `test-brain.sh` (la suite real) NO lo invoca; golpea la RED (`gh` autenticado) y depende
  del ESTADO del fixture. Portátil en sintaxis (jq/gh/bash/grep -iE/mktemp), pero su verde depende de
  red+auth+fixture, justo lo que la suite evita por diseño (determinista/mockeada).

### 5. ¿Conflictos post-3-oct?
**Ninguno.** El backup pre-parche de la cachy (≈2026-10-03) era **byte-idéntico** al `merge-develop-guard.sh`
actual de cortex (`diff` exit 0, 569 líneas ambos) → el archivo NO cambió desde el 3-oct (los fixes B1-B5 de
esta tanda tocaron OTROS guards: `ramas-zombie.sh`, `analizar-comando-git.sh`, `proteger-arbol.sh`,
`git-branch-guard`). Los 2 hunks aterrizan en anclas prístinas. ⚠️ Caveat futuro: B3/B4 (`TARGET_ROOT` de
merge-develop-guard, aún no hecho) debe re-chequear interacción cuando aterrice.

## Hallazgo extra (eficiencia, PreToolUse)
El loop hace `gh api compare` **por cada merge-commit** del PR. Medido: #40 tiene ~85 merge-commits. Retorna
temprano al primer `ahead_by>0`, pero un PR donde NINGUNO califica (o con red lenta) paga 85 llamadas de red
(15s de timeout c/u) **dentro de un hook PreToolUse que bloquea el comando del usuario** — riesgo de que el
harness mate el hook por timeout antes de terminar, o latencia de decenas de segundos. Candidato a acotar
(cap de N llamadas, o mirar solo el 1er merge-commit, o `mergeable`/conteo primero).

## Veredicto y recomendación
- **Lógica del guard: CORRECTA.** Fail-closed, autorización intacta (defensa en profundidad), anti-disfraz
  estructural. Los 4 negativos pasan; el positivo falla solo por fixture pudrido.
- **El test NO cuenta como cobertura real** hasta hermetizarlo: mockear `gh api` (patrón `CLAUDE_BZ_PRCACHE`/
  `CLAUDE_MERGE_JUEZ_MOCK` del propio brain) con un fixture determinista de ambas direcciones, y cablearlo a
  `test-brain.sh` (CI). Mientras tanto NO está wired a propósito (ver commit de PORT).
- **Eficiencia**: acotar las llamadas de red del loop antes de considerarlo cerrado.
- **Pendiente de prueba en vivo** con Jordi (parte del guion `guion-pruebas-guards-vivo-2026-10.md`, §sync-upstream).
