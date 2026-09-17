---
name: auditor-semantico
description: Auditoría semántica de un módulo/diff/merge — verifica que el código HAGA LO QUE QUEREMOS QUE HAGA (intención de negocio), no solo que compile y pase tests. Corre primero la Capa 1 determinista (scripts/auditor-semantico/checks/) y luego re-verifica con criterio cada invariante de scripts/auditor-semantico/invariantes-semanticos.yml contra el alcance dado, más una revisión abierta de bugs nuevos. Al final, cosecha lo que encuentre: promueve lo mecánico a un check nuevo, lo no-determinista al manifiesto. Úsala al cerrar un slice grande, tras aplicar la plantilla a un proyecto, o cuando quieras una segunda opinión independiente sobre código propio o de otra IA/dev.
---

# Auditor Semántico

Ver `scripts/auditor-semantico/README.md` para el modelo completo (dos capas: determinista vs
semántica) antes de correr esta skill por primera vez en un repo. Resumen: un test unitario
verifica sintaxis/integración; esta skill verifica **intención de negocio** — lo que ningún
test automatizado puede juzgar por sí solo, por eso necesita un LLM con criterio.

> **Motor genérico + catálogo por-repo.** El motor (`ejecutar.sh`, `lib-formato.sh`) y el
> esqueleto (`invariantes-semanticos.yml` con solo invariantes `general`) viajan desde el
> template (`cortex`). Los `checks/*.sh` de fábrica son EJEMPLOS de la plantilla .NET —
> cada repo afina su propio catálogo a su stack/dominio. Si en ESTE repo el `.yml` ya creció con
> entradas `proyecto-especifico`, úsalo tal cual (trae tanto los `general` heredados como el
> dominio acumulado aquí).

## 0. Define el alcance
Antes de arrancar, deja claro (con el usuario si hace falta) QUÉ se audita: un commit/rango de
commits, una rama antes de abrir MR, o el repo completo. Auditar "todo" en un repo grande no
es gratis — prioriza lo reciente/riesgoso (dinero, auth, tenancy, borrados) sobre CRUD trivial
ya revisado antes.

## 1. Corre la Capa 1 (gratis, primero)
```bash
./scripts/auditor-semantico/ejecutar.sh
```
Cada candidato que reporte trae su propio "revisar semántica de negocio con Capa 2" pegado en
la línea — eso ES este paso 2/3, no lo trates como un hallazgo aparte. No lo re-descubras a
mano con un agente: tómalo como punto de partida y ve derecho a re-verificarlo con criterio. Si
resulta un falso positivo genuino, documenta la excepción en el código
(`// auditor-semantico: intencional — <por qué>`) en vez de ignorarlo — y verifícalo de verdad
(lee la implementación, no solo el docstring) antes de escribir esa excepción: un auditor que
mienta ("esto está bien" sin haberlo comprobado) es peor que uno que no exista.

**Cuidado con el invariante que un grep textual verifica.** Si la regla se satisface editando
un MENSAJE en vez de arreglando el código, no es un invariante: es un acuerdo de caballeros con
el linter. Caso medido: una regla del proyecto ("ningún mutador fuera del punto único") se
verificaba con un grep de texto; alguien degradó un mensaje real de error para que el grep
pasara, y el check siguió en verde. Al escribir o revisar un check mecánico, pregúntate si lo
que mide es COMPORTAMIENTO o STRING — y si es lo segundo, busca una señal que no se pueda
apagar con un find-and-replace.

## 2. Re-verifica el manifiesto semántico (Capa 2, con criterio)
Lee `scripts/auditor-semantico/invariantes-semanticos.yml` de ESTE repo. Para cada entrada con
`estado: seed` o `activo` **cuyo dominio toque el alcance de esta ronda**, verifica su
`pregunta` contra el código actual (no contra lo que dice la última auditoría — el código
pudo haber cambiado). Si ya no aplica (el módulo relacionado no existe en este alcance),
sáltala sin gastar tokens en ella.

**Lee cada afirmación de la doc/comentario contra el código que tiene AL LADO, no solo contra
el módulo en general.** La contradicción más cara suele estar a tres líneas, no en otro
archivo. Casos medidos: un comentario decía *"el ensayo no ejecuta nada, solo LEE el
archivo"* tres líneas arriba del código que lo ESCRIBÍA; una especificación seguía afirmando
que el modo de ensayo "coloca el archivo" y llamaba a gatearlo "mejora opcional, no
bloqueante" — justo lo que la propia auditoría clasificó después como crítico.

**Un contrato escrito en una cabecera se verifica contra TODOS sus consumidores, no contra el
primero que revises.** Caso medido: la cabecera de una librería documentaba el comportamiento
ante fallo de sus dos consumidores, y uno de ellos ya no lo cumplía porque un cambio anterior
le había retirado esa ruta de salida — la doc conservaba lo que el código ya había
abandonado. Si el invariante habla de "todo consumidor de X", localiza a TODOS antes de
marcarlo `resuelto`.

## 3. Revisión abierta (lo que el manifiesto todavía no sabe preguntar)
Para el alcance definido en el paso 0, busca lo que un test no puede atrapar: reglas de
negocio no impuestas server-side, autorización/tenancy, integridad financiera o referencial,
condiciones de carrera, datos huérfanos, suplantación de identidad. Si el alcance es grande
(varios módulos/commits grandes), reparte el trabajo en agentes en paralelo (uno por módulo
natural), cada uno con contexto explícito: qué es este proyecto, qué decisiones de negocio
son FIRMES (no reabrir), qué secciones de `AGENTS.md` aplican. Pide veredicto de severidad y
`archivo:línea` concreto — nunca hallazgos vagos. **Pídele explícitamente al auditor que TE
corrija a ti**: "si algo de lo que te dije resulta falso al medirlo, corrígeme con la
evidencia en vez de acomodarlo" — en una tanda medida, esa corrección mejoró el resultado
media docena de veces.

**Pasada barata y sistemática: definido ≠ invocado.** Es el hallazgo semántico más rentable
medido hasta ahora. Por cada función de verificación/validación que el código o la doc
DECLARE, cuenta sus invocaciones reales con un `grep` desde el camino de ejecución — no
asumas que "existe" significa "corre". Caso medido: un producto declaraba verificar su
instalación con once predicados; seis existían y NUNCA se llamaban (una sola aparición: su
propia definición) — y eran justo los que medían el EFECTO real (el archivo quedó colocado,
sobrevive al reinicio, el nombre resuelve, el servicio subió), mientras los cinco que sí
corrían solo medían el registro del planificador. El reporte declaraba `LISTO` habiendo
comprobado que la maquinaria se instaló, no que hiciera su trabajo. Una función con una sola
aparición (su propia definición) es código muerto que la doc presenta como garantía.

**Y cuando SÍ se invocan, verifica que no den falsos negativos (o positivos) sistemáticos.**
Un verificador que siempre falla miente igual que uno que siempre pasa. Caso medido: los tres
predicados vivos de ese mismo producto fallaban siempre — uno buscaba una unidad de systemd
sin su sufijo `.service` (así crea el symlink el propio systemd), otro exigía un campo vacío
por diseño en los timers monotónicos que el producto instala, el tercero rechazaba el estado
`not running`, que es el estado NORMAL de un daemon ocioso. Medido contra daemons vivos: marcó
falla en uno que había escrito su log 47 segundos antes. Corre el predicado contra un caso que
SABES que debe pasar, no solo contra el que debe fallar.

**De qué fuente se fía cada decisión, y si esa fuente puede ser falsificada, estar vacía o
venir del exterior.** Patrón transversal medido en tres arreglos distintos del mismo sistema,
los tres etiquetados como "mejora de precisión" y los tres abriendo un agujero: uno leía el
JSON crudo del payload (un campo de DESCRIPCIÓN entraba al detector y bloqueaba comandos
legítimos), otro se apoyaba en la palabra del propio LLM sin re-verificarla de forma
determinista, y otro consumía un archivo de `/tmp` sin validar dueño ni antigüedad. Pregunta
siempre: ¿quién escribió este dato, puede mentir, y qué pasa si llega vacío o manipulado?

## 4. Cosecha (el paso que hace crecer el sistema)
Por cada hallazgo nuevo confirmado, decide dónde vive:
- **Mecánicamente detectable** (un patrón de texto reconocible sin entender intención de
  negocio) → escribe un check nuevo en `scripts/auditor-semantico/checks/`, numerado
  consecutivo. **No lo des por bueno sin probarlo en las dos direcciones**: un caso sintético
  que SÍ viola la regla (debe fallar) y correrlo contra el propio repo (debe salir limpio, o
  documentar la excepción). Usa `source ".../lib-formato.sh"` + `reportar_candidatos "$n"` +
  el sufijo `$SUFIJO_REVISAR_CAPA2` en cada línea de hallazgo (igual que los checks
  existentes) — es lo que mantiene el formato de salida honesto y consistente sin duplicar
  texto en cada script.
- **Requiere criterio/intención de negocio** → agrégalo a `invariantes-semanticos.yml`:
  - `alcance: general` si aplica a cualquier proyecto derivado de la plantilla → cosecha la
    entrada de vuelta al TEMPLATE (`cortex`), para que viaje a futuros clones.
  - `alcance: proyecto-especifico` si es una regla de negocio de ESTE repo concreto → va solo
    en la copia de ESTE proyecto, no en el template.
- Actualiza `estado` de las entradas re-verificadas (`resuelto` si ya se arregló y se
  confirmó; deja `activo` si sigue pendiente).

## 5. Reporta
Ordena hallazgos por severidad, con veredicto claro por bloque auditado y uno general al
final. Sigue la **definición de LISTO** del repo: esto es una auditoría, no una autorización
de cierre — no declares nada "arreglado" sin que el fix se haya hecho y verificado.

## Al aplicar la plantilla a un proyecto nuevo
La primera vez que un repo corre esta skill, su `invariantes-semanticos.yml` es el esqueleto del
template (solo invariantes `general`). A partir de ahí crece con el contexto de SU dominio —
cada ronda de auditoría en ese proyecto puede sumar entradas `proyecto-especifico` que nunca
suben al template (eso ensuciaría el manifiesto general con reglas de negocio ajenas). Solo los
invariantes `general` (patrones de arquitectura, no de negocio) se cosechan de vuelta al
template — mismo criterio que ya usa `cerrar-slice` §5 para decidir qué sube al cerebro global.
