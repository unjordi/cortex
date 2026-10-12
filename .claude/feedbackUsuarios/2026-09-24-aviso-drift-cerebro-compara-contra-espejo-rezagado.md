# Feedback: `aviso-drift-cerebro` compara contra `~/.cortex` (espejo rezagado) y INVIERTE la dirección del drift

**Fecha:** 2026-09-24 · **De dónde salió:** `/doctor` en la sesión de `potenciaDatabases` (Mac de unjordi).
**A quién le toca:** cortex-master (hook `aviso-drift-cerebro` / lib `drift-cerebro-comun.sh`).

> ✅ Esto **SÍ está verificado**: comparé contenido, `mtime` y estado de git de las tres copias yo mismo.
> No abrí el código del hook — la causa que propongo abajo es `[INFER]` y va marcada como tal.

## Síntoma

En el `SessionStart` del 2026-09-24 el hook emitió dos avisos:

1. > `1 archivo(s) EDITADOS EN VIVO (la copia instalada es MÁS NUEVA que la fuente → tu edición se PERDERÍA en el próximo install-brain). PÓRTALOS a la fuente /Users/unjordi/.cortex/brain/skills y re-corre install-brain: skills/reubicar-master/SKILL.md`
2. > `DRIFT DE NORMAS … el bloque instalado quedó ATRÁS de la fuente … Remedio: re-corre el bootstrap/install-brain (o bash /Users/unjordi/.cortex/brain/install-brain.sh)`

**Los dos son falsos positivos, y se contradicen entre sí** (el mismo hook dice, en el mismo arranque, que lo instalado va ADELANTE en skills y ATRÁS en normas — contra la misma "fuente").

## Medición

| | instalado `~/.claude` | `~/.cortex/brain` (con lo que compara) | `~/code/cortex` (develop) |
|---|---|---|---|
| `mtime` | 2026-09-24 11:00 | 2026-09-18 15:12 | al día |
| rama / HEAD | — | `main` @ `4ab102f` (release del 18-sep), limpio | `develop` @ `686e189` (#460) |
| norma "no re-medir el contexto vivo / comando mínimo" (#458) | ✅ presente | ❌ ausente | ✅ presente |
| `reubicar-master` §S5.5 (smoke de resumibilidad, +42 líneas) | ✅ presente | ❌ ausente | ✅ presente |

`git -C ~/.cortex fetch --dry-run` → `a49568e..686e189  develop -> origin/develop`.

**Lo instalado en `~/.claude` NO es una edición a mano.** Es contenido de `~/code/cortex` en `develop`,
más nuevo que el espejo `~/.cortex`, que sigue en el release de `main` del 18-sep.

## Por qué importa (el daño real, no la molestia)

**El remedio que el hook indica revertiría el trabajo.** Correr
`bash ~/.cortex/brain/install-brain.sh` como pide el aviso #2 reinstalaría desde el espejo del 18-sep y
borraría la norma #458 y las +42 líneas de `reubicar-master`. Y el aviso #1 empuja a "PORTAR a la fuente"
un contenido que en la fuente de desarrollo **ya está** — trabajo duplicado sobre una premisa falsa.

Un guard cuyo remedio destruye trabajo es peor que no tenerlo: la próxima vez que avise de un drift REAL,
ya no se le cree.

## Dirección del fix `[INFER]` — no abrí el hook

Dos huecos distintos, y conviene separarlos:

1. **Contra QUÉ compara.** `~/.cortex` es un *checkout desplegado* que puede quedar atrás de `origin`.
   Si es la fuente declarada, el drift-check debería **primero comprobar que el espejo esté al día**
   (`git -C ~/.cortex fetch` + comparar con `origin/<su rama>`) y, si no lo está, decir *"tu espejo está
   rezagado N commits"* en vez de acusar al usuario de editar en vivo. Un espejo stale no puede ser el
   árbitro de qué es "más nuevo".
2. **Cómo decide la DIRECCIÓN.** Hoy parece inferirla de `mtime` (instalado 24-sep > fuente 18-sep ⇒
   "editado en vivo"). El `mtime` de un archivo *instalado* lo pone el instalador, no una edición — así
   que no distingue "el usuario lo tocó" de "se instaló desde otro origen más nuevo". Un hash del
   contenido contra **el commit del que se instaló** (un sello tipo `.brain-version`, que ya existe para
   el sync por-repo) distingue las dos cosas; el `mtime` no.

Es el mismo defecto de clase que ya está en el corpus para otros guards: **razonar sobre el AMBIENTE
(qué archivo es más reciente en disco) en vez del SCOPE AUTORITATIVO (de qué commit salió esto).**

## Registrado en el corpus

La ocurrencia con su frase citada está en
**`/Users/unjordi/code/cortex/docs/guards-falsos-positivos.md`** (busca `aviso-drift-cerebro`).
