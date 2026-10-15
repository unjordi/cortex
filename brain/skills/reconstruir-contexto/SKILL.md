---
name: reconstruir-contexto
description: RED DE EMERGENCIA para cuando un checkpoint quedó mal hecho (hilo pobre/incompleto/ausente) y un /compact fundió el detalle real de la sesión — el caso en que [[rehidratar-hilo]] no basta porque el hilo que relee es inútil. Da el orden MECÁNICO de excavación, de lo más barato/fresco a lo más caro: (1) regenerar+leer el ANDAMIO mecánico, (2) las fuentes durables por-repo (estado-proyecto → bitácora → overflow), (3) el transcript .jsonl con grep/tail acotado, (4) re-volcar un hilo-mental BUENO ya reconstruido con [[checkpoint]]. Úsalo cuando retomas y el hilo está pobre/ausente/stale, o simplemente "no sé en qué iba" — antes de improvisar o confabular con seguridad.
---

# Reconstruir contexto — cuando el hilo se fundió y `rehidratar-hilo` no alcanza

**Procedimiento en una frase:** cuando retomas y el hilo mental está inútil, excava en ORDEN de lo más
barato a lo más caro — andamio mecánico → fuentes durables del repo → transcript `.jsonl` acotado — y
**termina siempre re-volcando** un hilo bueno con `checkpoint`, para que el próximo corte no repita esto.

> **Hermano de [[checkpoint]] y [[rehidratar-hilo]], para el caso en que ESE par falló.**
> `rehidratar-hilo` (hook + skill) **ASUME que el checkpoint se hizo bien**: relee
> `hilo-mental-actual.md` y lo reinyecta, confiando en que ahí está el juicio. Si el master estaba en
> pleno flow y no volcó, o volcó pobre (un hilo de 3 líneas, un "seguimos con lo de siempre" sin
> sustancia), `rehidratar-hilo` reinyecta ESO — y confirmarlo/anunciarlo no arregla nada, porque la
> fuente que lee ya está vacía. Este skill es lo que haces DESPUÉS de notar que el hilo reinyectado no
> sirve: **reconstruye** el hilo desde las fuentes que sobreviven a un mal checkpoint, y solo entonces
> vuelve a poner las cosas en manos de `checkpoint`/`rehidratar-hilo` para el siguiente ciclo.

## Cuándo invocarlo (la señal)

Retomaste (tras `/compact`, un corte, o un `--resume`) y pasa CUALQUIERA de estas:
- El hilo mental está **pobre o telegráfico** ("seguimos con X", sin decisión abierta ni siguiente paso
  concreto) — no te dice nada que no supieras ya por el nombre del archivo.
- El hilo está **ausente** (`hilo-mental-actual.md` no existe, o `rehidratar-hilo` avisó
  `⚠️ Compactaste SIN hilo mental fresco y SIN andamio`).
- El hilo está **marcado obsoleto** por el hook (`⚠️ HILO POSIBLEMENTE OBSOLETO`, otra rama o viejo) y
  no reconoces la tarea que describe.
- Honestamente **"no sé en qué iba"** — la señal más simple y la más importante: si la sientes, es tu
  cue para correr esto ANTES de escribir una sola línea de trabajo, no después de adivinar mal.

**Ninguna de estas es motivo para inventar.** El paso 0 de abajo es la regla dura que blinda contra el
modo de falla real: **confabular con seguridad tras un compact cuesta más que un "déjame verificar"**.
Un hilo reconstruido MAL (con criterio inventado en vez de excavado) es peor que admitir que no sabes —
porque se ve igual de seguro que uno bueno y nadie lo cuestiona.

## Paso 0 — regla dura: EXCAVA antes de afirmar, no adivines desde el resumen comprimido

El resumen que dejó el `/compact` (o el hilo pobre) es precisamente LA COSA QUE FALLÓ — no es una fuente
válida para reconstruir sobre ella. "Recupera de tu contexto vivo; EXCAVA/verifica solo lo que NO
tienes" (norma global, `~/.claude/CLAUDE.md`) aplica literal aquí: si la respuesta NO está en lo que
tienes vivo (y un hilo fundido significa que NO la tienes), la única salida honesta es excavar las
fuentes duras de abajo, en orden — nunca rellenar el hueco con lo que "probablemente" estabas haciendo.
Si al final de los 4 pasos sigue sin quedar claro, DÍLO ("no logro reconstruir la decisión de X, dame
20 segundos de contexto") en vez de fabricar una versión plausible.

## Paso 1 — regenera y lee el ANDAMIO mecánico (el más barato, hazlo SIEMPRE primero)

El andamio (`hilo-mental-actual.andamio.md`) lo escribe una MÁQUINA en `PreCompact`, sin turno del
modelo — por eso sobrevive exactamente al escenario que aquí te trajo (el master no alcanzó a volcar
juicio, pero la traza mecánica del tramo vivo sí quedó). Es el mismo paso 0 que ya exige `checkpoint`,
así que si ya lo corriste no lo repitas — pero si llegaste aquí SIN pasar por ahí, es tu primer movimiento:

```bash
node "$(ls ~/.local/bin/checkpoint-mecanico.js ~/.cortex/bin/checkpoint-mecanico.js 2>/dev/null | head -1)" \
     --self --ensure
cat .claude/memory/hilo-mental-actual.andamio.md
```

Esto te da GRATIS, sin gastar ventana ni criterio: el árbol de archivos tocados (Write/Edit + heurística
de escrituras por Bash), las skills invocadas, los `git commit`/mensajes de squash del tramo, y **las
últimas citas TEXTUALES del usuario** — la materia prima para no fabricar `[user: "…"]` de memoria.
Su ventana es el TRAMO VIVO desde el último `/compact`: describe justo lo que estaba por perderse.

**Qué NO esperar de él:** es evidencia, no juicio. No trae el "por qué Z" de una decisión que nunca se
tecleó, ni el trabajo hecho por subagentes (vive en otros `.jsonl`). Si con esto ya reconoces la tarea y
puedes reconstruir las 4 piezas del hilo (ver más abajo), **para aquí** — no hace falta ir más caro.

## Paso 2 — las fuentes durables del repo, EN ESTE ORDEN

Si el andamio no basta (te falta el "qué sigue" o el "por qué"), sigue con lo durable, del más reciente
al más histórico:

1. **`.claude/memory/estado-proyecto.md`** (o `estado-y-pendientes.md`) — el backlog VIVO: qué sigue,
   qué está decidido, qué quedó bloqueado y por qué. Es la fuente de verdad cross-sesión; si el hilo y
   este archivo divergen, manda éste.
2. **`.claude/memory/bitacora.md`** — el journal de qué PASÓ, día a día. Aquí encuentras la última línea
   de avance (`>>` appendeada) que te dice en qué commit/PR quedó el trabajo real.
3. **`.claude/memory/hilo-mental-actual-overflow.md`** (si existe) — si el hilo venía largo, el
   detalle de PLAN/RESUELTO/COSECHA se cortó ahí; el principal solo apunta a su existencia.

```bash
sed -n '1,80p' .claude/memory/estado-proyecto.md   # el tope suele traer la sección "activa"/"en curso"
tail -n 60 .claude/memory/bitacora.md              # las últimas líneas = lo más reciente
[ -f .claude/memory/hilo-mental-actual-overflow.md ] && cat .claude/memory/hilo-mental-actual-overflow.md
```

Con esto ya deberías tener el QUÉ (la tarea/ítem del backlog) y el DÓNDE QUEDÓ (último commit/PR en la
bitácora). Lo que sigue faltando casi siempre es el JUICIO fino — la decisión a medio cocinar, el porqué
de un enfoque sobre otro — y eso solo vive en el transcript.

## Paso 3 — excava el transcript `.jsonl` (el más caro; SIEMPRE acotado, NUNCA entero)

El transcript es la fuente ÚLTIMA (todo lo demás se derivó de ahí), pero es grande y su formato es
**interno y cambia entre versiones** (no lo parsees para producción, solo para lectura puntual). Vive en:

```
~/.claude/projects/<slug-del-cwd>/<session-id>.jsonl
```

donde `<slug>` sale del cwd con que ARRANCÓ la sesión, con todo carácter no-alfanumérico convertido a `-`.
⚠️ En un **worktree** ese cwd de arranque es el checkout PRINCIPAL, no el worktree — así que deriva el slug
del `git-common-dir`, NO de `pwd` (si no, apuntas a un dir de proyecto que no existe). Encuéntralo y acótalo
— **grep/tail con límite, jamás `cat`/`Read` completo** (overflow garantizado; son archivos de decenas de MB):

```bash
# dir de proyecto de ESTA sesión: se llavea al cwd de ARRANQUE = el checkout PRINCIPAL en un worktree.
# `printf` evita el \n final que `tr -c` volvería un '-' colgado; cae al .jsonl más reciente si el slug no calza.
ROOT=$(cd "$(git rev-parse --git-common-dir 2>/dev/null)/.." 2>/dev/null && pwd)
SLUG=$(printf '%s' "${ROOT:-$PWD}" | tr -c 'a-zA-Z0-9' '-')
T=$(ls -t ~/.claude/projects/"$SLUG"/*.jsonl 2>/dev/null | head -1)
[ -z "$T" ] && T=$(ls -t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -1)

# últimos mensajes de USUARIO, verbatim (la señal más directa de "qué pedí"). OJO: corta por LÍNEAS
# (`tail -n`), NO por bytes — un `tail -c` parte la 1ª línea y jq ABORTA el stream entero. El `.content`
# de un user es un ARRAY de bloques: desenvuelve el texto y descarta los tool_result (ruido de herramientas).
tail -n 600 "$T" | jq -rc 'select(.type=="user") | .message.content | if type=="string" then . else (map(select(.type=="text").text)|join(" ")) end | select(.!="")' 2>/dev/null | tail -20

# últimos tool_use (qué estabas HACIENDO — archivos tocados, comandos corridos):
tail -n 600 "$T" | jq -rc 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | {name, input}' 2>/dev/null | tail -30

# fallback si el jq no calza con esta versión del formato (texto plano; grep SÍ tolera un corte por bytes):
tail -c 500000 "$T" | grep -o '"text":"[^"]\{0,300\}' | tail -20
```

Nota el patrón: acotas DOS veces — la ventana de ENTRADA (`tail -n` para jq, que necesita líneas COMPLETAS;
`tail -c` solo para el grep, que tolera el corte a media línea) y luego `tail -N` sobre el RESULTADO. Si el
`jq` sale vacío porque el esquema cambió (es interno, puede driftear), cae al `grep` de texto plano: sigue
siendo mejor que adivinar.

**Qué buscar, en orden de utilidad:** (a) el último mensaje tuyo real (no saludo/confirmación corta) —
casi siempre contiene el objetivo vigente; (b) los últimos 2-3 `tool_use` de Write/Edit — qué archivo
estabas tocando cuando cortó; (c) si hace falta más contexto, sube la ventana de `tail -n` gradualmente
(nunca al archivo completo de una sola pasada).

## Paso 4 — RE-VUELCA un hilo-mental BUENO (cierra el lazo, no lo dejes solo reconstruido en tu cabeza)

Reconstruir sin volver a escribirlo es repetir el problema en el próximo corte. Con lo que juntaste en
los pasos 1-3, arma las 4 piezas que `checkpoint` exige y corre el skill `checkpoint` (nivel COMPLETO si
la tarea es sustantiva) para dejarlo en disco:

- **🗂️ Árbol de 3 ramas** — sale casi listo del andamio (paso 1): memorias tocadas hoy, insumos a leer,
  tooling relevante.
- **En qué estamos** — el QUÉ del paso 2 (ítem del backlog) + el DÓNDE QUEDÓ (último commit/PR de la
  bitácora).
- **Decisión abierta / siguiente paso** — el JUICIO fino que solo el paso 3 pudo dar: la última decisión
  a medio cocinar, con su procedencia (`[user: "…"]` si la cita es textual del transcript, `[INFER-mío]`
  si la estás infiriendo del patrón de archivos tocados — **nunca disfraces una inferencia de cita**).
- **Hilos sueltos** — cualquier cabo que el andamio o la bitácora mencionen sin resolver.

```
[[checkpoint]]   ← corre este skill para el volcado formal; no reescribas el hilo a mano fuera de su formato
```

## Anti-patrón que este skill existe para evitar

Retomar con un hilo pobre, notar que "algo no cuadra", y **seguir de todos modos** completando los
huecos con lo que "seguramente" era la intención — sin haber corrido los pasos 1-3. Eso es exactamente
confabular con seguridad tras un compact: el resultado suena igual de convincente que un hilo bien
reconstruido, y nadie (ni tú) puede distinguirlo hasta que ya costó una decisión mal tomada o un trabajo
tirado. El costo del paso 3 (un par de `tail`/`jq` acotados) es minutos; el costo de adivinar mal es
rehacer trabajo o pisar una decisión ya tomada.

## Qué NO es

- **No sustituye a `checkpoint`.** Este skill EXCAVA y reconstruye; `checkpoint` es quien VUELCA el
  resultado a `hilo-mental-actual.md` con su formato/gate de frescura. Siempre terminas en `checkpoint`.
- **No sustituye a `rehidratar-hilo`.** Ese asume que el hilo en disco ya es bueno y solo lo anuncia/
  retoma. Si el hilo SÍ era bueno, no necesitas esto — usa `rehidratar-hilo` directo.
- **No es un parser de producción del `.jsonl`.** El formato del transcript es interno y cambia entre
  versiones; los comandos de arriba son para LECTURA puntual de emergencia, con fallbacks cuando el
  esquema no calza — no para automatizar sobre él (para eso existe `checkpoint-mecanico.js`, que ya
  encapsula esa fragilidad).
