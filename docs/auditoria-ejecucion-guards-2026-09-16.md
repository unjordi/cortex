# Auditoría de EJECUCIÓN de los 5 guards de git — rama `fix/guards-criticos-fmea` (PR #433)

**Fecha:** 2026-09-16 · **Método:** dry-runs y escenarios completos en laboratorio aislado, NO lectura de código.
**Worktree:** `/Users/unjordi/code/cortex/.cortex-wt/aud-ejecucion` · rama `audit/ejecucion-guards-433`
**Laboratorio:** `/private/tmp/claude-501/-Users-unjordi-code-plantilladotnet/fc94c4e1-.../scratchpad/lab/`
(repos sandbox + worktrees + `curl`/PATH falsos + transcripts sintéticos; scripts `e2e.sh`, `critico1.sh`,
`secreto2.sh`, `chart.sh`, `resto.sh`, `ms.sh`, `rb.sh`).

---

## Veredicto

**El sistema CONVERGIÓ en lo que motivó el encargo.** El daño que unjordi quería prevenir —guards que
muerden a cada rato y terminan con el humano haciendo git a mano— **ya no se reproduce en el flujo
principal**: el día a día completo del modelo mini-develop pasa sin una sola frenada (9/9) y el cruce a
`develop`/`main` sí se gatea (4/4). Las clases de falso positivo DOMINANTES del corpus están cerradas,
medidas una por una.

Lo que queda son **6 hallazgos**, ninguno en el camino feliz: 1 ALTO (un bypass total del candado de
merge por un caché sin validar), 3 MEDIOS y 2 BAJOS. El ALTO es una **inconsistencia introducida por esta
misma rama**: el fix `MEDIO` endureció un caché y dejó a su hermano gemelo sin endurecer.

---

## 1. Lo que CONVERGIÓ (demostrado por ejecución)

### 1.1 El arnés, de baseline
```
$ bash brain/test-brain.sh
==> resultado: 1232 PASS · 0 FAIL
```

### 1.2 El día a día del mini-develop: CERO fricción (`e2e.sh`)
Los 5 guards, sobre cada comando de una jornada real, en un repo marcado `repo-compartido`:

```
### DIA A DIA en la mini-develop (oraculo: CERO friccion)
 ok  git checkout -b fix/login                       esperado=pasa   real=pasa
 ok  git add -A                                      esperado=pasa   real=pasa
 ok  git commit -m "fix(login): corrige el redirect" esperado=pasa   real=pasa
 ok  git push -u origin fix/login                    esperado=pasa   real=pasa
 ok  git push                                        esperado=pasa   real=pasa
 ok  git merge fix/login                             esperado=pasa   real=pasa
 ok  git push                                        esperado=pasa   real=pasa
 ok  glab mr merge 7 --squash --yes                  esperado=pasa   real=pasa
 ok  git branch -d fix/login                         esperado=pasa   real=pasa

### EL CRUCE a develop/main (oraculo: SI gate)
 ok  git push origin develop      esperado=FRENA  real=FRENA: git-branch-guard
 ok  git push                     esperado=FRENA  real=FRENA: git-branch-guard
 ok  glab mr merge 8 --yes        esperado=FRENA  real=FRENA: merge-squash-guard confirmar-merge-develop
 ok  glab mr merge 9 --squash --yes esperado=FRENA real=FRENA: confirmar-merge-develop
```
**Las dos mitades de la prueba pasan**: bloquea lo que debe y deja pasar lo que debe.

### 1.3 Clases de FP del corpus, re-corridas contra esta rama
| Corpus | Caso | Antes | Hoy |
|---|---|---|---|
| L52·L61·L103 | `git push --quiet` pelón desde un WORKTREE en ramita | FP | **SILENCIO** |
| L115·L125·L138 | `printf` que CITA un push a base, append a un `.md` | FP | **SILENCIO** |
| L128 | `cat > doc.md <<EOF` con push a base en el CUERPO | FP | **SILENCIO** |
| L35·L76 | `grep -rn` read-only del literal push-a-base | FP | **SILENCIO** |
| L2 | `gh pr merge develop` (develop = rama ORIGEN) | FP | **SILENCIO** |
| L14–L27 | `git branch -D` de rama YA squash-mergeada | FP ×14 | **SILENCIO** |
| L137 | `--squash --subject` curado + `--body` largo | FP | **PASA** |
| L42·L43·L46·L107 | `--squash-message` multilínea INLINE curado | FP | **PASA** |
| L30·L51·L135 | RELEASE a `main` sin `--squash` | FP | **PASA (exento)** |

Controles negativos vivos en la misma corrida: merge a develop sin `--squash` → DENY; `--squash` con
mensaje pobre (<12 palabras) → DENY; `git branch -D` de rama NO integrada → avisa.

### 1.4 Degradación del juez: el contrato fail-CLOSED se cumple
Con `curl` falso devolviendo cada código y un transcript real (`confirmar-merge-develop`):

| Escenario | Resultado |
|---|---|
| sin token OAuth | DENY · *"FRENO (sin token OAuth…) Corre 'claude setup-token'…"* |
| token expirado (401 ×2) | DENY · *"FRENO (token OAuth expirado)… REINTENTA en unos segundos"* |
| sin red (código 000) | DENY · *"FRENO (juez no disponible)…"* |
| HTTP 500 | DENY · *"FRENO (juez no disponible)…"* |
| destino irresoluble (sin gh/glab) | DENY **con diagnóstico de ENTORNO correcto** + carril nombrado |

Los tres estados producen mensajes **específicos y accionables**, y el de entorno dice explícitamente
*"Repetir la autorización NO va a destrabar esto — es un problema de ENTORNO, no de permiso"* y deja al
operador su carril (`git merge` LOCAL a su mini). Esto es exactamente lo contrario del patrón que generó
el corpus. **Corrijo una sospecha propia:** en mi primer intento ambos estados salían con el mensaje
genérico de "dame autorización más clara" — era mi arnés (sin `transcript_path`), no el código.

### 1.5 CRÍTICO-1 (lib rota) y secret-scan
Con `analizar-comando-git.sh` corrompida a propósito (`bash -n` confirma el error de sintaxis):

```
### LIB ROTA (debe fallar RUIDOSO y CERRADO)
  merge-squash-guard       merge sin squash -> deny
  confirmar-merge-develop  merge a develop  -> deny
```
`secret-scan`, con secretos de laboratorio de formato válido (AWS, `glpat-`, `sk-ant-`, PEM) staged:
**deny en los 4, con lib sana Y con lib rota**; contenido limpio → SILENCIO. `proteger-arbol` **no** es
evadible con `git -c k=v` ni `git --no-pager` (M1 cerró eso).

---

## 2. Hallazgos

### H1 · ALTO · FALSO NEGATIVO — el caché de destino se consume sin validar dueño, permisos ni edad
**Bypass TOTAL de `confirmar-merge-develop`.** `acg__destino_de_mr_full` lee
`${TMPDIR:-/tmp}/acg-mrdest-<key>` y lo devuelve tal cual, **sin ninguna verificación** (`analizar-comando-git.sh:490-491`):
```bash
cache="${TMPDIR:-/tmp}/acg-mrdest-${key}"
if [ -f "$cache" ]; then cat "$cache"; return 0; fi
```
Si el contenido dice una rama personal, el guard hace `exit 0` (`confirmar-merge-develop.sh:388`).

**Repro (medido):**
```
$ printf 'DevelopUnjordi\nAPI\n' > "$TMPDIR/acg-mrdest-org_proyecto_glab_5"; chmod 666 …
-rw-rw-rw-@ 1 unjordi wheel 19 … acg-mrdest-org_proyecto_glab_5
  destino='DevelopUnjordi'  conf='API'
=== El HOOK completo con ese cache plantado ===
  >>> SILENCIO = GATE SALTADO (bypass)
```
Se presenta además con confianza **`API`** (la máxima), no como caché.

**Por qué es de ESTA rama:** el commit `9cc6c7e` (*"MEDIO — CACHE-DE-CREACION solo se confía si es del
mismo usuario y sin permisos abiertos"*) endureció al **hermano gemelo** y dejó a éste intacto. Contraste
medido en la misma corrida:
```
  creacion 0666 -> destino=''               (RECHAZADO, correcto)
  creacion 0600 -> destino='DevelopUnjordi' (aceptado)
  regular  0666 -> destino='DevelopUnjordi' (aceptado)   <-- sin chequeo
```

**Vector benigno, sin atacante — y probablemente el más importante:** no hay **TTL en la lectura**.
- Un caché de 2020 se sigue sirviendo hoy como `API` (medido: `mtime = Jan 1 00:00:00 2020` → `destino='develop' conf='API'`).
- Si un MR se **re-apunta** (develop→main, operación normal en GitLab/GitHub), el guard sigue leyendo el
  destino viejo → **un release a `main` se gatearía con las reglas débiles de `develop`**, que es justo el
  downgrade que el fail-safe de destino existe para impedir.
- `limpiar-residuo.sh` los barre a los 7 días, pero es un script **manual/periódico**, no un chequeo en
  lectura: la ventana de staleness es de hasta 7 días, e ilimitada si nadie lo corre.

**Alcance:** los tres cachés de la lib comparten el patrón sin validación —`acg-mrdest-*` (490),
`acg-mrmsg-*` (679), `acg-prlist-*` (708)— y el de destino lo comparten `confirmar-merge-develop` **y**
`merge-squash-guard`, así que un solo archivo desvía a los dos jueces a la vez.
**Reachability:** en macOS `TMPDIR` es por-usuario; el fallback `/tmp` (compartido, sticky) aplica cuando
`TMPDIR` viene sin definir — lo típico en Linux (la máquina Cachy del proyecto) y en procesos lanzados con
entorno mínimo, el mismo modo de falla que ya documenta el corpus (#78, PATH de launchd).

---

### H2 · MEDIO · FALSO NEGATIVO — el destino de un push OPACO no se detecta (asimetría con `--repo`)
`acg_push_destino_base` es una regex sobre literales, **sin detección de opacidad**, mientras
`acg_repo_explicito` **sí** marca `OPACO` ante `$`/backtick y falla cerrado. Medido:

```
  acg_repo_explicito 'gh pr merge 5 --repo "$R"'  = OPACO
  acg_push_destino_base 'git push origin "$RAMA"' -> NO detecta (fail-OPEN)
  acg_push_sin_refspec  'git push origin "$RAMA"' -> CON refspec => no entra al fallback de rama-actual
```
Ninguna de las dos rutas cubre el caso, así que el guard queda ciego:
```
  [git push origin "$RAMA"]           -> SILENCIO
  [RAMA=develop; git push origin "$RAMA"] -> SILENCIO
  [git push origin "${BASE:-develop}"]    -> SILENCIO
  [git push origin `echo develop`]        -> SILENCIO
  [git push origin devel\op]              -> SILENCIO   (el shell expande a 'develop': verificado)
  [git push origin $'develop']            -> SILENCIO
```
Las formas por partición de comillas (`de'vel'op`, `"dev"elop`, `devel""op`) **sí** se bloquean, así que el
despoje funciona; lo que falta es la opacidad. El caso realista no es la evasión deliberada sino
`git push origin "$RAMA"` dentro de un script — y el corpus (L142) muestra que unjordi **ya usa** el patrón
`--repo "$R"`, donde el sistema sí es fail-closed. **El arnés no lo cubre:** sus 5 asertos de `OPACO` son
todos de `--repo`, ninguno del destino del push.

---

### H3 · MEDIO · FALSO POSITIVO — hambruna de la ventana del transcript en corridas largas
`acg_recent_intercalado` lee `tail -n 6000` del `.jsonl`. Si la autorización real del usuario queda fuera
de esas líneas, el piso barato de `_juez_merge_uno` (`confirmar-merge-develop.sh:93`) devuelve **DENY sin
consultar al juez**, y el mensaje **culpa al usuario** en vez de nombrar la causa.

**Repro:** transcript con la autorización `"mergea el MR 5 a develop cuando termines"` seguida de 6 200
turnos de asistente (una corrida autónoma normal):
```
lineas del transcript: 6201
ventana que ve el juez => lineas USUARIO: 0

FRENO (definición de LISTO): el juez no encontró tu confirmación EXPRESA para integrar este MR (MR 5) a develop.
  (a) Dámela clara para ESTE MR (p. ej. 'mergea esto a develop').
```
La autorización **existe y es inequívoca**. El operador la repetirá y seguirá fallando: es el patrón
"muerde de más → el humano lo hace a mano" en su forma pura, y pega justo donde más duele (`turno-nocturno`).

**Mitigación parcial que SÍ funciona:** con un grant durable vigente y destino confirmado `develop`, pasa
(medido: SILENCIO). Pero si además el destino es irresoluble —el fallo de entorno dominante del corpus— el
grant no se consulta (por diseño, fix CRÍTICO-2/3) y el resultado es DENY. Los dos fallos más frecuentes
del corpus se componen en un bloqueo sin salida por CLI.

---

### H4 · MEDIO · FALSO NEGATIVO — léxico de release de OTRO PR desactiva la exigencia de squash
Con destino irresoluble, `merge-squash-guard` usa la señal de release de la ventana (M4). Pero la señal es
**de la ventana, no de ESTE MR**. Medido con el PR 391 (destino real `develop`) y una ventana donde el
usuario dijo *"libera a main el PR 390"* por **otro** PR:
```
  destino IRRESOLUBLE + release-de-otro-PR en ventana => PASA
  destino RESUELTO=develop + mismo texto              => FRENA
```
Resultado: un merge a `develop` **sin squash** se cuela — exactamente lo que el guard existe para impedir.
Es un trade-off deliberado del fail-safe, pero está anclado a la señal equivocada. Degrada higiene de
historia, no seguridad.

---

### H5 · BAJO-MEDIO · FALSO POSITIVO — la SIEMBRA de un repo sigue bloqueada, y sin escape
Los casos L4 y L114 del corpus siguen vivos, y son acciones que la **norma global exige** (*"si un repo no
tiene develop, créalo"*; la siembra de un repo vacío es la excepción explícita de la norma de git):
```
  FP L4: siembra de repo VACIO (0 commits)      -> deny
  FP L114: CREAR la rama develop que no existia -> deny
```
Agravante: `git-branch-guard` **no tiene escape** cuando `jq` está presente. Su único escape
(`CLAUDE_GIT_GUARD_SIN_JQ_PERSONAL`) sólo se lee en la rama sin-`jq`. Con `jq` instalado —el caso normal—
el operador queda **duro contra la pared**: la norma le manda crear `develop`, el guard se lo prohíbe y no
hay carril. Frecuencia baja (una vez por repo), pero cuando ocurre fuerza exactamente el desenlace que se
quiere evitar. La severidad la baja que sea raro; la sube que no haya salida.

---

### H6 · BAJO · DOC QUE MIENTE — los flowcharts y el contrato describen conducta que el código ya no tiene
El encargo decía que los charts "acaban de regenerarse, así que describen el hoy". **Medido, no se cumple
en tres puntos** (y en direcciones opuestas, así que no es un desfase parejo):

1. **`docs/flowcharts/03-enforcement-git-guards.dot:133`** promete: *"grant DURABLE vigente — M6: se
   consulta TAMBIÉN con destino VACÍO si NINGUNA línea USUARIO trae léxico de release"*. El commit
   `e93ffae` (CRÍTICO-2/3) **revirtió justo eso**. Medido con grant vigente + destino vacío + ventana sin
   léxico de release: **FRENA**, el grant no se consulta. El chart manda al operador a confiar en un
   grant que nunca se honrará.
2. **`03-enforcement-git-guards.dot:109`** declara viva una evasión que M1 **cerró**: *"proteger-arbol hace
   su PROPIO despojo inline… `git -c k=v push` puede evadir su chequeo"*. Medido: `git -c core.pager=cat
   branch -D` y `git --no-pager branch -D` **ambos AVISAN**. El chart documenta un agujero inexistente.
3. **`brain/hooks/juez-comun.sh:24`**, la cabecera que el propio archivo declara "definición ÚNICA" del
   contrato, conserva: *"NOTOKEN → DENY + redirección al carril de la WEB de GitLab"*. M8 retiró esa
   redirección de los mensajes por la norma anti-vein-popper; la salida real ya no la trae (verificado
   arriba). La fuente de verdad del contrato sigue **prescribiendo** lo que la norma prohíbe.

*(Nota lateral, no es hallazgo de la rama: la copia GLOBAL instalada en `~/.claude/hooks` es
PRE-M8 —emite "normalmente el humano en la web de GitLab"— y bloqueó varias de mis propias invocaciones de
prueba por citar sintaxis de merge/push en una cadena, es decir las clases FP L108/L125/L140 que esta rama
sí cierra. La rama mejora de verdad; la máquina todavía no la tiene.)*

---

## 3. Costura entre guards

- **Coherentes** donde comparten decisión: en el cruce a develop, `merge-squash-guard` y
  `confirmar-merge-develop` frenan juntos por razones distintas y compatibles (falta squash / falta OK).
  No encontré dos guards con conclusiones contradictorias sobre la misma invocación.
- **Acoplamiento real por estado compartido:** el caché de destino lo leen los dos jueces (H1) — un solo
  archivo desvía a ambos. Es el único punto donde un guard depende de estado que otro proceso escribió.
- El dedupe por `$0` (copia repo cede a la global) funcionó en todas las corridas; no vi doble disparo.

## 4. Recomendación de orden

1. **H1** — aplicar al caché regular el mismo chequeo UID+permisos que ya tiene el de creación, y añadir
   un TTL en lectura (el de `limpiar-residuo`, 7 días, ya es la política declarada). Cierra bypass y
   staleness de un golpe, con el mecanismo que la rama ya escribió.
2. **H3** — que el piso barato distinga "ventana sin líneas USUARIO" de "usuario no autorizó", y lo diga
   con el mensaje de ENTORNO (que ya existe y es bueno) en vez del de permiso.
3. **H2** — tratar el destino opaco como `OPACO`, homologando con `acg_repo_explicito`; nace con su aserto
   en el arnés, que hoy no lo cubre.
4. **H5** — dar un carril explícito a la siembra (escape auditado, como `CLAUDE_SKIP_SECRET_SCAN`).
5. **H4** y **H6** — anclar la señal de release al MR, y corregir los tres puntos de doc.

Ninguna de estas es aflojar un gate: H1/H2/H4 **aprietan**, H3/H5/H6 son precisión y verdad de doc.
