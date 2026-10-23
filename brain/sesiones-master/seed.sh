#!/usr/bin/env bash
# seed.sh — siembra las sesiones master de la CARPETA DE SESIONES en ~/.claude/projects/ de ESTA
# máquina, para poder `claude --resume` la MISMA conversación aquí. La mitad "sembrar" del sync
# (la mitad "auto-export" es el hook exportar-sesion-master.sh).
#
# CARPETA DE SESIONES: default ~/.claude-sessions, override $CLAUDE_SESSIONS_DRIVE (mismo contrato que
# el hook de export). Si esa carpeta vive en una nube sincronizada (Drive/iCloud), las sesiones viajan
# entre máquinas. session-import.js (lo aporta cortex) reescribe el cwd de cada sesión a la ruta
# LOCAL del repo destino, así que el swap /Users<->/home sale solo.
# (Antes seed.sh vivía DENTRO de la carpeta de Drive y se autolocalizaba con $(dirname $0); al mudarse
#  al brain eso ya no aplica → la carpeta se resuelve por env, no por la ubicación del script.)
#
# ROBUSTO POR MÁQUINA: el `target` del roster puede NO calzar 1:1 con esta compu —
#   (a) diferencias de MAYÚSCULAS (macOS es case-insensitive, Linux NO: `code/PowerScripts` vs
#       `code/powerscripts`) → el repo destino se resuelve case-insensitive contra lo que EXISTE aquí,
#       y se siembra a la RUTA REAL (para que el cwd reescrito y el slug casen con el repo de verdad);
#   (b) un repo que en esta máquina NO está clonado (p. ej. potenciaDatabases solo vive en la Mac)
#       → ese master se SALTA (no se siembra a un cwd inexistente ni se malgastan cientos de MB).
#
# Uso:  ./seed.sh            (siembra lo presente cuyo repo destino EXISTA aquí; salta lo demás)
#       ./seed.sh --force        (re-siembra; pisa lo local SALVO que la copia local esté MÁS FRESCA que
#                                 el .gz — en ese caso la SALTA, para no regresar una sesión viva a una
#                                 copia vieja. El motor lo reporta como "local más fresco").
#       ./seed.sh --force-stale  (pisa lo local SIEMPRE, incluso con una copia más vieja; salta el gate
#                                 de frescura a propósito. Úsalo solo si sabes que quieres regresar).
set -euo pipefail
DIR="${CLAUDE_SESSIONS_DRIVE:-$HOME/.claude-sessions}"
FORCE="${1:-}"
[ -d "$DIR" ] || { echo "seed.sh: no existe la carpeta de sesiones '$DIR' (setea CLAUDE_SESSIONS_DRIVE, o crea ~/.claude-sessions)"; exit 1; }
# Opción A (2026-10-14): el roster de masters ya NO vive en UN masters.json compartido (lo generaba conflictos
# de Drive). Se DERIVA de: (1) los `masters-<host>.json` que cada máquina CURA A MANO y publica al Drive;
# (2) el `masters.json` legacy, si todavía existe (compat durante la migración); (3) los `<id>.meta.json`
# per-sid (proveniencia conflict-free que escribe el export) como RESPALDO para ids no listados a mano.
if ! ls "$DIR"/masters*.json "$DIR"/*.meta.json >/dev/null 2>&1; then
  echo "seed.sh: no hay masters-*.json/masters.json ni <id>.meta.json en '$DIR' (nada que sembrar)"; exit 0
fi

IMP=""
for c in "$HOME/.local/bin/session-import.js" "$HOME/.cortex/bin/session-import.js"; do
  [ -f "$c" ] && IMP="$c" && break
done
[ -n "$IMP" ] || { echo "seed.sh: no encuentro session-import.js (¿cortex instalado en esta máquina?)"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "seed.sh: falta node"; exit 1; }

# Resuelve el repo destino de un target relativo a $HOME → imprime la RUTA REAL local, o exit 1 si el
# repo no está en esta máquina. (1) match exacto; (2) match case-insensitive del último componente
# dentro de su carpeta padre (caza PowerScripts vs powerscripts en Linux, que es case-sensitive).
resolve_target() {
  local t="$1" parent base dir p
  if [ -d "$HOME/$t" ]; then printf '%s' "$HOME/$t"; return 0; fi
  parent="$(dirname "$t")"; base="$(basename "$t")"
  dir="$HOME/$parent"
  [ -d "$dir" ] || return 1
  for p in "$dir"/*/; do
    [ -d "$p" ] || continue
    if [ "$(basename "$p" | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')" ]; then
      printf '%s' "${p%/}"; return 0
    fi
  done
  return 1
}

# Construye el ROSTER (líneas id<TAB>target<TAB>name) uniendo las tres fuentes. Prioridad: la entrada
# CURADA A MANO (masters-<host>.json, y el masters.json legacy) GANA sobre la derivada del meta — el
# humano fija el `target` canónico (el repo, no un worktree) y el `name`. Un id solo en los metas se
# deriva: name = meta.label; target = originCwd con el prefijo del $HOME de ORIGEN (/Users/<u>/ o
# /home/<u>/) quitado → "code/<repo>". (resolve_target abajo lo resuelve case-insensitive a la ruta real;
# si el repo no está en esta máquina, se SALTA.)
node -e '
  const fs=require("fs"),path=require("path"),dir=process.argv[1];
  const roster=new Map();   // id -> {id,target,name}  (curado gana: no se pisa si ya está)
  const files=fs.readdirSync(dir);
  // (1) curado por-host (masters-<host>.json). (2) el masters.json LEGACY PIERDE: solo se lee si NO hay
  // ningún masters-<host>.json (compat de transición; con ids viejos puede sembrar sesiones muertas, así
  // que en cuanto exista el primer per-host, el legacy se IGNORA — claudio). seed además salta todo id sin
  // .gz fresco abajo, así que un id legacy sin respaldo tampoco se siembra.
  const perHost = files.filter(f=>/^masters-.+\.json$/.test(f)).sort();
  const rosterFiles = perHost.length ? perHost : files.filter(f=>f==="masters.json");
  for(const f of rosterFiles){
    try{const m=JSON.parse(fs.readFileSync(path.join(dir,f),"utf8"));
      for(const e of (m.masters||[])) if(e&&e.id&&!roster.has(e.id)) roster.set(e.id,{id:e.id,target:e.target||"",name:e.name||e.id});
    }catch(_){}
  }
  // (3) respaldo: <id>.meta.json para ids no curados
  for(const f of files.filter(f=>/\.meta\.json$/.test(f))){
    try{const meta=JSON.parse(fs.readFileSync(path.join(dir,f),"utf8"));
      if(!meta||!meta.id||roster.has(meta.id)) continue;
      const target=(meta.originCwd||"").replace(/^\/(Users|home)\/[^/]+\//,"");
      roster.set(meta.id,{id:meta.id,target,name:meta.label||meta.id});
    }catch(_){}
  }
  for(const e of roster.values()){
    const hasMeta = fs.existsSync(path.join(dir, e.id+".meta.json")) ? "1" : "0";
    console.log([e.id,e.target,e.name,hasMeta].join("\t"));
  }
' "$DIR" \
| while IFS=$'\t' read -r id target name hasmeta; do
    if [ -z "$target" ]; then
      echo "· omito   ${name:-$id}: sin target (cúralo en masters-<host>.json o falta originCwd en su meta)"
      continue
    fi
    if [ ! -f "$DIR/$id.jsonl.gz" ]; then
      # Un id del roster curado SIN .meta.json NI .gz no existe por ningún lado: es un FANTASMA (fixture
      # viejo o entrada tecleada mal) → avisa fuerte en vez de sembrar/omitir en silencio (claudio).
      if [ "${hasmeta:-1}" = 0 ]; then
        echo "⚠ fantasma $name ($id): en un masters-<host>.json pero SIN .meta.json NI .gz en '$DIR' — id inexistente (¿fixture o entrada vieja?); quítalo del roster curado"
      else
        echo "· omito   $name: sin .gz local (¿Drive terminó de bajar? ¿unidad montada?)"
      fi
      continue
    fi
    if repo="$(resolve_target "$target")"; then
      echo "· siembro $name  →  $repo"
      node "$IMP" --repo "$repo" --sessions-dir "$DIR" --only "$id" ${FORCE:+$FORCE}
    else
      echo "· omito   $name: el repo destino '$target' no existe en esta máquina (no se siembra)"
    fi
  done
echo ""
echo "✅ listo. Abre 'claude --resume' parado en la carpeta de cada master sembrado y elígela por nombre."
