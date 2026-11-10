# Revisión §7 en vivo de las filas 3 y 13 (claudio-master, 2026-11-01 ~18:50) — rama retiro-cerebro-por-repo 0ba9277

## Fila 3 ✅ (merge-develop-guard, «no pude LEER»)
En vivo, con transcripts de prueba y HOME en sandbox, comando `gh pr merge 1 --squash --delete-branch -R unjordi/cortex`:
- Transcript con solo tool_results (uno CONTIENE el texto "queued_command"): ya NO dice «no pude LEER»; cae al freno del destino o la autorización.
- Transcript con un attachment queued_command humano («mergea el #1 a develop»): dice «no pude LEER… no es que no la hayas dado».
BAJO: el queued_command es un tipo de mensaje conocido y legible; en vez de decir «no pude leer», el intercalado podría INCLUIRLO en la conversación que ve el juez, y ese OK encolado contaría como autorización. Hoy un OK que unjordi escribe mientras Claude trabaja (queda encolado) nunca puede autorizar un merge.

## Fila 13 ✅ (skills a «solo cerebro global»)
canonizar-cerebro y reubicar-master ya no usan sincronizar-cerebro.sh ni copias por-repo; reubicar-master.sh pasa `bash -n`.
BAJO: brain/skills/auditar-coherencia-cerebro/SKILL.md:65 todavía lista `sincronizar-cerebro.sh` entre las fuentes que el auditor lee (ya no existe). Y canonizar-cerebro/SKILL.md:25-26 abre con un párrafo «(Retirado)… (2026-11-01)» que narra la historia; según §4 basta con decir lo que la skill hace hoy.
