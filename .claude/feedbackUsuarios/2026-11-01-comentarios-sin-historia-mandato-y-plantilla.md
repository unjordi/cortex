# Comentarios sin historia: refinar el mandato del lote y la plantilla mandato-loop

De: claudio-master, pedido de unjordi (2026-11-01). Aplica a `docs/loop-lote-integracion.md` y a `brain/skills/mandato-loop/SKILL.md` (los dos en fix/retiro-cerebro-por-repo).

Por qué: la regla ya estaba («Código, comentarios y commits utilitarios», «§4 Comentarios utilitarios, sin historia ni trazabilidad») y aun así las filas entregaron comentarios con citas de unjordi, «[user fecha]», «hallazgo 4», «corrección de unjordi al hallazgo 1 de claudio» y párrafos que narran el incidente (AppDelegate.swift, aviso-contexto.sh, main.qml, Program.cs, install-brain.sh, merge-develop-guard.sh). Una regla de una línea no basta: le falta decir qué SÍ va, qué NO va, dónde va lo demás, y un paso que la haga cumplir.

## Cambios (texto exacto; en los dos archivos, adaptando solo los `<…>` de la plantilla)

1. En PRUEBAS, reemplazar la línea de §4 por:
   - §4 Comentarios en el código: dicen qué hace el código, su contrato (entradas, salida, qué pasa al fallar) y, solo si no es obvio, el porqué en una o dos líneas justo donde se mete la pata, apuntando al test o guard que lo frena. No llevan citas ni nombres de personas, fechas, números de fila, hallazgo, nota, PR o commit, «antes…/ahora…», «corrección de…», ni la historia del incidente. Eso va en el mensaje del commit y en la memoria. Un comentario de más de tres líneas se parte o se va al doc.

2. En CADA RONDA, paso 1 (lo que terminó: revísalo TÚ), agregar al final:
   Antes de commitear, lee una por una las líneas de comentario que agrega el diff (`git diff --cached -U0`) y deja solo lo que cumple §4; la historia que encuentres la mueves al mensaje del commit.

3. En la definición de fila ✅ (párrafo LA ÉPICA ESTÁ TERMINADA, «Cada fila está ✅ cuando…»), agregar: «y su diff no agrega comentarios fuera de §4».

4. En REGLAS, cambiar «Código, comentarios y commits utilitarios.» por:
   «Código y commits utilitarios; los comentarios, según PRUEBAS §4 (la historia va al commit, nunca al código).»

5. Esta fila ya cuenta para lo entregado: al cerrar las filas que faltan, limpia también los comentarios con historia que dejaron las ya hechas (los de fila 15 y los de install-brain.sh/merge-develop-guard.sh de los hallazgos 1, 4 y 5). Su CIERRA CUANDO: releer las líneas de comentario agregadas por el lote completo (`git diff develop...<rama> -U0`, por rama) y que ninguna lleve cita, fecha, ID de fila/hallazgo/nota o narración.

Nota para la plantilla: en «Cómo se redacta» ya está «Sin trazabilidad» para el MANDATO; agregar debajo una línea gemela para el CÓDIGO que produce el loop: «Lo mismo vale para los comentarios del código que entregue el loop: la plantilla los acota en PRUEBAS §4».
