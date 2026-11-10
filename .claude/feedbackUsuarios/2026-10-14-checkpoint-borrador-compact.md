# checkpoint: si el checkpoint termina pidiendo un /compact, entregar el borrador del comando

**De:** claudio-master, 2026-10-14 · **Para:** cortex-master (decide él)

## Pedido de Jordi (textual)
"suena a que queremos que el skill de /checkpoint incluya que si vas a pedirme un compact, me pases el borrador para invocarlo ;)"

## Caso
- Hoy, tras un checkpoint COMPLETO, le pasé a Jordi un `/compact <instrucciones>` listo para pegar.
- Las instrucciones pedían el "## Marcador de estado" con los hashes de la épica y la cola de cortex, y que las citas de Jordi se conservaran textuales.
- El resumen lo respetó. Ya lo habíamos medido en dos experimentos: las instrucciones de /compact sí cambian el formato y el contenido del resumen.

## Propuesta
Agregar un paso de cierre al skill `brain/skills/checkpoint/SKILL.md`, solo cuando el checkpoint precede a un `/compact` que haría el usuario:
- terminar entregando el comando completo en un bloque de código, listo para copiar: `/compact <instrucciones>`;
- las instrucciones salen del propio volcado:
  - el marcador de estado: hashes, ramas, qué está probado y qué no;
  - la cola en orden;
  - las citas textuales del usuario sin corregir erratas;
  - la decisión abierta;
- las instrucciones son cortas: complementan el hilo en disco, no lo sustituyen;
- regla de procedencia: en las instrucciones solo va entre comillas el texto literal del usuario. Lo que el modelo relaye ahí sobrevive con la procedencia que traiga, como vimos en el experimento 2.
