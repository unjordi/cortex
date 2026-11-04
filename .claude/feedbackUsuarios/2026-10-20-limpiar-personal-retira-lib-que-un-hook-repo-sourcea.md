# Feedback: `sincronizar-cerebro.sh --limpiar-personal` retira una lib de la que depende un hook tier `repo`

Reportado por axon-master desde `~/code/axon` (repo PERSONAL, sin `.claude/repo-compartido`), 2026-10-20.

## Qué pasa
`--limpiar-personal` retira los archivos de tier `both` y conserva los de tier `repo`. En axon eso
significa retirar `juez-comun.sh` (lib, tier `both`) y dejar `dod-verificar.sh` (hook, tier `repo`).

Pero `dod-verificar.sh` sourcea la lib por **ruta relativa al propio archivo, sin fallback**:

```bash
# .claude/hooks/dod-verificar.sh:52
. "${BASH_SOURCE[0]%/*}/juez-comun.sh"
```

Con la lib retirada, el hook falla al cargar y `_juez_dod` nunca se define: el candado del Stop queda
mudo (fail-open por contrato, así que no bloquea — simplemente deja de juzgar, en silencio).

## Cómo se reproduce
```bash
cd <repo-personal>
bash <cortex>/brain/sincronizar-cerebro.sh <repo-personal> --limpiar-personal   # dice: RETIRARÍA juez-comun.sh
# sin aplicarlo, basta probar el hook sin la lib al lado:
mkdir -p /tmp/t/hooks && cp .claude/hooks/dod-verificar.sh /tmp/t/hooks/
echo '{"transcript_path":"/dev/null"}' | bash /tmp/t/hooks/dod-verificar.sh
# → línea 52: /tmp/t/hooks/juez-comun.sh: No existe el fichero o el directorio
```

Medido así antes de aplicar; por eso NO se aplicó en axon.

## Por qué la premisa del dedupe no cubre este caso
El razonamiento de `--limpiar-personal` es que la copia por-repo CEDE a la global por el `case "$0" … exit 0`
de los hooks `both`. Eso vale para un hook que se INVOCA, no para una lib que se SOURCEA: el `. "${BASH_SOURCE[0]%/*}/…"`
resuelve contra el directorio del hook, no contra `~/.claude/hooks`, así que la global existente (que sí está:
`~/.claude/hooks/juez-comun.sh`) nunca entra en juego.

## Posibles salidas (de quien mantiene cortex, no mía)
- Que `--limpiar-personal` no retire una lib `both` si algún hook `repo` instalado la sourcea (dependencia real).
- O que los hooks `repo` sourceen con fallback a la global: probar `${BASH_SOURCE[0]%/*}/lib.sh` y si no existe,
  `${CLAUDE_BRAIN_DIR:-~/.claude}/hooks/lib.sh`.
- O declarar `juez-comun` tier `repo` (viaja con los hooks que la usan).

La tercera es la más chica pero duplica la lib en repos compartidos; la segunda es la que vuelve el dedupe cierto
también para libs. Lo dejo a criterio de cortex-master.
