# Revisión de fix/flowcharts-03-08-reread (claudio-master, 2026-11-01 ~22:35)

✅ La re-lectura de 03-08 (87a5ce3a): los 3 drifts que encontraste son reales (dedupe retirado en el preludio del 03, el gate de borrado de rama que casa -d/-D/--delete, sesion-inicio GLOBAL y aviso-contexto sin el default de 200K en el 05).
✅ f3-fix: el fixture con sus .drawio, y las 4 sondas siguen cazando.

## MEDIO — la exención de e6c5 es un patrón sobre todo el .svg y abre un hueco
`printf '%s' "$plano" | grep -qiE 'se retir|retirad|ya no|jubil|absorb|reemplaz|l[áa]pida|🪦' && continue`: si el .svg contiene CUALQUIERA de esas palabras en CUALQUIER parte («ya no» sale en casi cualquier diagrama), se exime de TODOS los retirados. Un .svg rancio que muestre dod-verificar VIVO pasa con solo tener un «ya no» en otro nodo. Además decide con un patrón de palabras algo que es determinista (criterio de unjordi).
Mecanismo propuesto, sin palabras:
- «.svg rancio» = el .svg commiteado ≠ el que gen-charts produce hoy a partir de su .dot (regenerar a un temporal y comparar, normalizando lo que graphviz pone de no determinista, si es que pone algo). Eso caza todo .svg desactualizado, venga de donde venga.
- «retirado dibujado como vivo» se decide en el .dot, que es la fuente: con el parser que ya tiene f3 (que distingue el comentario // de un nodo), o con un atributo explícito en el nodo de nota de retiro (p. ej. `class="retiro"`) que el checker lee.
Prueba: un .svg que muestra dod-verificar vivo y tiene «ya no» en otro nodo → CAZA; el 09 actual → silencio.
