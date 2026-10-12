# Feedback: a la skill `checkpoint` le falta el PISO entre checkpoints (y una edición se perdió)

**Fecha:** 2026-09-24 · **De dónde salió:** sesión `db-master` (potenciaDatabases), a raíz de una sesión
que perdió el flow con unjordi.
**A quién le toca:** cortex-master (skill `checkpoint`, fuente `brain/skills/checkpoint/SKILL.md`).

## Qué pasó
unjordi (2026-09-24): *"estuve trabajando con una sesión tuya que avanzó mucho en lo técnico, pero hizo mal
muchos checkpoints seguidos y perdió por completo el flow que tenemos... por eso regresé a despertarte en tu
versión de hace una semana :/ PLZ no deje que vuelva a pasar!! haz BIEN tus checkpoints!!"*

**Un ejemplo medido del patrón** (no necesariamente la sesión de la que habla unjordi — no sé cuál fue): en
el `git log` de `potenciaDatabases`, el 2026-09-20 tiene **9 commits de checkpoint en 5h42m**, con
intervalos de 43 · 91 · **4** · 120 · 44 · 28 · **6** · **6** min — contra el "~2h" que la propia skill
pide.

## El hueco en la skill
La skill dice **cuándo** correr un checkpoint pero **no tiene límite superior**: nada frena encadenarlos.
Y el costo de uno de más no es cero — `hilo-mental-actual.md` se **reescribe** en cada checkpoint, así que
N checkpoints seguidos son N re-compresiones sucesivas (fotocopia de fotocopia).

## Por qué la edición anterior se perdió
El mismo día agregué la sección de abajo **directo en la copia instalada** (`~/.claude/skills/checkpoint/`),
no en la fuente. La siguiente sincronización del brain la pisó: hoy no está en ninguna de las tres copias
(`grep -c "PISO entre checkpoints"` → 0 en `~/.claude/skills/`, `~/.cortex/brain/skills/` y
`~/code/cortex/brain/skills/`). Lo que sí sobrevivió es una línea en `como-trabajar-con-unjordi.md`
(memoria global, fuera del brain). **Por eso llega aquí, por el buzón.**

## El texto propuesto (va antes de `## Qué hace (el volcado)`)

```markdown
## ⚠️ El PISO entre checkpoints: ~2h. Uno de más DEGRADA lo que venía a proteger

**El disparador correcto es un EVENTO, no un hito de trabajo:** viene un compact (manual o
anunciado), llevas ~2h de corrida, o cambias de tema. Terminar un sub-paso NO es disparador —
para eso está la bitácora (`>>`, append, no reescribe nada).

**Regla dura: si el checkpoint anterior fue hace menos de ~30 min, NO hagas otro.** Si hay algo
que asentar, appendéalo a `bitacora.md`. Volver a volcar el hilo tan seguido no lo protege: lo
comprime otra vez.

**Por qué (el mecanismo, no la etiqueta):** `hilo-mental-actual.md` se REESCRIBE en cada
checkpoint. Nueve checkpoints son nueve re-compresiones sucesivas del mismo texto — la fotocopia
de la fotocopia. Cada pasada conserva lo que la plantilla nombra (plan, resuelto, tooling) y
adelgaza lo que no tiene casilla propia.

**Y lo primero que se cae NO es lo técnico — es el FLOW.** Lo técnico se re-mide barato (está en
los commits, en el código, en la BD). El modo de trabajar —el tono, la agency acordada, qué
decide quién, la procedencia de cada idea— no se re-mide de ningún lado: si se comprime, se
pierde. **Antídoto: el flow no vive en el hilo.** Vive en `~/.claude/CLAUDE.md`, en
`como-trabajar-con-<user>.md` y en el `CLAUDE.md` del repo. El hilo los REFERENCIA; jamás los
re-resume, porque re-resumir es justamente lo que los desgasta.

**Un caso medido:** 9 checkpoints en 5h42m en un mismo día, tres separados por 4 y 6 minutos.
```

## Sugerencia de mecanismo [INFER-mío]
La regla sin mecanismo es solo un deseo (norma "toda norma nace con su mecanismo"). El piso es
**medible**: el mtime del hilo, o el último commit que lo tocó. Un chequeo al invocar la skill —"el hilo se
volcó hace N min; si N < 30, appendea a la bitácora en vez de reescribirlo"— lo haría cumplir solo.

## De paso: otra skill con drift
El aviso de drift del SessionStart (2026-09-24) marca **`reubicar-master/SKILL.md` editada en vivo**
(la instalada es más nueva que la fuente). **No la toqué yo** — si esa edición es de alguien, se va a perder
igual en la próxima sincronización.
