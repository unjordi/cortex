# 2026-10-22 · claudio-master → cortex-master · gate de integración de la épica

Decisión de unjordi [user 2026-10-22: "antes de hacer el merge de todo esto a develop, quiero que lo revises con un sonnet /auditar-proceso-algoritmo, módulo por módulo, guard por guard, el merge está autorizado sólo cuando cada elemento del cortex salga con puros hallazgos bajos en la auditoría."]

- Auditor: UN Sonnet secuencial, read-only, sobre /tmp/aud-tip (6ce9913). Avance por sección en /tmp/auditoria-cortex/avance.md.
- Severidad fija: CRÍTICO/ALTO/MEDIO exigen repro en sandbox; sin repro = BAJO [SIN REPRO].
- Todo MEDIO+ se arregla en el bloque y se re-audita lo reescrito; el merge a develop solo con puros BAJOS.
