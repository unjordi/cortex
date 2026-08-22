# Auditor Semántico

**Motivación:** los tests unitarios verifican sintaxis, compilación e integración entre
componentes — nunca que el mecanismo HAGA LO QUE QUEREMOS QUE HAGA. Un test puede pasar en
verde con un endpoint sin permiso, un campo de catálogo editable por API, o una auditoría que
guarda `EntidadId = null`, porque ninguna de esas cosas rompe la sintaxis ni el contrato del
método — rompen la INTENCIÓN de negocio. Este auditor existe para atrapar esa clase de bug,
antes de que un humano tenga que encontrarlo a mano (como pasó con la auditoría que originó
este sistema, 2026-07-15).

## Motor genérico vs. checks de ejemplo (LÉEME primero)

Este directorio es un **MOTOR GENÉRICO** que vive en el template (`cortex/brain/scripts/`)
y viaja a cada repo:

- **Genérico (agnóstico de stack):** `ejecutar.sh` (el runner) y `lib-formato.sh` (el formato de
  salida honesto de Capa 1). No conocen ningún stack ni dominio.
- **Ejemplos de la plantilla .NET (`checks/*.sh`):** los 4 checks de fábrica son heurísticas de
  la arquitectura .NET de la plantilla (permisos de endpoints, auditoría por ruta, Dapper/
  DateOnly, grid homologado). **Cada repo AFINA su propio catálogo** — un repo no-.NET los
  reemplaza por los suyos; un repo .NET los hereda y agrega los propios. `ejecutar.sh` no aborta
  si no encuentra el layout .NET (`*.domain`): avisa y corre lo que haya.
- **Ejemplo/esqueleto de dominio (`invariantes-semanticos.yml`):** trae solo invariantes
  `general` (patrones de arquitectura). El DOMINIO de cada repo (reglas de negocio concretas) se
  agrega ahí como entradas `proyecto-especifico`, que NUNCA suben al template.

## El modelo: dos capas

### Capa 1 — determinista (`checks/*.sh`)

Chequeos de bash/grep, sin LLM, gratis, rápidos, invocables por cualquier humano y por CI. Cada
uno nace de un hallazgo REAL de una auditoría (positivo o negativo) que resultó ser
**mecánicamente detectable**: un patrón de código que se puede reconocer con una heurística de
texto, sin necesidad de entender la intención de negocio.

Corre todos con:
```bash
./scripts/auditor-semantico/ejecutar.sh
# o solo algunos, por número:
./scripts/auditor-semantico/ejecutar.sh 02 04
```

Exit 0 si todo limpio, exit 1 si algún check reportó candidatos (para gatear CI).

**Formato de salida — a propósito verboso, para que sea claro FUERA de contexto** (un humano
que solo pega el log, o un Claude/LLM sin memoria de esta conversación, debe entender qué hacer
sin más contexto que el propio texto):
```
./Proyecto.webapi/Controllers/ExportacionController.cs:33: método mutante sin [Authorize(Policy = ...)]/[AllowAnonymous] ni excepción documentada — revisar semántica de negocio con Capa 2 (skill auditor-semantico) antes de decidir si es bug o excepción documentada
RESULTADO: 0 hallazgo(s) semánticos CONFIRMADOS por Capa 1 (no puede confirmarlos — es determinista, no entiende intención de negocio)
RESULTADO: 1 candidato(s) a revisión semántica con Capa 2
```
Dos invariantes fijos en ese formato, para que ningún lector (humano o LLM) confunda "Capa 1
en rojo" con "hay un bug confirmado":
- La primera línea `RESULTADO` **siempre dice 0** — es matemáticamente imposible que diga otra
  cosa, porque Capa 1 nunca tiene la información de negocio para confirmar nada. Es un
  recordatorio estructural, no un conteo real.
- La segunda línea es el conteo real, pero se llama **candidato(s)**, nunca "bug(s)" ni
  "hallazgo(s) confirmados" — y cada línea de detalle repite la instrucción de qué hacer con
  ese candidato (revisarlo con la Capa 2).

Son heurísticas: **pueden dar falsos positivos**. Si uno es legítimo (una excepción de diseño a
propósito, no un olvido), **documéntalo en el código con un comentario**:
```csharp
// auditor-semantico: intencional — <por qué>
```
No apagues el check ni ignores el hallazgo en silencio — la próxima persona que lea el código
necesita saber que fue una decisión, no un descuido. Ver los headers de cada script en
`checks/` para el comentario exacto que cada uno reconoce como excepción documentada.

**Catálogo de ejemplo actual** (checks de la plantilla .NET; cada uno documenta en su header el
hallazgo que lo originó):
| Check | Qué verifica |
|---|---|
| `01-permisos-endpoints-mutantes.sh` | Todo endpoint mutante (`POST`/`PUT`/`DELETE`/`PATCH`) tiene `[Authorize(Policy=...)]`, `[AllowAnonymous]`, o una excepción documentada. |
| `02-ruta-id-para-auditoria.sh` | Toda ruta mutante con un placeholder ≠ `id` fija `EntidadId` a mano (si no, el filtro de registro de actividad audita esa mutación con `EntidadId=null`). |
| `03-dapper-dateonly-handler.sh` | Si el proyecto usa `DateOnly`/`TimeOnly` en Shared/Domain, existe su `SqlMapper.AddTypeHandler` en Infrastructure. |
| `04-grid-homologado.sh` | Toda página con `<MudTable Items="X">` liga `X` a un campo MATERIALIZADO, no a una propiedad con LINQ recalculado por fila (O(n²)). |

### Capa 2 — semántica (skill `auditor-semantico` + `invariantes-semanticos.yml`)

Lo que NO se puede reducir a una regla de texto porque requiere entender la intención de
negocio (¿este campo debería ser editable? ¿esta verificación falla cerrado o abierto?). Es
**inherentemente no determinista** — solo un LLM con criterio (Claude) puede evaluarla, por
eso vive en una skill y no en un script. Invócala con `/auditor-semantico` o pídele a Claude
que la corra.

`invariantes-semanticos.yml` es el manifiesto que la alimenta: cada entrada es una PREGUNTA
sembrada por una auditoría anterior, que la skill vuelve a hacerle al código en cada ronda.
Ver el header de ese archivo para el esquema completo y la distinción `general` (viaja con el
motor) vs `proyecto-especifico` (vive solo en la copia del repo que la originó).

## Cómo crece (el punto central de este sistema)

1. Se audita un proyecto.
2. Cada hallazgo (positivo: "esto está bien hecho, no lo rompan" o negativo: un bug real) se
   clasifica:
   - **Mecánicamente detectable** → se escribe un check nuevo en `checks/` (numerado
     consecutivo), probado contra un caso positivo y uno negativo antes de darlo por bueno.
   - **Requiere criterio/intención de negocio** → se agrega una entrada a
     `invariantes-semanticos.yml` (general si aplica a cualquier clon; `proyecto-especifico` si
     es una regla de negocio de ESE repo).
3. Los invariantes `general` y los checks agnósticos que nazcan se cosechan de vuelta al
   template (`cortex`); las reglas de dominio se quedan en el repo.
4. `cerrar-slice` invoca la Capa 1 como parte de la verificación de cada slice — ver
   `.claude/skills/cerrar-slice/SKILL.md`.

## Invocación humana / CI (sin Claude)

Cualquiera puede correr la Capa 1 sin gastar tokens ni depender de Claude:
```bash
./scripts/auditor-semantico/ejecutar.sh
```
Cablea un job informativo (`allow_failure: true`) en tu CI. Ejemplo para GitLab
(`.gitlab-ci.yml`) — el sufijo `-capa1` es a propósito: la Capa 2 NO corre en CI:
```yaml
auditor-semantico-capa1:
  stage: test
  allow_failure: true
  script:
    - bash scripts/auditor-semantico/ejecutar.sh
```
La Capa 2 (semántica) solo la puede correr Claude (u otro LLM con suficiente criterio) — no tiene
equivalente de CI puro; para eso está la skill. `ejecutar.sh` lo recuerda explícitamente al
final de su propio log, para que un CI en verde nunca se lea como "código auditado del todo".
