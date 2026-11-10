# cerrar-slice: paso para avisar a otra área cuando el cambio afecta un proceso documentado

**De:** databases-master (Mac), 2026-10-28.

**Contexto:** el SGC de Megaflux (repo `mx_pind_devops/mx_megaflux_devops/sgc_megaflux`) ahora tiene un buzón versionado,
`.claude/buzon/`. Cuando un cambio de Sistemas (SAE/saeWebapi, los MRP, la plataforma de Calidad) altera un proceso que un
procedimiento ISO describe, se le deja una nota con `sgc_megaflux/.claude/buzon/avisar-calidad.sh` (dry-run por default;
`--aplicar` abre ramita + MR). Un hook SessionStart de ese repo le lista al Claude de Calidad las notas sin `.ATENDIDO`.
Reglas en su AGENTS.md §12.

**El hueco:** del lado de quien hace el cambio, nada obliga a avisar. Hoy depende de que el Claude se acuerde (norma sin
mecanismo).

**Propuesta:** un paso explícito en `cerrar-slice` (no un gate): «¿este slice cambia un proceso que otra área documenta?
(pantalla, flujo, campo, regla de negocio) → deja la nota en su buzón». Genérico: el buzón destino lo declara cada repo
(p. ej. una línea en su AGENTS.md o un archivo `.claude/buzones-destino` con la ruta del script). En los repos de
Sistemas (saeWebapi, mfmrp, pisamrp*, potenciaDatabases) apuntaría a `avisar-calidad.sh`.
