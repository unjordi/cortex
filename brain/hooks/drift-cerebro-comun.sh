#!/usr/bin/env bash
# drift-cerebro-comun.sh — LIB (tier global). Detectores de DRIFT de la copia GLOBAL del cerebro vs la
# FUENTE única (clon de instalación): skills (~/.claude/skills), hooks/libs (~/.claude/hooks) y el bloque
# de normas de ~/.claude/CLAUDE.md. Lo sourcea aviso-drift-cerebro.sh (SessionStart) para avisar, warn-only,
# cuando la copia instalada quedó atrás de la fuente o se editó en vivo (se perdería en el próximo install-brain).
#
# El cerebro vive SOLO en global por máquina (decisión unjordi 2026-11-01 "solo cerebro global"): ya NO hay
# copias del cerebro POR-REPO, así que esta lib ya NO lleva el chequeo/auto-sync per-repo (`drift_chequea_repo`,
# retirado con el cerebro por-repo). Solo quedan los detectores GLOBALES y `resolve_brain_dir`.
# Cada detector imprime el mensaje humano si hay drift, NADA si está al día, y devuelve 0 SIEMPRE (fail-open).
# Guardado bash-3.2-safe (sin arrays asociativos ni ${x^^}).

# resolve_brain_dir — resuelve el clon de instalación del cerebro, con el MISMO orden/fallback que ya
# tienen los 3 widgets (#322): $CLAUDE_BRAIN_DIR → ~/.cortex → ~/.claude-brain (nombre PRE-rename),
# prefiriendo el primero que EXISTA (test -d). Fail-open: si ninguno existe, cae al default histórico
# ~/.cortex (mismo comportamiento de siempre) — NUNCA bloquea ni falla.
# Por qué: antes de esto, todo el tooling bash (este archivo, verificar-cerebro.sh,
# proteger-fuente-cerebro.sh, exportar-sesion-master.sh, sesiones-master/install-hook.sh) resolvía con
# `${CLAUDE_BRAIN_DIR:-$HOME/.cortex}` a secas — SIN el fallback a `~/.claude-brain`. En una máquina cuyo
# clon quedó bajo el nombre VIEJO (renombre sin migrar), `~/.cortex` no existe → autosync/verificación/
# protección de fuente quedaban CIEGOS (fail-open silencioso), asimetría con los widgets que sí migraron
# Única implementación — todo lo demás la llama, no la
# reimplementa. Imprime la ruta por stdout, sin trailing slash.
resolve_brain_dir() {
  if [ -n "${CLAUDE_BRAIN_DIR:-}" ] && [ -d "${CLAUDE_BRAIN_DIR:-}" ]; then
    printf '%s\n' "$CLAUDE_BRAIN_DIR"; return 0
  fi
  [ -d "$HOME/.cortex" ] && { printf '%s\n' "$HOME/.cortex"; return 0; }
  [ -d "$HOME/.claude-brain" ] && { printf '%s\n' "$HOME/.claude-brain"; return 0; }
  printf '%s\n' "$HOME/.cortex"
}

# ── drift_skills_global — drift de la copia GLOBAL de skills (~/.claude/skills) vs la FUENTE única
#    (brain/skills), para las skills de tier {global} del SKILLS-MANIFEST. Es el equivalente
#    AUTOMÁTICO del `drift_scan skills` del doctor verificar-cerebro (manual): antídoto al síntoma real
#    (~/.claude/skills/to-do se editó a mano en dev → la copia viva DRIFTÓ de la fuente y NADA lo detectaba).
#    WARN-ONLY (nunca reescribe la copia global: la dirección puede ser "edit en vivo sin portar" = mejora
#    que se PERDERÍA con un overwrite ciego; el remedio es editar la FUENTE + re-correr install-brain).
#    Imprime el mensaje humano si hay drift; NADA si está limpia. Devuelve 0 SIEMPRE (fail-open).
#    PRECISIÓN: solo skills del manifiesto {global}; solo compara archivos PRESENTES en la fuente
#    (una skill/archivo puramente local en ~/.claude/skills, sin contraparte fuente, NO es este drift → se
#    ignora, cero falso positivo). bash-3.2-safe.
drift_skills_global() {
  local BRAIN_DIR SRC_SKILLS INST_SKILLS MAN
  BRAIN_DIR="$(resolve_brain_dir)"
  SRC_SKILLS="$BRAIN_DIR/brain/skills"
  INST_SKILLS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
  MAN="$SRC_SKILLS/MANIFEST"
  [ -d "$SRC_SKILLS" ] || return 0          # sin fuente → fail-open
  [ -d "$INST_SKILLS" ] || return 0         # sin copia instalada → nada que comparar
  [ -f "$MAN" ] || return 0                 # sin manifiesto de skills → no sé qué es del brain → fail-open

  local names editadas stale n_ed n_st sk src inst rel
  names=$(awk '$1!~/^#/ && NF>=2 && $2=="global"{print $1}' "$MAN")
  editadas=""; stale=""; n_ed=0; n_st=0
  while IFS= read -r sk; do
    [ -z "$sk" ] && continue
    [ -d "$SRC_SKILLS/$sk" ] || continue
    while IFS= read -r src; do
      [ -z "$src" ] && continue
      rel="${src#"$SRC_SKILLS/$sk"/}"
      inst="$INST_SKILLS/$sk/$rel"
      [ -f "$inst" ] || { n_st=$((n_st+1)); stale="$stale skills/$sk/$rel(falta)"; continue; }
      cmp -s "$src" "$inst" && continue
      if [ "$inst" -nt "$src" ]; then n_ed=$((n_ed+1)); editadas="$editadas skills/$sk/$rel"
      else n_st=$((n_st+1)); stale="$stale skills/$sk/$rel"; fi
    done < <(find "$SRC_SKILLS/$sk" -type f 2>/dev/null)
  done <<EOF
$names
EOF

  [ "$n_ed" = 0 ] && [ "$n_st" = 0 ] && return 0   # limpia → silencio
  local msg="🧠⚠️ DRIFT DE SKILLS (copia GLOBAL ~/.claude/skills vs la fuente única del cerebro):"
  if [ "$n_ed" -gt 0 ]; then
    msg="$msg
  · $n_ed archivo(s) EDITADOS EN VIVO (la copia instalada es MÁS NUEVA que la fuente → tu edición se PERDERÍA en el próximo install-brain). PÓRTALOS a la fuente $SRC_SKILLS y re-corre install-brain:$editadas"
  fi
  if [ "$n_st" -gt 0 ]; then
    msg="$msg
  · $n_st archivo(s) que la copia instalada tiene DESACTUALIZADOS/ausentes (la fuente se ve más nueva por mtime). Remedio normal: re-corre el bootstrap/install-brain (o \`bash $BRAIN_DIR/brain/install-brain.sh\`). ⚠️ OJO: si EDITASTE esa copia EN VIVO, un \`git pull\` en la fuente pudo re-sellar su mtime y hacerla ver 'más nueva' aunque TU edición sea la real — compara el CONTENIDO antes de re-desplegar o perderías tu cambio (pórtalo a la fuente primero):$stale"
  fi
  printf '%s\n' "$msg"
  return 0
}

# ── drift_hooks_global — drift de la copia GLOBAL de hooks (~/.claude/hooks) vs la FUENTE única
#    (brain/hooks), para TODO archivo de tier {global} del HOOKS-MANIFEST. Es el equivalente
#    AUTOMÁTICO del `drift_scan hooks` del doctor verificar-cerebro (manual): antídoto al síntoma real
#    (~/.claude/hooks/*.sh se editó a mano en dev → la copia viva DRIFTÓ de la fuente y NADA lo detectaba;
#    "el global está congelado" con FPs vivos).
#    ALCANCE = EXACTAMENTE lo que install-brain COPIA a ~/.claude/hooks (install-brain.sh, awk de la etapa (a)):
#    todo {global} SIN filtrar kind → hooks + LIBS (analizar-comando-git, drift-cerebro-comun, juez-comun…)
#    + scripts. NO se limita a kind=hook: una lib compartida driftada (p.ej. la lógica git de los guards) es
#    justo el drift silencioso que este chequeo debe cazar. (El cableado sí filtra kind=hook, pero eso es OTRA
#    etapa; el DRIFT de la copia espeja la COPIA, no el cableado.)
#    WARN-ONLY (nunca reescribe la copia global: la dirección puede ser "edit en vivo sin portar" = mejora
#    que se PERDERÍA con un overwrite ciego; el remedio es editar la FUENTE + re-correr install-brain).
#    Imprime el mensaje humano si hay drift; NADA si está limpia. Devuelve 0 SIEMPRE (fail-open).
#    PRECISIÓN: solo archivos del manifiesto {global}; solo compara los PRESENTES en la fuente (un hook
#    puramente local en ~/.claude/hooks, sin contraparte fuente, NO es este drift → se ignora, cero FP).
#    bash-3.2-safe.
drift_hooks_global() {
  local BRAIN_DIR SRC_HOOKS INST_HOOKS MAN
  BRAIN_DIR="$(resolve_brain_dir)"
  SRC_HOOKS="$BRAIN_DIR/brain/hooks"
  INST_HOOKS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks"
  MAN="$SRC_HOOKS/MANIFEST"
  [ -d "$SRC_HOOKS" ] || return 0          # sin fuente → fail-open
  [ -d "$INST_HOOKS" ] || return 0         # sin copia instalada → nada que comparar
  [ -f "$MAN" ] || return 0                # sin manifiesto de hooks → no sé qué es del brain → fail-open

  local names editadas stale n_ed n_st h src inst
  names=$(awk '$1!~/^#/ && NF>=3 && $2=="global"{print $1".sh"}' "$MAN")
  editadas=""; stale=""; n_ed=0; n_st=0
  while IFS= read -r h; do
    [ -z "$h" ] && continue
    src="$SRC_HOOKS/$h"
    [ -f "$src" ] || continue
    inst="$INST_HOOKS/$h"
    [ -f "$inst" ] || { n_st=$((n_st+1)); stale="$stale hooks/$h(falta)"; continue; }
    cmp -s "$src" "$inst" && continue
    if [ "$inst" -nt "$src" ]; then n_ed=$((n_ed+1)); editadas="$editadas hooks/$h"
    else n_st=$((n_st+1)); stale="$stale hooks/$h"; fi
  done <<EOF
$names
EOF

  [ "$n_ed" = 0 ] && [ "$n_st" = 0 ] && return 0   # limpia → silencio
  local msg="🧠⚠️ DRIFT DE HOOKS (copia GLOBAL ~/.claude/hooks vs la fuente única del cerebro):"
  if [ "$n_ed" -gt 0 ]; then
    msg="$msg
  · $n_ed archivo(s) EDITADOS EN VIVO (la copia instalada es MÁS NUEVA que la fuente → tu edición se PERDERÍA en el próximo install-brain). PÓRTALOS a la fuente $SRC_HOOKS y re-corre install-brain:$editadas"
  fi
  if [ "$n_st" -gt 0 ]; then
    msg="$msg
  · $n_st archivo(s) que la copia instalada tiene DESACTUALIZADOS/ausentes (la fuente se ve más nueva por mtime). Remedio normal: re-corre el bootstrap/install-brain (o \`bash $BRAIN_DIR/brain/install-brain.sh\`). ⚠️ OJO: si EDITASTE esa copia EN VIVO, un \`git pull\` en la fuente pudo re-sellar su mtime y hacerla ver 'más nueva' aunque TU edición sea la real — compara el CONTENIDO antes de re-desplegar o perderías tu cambio (pórtalo a la fuente primero):$stale"
  fi
  printf '%s\n' "$msg"
  return 0
}

# ── drift_norms_global — drift del bloque de NORMAS instalado en ~/.claude/CLAUDE.md (marcadores
#    `<!-- BEGIN cortex … -->` … `<!-- END cortex -->`) vs la fuente única (brain/norms/global-claude-md.md).
#    install-brain.sh §(e) refresca este bloque en cada re-corrida (reemplaza el contenido completo en su
#    lugar); esta función avisa cuando hace falta re-correrlo.
#    Comparación EXACTA (no heurística): install-brain inserta el archivo fuente COMPLETO y VERBATIM entre
#    sus propios marcadores BEGIN/END (que el propio archivo fuente ya trae) — así que "instalado == fuente"
#    se reduce a extraer el bloque instalado (desde la línea BEGIN hasta la línea END, ambas inclusive) y
#    comparar byte a byte contra el archivo fuente completo (cmp -s, sin falsos positivos por mtime/edición
#    en vivo: es un bloque GENERADO, nunca se edita a mano — a diferencia de hooks/skills no hace falta
#    distinguir "editado en vivo" de "desactualizado", solo hay UN motivo de drift: re-correr install-brain).
#    WARN-ONLY (nunca reescribe ~/.claude/CLAUDE.md — esa es la sección PERSONAL del usuario fuera del
#    bloque, y el remedio real de todos modos es re-correr install-brain, que YA sabe hacerlo con su propia
#    red de seguridad de backup). Silencio si no hay fuente, no hay CLAUDE.md, o el bloque no está instalado
#    (fail-open: "aún no instalado" no es "instalado y desactualizado" — eso lo cubre el bootstrap inicial,
#    no este drift-check). Imprime el mensaje humano si hay drift; NADA si está limpia. bash-3.2-safe.
drift_norms_global() {
  local BRAIN_DIR SRC_NORMS INST
  BRAIN_DIR="$(resolve_brain_dir)"
  SRC_NORMS="$BRAIN_DIR/brain/norms/global-claude-md.md"
  INST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md"
  [ -f "$SRC_NORMS" ] || return 0    # sin fuente → fail-open
  [ -f "$INST" ] || return 0         # CLAUDE.md global ni existe → nada que comparar (bootstrap aún no corrió)

  local block
  block="$(awk '
    /<!-- BEGIN cortex/ { f=1 }
    f { print }
    /<!-- END cortex -->/ { if (f==1) exit }
  ' "$INST")"
  [ -n "$block" ] || return 0        # bloque no instalado aún → fail-open (no es "desactualizado")

  if printf '%s\n' "$block" | cmp -s - "$SRC_NORMS"; then
    return 0                         # byte-idéntico → limpia, silencio
  fi
  printf '%s\n' "🧠⚠️ DRIFT DE NORMAS (bloque BEGIN/END cortex de ~/.claude/CLAUDE.md vs la fuente única brain/norms/global-claude-md.md): el bloque instalado quedó ATRÁS de la fuente — normas nuevas/retiradas/corregidas en el repo (p. ej. un hook que se retiró y cuya regla subió a norma) NO llegaron a esta máquina. Remedio: re-corre el bootstrap/install-brain (o \`bash $BRAIN_DIR/brain/install-brain.sh\`) — §(e) REFRESCA el bloque completo en su lugar (respaldo automático en CLAUDE.md.bak, tu sección personal fuera del bloque queda intacta). NO edites el bloque a mano: se regenera y tu edición se perdería."
  return 0
}
