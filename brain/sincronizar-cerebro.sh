#!/usr/bin/env bash
# sincronizar-cerebro.sh — despliega/actualiza la copia POR-REPO del cerebro (claude-brain) en un repo
# consumidor (p. ej. un repo .NET), desde brain/ como FUENTE ÚNICA. Antídoto al drift: la copia
# por-repo deja de curarse a mano y se DERIVA del MANIFEST (tier {repo, both}).
#
# Qué copia a <repo>/.claude/hooks/: los archivos de tier {repo, both} (hooks + libs que sourcean),
# NO los global-only (esos los pone el bootstrap en ~/.claude). Y a <repo>/.claude/skills/: las SKILLS de
# tier {both, repo} del brain/skills/MANIFEST (árbol COMPLETO de cada skill, no solo SKILL.md; diff-aware;
# prune SEGURO por ledger .claude/skills/.brain-skills que nunca toca skills PROPIAS del repo). Además:
#   - estampa la VERSIÓN del cerebro en <repo>/.claude/hooks/.brain-version (drift por versión detectable),
#   - CABLEA en <repo>/.claude/settings.json (idempotente, "shell":"bash", ruta ${CLAUDE_PROJECT_DIR}/...)
#     los hooks de kind=hook de tier {repo, both} (evento por el mapa de abajo),
#   - PODA los hooks RETIRADOS: un .sh en el destino que NO está en el manifiesto PERO SÍ en la lista
#     brain/hooks/RETIRED (hooks que el cerebro ya retiró, p. ej. precompact-volcar-estado) se de-cablea
#     + borra SOLO en cualquier --apply (seguro: el brain lo declaró muerto). Los demás huérfanos
#     (posibles hooks PROPIOS del repo) solo se REPORTAN; --prune-orphans los retira (decisión deliberada).
#
# SEGURO por default: DRY-RUN (muestra qué cambiaría, no escribe). Con --apply copia y cablea.
# NO es `cp -f` ciego: diffea archivo por archivo y solo toca los que cambian. Requiere jq para cablear.
#
# --only <csv>: restringe la sincronización a esos nombres (sin .sh), útil para propagar un slice
#   acotado (p. ej. solo la lib + los wrappers que cambiaron) sin arrastrar drift de otros archivos
#   que se reconcilian en otro momento. Siempre respeta el tier del manifiesto (solo {repo,both}).
#
# --prune-orphans: RETIRA (de-wire del settings.json + borra el .sh) los huérfanos = archivos en el
#   destino que ya NO están en el manifiesto (el cerebro los retiró). Es DESTRUCTIVO → solo con --apply
#   borra; en dry-run los lista como "RETIRARÍA". Antídoto a un hook retirado que quedó cableado y
#   rompe (caso real: el viejo precompact-volcar-estado intentaba inyectar y el CLI lo rechazaba).
#
# --disable <a,b,c>: DES-CABLEA (quita del settings.json) + BORRA el/los hook(s) NOMBRADO(s) del repo
#   destino, sin sincronizar nada más. Es la vía ÚNICA y consolidada para retirar un hook obsoleto de
#   un repo (antes había shims sueltos con su propio `--uninstall` que divergían). Reusa la MISMA lógica
#   de de-cableado del pruning (dewire_hook, event-agnóstico → cubre los multi-evento del MANIFEST).
#   DRY-RUN por default (lista "DESHABILITARÍA"); con --apply de-cablea + borra. Idempotente (un hook ya
#   ausente se reporta y se salta). Funciona aunque el hook NO esté en el manifiesto (ese es el punto).
#
# Uso:  bash sincronizar-cerebro.sh <ruta-repo-destino> [--apply] [--only a,b,c] [--prune-orphans]
#       bash sincronizar-cerebro.sh <ruta-repo-destino> --disable <hook[,hook2,…]> [--apply]
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_HOOKS="$SCRIPT_DIR/hooks"
MANIFEST="$SRC_HOOKS/MANIFEST"
VERSION_FILE="$SCRIPT_DIR/VERSION"

DEST=""; APPLY=0; ONLY=""; PRUNE=0; PRUNEONLY=0; DISABLE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --only)  shift; ONLY="${1:-}" ;;
    --only=*) ONLY="${1#--only=}" ;;
    --prune-orphans) PRUNE=1 ;;
    --prune-only) PRUNE=1; PRUNEONLY=1 ;;   # SOLO retira huérfanos; NO sincroniza nada más (fix quirúrgico)
    --disable) shift; DISABLE="${1:-}" ;;    # SOLO deshabilita el/los hook(s) nombrado(s) (de-cablea + borra)
    --disable=*) DISABLE="${1#--disable=}" ;;
    -*) echo "ERROR: flag desconocido: $1"; exit 2 ;;
    *) [ -z "$DEST" ] && DEST="$1" || { echo "ERROR: argumento inesperado: $1"; exit 2; } ;;
  esac
  shift
done

if [ -z "$DEST" ] || [ ! -d "$DEST" ]; then
  echo "Uso: bash sincronizar-cerebro.sh <ruta-repo-destino> [--apply] [--only a,b,c]"
  echo "  (sin --apply = DRY-RUN: muestra qué cambiaría, no escribe)"
  exit 2
fi
# ¿el nombre está en el filtro --only? (sin filtro → todo pasa). CSV a espacios, match exacto.
only_ok() { [ -z "$ONLY" ] && return 0; printf '%s' "$ONLY" | tr ',' '\n' | grep -qxF "$1"; }
[ -f "$MANIFEST" ] || { echo "ERROR: falta $MANIFEST"; exit 1; }

DST_HOOKS="$DEST/.claude/hooks"
DST_SET="$DEST/.claude/settings.json"
# Versión = "<PREFIJO>.<commit-count>" (PREFIJO = brain/VERSION; count = git rev-list del clon brain).
# Auto-incrementa con cada commit; fallback COUNT=0 si no es repo git. Contrato compartido con install-brain.sh.
VERPREFIJO="$( [ -f "$VERSION_FILE" ] && head -1 "$VERSION_FILE" | tr -d '[:space:]' || echo '?' )"
VERCOUNT="$(git -C "$SCRIPT_DIR" rev-list --count HEAD 2>/dev/null || echo 0)"
VER="$VERPREFIJO.$VERCOUNT"

echo "==> sincronizar-cerebro (v$VER) — FUENTE: $SRC_HOOKS"
echo "    DESTINO: $DST_HOOKS"
[ "$APPLY" = 1 ] && echo "    modo: APPLY (escribe)" || echo "    modo: DRY-RUN (no escribe; usa --apply para aplicar)"
echo ""

# Evento+matcher para cablear los kind=hook de tier {repo,both}. (Los global-only los cablea el bootstrap.)
ev_de() {
  case "$1" in
    git-branch-guard|merge-squash-guard|confirmar-merge-develop|recordar-dashboard|secret-scan|entorno-maquina-guard|no-bypass-deploy) echo "PreToolUse|Bash" ;;
    dod-verificar)  echo "Stop|" ;;
    sesion-inicio)  echo "SessionStart|" ;;
    recordar-cosechar) echo "Stop|" ;;
    recordar-unificar-cerebro) echo "SessionStart|" ;;
    *) echo "" ;;
  esac
}

# register_hook <settings.json> <event> <matcher> <cmd> <patrón-dedupe>  (idempotente, igual que install-brain)
register_hook() {
  local gset="$1" ev="$2" m="$3" cmd="$4" pat="$5" tmp
  command -v jq >/dev/null 2>&1 || { echo "  warn: jq no está; cablea '$pat' a mano en $gset"; return; }
  [ -f "$gset" ] || echo '{}' > "$gset"
  tmp="$(mktemp)" || return
  if jq --arg ev "$ev" --arg m "$m" --arg cmd "$cmd" --arg pat "$pat" '
      .hooks = (.hooks // {}) |
      .hooks[$ev] = (.hooks[$ev] // []) |
      if any(.hooks[$ev][]?; ([.hooks[]?.command] | join(" ")) | test($pat))
      then . else .hooks[$ev] += [ (if $m=="" then {} else {"matcher":$m} end) + {"hooks":[{"type":"command","command":$cmd,"shell":"bash"}]} ] end
    ' "$gset" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then mv "$tmp" "$gset"; else rm -f "$tmp"; echo "  warn: no pude cablear ($pat)"; fi
}

# De-cablea del settings.json TODAS las entradas cuyo 'command' cite el basename del hook (jq).
# Event-agnóstico: recorre TODOS los eventos → cubre los hooks multi-evento del MANIFEST. Lo usan el
# pruning de huérfanos/retirados y la opción --disable.
dewire_hook() {
  local gset="$1" base="$2" tmp
  command -v jq >/dev/null 2>&1 || { echo "  warn: jq no está; quita a mano '$base' de $gset"; return; }
  [ -f "$gset" ] || return
  tmp="$(mktemp)" || return
  if jq --arg pat "$base\\.sh" '
      if (.hooks|type)=="object" then
        .hooks |= ( to_entries
          | map(.value |= [ .[] | select((([.hooks[]?.command]|join(" "))|test($pat))|not) ])
          | map(select((.value|type)=="array" and (.value|length)>0)) | from_entries )
        | (if (.hooks|length)==0 then del(.hooks) else . end)
      else . end
    ' "$gset" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then mv "$tmp" "$gset"; else rm -f "$tmp"; echo "  warn: no pude de-cablear ($base)"; fi
}

# wired_in <settings.json> <nombre-hook>  → 0 si algún command del settings.json cita .../<nombre>.sh.
# Base de la detección de CABLEADO FALTANTE (abajo). Sin jq NO podemos saberlo de forma fiable → damos
# "cableado" (fail-open: no inflar el contador faltante) para no reportar falso drift.
wired_in() {
  local gset="$1" name="$2"
  [ -f "$gset" ] || return 1
  command -v jq >/dev/null 2>&1 || return 0
  jq -e --arg pat "/$name\\.sh" 'any(.hooks[]?[]?; ([.hooks[]?.command] | join(" ")) | test($pat))' "$gset" >/dev/null 2>&1
}

# Instalación ATÓMICA: cp a un tmp en el MISMO dir + mv (rename atómico). Si el sync corre con una sesión
# VIVA, un `cp -f` in-situ deja una ventana en la que un hook que hace `source` de una lib (p. ej.
# analizar-comando-git.sh) la leería a medio sobrescribir; el mv/rename evita esa lectura parcial.
atomic_install() {  # <src> <dst>
  local src="$1" dst="$2" tmp
  tmp="$(dirname "$dst")/.$(basename "$dst").tmp.$$"
  if cp -f "$src" "$tmp" 2>/dev/null; then
    chmod +x "$tmp" 2>/dev/null
    mv -f "$tmp" "$dst" 2>/dev/null || { rm -f "$tmp"; return 1; }
  else
    rm -f "$tmp" 2>/dev/null; return 1
  fi
}

# ── --disable <a,b,c>: retira el/los hook(s) NOMBRADO(s) del repo destino y termina (no sincroniza) ──
# Vía consolidada para quitar un hook obsoleto de un repo (reemplaza los shims sueltos de `--uninstall`).
# De-cablea (dewire_hook, event-agnóstico) + borra el .sh. DRY-RUN por default; --apply escribe.
if [ -n "$DISABLE" ]; then
  echo "  (--disable: NO sincronizo; solo retiro el/los hook(s) nombrado(s))"
  n_dis=0; n_miss=0
  for name in $(printf '%s' "$DISABLE" | tr ',' ' '); do
    [ -z "$name" ] && continue
    dst="$DST_HOOKS/$name.sh"
    present=0; wired=0
    [ -f "$dst" ] && present=1
    wired_in "$DST_SET" "$name" && wired=1
    if [ "$present" = 0 ] && [ "$wired" = 0 ]; then
      echo "  YA AUSENTE $name (ni .sh ni cableado en settings.json)"; n_miss=$((n_miss+1)); continue
    fi
    if [ "$APPLY" = 1 ]; then
      [ "$wired" = 1 ] && dewire_hook "$DST_SET" "$name"
      [ "$present" = 1 ] && rm -f "$dst"
      echo "  DESHABILITADO $name.sh — de-cableado del settings.json + borrado"
    else
      echo "  DESHABILITARÍA $name.sh — de-cablearía del settings.json + borraría (usa --apply)"
    fi
    n_dis=$((n_dis+1))
  done
  echo ""
  echo "==> resumen (--disable): $n_dis hook(s) a deshabilitar · $n_miss ya ausente(s)"
  [ "$APPLY" = 1 ] || echo "    (DRY-RUN — nada escrito. Re-corre con --apply para aplicar.)"
  exit 0
fi

# ── Sincronizar los archivos de tier {repo, both} (se SALTA entero con --prune-only) ──
n_new=0; n_upd=0; n_ok=0; n_wire=0
PER_REPO="$(awk '$1!~/^#/ && NF>=3 && ($2=="repo"||$2=="both"){print $1"|"$3}' "$MANIFEST")"

[ "$PRUNEONLY" = 1 ] && echo "  (--prune-only: NO sincronizo hooks; solo retiro huérfanos)"
[ "$APPLY" = 1 ] && [ "$PRUNEONLY" != 1 ] && mkdir -p "$DST_HOOKS"
while [ "$PRUNEONLY" != 1 ] && IFS='|' read -r name kind; do
  [ -z "$name" ] && continue
  only_ok "$name" || continue
  src="$SRC_HOOKS/$name.sh"; dst="$DST_HOOKS/$name.sh"
  if [ ! -f "$src" ]; then echo "  warn: el manifiesto lista $name pero falta $src"; continue; fi
  if [ ! -f "$dst" ]; then
    echo "  NUEVO      $name.sh ($kind)"; n_new=$((n_new+1))
    [ "$APPLY" = 1 ] && { atomic_install "$src" "$dst" || echo "  warn: no pude instalar $name.sh"; }
  elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
    echo "  ACTUALIZA  $name.sh ($kind)  [$(diff "$src" "$dst" 2>/dev/null | grep -cE '^[<>]') líneas ±]"; n_upd=$((n_upd+1))
    [ "$APPLY" = 1 ] && { atomic_install "$src" "$dst" || echo "  warn: no pude instalar $name.sh"; }
  else
    n_ok=$((n_ok+1))
  fi
  # Cablear (solo kind=hook; libs/scripts no se cablean)
  if [ "$kind" = "hook" ]; then
    evm="$(ev_de "$name")"
    if [ -n "$evm" ]; then
      ev="${evm%%|*}"; m="${evm#*|}"
      if [ "$APPLY" = 1 ]; then
        register_hook "$DST_SET" "$ev" "$m" "bash \"\${CLAUDE_PROJECT_DIR}/.claude/hooks/$name.sh\"" "$name"
      fi
      n_wire=$((n_wire+1))
    else
      echo "  warn: no tengo evento para cablear $name (agrégalo a ev_de)"
    fi
  fi
done <<EOF
$PER_REPO
EOF

# ── Drift de CABLEADO: hooks kind=hook de tier {repo,both} cuyo comando NO aparece en el settings.json
#    destino. Antes esto era INVISIBLE al resumen → aviso-drift-cerebro lo daba por "al día" aunque el
#    repo tuviera hooks presentes-pero-SIN-cablear (bug de costura ALTO, comprobado en la plantilla: 3
#    hooks sin cablear se reportaban como 0 drift). Ahora se CUENTA y se REPORTA en el resumen para que
#    aviso-drift lo trate como drift. Independiente de que el .sh esté presente (si falta ya cuenta como
#    NUEVO). En --apply los hooks ya se cablearon arriba → este conteo dará 0. Se salta con --prune-only.
n_missing_wire=0
if [ "$PRUNEONLY" != 1 ]; then
  while IFS='|' read -r name kind; do
    [ -z "$name" ] && continue
    [ "$kind" = "hook" ] || continue
    only_ok "$name" || continue
    [ -n "$(ev_de "$name")" ] || continue   # sin evento no se cablea (ya se avisa arriba)
    if ! wired_in "$DST_SET" "$name"; then
      n_missing_wire=$((n_missing_wire+1))
      echo "  SIN CABLEAR $name.sh — presente en el manifiesto pero su comando NO está en settings.json"
    fi
  done <<EOF
$PER_REPO
EOF
fi

# ── Estampar la versión SOLO en sync COMPLETO: cualquier operación PARCIAL (--only o --prune-only) NO
# representa esa versión (el repo no queda completo) → estamparla MENTIRÍA sobre el estado del cerebro. ──
if [ "$APPLY" = 1 ] && [ -z "$ONLY" ] && [ "$PRUNEONLY" != 1 ] && [ -f "$VERSION_FILE" ]; then
  { echo "$VER"; date +%Y-%m-%d; } > "$DST_HOOKS/.brain-version"   # 2 líneas: versión + fecha (contrato)
  echo ""; echo "  sello: $DST_HOOKS/.brain-version = v$VER · $(date +%Y-%m-%d)"
elif [ "$APPLY" = 1 ] && { [ -n "$ONLY" ] || [ "$PRUNEONLY" = 1 ]; }; then
  echo ""; echo "  (operación PARCIAL (--only/--prune-only): NO estampo versión — el repo no queda completo en v$VER)"
fi

# ── Huérfanos (.sh en el destino que NO están en el manifiesto). Dos clases:
#    (a) RETIRADOS por el cerebro (en la lista brain/hooks/RETIRED) → se PODAN SOLOS en cualquier
#        --apply (de-cablear + borrar), sin --prune-orphans: el brain los declaró muertos = seguro.
#    (b) DESCONOCIDOS (posible hook PROPIO del repo) → solo se reportan; --prune-orphans los retira. ──
RETIRED_FILE="$SRC_HOOKS/RETIRED"
es_retirado() { [ -f "$RETIRED_FILE" ] && awk '$1!~/^#/ && NF{print $1}' "$RETIRED_FILE" | grep -qxF "$1"; }
echo ""
n_orph=0; n_retired=0
if [ -d "$DST_HOOKS" ]; then
  for f in "$DST_HOOKS"/*.sh; do
    [ -e "$f" ] || continue
    b="$(basename "$f" .sh)"
    awk '$1!~/^#/ && NF>=3 {print $1}' "$MANIFEST" | grep -qxF "$b" && continue   # en el manifiesto → no es huérfano
    if es_retirado "$b"; then
      # (a) RETIRADO por el cerebro → poda AUTOMÁTICA (no requiere --prune-orphans).
      n_retired=$((n_retired+1))
      if [ "$APPLY" = 1 ]; then
        dewire_hook "$DST_SET" "$b"; rm -f "$f"
        echo "  RETIRADO   $b.sh — retirado del cerebro (RETIRED): de-cableado + borrado (auto)"
      else
        echo "  RETIRARÍA  $b.sh — retirado del cerebro (RETIRED): --apply lo de-cablea + borra SOLO (auto)"
      fi
    else
      # (b) huérfano DESCONOCIDO → solo --prune-orphans lo retira.
      n_orph=$((n_orph+1))
      if [ "$PRUNE" = 1 ] && [ "$APPLY" = 1 ]; then
        dewire_hook "$DST_SET" "$b"; rm -f "$f"
        echo "  RETIRADO   $b.sh — de-cableado + borrado (--prune-orphans)"
      elif [ "$PRUNE" = 1 ]; then
        echo "  RETIRARÍA  $b.sh — huérfano; de-cablearía + borraría (usa --apply)"
      else
        echo "  HUÉRFANO   $b.sh — no está en el manifiesto NI en RETIRED (¿hook propio del repo? usa --prune-orphans para retirarlo)"
      fi
    fi
  done
fi

echo ""
echo "==> resumen: $n_new nuevos · $n_upd a actualizar · $n_ok ya al día · $n_retired retirado(s) del cerebro · $n_wire hooks cableados (kind=hook) · $n_missing_wire cableado faltante"

# ══════════════════════════════════════════════════════════════════════════════════════════════════════
# SKILLS por-repo (tier {both,repo} del SKILLS-MANIFEST). Misma disciplina que los hooks: fuente
# brain/skills → <repo>/.claude/skills, ÁRBOL COMPLETO de cada skill (no solo SKILL.md — algunas traen
# reference/ o bootstrap-claude.sh), diff-aware, atómico, idempotente, respeta --apply/--only/--prune-orphans.
# Emite su PROPIO resumen ("==> resumen skills:") → drift-cerebro-comun lo suma al total (misma bifurcación
# .claude/repo-compartido: en un repo COMPARTIDO auto-sync en la mini; en PERSONAL ni se corre este sync).
# Las skills GLOBALES ({global,both}) las despliega el bootstrap/install-brain; aquí solo va lo por-repo.
# Prune SEGURO por LEDGER: solo toca skills que ESTE sync desplegó (registradas en .claude/skills/.brain-skills);
# las skills PROPIAS del repo (no del brain) nunca están en el ledger → jamás se tocan.
SRC_SKILLS="$SCRIPT_DIR/skills"
SKILLS_MANIFEST="$SRC_SKILLS/MANIFEST"
DST_SKILLS="$DEST/.claude/skills"
LEDGER="$DST_SKILLS/.brain-skills"

if [ "$PRUNEONLY" != 1 ] && [ -f "$SKILLS_MANIFEST" ]; then
  # Skills de tier {both,repo} = las que viajan por-repo. (global-only NO.)
  PER_REPO_SK="$(awk '$1!~/^#/ && NF>=2 && ($2=="both"||$2=="repo"){print $1}' "$SKILLS_MANIFEST")"
  sk_new=0; sk_upd=0; sk_ok=0; deployed=""
  echo ""
  [ "$APPLY" = 1 ] && mkdir -p "$DST_SKILLS"
  while IFS= read -r skname; do
    [ -z "$skname" ] && continue
    only_ok "$skname" || continue
    ssk="$SRC_SKILLS/$skname"
    [ -d "$ssk" ] || { echo "  warn: el SKILLS-MANIFEST lista '$skname' pero falta $ssk"; continue; }
    deployed="$deployed $skname"
    # Recorre el ÁRBOL COMPLETO de la skill fuente y diffea archivo por archivo.
    while IFS= read -r sf; do
      [ -z "$sf" ] && continue
      rel="${sf#"$ssk"/}"
      df="$DST_SKILLS/$skname/$rel"
      if [ ! -f "$df" ]; then
        echo "  NUEVA      skills/$skname/$rel"; sk_new=$((sk_new+1))
        [ "$APPLY" = 1 ] && { mkdir -p "$(dirname "$df")"; atomic_install "$sf" "$df" || echo "  warn: no pude instalar skills/$skname/$rel"; }
      elif ! diff -q "$sf" "$df" >/dev/null 2>&1; then
        echo "  ACTUALIZA  skills/$skname/$rel  [$(diff "$sf" "$df" 2>/dev/null | grep -cE '^[<>]') líneas ±]"; sk_upd=$((sk_upd+1))
        [ "$APPLY" = 1 ] && { mkdir -p "$(dirname "$df")"; atomic_install "$sf" "$df" || echo "  warn: no pude instalar skills/$skname/$rel"; }
      else
        sk_ok=$((sk_ok+1))
      fi
    done < <(find "$ssk" -type f 2>/dev/null)
  done <<EOF
$PER_REPO_SK
EOF

  # ── Prune de skills del BRAIN retiradas/demotidas: nombre en el LEDGER anterior que YA NO está en
  #    {both,repo}. Solo skills que ESTE sync desplegó antes → nunca toca skills propias del repo.
  sk_orph=0
  if [ -f "$LEDGER" ]; then
    while IFS= read -r old; do
      [ -z "$old" ] && continue
      printf '%s\n' $PER_REPO_SK | grep -qxF "$old" && continue   # sigue siendo brain-por-repo → no es huérfana
      [ -d "$DST_SKILLS/$old" ] || continue
      sk_orph=$((sk_orph+1))
      if [ "$PRUNE" = 1 ] && [ "$APPLY" = 1 ]; then
        rm -rf "${DST_SKILLS:?}/${old:?}"
        echo "  RETIRADA   skills/$old — skill del brain ya no {both,repo}: borrada (--prune-orphans, del ledger)"
      elif [ "$PRUNE" = 1 ]; then
        echo "  RETIRARÍA  skills/$old — skill del brain ya no {both,repo}: la borraría (usa --apply; estaba en el ledger)"
      else
        echo "  HUÉRFANA   skills/$old — skill del brain desplegada antes, ya no {both,repo} (usa --prune-orphans para retirarla)"
      fi
    done < "$LEDGER"
  fi

  # Refresca el LEDGER (solo en --apply COMPLETO — sin --only, que es parcial y no representa el set entero).
  # El ledger = las skills del brain que SIGUEN desplegadas en disco: las {both,repo} actuales + las
  # huérfanas que NO se podaron (siguen presentes). Una huérfana pruneada (dir borrado) sale del ledger.
  if [ "$APPLY" = 1 ] && [ -z "$ONLY" ]; then
    { printf '%s\n' $deployed; [ -f "$LEDGER" ] && cat "$LEDGER"; } 2>/dev/null | sort -u | while IFS= read -r nm; do
      [ -n "$nm" ] && [ -d "$DST_SKILLS/$nm" ] && printf '%s\n' "$nm"
    done > "$LEDGER.tmp.$$" 2>/dev/null
    if [ -s "$LEDGER.tmp.$$" ]; then mkdir -p "$DST_SKILLS"; mv -f "$LEDGER.tmp.$$" "$LEDGER"
    else rm -f "$LEDGER.tmp.$$" "$LEDGER" 2>/dev/null; fi
  fi

  echo "==> resumen skills: $sk_new nuevas · $sk_upd a actualizar · $sk_ok ya al día · $sk_orph huérfana(s)"
fi
# ══════════════════════════════════════════════════════════════════════════════════════════════════════

[ "$APPLY" = 1 ] || echo "    (DRY-RUN — nada escrito. Re-corre con --apply para aplicar.)"
