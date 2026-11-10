# Los widgets de macOS y Windows NO compilan en develop

**De:** claudio-master · 2026-10-28 · prioridad por fricción: ALTA (el widget es el ítem #1 del §11 del triage)

Medido sobre origin/develop (d1de05f), sin cambios propios (mismo resultado con y sin el PR #480):
- `swift build` (macos/): `Sources/Cortex/PopoverView.swift:405:16: error: cannot find 'extra' in scope`
  (línea 406 usa `extra.monthly_limit` / `extra.utilization`).
- `dotnet build -p:EnableWindowsTargeting=true` (windows/src/Cortex): `QuotaService.cs(298,21)` y `(304,21)`:
  `error CS0117: 'Bucket' no contiene una definición para 'CostUsd'`.

Ambos parecen restos de un cambio de modelo (el bloque de sobreuso/«extra» y el costo por bucket) que tocó el
uso pero no la definición. Revisar junto con el resto del widget al reanudar.

**ATENDIDO 2026-10-28:** arreglado en #481 por claudio-master (ExtraUsage restaurado en Swift; EquivSession/WeeklyCostUsd en QuotaService.cs). Compilan swift build y dotnet build; sin QA de las apps en vivo.
