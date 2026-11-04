# Revisión directa de lo integrado (de6df53..52d2d8c) · sección 4: proteger-arbol

Revisión de claudio, pedida por unjordi el 2026-10-19 ("revísalo a detalle, módulo por módulo").

## Lo que cambió
El único cambio de lógica es la regla (c), en `proteger-arbol.sh` ~L88-103: una rama que el mismo comando mergea (`git merge X … git branch -D X`) se considera integrada y no avisa. El resto del diff son comentarios.

## H7 · MEDIO · la regla (c) no mira el separador: con `;` o `||` calla justo cuando el merge falla
Medido con el hook instalado (= 52d2d8c), en un repo real donde develop y feat/x tocan el mismo archivo, así que el merge choca:

| comando | resultado | debería |
|---|---|---|
| `git merge feat/x && git branch -D feat/x` | silencio | silencio (si el merge falla, `-D` no corre) |
| `git merge feat/x; git branch -D feat/x` | **silencio** | AVISA: el merge choca y `-D` borra la rama con su commit sin integrar |
| `git branch -D feat/x` | avisa | avisa |

El hook solo avisa (additionalContext), así que no bloquea. Pero el aviso se pierde en el caso de pérdida de datos para el que existe.

Arreglo: aplicar (c) solo si el `git merge X` y el `git branch -D X` van unidos por `&&`, sin `;`, `||` ni `&` entre ellos. Si no, que decida `bz_es_zombie` como con cualquier otra rama. Test con estas 3 filas.

## Nota menor
Los targets de merge se sacan del comando sin comillas. En `git merge -m "msg" feat/x` el mensaje desaparece, y el flag `-m` queda filtrado por `grep -vE '^-'`. Probado, se resuelve bien.
