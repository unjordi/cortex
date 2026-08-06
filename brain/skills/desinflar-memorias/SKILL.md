---
name: desinflar-memorias
description: Desinflar un árbol de memorias que se llenó de narrativa, tutoriales y conocimiento ya desmentido — SIN perder ninguna lección. Cada tirada de historia se colapsa a su lección en 1-2 líneas EN SU LUGAR, y los mitos descartados se comprimen a una línea y se mudan a una sección ⚰️ Lápidas AL FINAL del archivo. También poda los punteros-lápida de reubicación (líneas que solo narran que un tema se mudó a otro lado, inútiles para quien lee ESTE archivo). Úsalo cuando una memoria ya no se pueda leer de un jalón, o cuando el usuario diga "está inflada / no quiero leer 3 párrafos de cómo aprendimos X".
---

# Desinflar memorias (sin perder el valor)

Las memorias se inflan solas: cada sesión appendea contexto, cada investigación deja su diario, y lo
que se descartó sigue ahí ocupando espacio junto a lo vigente. El resultado es un archivo que **nadie
lee completo** — y una memoria que no se lee no sirve.

> **El encargo que originó este skill** (unjordi, 2026-07-30, sobre un árbol de 2,759 líneas):
> *"¿puedes revisar que las memorias no estén infladas con menciones a conocimiento deprecated o que
> ya se desmintió? Sí queremos las lecciones y los gotchas en memoria, pero **no a medio tutorial**,
> ni queremos leer **3 párrafos de la historia de cómo aprendimos** que sí o sí van juntos los vdf con
> su archivo hermano…"* + *"y las lápidas van AL FINAL"*.
> Resultado de esa pasada: **−21% de líneas, −26% de palabras, 0 lecciones perdidas.**

## Las DOS reglas que hacen todo el trabajo

### 1. Toda tirada de narrativa se colapsa a su LECCIÓN, en 1-2 líneas, EN SU LUGAR
No se borra: se destila. El diario de la investigación se va; lo que aprendimos se queda donde estaba,
para que quien lea ese punto del archivo reciba el conocimiento sin el relato.

> **Ejemplo real.** 24 líneas de hipótesis sobre por qué una consola no entraba en suspensión →
> *"Armada usa un «fake-suspend» (comentario literal `fake-suspend owns wake`)… **NO hay binding que
> lo arregle; es el techo del SoC/Armada hoy → no perseguir deep-sleep real.**"*

Si al colapsar no puedes escribir la lección, **es señal de que ahí no había lección** — o de que no
la entendiste todavía. En el segundo caso, déjalo y repórtalo; no lo cortes a ciegas.

### 2. Los mitos descartados NO se borran: se comprimen a UNA línea y van al FINAL
Si borras "el mito X está descartado", **el siguiente agente lo re-descubre y pierde horas**. Pero si
lo dejas intercalado, estorba a quien lee lo vigente. Solución: una sección al final.

```markdown
## ⚰️ Lápidas — descartado, NO re-proponer
- **Mito «Steam randomiza los appids al abrir» (#9463):** DESCARTADO 2026-07-29 — la causa real era un
  vdf truncado. El appid es determinista: `crc32(Exe+AppName)`.
- **SRM / EmuDeck como vía:** RETIRADO 2026-07-29 → hoy se usa el tooling propio.
- **Timer de respaldo en `daily`:** ⛔ no volver — saltaba siempre las consolas dormidas.
```

Cada lápida = **una línea**: qué se descartó · cuándo · con qué se reemplazó (o por qué). Nada de
párrafos. Donde el contenido de arriba necesite la advertencia para no equivocarse, deja un puntero
corto — `(ver ⚰️ Lápidas al final)` — en vez de repetir la explicación.

## Qué más se corta
- **Medio tutorial.** Explicaciones genéricas de herramientas que cualquier agente ya sabe (qué es un
  symlink, cómo funciona systemd) o que solo repiten la doc oficial. Se queda **solo lo específico de
  ESTE proyecto**: el flag raro que hizo falta, la ruta exacta, el gotcha.
- **Duplicación entre archivos.** Deja **UNA canónica** (la que tiene el flujo completo) y punteros de
  una línea en las demás. Di cuál elegiste y por qué.
- **Pasos ya ejecutados** que no volverán a correrse → "se hizo X el `<fecha>`, resultado Y".
- **Datos que ya viven en una fuente REGENERABLE** (un CSV, un script que los deriva) → puntero + el
  comando para obtenerlos. Un conteo a mano en una memoria se queda viejo; uno derivado, no.
- **Punteros-lápida de REUBICACIÓN.** Una línea cuyo único fin es avisar que un tema *se movió a otro
  lado* — «esto ahora vive en el skill/archivo X», «se sacó de aquí, ver Y» — **no sirve a quien abre
  ESTE archivo por su objetivo**: le quema tokens contándole la historia de una mudanza que no vino a
  leer. **Córtala.** El destino se descubre por el registro de skills / el índice (`MEMORY.md`), no por
  lápidas regadas en documentos ajenos. **Distínguela del puntero ÚTIL** (ese SÍ se queda): el útil
  ROUTEA al lector a MÁS de lo que vino a buscar aquí — la versión canónica del tema que este archivo
  toca, el detalle en otra memoria, el comando que regenera un dato. **Test de una línea:** *¿el puntero
  le da algo que NECESITA para lo que vino a hacer aquí?* Sí → queda; solo narra que algo se mudó → fuera.

## Qué NO se corta (esta lista es la que protege el valor)
1. **Los gotchas y las lecciones**, aunque suenen anecdóticos. Son el archivo.
2. **Las advertencias destructivas** (🛑 "esto borra datos reales", "verifica antes de escribir"): se
   conservan íntegras y, si acaso, se hacen MÁS visibles. **Duplicarlas es correcto** si quien lee un
   archivo no necesariamente abrirá el otro.
3. **Comandos, rutas, IDs y valores concretos** que funcionan: se copian tal cual, no se parafrasean.
4. **Decisiones del usuario con su porqué**, sobre todo las que traen un "NO re-proponer".
5. **Datos irrepetibles**: listas cuya fuente original ya no existe y que costaría regenerar.
6. El **frontmatter** (`name`, `description`, `metadata`). Actualiza la `description` si el archivo
   cambió tanto que quedó falsa.

## Qué NO se toca, por diseño
- **El `CLAUDE.md`** (la firma-árbol del cerebro) **salvo su sección `## Reglas duras`.** Gradiente de
  estabilidad: `CLAUDE.md`=`main` — SOLO estructura + atemporal (identidad, "dónde va cada cosa", el ÁRBOL),
  muta casi nunca por diseño. Esta pasada **no lo desinfla**: la única prosa que puede adelgazar en él es la de
  `## Reglas duras`. (El `MEMORY.md`=`develop` y las memorias=ramitas SÍ son el terreno normal del desinflado.)
- **La bitácora** (o cualquier log append-only): es narrativa fechada a propósito, y varias sesiones
  escriben en ella con `>>`. **No se edita.**
- **El hilo mental** (memoria de trabajo volátil de otra sesión).
- **El índice** (`MEMORY.md`): solo se corrige la línea de un archivo cuya descripción quedó falsa.

## Cómo correrlo
1. **Copia de trabajo.** `cp -r .claude/memory .claude/memory-WORKING` y edita ahí. Es lo que permite
   revisar el diff completo antes de integrar, y volver atrás sin drama.
2. **Lee TODO el árbol antes de cortar nada** — la duplicación entre archivos no se ve leyendo uno.
3. Corta con las reglas de arriba. **Ediciones quirúrgicas**, no reescrituras completas.
4. **Verifica antes de integrar**, y no de palabra:
   - `cmp` sobre los archivos intocables (bitácora, hilo) — deben salir idénticos.
   - que el heading de `⚰️ Lápidas` esté de verdad en el último tramo de cada archivo (⚠️ busca el
     **heading**, no la mención: los punteros "ver lápidas al final" dan falsos positivos).
   - que las advertencias destructivas sigan presentes.
   - que todo archivo siga empezando con su frontmatter.
5. **Integra y borra la copia de trabajo.**
6. Appendea a la bitácora qué se desinfló y cuánto.

## Trampa a la que se cae con esto
Al desinflar se **conserva texto viejo que era FALSO** y queda con aire de vigente. En la pasada
original sobrevivió una memoria que citaba un dato ya desmentido *como si fuera el bueno* — dentro del
archivo dedicado a no mentirse. **Mientras cortas, cualquier cifra o afirmación que reconozcas como
superada se corrige o se manda a las lápidas**; no se copia tal cual solo porque estaba ahí.

## Hermanos
- `auditar-suficiencia-operativa` — audita si la doc ALCANZA para hacer el trabajo. Este skill la
  adelgaza; ése verifica que siga sirviendo. Corre el auditor **después** de desinflar.
- `positivar-doc` — el orden "ESTO SÍ antes del ESTO NO" dentro de cada sección.
- `cosechar-sesion` — lo que agrega contenido a las memorias; este skill es su contrapeso.
