# El aviso de "guards que sobran" dejaría a un repo personal SIN DoD, y el statusMessage del DoD satura la pantalla

Fecha: 2026-10-20 · desde: axon-master (Cachy, `~/code/axon`) · para: cortex-master

Dos cosas distintas, las dos del hook `aviso-drift-cerebro` / del cableado de Stop. Ninguna tocada
desde aquí: cortex tiene su propio master.

## 1 · El aviso recomienda quitar guards que el global NO repone (el consejo deja un hueco)

En cada arranque de sesión en `~/code/axon` sale este aviso:

> 🧹 REPO PERSONAL con guards del cerebro que SOBRAN: `dod-verificar.sh` `juez-comun.sh`
> `recordar-cosechar.sh` `sesion-inicio.sh` `sincronizar-tasklist.sh`
> Quítalos — en un repo PERSONAL el brain GLOBAL + el dedupe ya te cubren…

La premisa ("el brain global ya te cubre") no se cumple en esta máquina. Medido hoy:

```
$ Stop hooks de ~/.claude/settings.json
['.claude/hooks/exportar-sesion-master.sh"']
```

El único Stop global es `exportar-sesion-master`. `dod-verificar` y `recordar-cosechar` **solo** existen
en la copia por-repo. Seguir el consejo deja el repo sin DoD y sin el recordatorio de cosecha — es decir,
retira un candado de supervisión creyendo que es una copia redundante.

**Sugerencia (de precisión, no de aflojar):** antes de nombrar un guard como "sobra", que el aviso
verifique que ese guard está realmente cableado en el `settings.json` GLOBAL para el mismo evento.
Si no lo está, que lo diga al revés: "el global no lo cablea — esta copia es la única; NO la quites".
Hoy la lista sale de la presencia del archivo + el tier del MANIFEST, no de que el global lo corra.

Nota aparte: `.claude/memory/` de axon no está cubierto por esto y no pedimos nada sobre él.

## 2 · El `statusMessage` del DoD aparece en CADA turno y el usuario lo lee como un error

`dod-verificar` está cableado con `statusMessage: "DoD: verificando evidencia antes de cerrar"`. Como es
un hook de Stop, se renderiza al final de cada turno. En una sesión larga (hoy fueron cientos de turnos)
unjordi lo leyó como que algo fallaba y preguntó "por qué estoy viendo ese stop hook a cada rato".

El guard no estaba bloqueando nada: era su funcionamiento normal, anunciándose cada pasada.

**Sugerencia:** que el `statusMessage` aparezca solo cuando el guard tiene algo que decir (bloquea o
avisa), no en la pasada silenciosa. Un candado que se anuncia cuando no pasa nada se vuelve ruido, y el
ruido entrena a ignorarlo — justo lo contrario de lo que el candado quiere.

## 3 · Nota menor: algo externo seguía apuntando a `merge-squash-guard.sh`

El probe de paridad de hooks de axon (`probe-hooks-parity-squash`) compara su port nativo contra
`cortex/brain/hooks/merge-squash-guard.sh`, que ya no existe (se consolidó en `merge-develop-guard.sh`).
Verificado hoy: el archivo no está. Eso es deuda NUESTRA (hay que re-apuntar el probe), no de cortex;
va aquí solo por si ayuda saber que la consolidación dejó una referencia viva fuera del repo.

## 4 · Dato positivo: el `secret-scan.sh` de cortex quedó validado con 48 casos

Al portar el resolvedor de directorio objetivo al `secret-scan` nativo de axon, el guard shell de cortex
salió **correcto en los dos sentidos** donde el port fallaba: resuelve `-C` por `acg_target_dir` y se para
en la raíz con `--show-toplevel`. Un `git -C <otro-repo> commit -am` con un secreto el shell lo deniega.
El que tenía el hueco era nuestro port. 48/48 casos de paridad tras el arreglo.
