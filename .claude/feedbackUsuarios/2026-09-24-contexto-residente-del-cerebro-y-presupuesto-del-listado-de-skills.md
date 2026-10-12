# Feedback: peso del cerebro en contexto residente — 15k del bloque global + 5.9k del listado de skills

**Fecha:** 2026-09-24 · **De dónde salió:** `/doctor` en la sesión de `potenciaDatabases` (Mac de unjordi).
**A quién le toca:** cortex-master (bloque de normas de `~/.claude/CLAUDE.md`, `brain/skills/*` y su `MANIFEST`).

> ✅ Medido en disco (caracteres÷4, estimación). **No es un reporte de bug**: es un presupuesto, para que
> el cerebro se diseñe sabiendo lo que cuesta. Nada de esto está roto hoy.

## El presupuesto medido en esta máquina

```
10,535  inventario-tooling-y-re.md          ← de potenciaDatabases, @importado A PROPÓSITO (ver nota abajo)
 9,308  ~/.claude/CLAUDE.md  (bloque cortex + sección personal)   ← cerebro
 6,187  CLAUDE.md de potenciaDatabases
 5,894  listado de las 36 skills (name + description)             ← cerebro (21 de 36 son del brain)
 2,527  como-trabajar-con-unjordi.md                              ← cerebro
 2,502  .claude/memory/MEMORY.md
 1,547  MEMORY.md de auto-memoria
 1,190  entorno-maquina.md                                        ← cerebro
   254  aliases-activos.md                                        ← cerebro
──────
39,944  tokens est. residentes en CADA turno
```

**Lo que aporta el cerebro: ~19,200 tokens est.** (48% del total), repartido entre el bloque de normas,
los tres `@import` globales y el listado de skills.

Con la ventana de 1M eso es ~4% y no duele. La nota es para cuando la sesión corre en un modelo de 200k.

## El riesgo concreto: el presupuesto del listado de skills

El listado de skills (nombre + descripción de cada una, siempre residente) está presupuestado en **~1% de
la ventana**. Cuando la suma lo pasa, el CLI **trunca entradas** y el enrutado de skills se degrada —
justo el modo de falla peor, porque no avisa: simplemente dejo de ver una skill que existe.

- Ventana de 1M → presupuesto ~10k. Hoy: **5,894**. Holgado.
- Ventana de 200k → presupuesto ~2k. Hoy: **5,894**. **~3× por encima → truncamiento.**

Las descripciones más caras, todas del brain:

| skill | tok est. |
|---|---|
| `reubicar-master` | 389 |
| `checkpoint` | 266 |
| `canonizar-cerebro` | 264 |
| `ingenieria-inversa-gui-db-navegador` | 257 |
| `control-gui-remota-por-ssh` | 256 |
| `turno-nocturno` | 209 |
| `md-a-tex-pdf` | 206 |
| `investigar-dominio` | 188 |

La de `checkpoint` son 1,063 caracteres en una sola línea de `description:` — describe los dos niveles, lo
que hace cada uno y el criterio de desempate. Eso es documentación de uso, y su hogar natural es el cuerpo
del `SKILL.md` (que se carga al invocar); la `description` solo necesita lo que hace falta para **decidir
si la invoco**.

**Sugerencia, no urgencia:** poner un tope por `description` (p. ej. ~250 caracteres) como chequeo de
`test-brain.sh`, con la regla escrita al lado: *la description es para ENRUTAR, no para instruir.* Bajar
las 8 de arriba a ~250 caracteres recorta ~1,100 tokens est. y, más importante, deja de crecer sin freno
conforme el brain suma skills. Es de los chequeos que tienen que nacer con su mecanismo o no se cumplen.

## Hallazgo menor: `@aliases-activos.md` se importa dos veces

En `~/.claude/CLAUDE.md`:

- **línea 27** — dentro de la sección personal de unjordi, escrita a mano.
- **línea 236** — fuera del bloque cortex, con su marca `<!-- brain:import-aliases — VISTA per-máquina … GENERADA … -->`.

El cargador deduplica el contenido, así que el costo real es ~0 y no urge. Pero son dos declaraciones del
mismo import, una generada y otra a mano: si el brain cambia el nombre o la ruta del archivo de aliases,
la de la línea 27 se queda apuntando a lo viejo. La generada es la autoritativa; la de la línea 27 sobra.

`[INFER]` — parece residuo de antes de que `install-brain` gestionara ese import. Posible chequeo: que el
bootstrap avise si el import que él inyecta ya existe a mano en la sección personal.

## Nota sobre `inventario-tooling-y-re.md` (el renglón más grande) — NO es un pendiente

Propuse migrarlo a skill para ahorrar ~10k/sesión y **unjordi lo rechazó, con razón y a propósito**:

> "lo hice a propósito. dejarlo anclado a todos los claudes que funcionen en este repo ahorra MUCHÍSIMOS
> TOKENS de escarbado contínuo"

Queda aquí escrito para que nadie lo "descubra" otra vez y lo proponga como mejora. **El índice anclado es
la decisión**: 10k residentes compran no re-descubrir el tooling por enésima vez. Si algún día se
templatiza este patrón al brain, ese es el razonamiento que hay que portar con él.
