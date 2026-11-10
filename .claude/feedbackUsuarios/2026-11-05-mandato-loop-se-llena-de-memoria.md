# mandato-loop: el mandato se redacta de memoria y pierde secciones

Reporta: games-master (Mac), 2026-11-05.

## Qué pasó
El mandato del loop de Ikaruga (`~/juegos/.claude/projects/ikaruga-psp/LOOP-ikaruga-psp.md`) se escribió sin partir del bloque `text` de la plantilla. Quedaron fuera, sin que nadie lo decidiera:
- PRUEBAS §1-§2 (la prueba de una prueba, las siete firmas de rechazo);
- PRUEBAS §7 (revisión semántica), que es lo que cierra una fila;
- en el cierre de la épica, la revisión semántica del conjunto y su línea en el reporte por fila.

El loop corrió dos rondas así. Lo detectó Jordi preguntando si se estaban haciendo las revisiones semánticas.

## Por qué el skill no lo frenó
El SKILL.md dice qué secciones lleva y en qué orden, pero no obliga a partir de la copia literal del bloque ni revisa el resultado. Un master con prisa (o con la plantilla "ya sabida") la reconstruye de memoria y se queda con lo que recuerda.

## Propuesta (mecanismo, no recordatorio)
1. Paso 1 explícito del skill: copiar el bloque `text` íntegro al archivo del mandato y reemplazar los `<…>`; quitar una sección solo con una línea "N/A: <por qué>" en su lugar.
2. Un verificador (`verificar-mandato.sh <archivo>`) que compare los encabezados del mandato contra los de la plantilla (FILAS, LA ÉPICA ESTÁ TERMINADA, CADA RONDA, DELEGACIÓN, PRUEBAS §1-§7, HIGIENE MENTAL, REGLAS) y falle si falta alguno sin su N/A. Que el skill lo corra antes de lanzar `/loop`.
3. Prueba del verificador: falla con un mandato al que se le quitan PRUEBAS §1-§2 y §7 (como quedó el de Ikaruga; no se guardó copia de esa versión) y pasa con el corregido.
