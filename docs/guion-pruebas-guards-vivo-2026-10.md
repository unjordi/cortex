# Guion de pruebas EN VIVO — tanda de afinado de guards 2026-10

> **Qué es.** El guion de casos para probar los guards de esta tanda **con Jordi, en una sola sesión al
> final** (Jordi: *"los guards no los voy a aprobar yo, baby… los VAMOS A PROBAR JUNTOS"* · *"en vez de
> presionarme por merges de CADA slice, los juntamos todos"*). NO es una tabla de aprobación: es un
> set de comandos reales con su resultado esperado, para VER cada guard frenar lo que debe y dejar de
> frenar lo que no.
>
> **Estructura por guard** (la que pidió Jordi): **(1) TP que DEBE seguir frenando** · **(2) FP del
> corpus que deja de frenar** (lo que el fix arregla) · **(3) ≥1 caso límite**. Cada caso trae el
> comando/frase EXACTA y qué debe verse.
>
> **Dos formas de correr cada caso** (equivalentes; el efecto observable es el mismo):
> - **(A) directa al hook** — monta un repo desechable y le pasa al guard el MISMO JSON que ve como
>   PreToolUse. Determinista, reproducible, no necesita el guard instalado. Es la forma de abajo.
> - **(B) end-to-end** — con el cerebro de la épica ya instalado, Jordi TECLEA el comando y ve si el
>   hook dispara. Es la prueba "de verdad"; se hace en la sesión final cuando la épica está instalada.
>
> **Helper para la forma (A)** (pégalo una vez en la sesión):
> ```bash
> PA="$HOME/.cortex/brain/hooks/proteger-arbol.sh"   # o la ruta del worktree de la épica
> pa() {  # pa '<comando git>' '<cwd del repo>'  → imprime lo que el guard avisaría (vacío = SILENCIO)
>   printf '{"tool_input":{"command":%s},"cwd":%s}' \
>     "$(printf '%s' "$1" | jq -R .)" "$(printf '%s' "$2" | jq -R .)" | bash "$PA" 2>/dev/null
> }
> ```

---

## B1 — `proteger-arbol`, carril `git branch -d/-D` (commit `1c30a42`)

**Qué cambió.** El carril `branch -D` ahora decide el riesgo POR RAMA con `ramas-zombie.sh`, que suma
dos reconocimientos squash-safe: **(t) integración TRANSITIVA acotada** (rama→mini→squash a develop) y,
en `proteger-arbol`, **(c) el compound** `git merge X && git branch -D X` (el merge integra X en el acto).
Antes, ambos casos daban un **falso AVISO** sobre una rama que ya estaba a salvo. **Nada se afloja:** un
commit de la rama más allá del merge rompe el ancestro → vuelve a conservarse (avisa).

### Setup común (un repo desechable que modela el flujo mini-develop)
```bash
R="$(mktemp -d)"; cd "$R"
git init -q && git config user.email t@t && git config user.name t
git checkout -q -b develop && echo base > base.txt && git add . && git commit -qm base
# mini-develop (X) con un commit propio:
git checkout -q -b epic/mini && echo m1 > m1.txt && git add . && git commit -qm c1
# feat/a nace de la mini y se mergea a ella:
git checkout -q -b feat/a && echo a2 > a2.txt && git add . && git commit -qm c2
git checkout -q epic/mini && git merge -q --no-ff feat/a -m 'merge feat/a a la mini'
# develop recibe la mini por SQUASH (un commit nuevo que nombra la rama integrada):
git checkout -q develop && echo squashed > squashed.txt && git add . \
  && git commit -qm "$(printf 'squash de la mini\n\nRama: epic/mini')"
# feat/b: rama con trabajo propio NO integrado a nada:
git checkout -q -b feat/b && echo b1 > b1.txt && git add . && git commit -qm trabajo
git checkout -q develop
```

### (1) TP — DEBEN seguir avisando (nada se afloja)
| # | Comando | Esperado | Por qué |
|---|---------|----------|---------|
| T1 | `pa 'git branch -D feat/b' "$R"` | **AVISA** (nombra `feat/b`) | `feat/b` tiene un commit propio sin integrar a develop → borrarla pierde trabajo. |
| T2 | tras `git checkout feat/a && echo a3 > a3.txt && git add . && git commit -qm c3 && git checkout develop` → `pa 'git branch -D feat/a' "$R"` | **AVISA** (nombra `feat/a`) | El commit EXTRA tras el merge a la mini rompe el ancestro `feat/a`→`epic/mini` → la transitiva (t) ya no aplica → se conserva. Es la dirección contraria del fix: nada se afloja. |
| T3 | `pa 'git reset --hard HEAD~1' "$R"` (con commits en riesgo) | **AVISA** | El carril destructivo (reset/rebase/checkout -f) es independiente de B1 y sigue intacto. |

### (2) FP del corpus — DEJAN de avisar (lo que B1 arregla)
| # | Comando | Esperado | Por qué |
|---|---------|----------|---------|
| F1 | `pa 'git branch -D feat/a' "$R"` (con el setup limpio, sin el commit extra de T2) | **SILENCIO** | `feat/a` entró a develop TRANSITIVAMENTE (mergeada a `epic/mini`, la mini squasheada a develop con `Rama: epic/mini`). Señales directas fallan (squash N→1); la transitiva (t) la reconoce. **Este era el falso AVISO.** |
| F2 | `pa 'git merge feat/b && git branch -D feat/b' "$R"` | **SILENCIO** | El mismo comando mergea `feat/b` a develop antes de borrarla → queda integrada en el acto. `proteger-arbol` recoge los targets de cada `git merge` del comando y los trata como seguros. **Era el otro falso AVISO.** |

### (3) Casos límite
| # | Comando | Esperado | Por qué |
|---|---------|----------|---------|
| L1 | hermano en el MISMO tip: `git checkout feat/a && git checkout -b feat/a-hermano && git checkout develop` (sin el commit extra) → `pa 'git branch -D feat/a-hermano' "$R"` | **SILENCIO** | `feat/a-hermano` apunta al mismo commit que `feat/a`, que entró por la mini → también es transitivamente integrada. (El caso que NO debe aflojar es el inverso, cubierto por la exclusión mismo-tip en la transitiva: un hermano NO integrado no se vuelve zombie porque otro hermano en su tip sí lo esté — regresión b3g, ya en la suite.) |
| L2 | compound con OTRA rama: `pa 'git merge feat/a && git branch -D feat/b' "$R"` | **AVISA** (nombra `feat/b`) | El merge es de `feat/a`, no de `feat/b`; `feat/b` sigue evaluándose normal y tiene trabajo sin integrar → el fix del compound NO se sobre-extiende a ramas que el comando no mergea. |

### Respaldo automatizado (ya en la suite, corre sin Jordi)
`brain/test-brain.sh` §`(b1-transit)` (transitiva pasa / commit extra FRENA) y §`(b1-compound)`
(compound silencio / branch -D solo AVISA) — ambos **fallan contra el código viejo**. Suite 1389 PASS · 0 FAIL.

---

## B1b — `ramas-zombie.sh`, señal (e) acotada (#486)

**Qué cambió.** La señal **(e)** daba por integrada una rama solo porque el log de la base trae el pie
`Rama: <br>` del squash — SIN comprobar que el tip ACTUAL esté contenido. Una rama **reusada tras su
squash** (commits nuevos encima) seguía dando (e) → los barredores y el carril `branch -D` la borraban
con su trabajo nuevo (**pérdida de datos**). Ahora (e) solo vale si la rama **no trae nada más nuevo** que
el commit de squash que la nombra (committer-date); si sí, cae a (d) —cuyo containment re-chequea el tip—
y de ahí a conservar. Mismo acotamiento en `bz_remota_integrada` (ramas remotas). Dirección SEGURA: (e)
solo **retira** falsos "integrada", nunca agrega → B1b **restaura** un aviso correcto, no afloja ninguno.

### Setup (rama squasheada con pie `Rama:`, luego REUSADA)
```bash
R="$(mktemp -d)"; cd "$R"
git init -q && git config user.email t@t && git config user.name t
export GIT_COMMITTER_DATE
GIT_COMMITTER_DATE="2026-01-01T00:00:00" git checkout -q -b develop && echo base>base.txt && git add . && git commit -qm base
GIT_COMMITTER_DATE="2026-01-01T00:00:00" git checkout -q -b feat/x && echo x>x.txt && git add . && git commit -qm cX
git checkout -q develop && echo s>s.txt && git add .
GIT_COMMITTER_DATE="2026-01-02T00:00:00" git commit -qm "$(printf 'squash de feat/x\n\nRama: feat/x')"
# feat/x REUSADA: un commit NUEVO después del squash (committer-date > el del squash):
git checkout -q feat/x && echo n>n.txt && git add .
GIT_COMMITTER_DATE="2026-01-03T00:00:00" git commit -qm cNEW && git checkout -q develop
```

| # | Caso | Comando | Esperado | Por qué |
|---|------|---------|----------|---------|
| B1b-T | rama REUSADA tras squash | `pa 'git branch -D feat/x' "$R"` | **AVISA** (nombra `feat/x`) | `feat/x` tiene `cNEW` posterior al squash → borrarla pierde ese trabajo. El código VIEJO callaba (solo veía el pie `Rama:`) → **este era el data-loss.** |
| B1b-control | rama SIN reúso | tras `git -C "$R" branch -f feat/x feat/x~1` (quitar cNEW) → `pa 'git branch -D feat/x' "$R"` | **SILENCIO** | Sin trabajo posterior al squash, (e) sigue valiendo → integrada. El acotamiento no sobre-frena el caso normal. |

### Respaldo automatizado
`brain/test-brain.sh` §`(b1b-reuso)`: positivo (sin reúso → zombie razón e, conservado) + negativo
(reúso → se conserva). El negativo **falla contra el código viejo** (daba `Z:e` → data-loss). Verificado
también que el commit de squash se fecha con `_bz_squash_ct` (committer-date del pie `Rama:` más nuevo).

---

## B1c — `proteger-arbol`/`ramas-zombie`, base REMOTA adelantada (FP más frecuente del corpus)

**Qué cambió.** La FP MÁS frecuente del corpus (hallazgo de claudio 2026-10-14): `git pull --ff-only &&
git branch -D <rama>` con la **base LOCAL atrasada**. El guard corre ANTES del pull → ve `develop` local
sin el squash → avisaba en falso. Ahora `bz_es_zombie` re-prueba la MISMA definición de "integrada"
(directa + transitiva) contra **`origin/<base>`** (señal **r**): si ya hiciste `git fetch` y origin/develop
trae el squash, el trabajo de la rama **ya vive en el remoto** → un `git branch -D` local no pierde nada.
SOLO lee refs locales (sin red); si origin/<base> también está atrasada, no matchea → avisa como hoy.

### Setup (origin/develop fresco con el squash, develop LOCAL atrasado)
```bash
R="$(mktemp -d)"; cd "$R"
git init -q && git config user.email t@t && git config user.name t
git checkout -q -b develop && echo base>base.txt && git add . && git commit -qm base
BASE=$(git rev-parse HEAD)
git checkout -q -b feat/r2 && echo r2>r2.txt && git add . && git commit -qm "trabajo r2"
git checkout -q develop && echo sq>sq.txt && git add . && git commit -qm "$(printf 'squash de feat/r2\n\nRama: feat/r2')"
git update-ref refs/remotes/origin/develop "$(git rev-parse HEAD)"   # origin/develop FRESCO (ya fetcheado)
git update-ref refs/heads/develop "$BASE"                            # develop LOCAL atrasado
git symbolic-ref HEAD refs/heads/develop
```

| # | Caso | Comando | Esperado | Por qué |
|---|------|---------|----------|---------|
| B1c-F | FP del corpus | `pa 'git pull --ff-only && git branch -D feat/r2' "$R"` | **SILENCIO** | `feat/r2` está integrada en `origin/develop` (adelantada) → su trabajo vive en el remoto; el pull adelantará la base local. **Era el falso AVISO.** |
| B1c-T | nada se afloja | tras `git -C "$R" update-ref refs/remotes/origin/develop "$BASE"` (origin/develop también atrasada) → `pa 'git pull --ff-only && git branch -D feat/r2' "$R"` | **AVISA** (nombra `feat/r2`) | Sin evidencia en la base remota, no hay prueba de que el trabajo esté a salvo → conserva. La señal (r) solo RETIRA falsos avisos cuando el remoto lo respalda. |

### Respaldo automatizado
`brain/test-brain.sh` §`(b1c-remota)`: positivo (origin/develop adelantada → zombie razón r) + negativo
(origin/develop atrasada → se conserva). El positivo **falla contra el código viejo** (sin (r) → VIVO → FP).

---

## B5 — `git-branch-guard`, push a un remote-tracking ref (precisión, Jordi aprobó 2026-10-11)

**Qué cambió.** Un push que ACTUALIZA un **remote-tracking ref** (`refs/remotes/<remote>/<base>`) —típico al
sincronizar el clon de OTRA máquina, p. ej. `git push backup develop:refs/remotes/origin/develop`— NO toca la
RAMA base del remoto, pero el `/develop` final del ref lo hacía bloquear en falso. `acg_push_destino_base`
ahora BORRA los destinos `refs/remotes/.../<base>` antes de buscar la base. Fail-closed: un destino de RAMA
real sigue bloqueando.

> Este guard es DENY y corre GLOBAL (la copia del repo cede). En la sesión final, con la épica instalada,
> Jordi **teclea** cada comando en un repo de prueba y ve si git-branch-guard lo deja o lo bloquea. (Para
> una verificación sin instalar: `bash -c '. brain/hooks/analizar-comando-git.sh; acg_push_toca_base "<cmd>" && echo BLOQUEA || echo pasa'`.)

| # | Caso | Comando | Esperado | Por qué |
|---|------|---------|----------|---------|
| B5-F | FP que cerramos | `git push backup develop:refs/remotes/origin/develop` | **PASA** | Actualiza el tracking ref del clon de otra máquina; no toca la rama base del remoto. |
| B5-F2 | ramita → tracking ref | `git push origin feat/x:refs/remotes/origin/develop` | **PASA** | El dest es un tracking ref, no la rama base. |
| B5-T1 | nada se afloja | `git push origin develop` | **BLOQUEA** | Push a la RAMA base — sigue prohibido. |
| B5-T2 | nada se afloja | `git push origin HEAD:refs/heads/develop` | **BLOQUEA** | Destino de rama base explícito. |
| B5-T3 | nada se afloja | `git push origin :develop` | **BLOQUEA** | Borrar la rama base — sigue prohibido. |

### Respaldo automatizado
`brain/test-brain.sh` (bloque B5, junto a H2): los 2 FP pasan y los 3 controles de rama-base bloquean. El
caso FP **falla contra el código viejo** (el regex sin el borrado del tracking ref sí bloqueaba).

---

## sync-upstream — `merge-develop-guard`, excepción al squash (PORT `7e3eedd` + revisión `docs/revision-sync-upstream-2026-10.md`)

> Portado tal cual de la cachy (Jordi autorizó 2026-10-03 + en vivo vía claudio). La excepción exime del
> `--squash` a un merge de MR que es un **sync de upstream** real (PR con merge-commit cuyo 2º padre aporta
> historia que `develop` no tiene) con `--merge` + frase USUARIO anclada al PR. **No afloja el candado**: el
> merge sigue pasando por el juez de autorización (PASO 3b); la excepción solo waivea el squash.
>
> ⚠️ **Este guard necesita un PR real abierto para el positivo** (el test contra `unjordi/armada-rp6` #40 se
> **pudrió**: #40 ya se mergeó → `ahead_by=0` → ya no es sync). El positivo-en-vivo exige un PR de sync
> ABIERTO en un repo de Jordi; la cobertura determinista la dará un mock hermético (pendiente, ver revisión).
> Los negativos NO necesitan red (cortan antes del `gh api`).

| # | Caso | Comando (con una línea USUARIO `autorizo --merge (sin squash) del PR #N a develop`) | Esperado | Por qué |
|---|------|------|----------|---------|
| SU-T1 | sync real + frase | `gh pr merge <N> --merge --repo <slug>` sobre un PR de sync **ABIERTO** (2º padre con `ahead_by>0`) | **PASA el squash** (cae al juez) | Es el caso que la excepción habilita: preservar la historia de upstream. |
| SU-F1 | sin frase | `gh pr merge <N> --merge --repo <slug>` **sin** línea USUARIO para ese PR | **BLOQUEA (exige squash)** | Falta la autorización textual anclada al PR. |
| SU-F2 | sin `--merge` | `gh pr merge <N> --repo <slug>` + frase | **BLOQUEA (exige squash)** | Sin `--merge` no es el caso de la excepción. |
| SU-F3 | PR normal (no sync) | `gh pr merge <N> --merge --repo <slug>` + frase, PR SIN merge-commit ajeno | **BLOQUEA (exige squash)** | `ahead_by=0` → no hay historia de upstream que preservar (anti-disfraz). |
| SU-F4 | frase de OTRO PR | `gh pr merge <N> --merge` + frase que nombra el PR **M≠N** | **BLOQUEA (exige squash)** | La frase no ancla a ESTE PR. |

### Respaldo automatizado
Hoy: `brain/hooks/tests-locales/test-merge-sync-upstream.sh` (portado tal cual, 1 positivo + 4 negativos
contra PRs reales de `unjordi/armada-rp6`). **NO cableado a `test-brain.sh`/CI a propósito** (golpea la red +
depende del estado del fixture; el positivo ya no pasa porque #40 se mergeó). **Pendiente de la revisión:**
hermetizar con mock de `gh api` + fixture determinista de ambas direcciones y cablearlo a la suite.

---

<!-- Las secciones de B8, B2, B3/B4 y N1-N7/N2 se agregan aquí conforme cada slice cierra. -->
