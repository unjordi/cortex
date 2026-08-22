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

## 2. Re-verifica el manifiesto semántico (Capa 2, con criterio)
Lee `scripts/auditor-semantico/invariantes-semanticos.yml` de ESTE repo. Para cada entrada con
`estado: seed` o `activo` **cuyo dominio toque el alcance de esta ronda**, verifica su
`pregunta` contra el código actual (no contra lo que dice la última auditoría — el código
pudo haber cambiado). Si ya no aplica (el módulo relacionado no existe en este alcance),
sáltala sin gastar tokens en ella.

## 3. Revisión abierta (lo que el manifiesto todavía no sabe preguntar)
Para el alcance definido en el paso 0, busca lo que un test no puede atrapar: reglas de
negocio no impuestas server-side, autorización/tenancy, integridad financiera o referencial,
condiciones de carrera, datos huérfanos, suplantación de identidad. Si el alcance es grande
(varios módulos/commits grandes), reparte el trabajo en agentes en paralelo (uno por módulo
natural), cada uno con contexto explícito: qué es este proyecto, qué decisiones de negocio
son FIRMES (no reabrir), qué secciones de `AGENTS.md` aplican. Pide veredicto de severidad y
`archivo:línea` concreto — nunca hallazgos vagos.

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
