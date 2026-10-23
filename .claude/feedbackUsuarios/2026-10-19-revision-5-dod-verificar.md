# Revisión directa de lo integrado (de6df53..52d2d8c) · sección 5: dod-verificar

Revisión de claudio, pedida por unjordi el 2026-10-19 ("revísalo a detalle, módulo por módulo").

## Lo que cambió
1. **El prompt del juez** suma el criterio "RESULTADO MEDIDO DE UNA OPERACIÓN / ARTEFACTO INTERMEDIO": reportar el desenlace de una operación no cuenta como cierre.
2. **El texto del usuario del turno** ahora incluye el OK escrito a media vuelta: el attachment `queued_command` con `origin.kind == "human"`, leído de `.attachment.prompt`.

## H8 · MEDIO · un OK a media vuelta CON IMAGEN tumba el texto de usuario de todo el turno
Cuando el mensaje trae imagen, `.attachment.prompt` es un ARRAY de bloques, no un string. Después, `select(test("<system-reminder>") | not)` aborta jq con "array … cannot be matched, as it is not a string". Como el error va a /dev/null, `usertext` queda vacío y se pierde TODO el texto de usuario del turno, no solo esa entrada. El juez no ve el OK y frena.

Lo reproduje con el filtro jq exacto de 52d2d8c:
- `prompt: "sí, ciérralo, ya lo probé"` → sale el texto.
- `prompt: [{"type":"text","text":"sí, ciérralo, ya lo probé"},{"type":"image",…}]` → `jq: error … array … cannot be matched`, y la salida queda vacía.

El mismo caso YA está arreglado en `analizar-comando-git.sh` (`acg_recent_intercalado`: si `.prompt` es array, une el texto de sus bloques `type=="text"`). Aquí no se portó. Es la regla "¿esto vive en más de un lugar?".

**Arreglo:** el mismo manejo de array que la librería. Mejor todavía: que los dos lean el texto del usuario con UNA sola función compartida. Test con un attachment con imagen que falle contra 52d2d8c.

## H9 · BAJO · el criterio nuevo del prompt no cubre el estatus de una etapa de trabajo que no es código
FP de hoy, ya en el corpus: "Ronda 4 terminada: cerré la sección 4, proteger-arbol". Era el estatus de una sección de una revisión de código ajeno, sin código entregado (en ese turno solo se escribieron notas al buzón). El criterio nuevo habla de "operación" y "artefacto intermedio", y el juez no lo aplicó a "terminé esta etapa de una revisión".

**Arreglo:** que el criterio incluya cerrar una etapa o sección de un trabajo en curso (revisión, auditoría, ronda de un loop) cuando no se declara listo un entregable. Fixture con esa frase.
