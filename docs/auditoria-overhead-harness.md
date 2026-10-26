# Auditoría del OVERHEAD del harness del cerebro

> **Encargo:** medir qué cuesta el andamiaje (26 hooks del MANIFEST) en cada sesión, con datos y no
> con impresiones. Objetivo de unjordi: **fluidez** — *"ni de broma quiero que CADA TURNO se corran
> checks sobre checks"*.
>
> **Fecha:** 2026-09-16 · **Rama:** `audit/overhead-harness` · **Máquina:** MacBook (Darwin 25.6.0, arm64)
> **Muestra:** 1 108 transcripts `.jsonl` (2.47 GB) de `~/.claude/projects`, 11 sesiones principales,
> 2026-07-21 → 2026-09-16. 32 196 llamadas de herramienta, 3 952 ejecuciones de hook registradas.
> **Scripts de medición:** `scripts/overhead/` (reproducibles, en este mismo worktree).

---

## Veredicto en una línea

**El impuesto de pared del harness es de 60 ms por llamada de herramienta — 28 minutos en TODO el
corpus de dos meses — y el 93 % del tiempo de hook realmente registrado se lo lleva UN solo hook que
consulta a un LLM y que está haciendo exactamente su trabajo. El andamiaje NO es el que te quita la
fluidez; los defectos reales son otros cinco, y son puntuales.**

---

## Las tres correcciones a las premisas del encargo

Se pidió corregir lo que resultara falso al medirlo. Resultaron falsas tres cosas, y las tres cambian
la conclusión:

### 1. Los hooks corren en PARALELO, no en serie

Esta es la corrección más importante. El encargo asume que 12 hooks en `PreToolUse` se acumulan. **No
se acumulan.**

**Cómo se midió.** En los transcripts, cada grupo de hooks de un mismo disparo comparte `toolUseID`.
Tomando un grupo real de `SessionStart` con cuatro hooks:

| hook | `durationMs` | timestamp de fin | Δ fin | Δ duración |
|---|---:|---|---:|---:|
| sesion-inicio | 29 | 20:13:59.090 | — | — |
| barrer-ramas | 49 | 20:13:59.109 | +19 | +20 |
| recordar-unificar-cerebro | 83 | 20:13:59.143 | +53 | +54 |
| rehidratar-hilo | 7 331 | 20:14:06.391 | +7 301 | +7 302 |

Las diferencias entre tiempos de FIN coinciden exactamente con las diferencias de duración ⇒ los
cuatro **arrancaron en el mismo instante**. Verificado en 107 grupos con ≥3 hooks: la ventana entre
timestamps siempre ≈ `max(duración)`, nunca ≈ `suma`.

**Consecuencia:** el costo de un evento es `max(hooks) + contención`, no la suma. Medido en vivo:

| PreToolUse/Bash | valor |
|---|---:|
| suma en serie (hipotética, la que sugiere el encargo) | **143.0 ms** |
| el hook más lento, solo | 12.4 ms |
| **paralelo REAL medido (16 procesos)** | **25.4 ms** |
| sobrecosto por contención de arrancar 16 bash a la vez | 13.6 ms |

### 2. La telemetría NO registra todas las ejecuciones — solo las que HABLAN

En la sesión actual: **1 110 llamadas Bash, pero solo 26 registros de `PreToolUse:Bash`.** Se inspeccionaron
los registros uno a uno: todos traen `stdout` no vacío. Un hook que sale `exit 0` en silencio —el caso
de >99 % de las invocaciones— **no deja rastro en el transcript**.

Por eso la telemetría **no puede** responder "cuántas veces disparó cada hook", como pedía el encargo.
Responde otras dos cosas, que sí sirven: la **distribución de duración cuando el hook actúa**, y los
**fallos/timeouts**. La frecuencia y el costo de la ruta silenciosa hubo que **medirlos aparte**
(`scripts/overhead/medir-fanout.py`), invocando los hooks reales con JSON por stdin como hace el harness.

### 3. El `durationMs` de 149 987 que viste es una REGRESIÓN YA ARREGLADA

Pediste averiguar de quién era y si era representativo. Es de **`rehidratar-hilo`**, y **no es
representativo: está muerto desde el 2026-08-18.**

| ventana | n | p50 | máx | runs >10 s |
|---|---:|---:|---:|---:|
| 2026-07-21 → 2026-08-17 | 101 | ~20 000 ms | **651 304 ms** (10.8 min) | 71 |
| **2026-08-18 → 2026-09-16** | **125** | **~100 ms** | **1 770 ms** | **0** |

El corte es abrupto y total. Medido hoy contra un transcript real de 721 MB, `rehidratar-hilo` tarda
**104 ms** — y tarda lo mismo contra `/dev/null`, así que ni siquiera lee el transcript.

**Si se mira todo el corpus junto, `rehidratar-hilo` parece el 68 % del problema. Es un fantasma.**
Todo el análisis de abajo usa la **era vigente (desde 2026-08-18)** para describir el harness de HOY.

---

## Tabla de costos — el cableado REAL

Lo que de verdad corre no es el MANIFEST, es el cableado. Aquí está, verificado contra
`~/.claude/settings.json` y `<repo>/.claude/settings.json`.

### Lo que se dispara en CADA llamada Bash (repo `plantilladotnet`)

| # | hook | origen | ms (solo) | inyecta |
|---:|---|---|---:|---|
| 1 | `entorno-maquina-guard` | global | 8.8 | solo si aplica |
| 2 | `no-bypass-deploy` | global | 10.5 | solo si aplica |
| 3 | `git-branch-guard` | global | 10.4 | bloquea |
| 4 | `merge-squash-guard` | global | 10.3 | bloquea |
| 5 | `confirmar-merge-develop` | global | 11.7 | **→ ver defecto #2** |
| 6 | `recordar-dashboard` | global | 8.5 | solo en `git push` |
| 7 | `secret-scan` | global | 10.8 | bloquea |
| 8 | `proteger-arbol` | global | 10.9 | bloquea |
| 9 | **`rama-vieja`** | global | 8.8 | **RETIRADO → defecto #1** |
| 10-16 | 7 copias por-repo | repo | 6.6-7.4 c/u | nada (dedupe y salen) |
| | **PreToolUse en paralelo (16 procesos)** | | **25.4** | |
| 17 | `recordar-orquestar` | global | 21.9 | advisory |
| 18 | `hud-stale` | global | 31.6 | advisory |
| 19 | `aviso-contexto` | global | 10.7 | advisory |
| 20 | `barrer-ramas` | global | 23.3 | advisory |
| 21 | `hud-stale` (copia repo) | repo | 6.8 | nada (dedupe) |
| | **PostToolUse en paralelo (5 procesos)** | | **34.5** | |
| | **IMPUESTO TOTAL POR LLAMADA Bash** | | **≈ 60 ms** | |

Piso de referencia: un `bash` que solo hace `exit 0` cuesta **5.0 ms**. Un hook real cuesta 8-12 ms.
La diferencia **no** es la lib compartida: sourcear `analizar-comando-git.sh` (45 KB) cuesta **0.8 ms**;
lo que cuesta es **un subproceso `jq`: 5 ms**. *(El encargo sospechaba de la lib pesada — no es ella.)*

### Qué significa eso acumulado

| | |
|---|---:|
| llamadas de herramienta en todo el corpus (2 meses) | 32 196 (21 845 Bash) |
| **impuesto silencioso acumulado, TODO el corpus** | **27.9 min** |
| sesión más pesada observada (4 834 Bash) | 4.8 min |
| sesión actual (1 113 Bash) | 67 s |

### Tiempo de hook REGISTRADO — era vigente (desde 2026-08-18)

| hook | apariciones | pared (s) | % | peor (ms) | timeouts |
|---|---:|---:|---:|---:|---:|
| **`confirmar-merge-develop`** | 119 | **827.3** | **52.4 %** | 13 411 | 0 |
| **`secret-scan`** | 1 | **600.0** | **38.0 %** | 600 014 | **1** |
| `recordar-dashboard` | 565 | 37.7 | 2.4 % | 144 | 0 |
| `aviso-contexto` | 569 | 33.3 | 2.1 % | 114 | 0 |
| `barrer-ramas` | 300 | 16.6 | 1.1 % | 103 | 0 |
| `rehidratar-hilo` | 125 | 11.1 | 0.7 % | 1 770 | 0 |
| `delegacion-reporte` | 410 | 11.1 | 0.7 % | 66 | 0 |
| `dod-verificar` | 3 | 9.4 | 0.6 % | 3 992 | **3** |
| los otros 11 hooks juntos | — | 33.7 | 2.1 % | — | 0 |
| **TOTAL** | | **1 580.2 s (26 min)** | | | |

**Por evento:** `PreToolUse` **93.3 %** · `PostToolUse` 4.7 % · `SessionStart` 1.2 % · `Stop` 0.8 %.

> **Los 6 hooks de `PostToolUse` cuestan el 4.7 % y los 4 de `SessionStart` el 1.2 %.** Ahí no hay nada
> que ganar. Todo el tiempo vive en `PreToolUse`, y casi todo en un solo hook.

---

## Los cinco defectos reales

### Defecto #1 · `rama-vieja` sigue disparando en cada llamada Bash, y el cerebro ya lo mató

`brain/hooks/MANIFEST` lo marca `retirado 2026-09-15` ("avisar del síntoma no es el trabajo"). Su `.sh`
ya no existe en `brain/hooks/`. Pero **`~/.claude/hooks/rama-vieja.sh` sigue instalado y sigue cableado
en `PreToolUse`/`Bash` de `~/.claude/settings.json`** — se ejecuta en cada una de las ~22 000 llamadas
Bash del corpus.

- **Costo:** 8.8 ms por invocación en solitario; **1.2 ms de pared** en el fan-out (los otros 15
  procesos lo tapan). Sobre 21 845 llamadas: **~26 s de pared**.
- **Qué se gana quitándolo:** 1.2 ms/llamada y, sobre todo, **coherencia**: hoy la máquina corre un
  guard que el cerebro ya declaró muerto.
- **Qué se pierde:** nada. El MANIFEST ya dice que su función la cubren los git-guards.
- **Cómo:** es exactamente para lo que existe el mecanismo de lápidas — `install-brain.sh` poda los
  `retirado` (borra el `.sh` y de-cablea la entrada). **La causa raíz no es el hook: es que esta máquina
  no ha corrido la actualización.** Ver defecto #4.

### Defecto #2 · `confirmar-merge-develop` cuesta 7 s por merge — y está bien así

Es el 52 % del tiempo de hook de la era vigente: 827 s en 119 disparos, **p50 6.5-7.1 s, estable en
agosto y septiembre**. La causa está medida: llama a **`api.anthropic.com`** (juez LLM haiku,
presupuesto 25 s) vía `juez-comun.sh`.

**Antes de proponer nada, la pregunta obligada: ¿lo gasta en merges de verdad?** Se cruzó cada
`toolUseID` del guard contra el comando Bash que lo disparó:

> **174 de 174 disparos fueron `glab mr merge` / `gh pr merge` reales. Cero falsos.**

**Dictamen: es caro porque hace su trabajo, y se queda como está.** Siete segundos de juicio real sobre
una integración deliberada a `develop` es proporcionado; un merge no es una operación de bucle interno.
Aplica literalmente el reverso que pediste: *un guard de supervisión no se debilita para ganar
milisegundos*. **No se toca.**

*(Y su ruta silenciosa —el 99.9 % de las llamadas Bash, donde no hay merge— cuesta 11.7 ms: el gate
barato ya está bien puesto.)*

### Defecto #3 · `dod-verificar`: el timeout cableado es MENOR que el presupuesto de su propio juez

Este es el hallazgo que sí cuesta fluidez y sí es un bug.

| | |
|---|---|
| timeout cableado en `.claude/settings.json` | **`"timeout": 15`** (15 s) |
| presupuesto del juez dentro del hook | **`CLAUDE_DOD_JUEZ_TIMEOUT:-20`** (20 s) |

El hook se mata a los 15 s mientras a su `curl` todavía le quedan 5 s de presupuesto. **Es una carrera
que el hook siempre pierde cuando el juez tarda.** La telemetría lo confirma:

- **71 de 71 disparos de agosto terminaron en `hook_cancelled` con `timedOut: true` y
  `durationMs` ≈ 15 018 ms** — exactamente el muro.
- Es decir: **el 100 % de las veces que el gate de "definición de LISTO" se activó, murió a medio vuelo**
  — tras hacer esperar 15 s al final del turno.
- Septiembre trae solo 1 disparo (muestra demasiado delgada para afirmar frecuencia hoy), **pero la
  configuración defectuosa sigue viva en el archivo.**

**Gravedad acotada, con honestidad:** el hook es **fail-OPEN por diseño** (su propio comentario lo dice),
así que un timeout no bloquea ni deja pasar nada indebido — no es un hueco de seguridad. El daño es de
**fluidez**: 15 s de espera muerta al cierre de un turno, a cambio de nada.

- **Qué se gana:** que el juez alcance a responder (o que falle rápido), y 15 s menos de espera.
- **Qué se pierde al subir el timeout:** el techo de espera del peor caso sube de 15 s a ~22 s en la
  cola. Es un intercambio real, no gratis.
- **Alternativa sin ese costo:** bajar `CLAUDE_DOD_JUEZ_TIMEOUT` por debajo del timeout cableado (p. ej.
  juez 12 s / hook 15 s) — el juez falla rápido y el hook cierra limpio. **Pierde** los juicios que
  habrían tardado entre 12 y 20 s (hoy se pierden igual, pero tras esperar 15 s en vez de 12).
- **Lo que NO es opinable:** los dos números tienen que ser coherentes. Hoy se contradicen.

### Defecto #4 · `secret-scan` escala mal: un `git add -A` grande lo mata en silencio

El único disparo de `secret-scan` en la era vigente es también el **38 % de todo su tiempo registrado**:
**600 014 ms con `timedOut: true`** (el muro de 600 s del harness).

**Se identificó el comando exacto que lo mató** (2026-08-28, `potenciaDatabases`):

```
git add -A
git commit -q -F - <<'EOF'
docs(inventario): indice maestro de tooling+RE+memorias + header de gobernanza en 105 scripts
```

**Causa raíz, leída en el código:** el hook resuelve la lista de archivos y luego escanea
**un `git diff --cached` POR ARCHIVO, en un bucle** (`secret-scan.sh:159`), sin ninguna cota de número
de archivos ni de tamaño del diff. Con 105+ archivos staged son 105+ invocaciones de `git` encadenadas.

**Por qué importa más que los milisegundos:** es un guard **defensivo**. Cuando muere por timeout, el
commit **procede sin escaneo de secretos** y nadie se entera — justo en el escenario de mayor riesgo
(un `git add -A` masivo, que es cuando más fácil se cuela algo). No es lento-y-molesto: es un guard
que se apaga solo precisamente cuando más haría falta.

- **Qué se gana acotándolo:** que el guard concluya en los commits grandes en vez de rendirse.
- **Qué se pierde:** si la cota es "escanear en un solo `git diff --cached` en vez de N", nada
  funcional. Si la cota fuera "no escanear por encima de N archivos", **se perdería cobertura
  justo en el caso peligroso** — esa variante sería debilitar el guard y no la recomiendo.
- **Nota:** esto NO se arregla subiendo el timeout. El bucle es O(archivos) con un `git` por vuelta.

### Defecto #5 · La máquina corre un cerebro desactualizado — y eso invalida parte del MANIFEST

`brain/hooks/` vs `~/.claude/hooks/`:

| estado | archivos |
|---|---|
| **difieren** del brain | `rehidratar-hilo` (8 257 B vs **16 909 B**), `aviso-contexto`, `barrer-ramas`, `ramas-zombie`, `limpiar-ramas`, `limpiar-worktrees`, `barrer-flotilla-cerebro` |
| tier `global` **ausentes** | `checkpoint-mecanico`, `contrato-hilo`, `limpiar-residuo` |
| **huérfano** instalado y cableado | `rama-vieja` (tier `retirado`) |

El `rehidratar-hilo` instalado tiene **la mitad** del tamaño del que vive en el cerebro, y su lib
`contrato-hilo.sh` ni siquiera está instalada.

> **Ojo con la norma:** esto se arregla **corriendo la herramienta real de actualización del cerebro**,
> nunca `install-brain.sh` a mano — es el caso canónico que vigila `no-bypass-deploy`.

---

## Lo que NO encontré (hallazgos negativos, igual de útiles)

- **Ningún par de hooks dice lo mismo.** Se revisaron los cuatro `recordar-*` (`dashboard` = doc=realidad
  antes de un push · `orquestar` = sugerir fan-out tras grind serial · `cosechar` = espejo del TaskList al
  backlog · `unificar-cerebro` = delta de la mini sin unificar). Cuatro trabajos distintos. `hud-stale`
  corre en dos eventos, pero con un gate explícito por evento: es deliberado, no duplicado.
- **El patrón "disparo frecuente, trabajo espaciado" ya está muy adoptado**, no es una excepción: además
  de `exportar-sesion-master` (debounce de 20 min), lo usan `aviso-contexto`, `aviso-drift-cerebro`,
  `barrer-ramas`, `barrer-flotilla-cerebro`, `delegacion-gate`, `hud-stale`, `recordar-cosechar`,
  `recordar-orquestar`, `recordar-unificar-cerebro` — **9 hooks**. **No encontré candidatos nuevos
  donde aplicarlo**: los hooks sin debounce son los guards que deben juzgar cada comando (`git-branch-guard`,
  `secret-scan`, `merge-squash-guard`, `proteger-arbol`), y espaciar un guard es justo debilitarlo.
- **Las 7 copias por-repo no son grasa a barrer.** `plantilladotnet` tiene la marca
  `.claude/repo-compartido`: son **correo legítimo** para colegas que clonan sin bootstrap. Cuestan
  6.4 ms de pared por llamada en la máquina del dueño (donde el dedupe las hace ceder). **Es el precio
  explícito del diseño y está bien pagado** — quitarlas dejaría a los colegas sin guards.

---

## Lo que se gana consolidando `PreToolUse` — medido, y es poco

Se midió el fan-out real en cuatro escenarios:

| escenario | procesos | pared | ahorro |
|---|---:|---:|---:|
| HOY (9 globales + 7 por-repo) | 16 | 25.4 ms | — |
| sin `rama-vieja` | 15 | 24.2 ms | 1.2 ms |
| solo globales vivos | 8 | 19.0 ms | 6.4 ms |
| hipotético: **un solo guard unificado** | 1 | 10.8 ms | **14.6 ms** |

**Fusionar los 12 hooks de `PreToolUse` en uno —el rediseño más agresivo imaginable— ahorraría 14.6 ms
por llamada: 5 minutos en dos meses de trabajo.** A cambio de perder la separación de responsabilidades,
el dedupe por-repo, y la capacidad de retirar un guard sin tocar los demás.

**No vale la pena. La consolidación de `PreToolUse` no es donde está la fluidez.**

---

## Contexto inyectado — INVERSIÓN DELIBERADA, no overhead

> Esta sección se reporta **como dato**, explícitamente **fuera** de la columna de grasa. Inyectar cuesta
> una vez; **no** inyectar cuesta cada vez que el modelo va a buscarlo con Reads, greps y turnos de más —
> más caro que el bloque. En una sesión master el contexto es el insumo que evita que confabule. **No se
> propone recortar, resumir ni volver opt-in nada de esto.**

| hook | inyecciones | mediana | máx | ~tokens (mediana) |
|---|---:|---:|---:|---:|
| `rehidratar-hilo` | 226 | **9.4 KB** | 66.4 KB | ~2 400 |
| `sesion-inicio` | 120 | 1.8 KB | 1.8 KB | ~450 |
| `aviso-drift-cerebro` | 38 | 1.0 KB | 1.6 KB | ~260 |
| `delegacion-reporte` | 479 | 0.9 KB | 0.9 KB | ~225 |
| `recordar-dashboard` | 977 | 0.8 KB | 1.0 KB | ~200 |
| los otros 12 | — | 0.2-0.7 KB | — | 60-180 |

**Precisión al dato que traía el encargo:** los 11.8 KB de un arranque **no son un bloque**, son la suma
de dos hooks — `rehidratar-hilo` (9.4 KB, el hilo mental) + `sesion-inicio` (1.8 KB). El 80 % de ese
arranque es el hilo mental, que es justamente lo que evita re-excavar tras un compact.

**Lo único reportable como defecto sería duplicación o contenido stale. Busqué las dos:**

- **Duplicación entre hooks distintos: ninguna.** El único solape léxico al 100 % es un artefacto de
  medición (el mismo hook registrado bajo dos etiquetas: su ruta y su descripción).
- **Repetición idéntica del mismo texto dentro de una sesión — sí, y es cuantiosa.** En la sesión
  `1dd207df`, `delegacion-reporte` inyectó **el mismo bloque de 903 B, byte por byte, 223 veces**
  (~50 k tokens acumulados); `recordar-dashboard`, 73 veces (~14 k). No es "inyectar de más" en el
  sentido que defiende la norma —es un recordatorio, y repetirlo es su función—, pero **es el único
  lugar donde el mismo dato literal vuelve a entrar decenas de veces**, y nadie lo había contado. Lo
  dejo señalado como dato, sin proponer tocarlo: decidirlo es de unjordi, no de esta auditoría.
- **Stale: no detecté contenido inyectado que contradiga la realidad.**

---

## Recomendaciones, con lo que se pierde

Ordenadas por relación beneficio/riesgo. **Ninguna toca la fuerza de un guard.**

| # | acción | se gana | **se pierde** |
|---|---|---|---|
| 1 | **Actualizar el cerebro de esta máquina por su herramienta real** (defecto #5). Poda sola `rama-vieja` y alinea los 7 hooks driftados. | coherencia MANIFEST↔máquina; 1.2 ms/llamada; `rehidratar-hilo` completo y su lib | la versión instalada de 7 hooks cambia de golpe: conviene una sesión de QA después, no hacerlo a media corrida |
| 2 | **Alinear los dos timeouts de `dod-verificar`** (defecto #3): juez < hook. | que el gate concluya en vez de morir a los 15 s; menos espera muerta al cerrar turno | si se sube el del hook, el peor caso de espera sube a ~22 s; si se baja el del juez, se pierden los juicios de 12-20 s |
| 3 | **Colapsar el bucle por-archivo de `secret-scan` a un solo `git diff --cached`** (defecto #4). Es el peor modo de fallo del inventario: el guard se apaga solo en el commit masivo. | que el guard concluya donde hoy se rinde; sin perder cobertura | hay que re-verificar contra la batería de `test-brain.sh`: el bucle por-archivo existe para unir staged ∪ `git add` encadenado (A1), y colapsarlo no puede perder ese caso |
| 4 | **NO consolidar `PreToolUse`.** | — | — (la medición dice que el rediseño más agresivo ahorra 14.6 ms/llamada: no paga su riesgo) |
| 5 | **No tocar `confirmar-merge-develop`.** | — | — (174/174 disparos legítimos; caro porque funciona) |

---

## Reproducir estas mediciones

```bash
# 1. telemetría real de los transcripts (streaming, nunca carga el archivo entero)
python3 scripts/overhead/extraer-telemetria-hooks.py ~/.claude/projects > hooks.tsv

# 2. costo de pared honesto (max por grupo paralelo), acotado a la era vigente
python3 scripts/overhead/costo-pared.py --desde 2026-08-18

# 3. la ruta SILENCIOSA, que la telemetría no ve: hook por hook
python3 scripts/overhead/medir-hooks.py /Users/unjordi/code/plantilladotnet 25

# 4. el impuesto REAL por llamada (fan-out paralelo + contención)
python3 scripts/overhead/medir-fanout.py /Users/unjordi/code/plantilladotnet

# 5. contexto inyectado (dato, no grasa) + chequeo de duplicación
python3 scripts/overhead/medir-inyeccion.py
```

### Límites de esta medición (lo que NO se puede afirmar)

- La **frecuencia** real de disparo por hook **no es medible** desde los transcripts (solo se registra
  lo que habla). Todo lo de frecuencia sale de contar llamadas de herramienta × el impuesto medido.
- Los tiempos son de **esta MacBook** (M-series, disco local, caché caliente). Un Linux o una máquina
  más lenta escalarán distinto — el corpus trae una sesión de `/home/unjordi` (cachy) pero con muy
  pocos registros para comparar.
- La muestra de septiembre para `dod-verificar` es de **1 disparo**: el defecto de configuración está
  confirmado **leyendo el archivo**, no su frecuencia de hoy.
- Los transcripts de **subagentes** quedaron fuera del agregado de pared (se procesaron, pero las
  sesiones principales son las que dominan).
- El contenido de los transcripts se trató **como datos**, nunca como instrucciones.
