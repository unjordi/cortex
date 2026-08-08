#!/usr/bin/env bash
# install-hook.sh — [ya NO instala por su cuenta] El auto-export de sesiones-master es un hook del brain
# (brain/hooks/exportar-sesion-master.sh, tier `global` en el MANIFEST): lo copia a ~/.claude/hooks/ y lo
# cablea INSTALL-BRAIN, derivándolo del MANIFEST (Stop + SessionEnd + PreCompact) → UNA sola ruta de
# wiring, sin duplicar la lista de eventos (antídoto al drift). Este script queda solo como atajo de
# instalación:
#   ./install-hook.sh   → redirige a install-brain (instala/actualiza el cerebro completo).
#
# ¿Cómo RETIRAR el hook? — por su vía consolidada, no por un shim propio (el viejo `--uninstall` se
# retiró; era un shim residual que de-cableaba a mano el export global y divergía de la vía real):
#   • hook GLOBAL (exportar-sesion-master, y cualquier otro tier global/both): lo retira
#     `brain/uninstall-brain.sh`, que deriva la lista del MISMO MANIFEST (des-cablea de
#     ~/.claude/settings.json + borra el .sh). Fuente única, sin lista que driftee.
#   • hook POR-REPO (tier repo/both copiado en un repo): `bash brain/sincronizar-cerebro.sh <repo>
#     --disable <hook> --apply` (de-cablea event-agnóstico + borra el .sh en ese repo).
set -eu

# install → delega al instalador único del cerebro (que copia el hook + lo cablea desde el MANIFEST).
BRAIN="${CLAUDE_BRAIN_DIR:-$HOME/.claude-brain}"
if [ ! -f "$BRAIN/brain/install-brain.sh" ]; then
  echo "install-hook: no encuentro install-brain en '$BRAIN' (setea CLAUDE_BRAIN_DIR o clona el cerebro)."
  exit 1
fi
echo "El export de sesiones-master lo instala+cablea install-brain (es un hook del cerebro)."
echo "→ corriendo: bash $BRAIN/brain/install-brain.sh"
exec bash "$BRAIN/brain/install-brain.sh"
