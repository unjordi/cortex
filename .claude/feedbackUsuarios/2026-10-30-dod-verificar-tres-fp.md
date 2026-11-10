# dod-verificar — tres falsos positivos medidos (2026-10-30)

De: axon-master (cachy). Hook en `origin/develop` (md5 `95a9573c744910f0ed4c7b75a5c734b8`), idéntico al
instalado; no es desfase de versión. Disparó al cerrar la épica A+B de axon.

## 1. B4 «OJO MIGRACIÓN»: el patrón `legad` muerde «desplegada»

`grep -iE 'migrac|migrad|paridad|legad'` sobre `$last`. En el mensaje que disparó, la única coincidencia
fue **desp-LEGAD-a**, dos veces; no había migración en el turno. Todo cierre de un despliegue arrastra el
recordatorio de auditoría de paridad.

Precisión: `legado|legacy` con frontera de palabra (`\blegad[oa]s?\b|\blegacy\b`).
Prueba: un turno que dice «desplegada» y no habla de migración NO imprime la línea B4; uno que dice
«migramos el módulo legado» sí. Falla contra el código viejo en el primer caso.

## 2. El detector de memoria solo ve Write/Edit — y la norma exige `>>`

`printf '%s' "$turn" | grep -qE '"file_path":"[^"]*\.claude/memory/'` (línea ~334). La memoria escrita
por Bash (`>>`) o por un heredoc de python3 nunca cuenta. En el turno reportado se appendearon
`bitacora.md`, `estado-proyecto.md`, `hilo-mental-actual.md` y `ritmo-cuota-epica-ab.md`, y el hook
reportó `memoria actualizada: no`.

El append-only con `>>` es justamente lo que la norma de bitácora EXIGE («nunca un Edit»), así que
obedecerla garantiza el falso negativo del indicador que la vigila. Es el más grave de los tres: no es
ruido, es un indicador que miente.

Precisión: contar también el comando de los `Bash` del turno cuando escribe en `.claude/memory/`
(`>>` o `>` a una ruta de memoria, o un `open(...,"w"/"a")` sobre esa ruta).
Prueba: un turno cuya única escritura de memoria es `printf ... >> .claude/memory/bitacora.md` marca
`mem=si`; uno que no toca memoria sigue en `no`.

## 3. El eje MARCA no reconoce el mandato de un `/loop` como autorización

El turno juzgado SÍ incluía la autorización del usuario: el mensaje `/loop` (línea 105809 del transcript)
decía «integra epic/cierre-ab→develop (squash, CI verde, Rama:/PR:) y haz el despliegue único **sin pedir
OK**, como define el plan; verifícalo en vivo». Verificado que caía dentro de la ventana de 1500 líneas y
dentro del recorte del turno (el awk cortó justo en esa línea, 105809..106558). El juez devolvió
`MARCA=no`.

Matiz honesto, por si pesa en el diseño: el bloqueo no era del todo espurio. El mandato autorizaba
integrar y desplegar, y eso sí lo cubría; el mensaje del asistente estiró esa autorización acotada a
«la épica quedó cerrada» cuando el QA del usuario seguía pendiente. O sea el juez acertó en el fondo por
la razón equivocada. Lo que sí es FP es que un mandato explícito de `/loop` no cuente como autorización
de NADA de lo que nombra.

Sugerencia (no la toqué: aflojar el eje MARCA es decisión de quien lo mantiene): que el juez reconozca
una autorización ACOTADA en el mensaje del usuario del turno y la aplique SOLO a lo que nombra, en vez
de ignorarla por completo.

## Estado

Nada tocado del hook. Los tres quedaron registrados en `docs/guards-falsos-positivos.md` de cortex
(append), pendientes de commit en el clon de la cachy — ver nota abajo.

## Nota aparte: el clon `~/code/cortex` de la cachy

Quedó 15 commits atrás de `origin/develop` y el `pull --ff-only` aborta por trabajo sin commitear que no
es mío: `.claude/memory/bitacora.md` (nota de un worktree `espejo-silencioso` pendiente) y
`docs/guards-falsos-positivos.md` (entradas del 22 al 27 de octubre, más las tres mías de hoy), más tres
`.claude/feedbackUsuarios/*.md` sin trackear. No lo commiteé por ser repo con master propio.
`~/.cortex` (la fuente del install) sí quedó al día en `9a231e8` y el cerebro global reinstalado en
v0.2.441.
