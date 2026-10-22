#!/usr/bin/env bash
# ramas-zombie.sh — LIB compartida (no se cablea; se hace `source`). Decide si una rama YA está integrada
# ("zombie") de forma robusta al flujo SQUASH, resuelve la base de integración, y decide si una rama es
# INTOCABLE pase lo que pase. La consumen `limpiar.sh worktrees` (barre worktrees) y `limpiar.sh ramas`
# (barre ramas locales) → una sola definición de "mergeada" Y de "protegida", sin divergencia (antídoto
# al drift entre los dos barredores).
#
# "Mergeada" es QUÍNTUPLE porque el flujo SQUASHEA (la rama NO queda de ancestro): (a) ancestro de la base
# (flujo merge-commit) O (e) el mensaje de squash trae la línea "Rama: <rama>" (convención del equipo,
# señal LOCAL/gratis/offline — ver abajo) O (d) su PR/MR se MERGEÓ en el host (señal autoritativa, depende
# de gh/glab) O (c) sus commits ya están en la base por EQUIVALENCIA de parche (git cherry) — el merge
# LOCAL a la mini-develop y los cherry-picks O (b) la rama fue pusheada, su rama remota YA no existe (se
# borró al mergear con --delete-branch, típico del squash → `: gone`) Y NO trae commits propios sin integrar.
#
# POR QUÉ existe (e): (d) es la ÚNICA señal que caza el squash de VARIOS commits (el caso MÁS común del
# flujo), pero (d) depende de gh/glab — AUSENTES del PATH de launchd (el que hereda el hook cuando Claude
# corre desde la GUI) → (d) muere en silencio y el squash-multi-commit se CONSERVA para siempre sin poder
# verificarse. (e) es determinista y NO depende de ningún binario externo: el equipo pone "Rama: <nombre>"
# en el mensaje de cada squash (convención existente), así que
# `git log --format=%B <base> | grep -qxF "Rama: <rama>"` prueba la integración sin red.
#
# POR QUÉ existe (d): un squash de VARIOS commits a uno NO empareja patch-id → (c) no lo caza y (b)
# CONSERVA si git cherry marca algún '+'. (d) pregunta al HOST si el PR/MR de la rama se mergeó — si sí,
# sus commits están en la base aunque git no los empareje (y solo si el head mergeado CONTIENE el tip
# local, para no borrar trabajo post-merge). FAIL-OPEN: sin gh/glab, sin red, host no reconocido o error
# → (d) no aplica y se cae a las señales de git (conservador).
#
# Una rama NUNCA pusheada y sin equivalencia → se CONSERVA. La regla (b) NUNCA borra a ciegas: si la rama
# tiene commits propios no equivalentes a la base (git cherry marca '+'), se CONSERVA aunque su remota ya
# no exista — la ausencia de la remota no prueba integración, y el `branch -D` es irreversible.
#
# TRES ESTADOS, no dos: cuando git cherry marca '+' (contenido no patch-equivalente) y (d) NO pudo
# consultarse (gh/glab ausentes, host no reconocido, sin red), el veredicto correcto NO es "vivo con
# certeza": es INDETERMINADO — pudo ser un squash multi-commit YA mergeado que (d) habría cazado. La
# ACCIÓN es la misma en ambos casos (conservar: `bz_es_zombie` devuelve 1, nunca se borra a ciegas), pero
# el REPORTE debe distinguirlos (`$BZ_RAZON`) para no afirmar "trabajo sin integrar" cuando lo honesto es
# "no se pudo comprobar" — mentir aquí contamina la bitácora con pendientes falsos.

# bz_resolver_base ROOT → imprime la base de integración.
# La base es configurable (CLAUDE_INTEGRACION_BASE): en el flujo mini-develop NO es develop sino TU rama
# personal (convención `Develop<Usuario>`, p. ej. `DevelopAna`). Precedencia sin override:
#   1) HEAD parado en una mini-develop `Develop<Usuario>` → esa (es la base viva del dev).
#   2) una rama local `Develop<Usuario>` existe → esa (el día a día del dev vive en su mini-develop;
#      sus ramitas se integran a la mini, NO directo a develop — así el barrido las ve integradas).
#   3) fallback clásico: develop, o la rama por defecto del remoto, o main.
# Sin `Develop*` local (repo de flujo develop puro, p. ej. un solo-dev sobre develop) → cae a (3), intacto.
# Con VARIAS `Develop*` locales y HEAD en ninguna NO SE ADIVINA (tomar la primera por orden alfabético daría
# una base ARBITRARIA, p. ej. la mini de un colega) — cae a (3). El caller que quiera el AVISO llama `bz_aviso_base ROOT`
# (función independiente, NO una variable global): `base="$(bz_resolver_base "$ROOT")"` es una
# sustitución de comando — bash la corre en un SUBSHELL — así que cualquier variable que la función
# fijara ahí adentro se perdería al volver; una función separada, invocada con su PROPIA sustitución de
# comando, no tiene ese problema porque su valor de retorno ES precisamente lo que imprime.
bz_resolver_base() {
  local ROOT="$1" base="${CLAUDE_INTEGRACION_BASE:-}" cur mini n_mini
  if [ -z "$base" ]; then
    # (1) HEAD en una mini-develop (Develop<Usuario>; case-sensitive, ≥1 char tras "Develop" → excluye
    #     el `develop` minúsculas y un `Develop` pelón).
    cur=$(git -C "$ROOT" symbolic-ref --short -q HEAD 2>/dev/null || true)
    case "$cur" in Develop?*) base="$cur" ;; esac
    # (2) preferir una mini-develop LOCAL si la hay — pero solo si hay UNA sola; con varias y HEAD en
    #     ninguna, adivinar es peor que caer a (3).
    if [ -z "$base" ]; then
      n_mini=$(git -C "$ROOT" for-each-ref --format='%(refname:short)' 'refs/heads/Develop*' 2>/dev/null | wc -l | tr -d ' ')
      if [ "${n_mini:-0}" = 1 ]; then
        mini=$(git -C "$ROOT" for-each-ref --format='%(refname:short)' 'refs/heads/Develop*' 2>/dev/null)
        [ -n "$mini" ] && base="$mini"
      fi
    fi
    # (3) fallback: develop → rama por defecto del remoto → main.
    # El fallback a `main` es un paso APARTE que decide mirando si la cadena quedó VACÍA, no el código de
    # salida del pipeline: `sed` sale 0 con salida vacía cuando `symbolic-ref -q` no encontró `origin/HEAD`,
    # así que un `|| echo main` ligado al pipeline nunca correría y la base quedaría en "". Con base vacía
    # TODAS las señales de integración fallan MUDAS (is-ancestor/log/cherry contra "") → una rama con su
    # remota `gone` caería a (b), se declararía "integrada" y se iría en un `git branch -D` con trabajo sin
    # integrar (PÉRDIDA DE DATOS).
    if [ -z "$base" ]; then
      base=develop
      if ! git -C "$ROOT" rev-parse --verify -q refs/heads/develop >/dev/null 2>&1; then
        base=$(git -C "$ROOT" symbolic-ref --short -q refs/remotes/origin/HEAD 2>/dev/null | sed 's#origin/##')
        [ -n "$base" ] || base=main
      fi
    fi
  fi
  printf '%s' "$base"
}

# bz_base_valida ROOT BASE → 0 si BASE resuelve a un commit REAL en ROOT; 1 si no (vacía o fantasma).
# Segundo candado (el que de verdad importa): NINGUNA señal de integración es evaluable sin una base
# que exista — `merge-base --is-ancestor <br> ""`, `log ""`, `git cherry "" <br>` fallan MUDAS y empujan
# toda rama a la señal (b), que es destructiva. Barrer con base irresoluble no puede ser correcto NUNCA,
# venga el vacío de donde venga (fallback roto, CLAUDE_INTEGRACION_BASE con un typo, base aún no creada):
# los barredores lo consultan y ABORTAN en vez de evaluar contra una base fantasma. Ante duda, se conserva.
bz_base_valida() {
  local ROOT="$1" base="${2:-}"
  [ -n "$base" ] || return 1
  git -C "$ROOT" rev-parse --verify -q "${base}^{commit}" >/dev/null 2>&1
}

# bz_aviso_base ROOT → imprime (por stdout) un aviso si hay AMBIGÜEDAD real en la base que
# `bz_resolver_base` no pudo resolver (varias `Develop*` locales y HEAD en ninguna) — vacío si no
# aplica. Recalcula de forma INDEPENDIENTE (no comparte estado con `bz_resolver_base`): así sobrevive a la
# forma más común de consumir la base (`base="$(bz_resolver_base "$ROOT")"`, que corre en un subshell).
bz_aviso_base() {
  local ROOT="$1" cur n_mini
  [ -n "${CLAUDE_INTEGRACION_BASE:-}" ] && return 0   # override explícito → sin ambigüedad que avisar
  cur=$(git -C "$ROOT" symbolic-ref --short -q HEAD 2>/dev/null || true)
  case "$cur" in Develop?*) return 0 ;; esac           # HEAD ya está en una mini → sin ambigüedad
  n_mini=$(git -C "$ROOT" for-each-ref --format='%(refname:short)' 'refs/heads/Develop*' 2>/dev/null | wc -l | tr -d ' ')
  if [ "${n_mini:-0}" -gt 1 ] 2>/dev/null; then
    printf 'hay %s mini-develop locales y HEAD no está en ninguna; no se adivina' "$n_mini"
  fi
}

# --- Señal (d): ¿el PR/MR de la rama se MERGEÓ en el host? (autoritativa para el flujo SQUASH) --------
# Se consulta 1× por proceso (memoizado por ROOT). FAIL-OPEN total: sin gh/glab, sin red, host no
# reconocido o error → cache vacío → (d) no aplica → se cae a las señales de git. TEST: exporta
# CLAUDE_BZ_PRCACHE=<archivo con líneas 'rama<TAB>sha'> para inyectar el mapa de PRs mergeados sin red.
# $_BZ_D_INTENTADO: 1 si de verdad se INTENTÓ consultar el host (binario disponible e invocado, o cache
# inyectada por test) — 0 si no se pudo ni intentar (binario ausente). $_BZ_D_APLICABLE: 1 si hay un
# remoto de RED configurado (scheme:// o user@host:) donde (d) PODRÍA en teoría aplicar — 0 si no hay
# remoto o es una ruta local (nunca hubo dónde mergear un PR/MR, así que (d) no aplica ni en teoría — no
# es "no se pudo consultar", es "no corresponde"). `bz_es_zombie` usa AMBAS para distinguir "consultamos y
# esta rama no aplica" / "no había host que consultar" (ambas → vivo con certeza) de "había host pero no
# se pudo consultar" (→ indeterminado, tercer estado).
_BZ_PRCACHE_FILE=""; _BZ_PRCACHE_ROOT=""; _BZ_D_INTENTADO=0; _BZ_D_APLICABLE=0
_bz_run() {  # _bz_run SEGUNDOS cmd... — con timeout si existe (que un host colgado no cuelgue la poda)
  local t="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$t" "$@"; else "$@"; fi
}
# El cap de PRs consultados es configurable (CLAUDE_BZ_PR_LIMIT; default con holgura): un cap fijo y MUDO
# dejaría las ramas viejas de un repo con muchos PRs fuera de la señal (d) sin decirlo. `gh --limit` pagina
# internamente; `glab --per-page` topa en 100 por página en la API de GitLab, así que se PAGINA hasta agotar
# (o hasta el tope).
_bz_limite() { local l="${CLAUDE_BZ_PR_LIMIT:-1000}"; case "$l" in ''|*[!0-9]*) l=1000 ;; esac; printf '%s' "$l"; }
_bz_glab_paginar() {  # $1=proj $2=filtro(-M|-A) $3=archivo destino $4=expresión jq
  local proj="$1" filtro="$2" dest="$3" jqf="$4" pag=1 n maxp
  maxp=$(( $(_bz_limite) / 100 )); [ "$maxp" -ge 1 ] || maxp=1
  while [ "$pag" -le "$maxp" ]; do
    n=$(_bz_run 15 glab mr list -R "$proj" "$filtro" --per-page 100 --page "$pag" -F json \
          --jq "$jqf" 2>/dev/null | tee -a "$dest" | wc -l | tr -d ' ')
    [ "${n:-0}" -lt 100 ] && break
    pag=$((pag+1))
  done
}
_bz_intentar_gh() {  # $1=ROOT $2=proj — apéndice al cache si gh está disponible
  local ROOT="$1" proj="$2"
  command -v gh >/dev/null 2>&1 || return 0
  _BZ_D_INTENTADO=1
  _bz_run 15 gh -R "$proj" pr list --state merged --limit "$(_bz_limite)" \
    --json headRefName,headRefOid --jq '.[] | "\(.headRefName)\t\(.headRefOid)"' \
    >>"$_BZ_PRCACHE_FILE" 2>/dev/null
}
_bz_intentar_glab() {  # $1=ROOT $2=proj — apéndice al cache si glab está disponible
  local ROOT="$1" proj="$2"
  command -v glab >/dev/null 2>&1 || return 0
  _BZ_D_INTENTADO=1
  _bz_glab_paginar "$proj" -M "$_BZ_PRCACHE_FILE" '.[] | "\(.source_branch)\t\(.sha)"'
}
_bz_cargar_prcache() {  # puebla $_BZ_PRCACHE_FILE (líneas 'rama<TAB>sha') para ROOT, una sola vez
  local ROOT="$1" url proj host
  [ "$_BZ_PRCACHE_ROOT" = "$ROOT" ] && return 0
  _BZ_PRCACHE_ROOT="$ROOT"
  if [ -n "${CLAUDE_BZ_PRCACHE:-}" ]; then
    _BZ_PRCACHE_FILE="$CLAUDE_BZ_PRCACHE"; _BZ_D_INTENTADO=1; _BZ_D_APLICABLE=1; return 0
  fi
  _BZ_PRCACHE_FILE="$(mktemp 2>/dev/null)" || { _BZ_PRCACHE_FILE=""; return 0; }
  # el temp es NUESTRO (no el inyectado) → limpiarlo al salir del proceso; ningún caller usa trap EXIT
  _BZ_PRCACHE_OWNED="$_BZ_PRCACHE_FILE"; trap 'rm -f "$_BZ_PRCACHE_OWNED" 2>/dev/null' EXIT
  url="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
  # ¿Tiene forma de remoto de RED (scheme:// o user@host:)? Una ruta local (bare de un fixture de prueba,
  # o un remoto sin origin) NUNCA tuvo dónde mergear un PR/MR → (d) no aplica NI EN TEORÍA (no es "no se
  # pudo consultar" — no corresponde). Evita además invocar gh/glab contra un path que no es un host real.
  case "$url" in
    *://*|*@*:*) : ;;
    *) return 0 ;;
  esac
  _BZ_D_APLICABLE=1
  # path del proyecto desde el remoto (owner/repo o group/subgrupo/proyecto) → -R, sin `cd` (un `cd`
  # dispararía un hook chpwd del shell que contaminaría el cache; -R es además más robusto).
  proj="$(printf '%s' "$url" | sed -E 's#^[a-z]+://[^/]+/##; s#^[^@]+@[^:]+:##; s#\.git$##')"
  [ -n "$proj" ] || return 0
  # Clasificar por el HOST real de la URL, no por una subcadena de la URL ENTERA: un proyecto como
  # `git@gitlab.com:grupo/github-tools.git` matchearía *github* por el PATH y elegiría el CLI equivocado.
  # Con host self-hosted/desconocido: probar lo que haya instalado en vez de rendirse.
  host="$(printf '%s' "$url" | sed -E 's#^[a-z]+://##; s#^[^@]+@##; s#[:/].*$##')"
  case "$host" in
    github.com|*.github.com) _bz_intentar_gh "$ROOT" "$proj" ;;
    gitlab.com|*.gitlab.com) _bz_intentar_glab "$ROOT" "$proj" ;;
    *) _bz_intentar_gh "$ROOT" "$proj"; _bz_intentar_glab "$ROOT" "$proj" ;;
  esac
  return 0
}
# bz_pr_mergeado ROOT BR → 0 si el PR/MR de BR se mergeó y su head CONTIENE el tip actual de BR (todos sus
# commits integrados). Si BR trae commits MÁS ALLÁ del head mergeado (trabajo post-merge) → 1 (conservar).
# El 3er argumento (opcional) es el REF a contener — por defecto la propia rama local. Existe para que la
# pasada de ramas REMOTAS sin contraparte local pueda preguntar por el PR de `feat/x` (así se llama en el
# foro) evaluando el containment sobre `origin/feat/x` (el único ref que existe aquí).
bz_pr_mergeado() {
  local ROOT="$1" br="$2" ref="${3:-$2}" oid
  _bz_cargar_prcache "$ROOT"
  [ -n "$_BZ_PRCACHE_FILE" ] && [ -s "$_BZ_PRCACHE_FILE" ] || return 1
  oid="$(awk -F'\t' -v b="$br" '$1==b{print $2; exit}' "$_BZ_PRCACHE_FILE" 2>/dev/null)"
  [ -n "$oid" ] || return 1
  git -C "$ROOT" merge-base --is-ancestor "$ref" "$oid" 2>/dev/null   # tip ⊆ head mergeado → integrada
}

# --- Estado del PR/MR de una rama — SOLO para el DETECTOR DE REPRESA, jamás para decidir un borrado ---
# `bz_pr_mergeado` consulta únicamente `--state merged`, así que un PR CERRADO SIN MERGEAR es indistinguible
# de "nunca hubo PR" — ambos se conservan mudos para siempre. Y la transición "rama pusheada → PR abierto"
# no la vigila NADIE: es la clase entera de trabajo represado.
# Esta consulta alimenta el REPORTE, nunca una decisión destructiva, así que su fallo no puede hacer daño:
# sin gh/glab, sin red o con host no reconocido devuelve DESCONOCIDO y el reporte lo dice tal cual.
# TEST: CLAUDE_BZ_STCACHE=<archivo con líneas 'rama<TAB>ESTADO<TAB>id'> inyecta el mapa sin red.
_BZ_STCACHE_FILE=""; _BZ_STCACHE_ROOT=""; _BZ_ST_OK=0
_bz_cargar_stcache() {
  local ROOT="$1" url proj host
  [ "$_BZ_STCACHE_ROOT" = "$ROOT" ] && return 0
  _BZ_STCACHE_ROOT="$ROOT"
  if [ -n "${CLAUDE_BZ_STCACHE:-}" ]; then
    _BZ_STCACHE_FILE="$CLAUDE_BZ_STCACHE"; _BZ_ST_OK=1; return 0
  fi
  _BZ_STCACHE_FILE="$(mktemp 2>/dev/null)" || { _BZ_STCACHE_FILE=""; return 0; }
  url="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
  case "$url" in *://*|*@*:*) : ;; *) return 0 ;; esac
  proj="$(printf '%s' "$url" | sed -E 's#^[a-z]+://[^/]+/##; s#^[^@]+@[^:]+:##; s#\.git$##')"
  [ -n "$proj" ] || return 0
  host="$(printf '%s' "$url" | sed -E 's#^[a-z]+://##; s#^[^@]+@##; s#[:/].*$##')"
  case "$host" in
    gitlab.com|*.gitlab.com) : ;;
    *) if command -v gh >/dev/null 2>&1; then
         _bz_run 15 gh -R "$proj" pr list --state all --limit "$(_bz_limite)" \
           --json headRefName,state,number --jq '.[] | "\(.headRefName)\t\(.state)\t\(.number)"' \
           >>"$_BZ_STCACHE_FILE" 2>/dev/null && _BZ_ST_OK=1
       fi ;;
  esac
  case "$host" in
    github.com|*.github.com) : ;;
    *) if command -v glab >/dev/null 2>&1; then
         _bz_glab_paginar "$proj" -A "$_BZ_STCACHE_FILE" '.[] | "\(.source_branch)\t\(.state)\t\(.iid)"' \
           && _BZ_ST_OK=1
       fi ;;
  esac
  return 0
}
# bz_pr_estado ROOT BR → "SIN PR" | "PR #n ABIERTO" | "PR #n CERRADO sin merge" | "PR #n MERGEADO" |
# "estado del PR desconocido". Nunca falla, nunca bloquea: lo peor que dice es que no pudo averiguarlo.
bz_pr_estado() {
  local ROOT="$1" br="$2" st
  _bz_cargar_stcache "$ROOT"
  { [ "$_BZ_ST_OK" = 1 ] && [ -n "$_BZ_STCACHE_FILE" ]; } || { printf 'estado del PR desconocido (no se pudo consultar el foro)'; return 0; }
  st="$(awk -F'\t' -v b="$br" '$1==b{print $2"|"$3; exit}' "$_BZ_STCACHE_FILE" 2>/dev/null)"
  [ -n "$st" ] || { printf 'SIN PR'; return 0; }
  case "${st%%|*}" in
    OPEN|opened|locked) printf 'PR #%s ABIERTO' "${st##*|}" ;;
    CLOSED|closed)      printf 'PR #%s CERRADO sin merge' "${st##*|}" ;;
    MERGED|merged)      printf 'PR #%s MERGEADO' "${st##*|}" ;;
    *)                  printf 'estado del PR desconocido (no se pudo consultar el foro)' ;;
  esac
}

# bz_remota_integrada ROOT BR REF BASEREF → 0 si la rama REMOTA REF (que NO tiene contraparte local) ya
# está integrada a BASEREF. Motivo en $BZ_RRAZON (a|e|d|c|vivo).
#
# Admite SOLO las señales (a)/(e)/(d)/(c). La señal (b)
# —"la remota ya no existe"— NO aplica aquí: su premisa es justamente lo contrario de lo que estamos
# evaluando (esta rama existe EN el remoto), así que aplicarla inventaría zombies por construcción.
# Todas las señales admitidas son POSITIVOS squash-safe: prueban que el contenido YA está en la base, no
# que "no encontramos rastro". `git cherry` se usa solo en su positivo (ningún '+'), nunca en negativo —
# bajo squash multi-commit su '+' no prueba nada.
BZ_RRAZON=""
bz_remota_integrada() {
  local ROOT="$1" br="$2" ref="$3" baseref="$4" cherry _sq_ct _ref_ct
  BZ_RRAZON=""
  git -C "$ROOT" merge-base --is-ancestor "$ref" "$baseref" 2>/dev/null && { BZ_RRAZON=a; return 0; }   # (a)
  # (e) ACOTADA: el pie "Rama: <br>" en BASEREF no prueba que el tip REMOTO actual esté contenido —
  # una rama remota reusada tras su squash avanzó y (e) la borraría. Solo vale si REF no trae nada más nuevo
  # que el squash que la nombra (committer-date); si no se puede fechar, conservador: NO (e) → cae a (d),
  # cuyo containment sí re-chequea el tip remoto. Dirección segura: solo RETIRA falsos "integrada".
  if _sq_ct=$(_bz_squash_ct "$ROOT" "$br" "$baseref") && [ -n "$_sq_ct" ]; then
    _ref_ct=$(git -C "$ROOT" log --format='%ct' "$ref" --not "$baseref" 2>/dev/null | sort -nr | head -1)
    if [ -z "$_ref_ct" ] || [ "$_ref_ct" -le "$_sq_ct" ]; then BZ_RRAZON=e; return 0; fi
  fi
  bz_pr_mergeado "$ROOT" "$br" "$ref" && { BZ_RRAZON=d; return 0; }                                      # (d)
  cherry=$(git -C "$ROOT" cherry "$baseref" "$ref" 2>/dev/null)                                          # (c)
  if [ -n "$cherry" ] && ! printf '%s\n' "$cherry" | grep -q '^+'; then BZ_RRAZON=c; return 0; fi
  BZ_RRAZON=vivo; return 1
}

# bz_es_zombie ROOT BR BASE [MODO] → 0 si BR ya está integrada a BASE (zombie), 1 si conservar. MODO="barrido"
# (lo pasan limpiar-ramas/worktrees; proteger-arbol NO) activa la señal (p). Deja el MOTIVO en
# $BZ_RAZON: a=ancestro · e=squash con "Rama:" en el log · d=PR/MR mergeado · c=cherry patch-equivalente ·
# p=PRESENCIA por contenido (merge-tree da el árbol de base; SOLO en modo=barrido; red para lo mergeado
# DENTRO de una contenedora sin traza propia) · t=TRANSITIVA (un salto BR→X→BASE) · r=integrada en la base
# REMOTA (origin/<base> adelantada; su trabajo ya vive en el remoto) · b=remota borrada sin commits propios · vivo=commits propios
# confirmados (con o sin remota) · indeterminado=había '+' en git cherry pero NO se pudo consultar el host
# para descartar un squash-multi ya mergeado (la acción es conservar igual, pero el reporte no debe
# afirmar "vivo" con certeza).
BZ_RAZON=""

# _bz_squash_ct ROOT BR BASE → imprime el committer-date (epoch) del commit de squash MÁS NUEVO en BASE cuyo
# mensaje trae la línea EXACTA "Rama: <br>" (el pie de trazabilidad del equipo); vacío + return 1 si no hay.
# Lo usa (e) para ACOTARSE: una rama REUSADA tras su squash (commits nuevos encima) no debe darse por
# integrada solo porque el pie "Rama:" siga en la base. `-F --grep` filtra server-side y devuelve los
# commits de nuevo-a-viejo; el 1er match línea-exacta ES el más nuevo (un "Rama: <br>-otra" por subcadena se
# descarta con el grep -qxF por-commit y la búsqueda sigue con el siguiente candidato).
_bz_squash_ct() {
  local ROOT="$1" br="$2" base="$3" h
  while IFS= read -r h; do
    [ -z "$h" ] && continue
    if git -C "$ROOT" log -1 --format='%B' "$h" 2>/dev/null | grep -qxF "Rama: $br"; then
      git -C "$ROOT" log -1 --format='%ct' "$h" 2>/dev/null
      return 0
    fi
  done < <(git -C "$ROOT" log --format='%H' -F --grep="Rama: $br" "$base" 2>/dev/null)
  return 1
}

# (p) PRESENCIA POR CONTENIDO — SEÑAL DEL BARRIDO (modo=barrido), NUNCA de proteger-arbol. Red para lo YA
# mergeado SIN traza propia: una rama que entró DENTRO de una contenedora (épica/integración) cuyo squash
# nombra SOLO la contenedora no es ancestro, no tiene su `Rama:`, no tiene PR propio y `git cherry` no la
# empareja → (a)/(e)/(d)/(c) fallan aunque su CONTENIDO esté 100% en la base (medido 2026-10-22, 19 ramas).
# Señal: existe un commit C en la historia first-parent de BASE donde fusionar C con BR da el MISMO ÁRBOL que C
# ⇒ EN ESE MOMENTO BR no aportaba NADA que no estuviera ya en C (entró íntegra ahí). Probar SOLO contra la PUNTA
# de BASE falla cuando BASE evolucionó y TOCÓ los mismos archivos tras integrar BR (merge-tree conflictúa → exit≠0):
# ahí BR SÍ entró, pero la punta ya no lo refleja (medido 2026-10-22: contra la punta solo cazaba 2 de 19). Por eso
# se recorre la historia first-parent desde la PUNTA hacia atrás, acotado a los $CLAUDE_BZ_PRESENCIA_MAX (def 200)
# commits más recientes, cortando en el merge-base (antes de él BR no pudo entrar). Las ramas SUPERADAS por
# reimplementación quedan conservadas: su árbol nunca fue un no-op contra NINGÚN commit histórico. Usa
# `git merge-tree --write-tree` (git ≥2.38; su 1ª línea en un merge LIMPIO es el OID del árbol); subcomando ausente
# o merge que CONFLICTÚA en ese commit → ese commit NO cuenta (se sigue con el siguiente). Compara ÁRBOLES → squash-
# safe. SOLO en el BARRIDO (limpiar-ramas/worktrees, que pregunta "¿el trabajo está integrado, seguro borrar?"):
# proteger-arbol pregunta OTRA cosa ("¿orfanaría un COMMIT sin pushear?", p.ej. un commit VACÍO con árbol
# idéntico SÍ se orfana) → NO recibe modo=barrido y (p) queda APAGADA ahí. Un llamador nuevo sin el modo
# tampoco la hereda (fail-safe).
_bz_presencia_contenido() {
  local ROOT="$1" br="$2" base="$3" c c_tree mt_tree n=0 mb max="${CLAUDE_BZ_PRESENCIA_MAX:-200}"
  mb=$(git -C "$ROOT" merge-base "$base" "$br" 2>/dev/null)
  while IFS= read -r c; do
    [ -z "$c" ] && continue
    [ -n "$mb" ] && [ "$c" = "$mb" ] && break        # antes del merge-base BR no pudo entrar
    c_tree=$(git -C "$ROOT" rev-parse --verify -q "$c^{tree}" 2>/dev/null) || { n=$((n+1)); [ "$n" -ge "$max" ] && break; continue; }
    if mt_tree=$(git -C "$ROOT" merge-tree --write-tree "$c" "$br" 2>/dev/null); then   # exit≠0 (conflicto/git viejo) → ese commit NO cuenta
      mt_tree=$(printf '%s\n' "$mt_tree" | head -1)
      [ -n "$mt_tree" ] && [ "$mt_tree" = "$c_tree" ] && return 0
    fi
    n=$((n+1)); [ "$n" -ge "$max" ] && break
  done < <(git -C "$ROOT" rev-list --first-parent --max-count="$max" "$base" 2>/dev/null)
  return 1
}

# _bz_integrada_directa ROOT BR BASE [MODO] → 0 si BR está integrada a BASE por una señal POSITIVA DIRECTA
# (a ancestro · e "Rama:" en el squash · d PR/MR mergeado · c patch-equivalente sin '+' · p presencia por
# contenido SOLO si MODO=barrido). Sin (b)/upstream ni transitiva. Fija $BZ_RAZON con la letra al acertar (no
# la toca al fallar). La comparten bz_es_zombie (BR→BASE) y el carril transitivo (t) para el 2º eslabón X→BASE
# — UNA sola definición de "las señales de siempre", sin divergencia. MODO lo FIJA el llamador (el barrido pasa
# "barrido"; proteger-arbol no pasa nada → (p) off).
_bz_integrada_directa() {
  local ROOT="$1" br="$2" base="$3" modo="${4:-}" cherry _sq_ct _br_ct
  git -C "$ROOT" merge-base --is-ancestor "$br" "$base" 2>/dev/null && { BZ_RAZON=a; return 0; }  # (a)
  # (e) ACOTADA: el pie "Rama: <br>" está en la base, PERO solo vale si BR no avanzó tras ese squash
  # — si no, (e) borraría los commits nuevos (reúso de la rama). Compara el committer-date del squash que la
  # nombra vs el del commit MÁS NUEVO de BR ausente de BASE: si BR trae algo más nuevo → NO (e) (cae a (d),
  # cuyo containment sí re-chequea el tip, y de ahí a (b)/conservar). Si no se puede fechar el squash →
  # conservador: NO (e). Dirección SEGURA: (e) solo RETIRA falsos "integrada", nunca agrega.
  if _sq_ct=$(_bz_squash_ct "$ROOT" "$br" "$base") && [ -n "$_sq_ct" ]; then
    _br_ct=$(git -C "$ROOT" log --format='%ct' "$br" --not "$base" 2>/dev/null | sort -nr | head -1)
    if [ -z "$_br_ct" ] || [ "$_br_ct" -le "$_sq_ct" ]; then BZ_RAZON=e; return 0; fi                # (e offline)
  fi
  bz_pr_mergeado "$ROOT" "$br" && { BZ_RAZON=d; return 0; }                                          # (d)
  cherry=$(git -C "$ROOT" cherry "$base" "$br" 2>/dev/null)                                          # (c)
  if [ -n "$cherry" ] && ! printf '%s\n' "$cherry" | grep -q '^+'; then BZ_RAZON=c; return 0; fi
  [ "$modo" = barrido ] && _bz_presencia_contenido "$ROOT" "$br" "$base" && { BZ_RAZON=p; return 0; } # (p) solo en el barrido
  return 1
}

# _bz_base_remota ROOT BASE → imprime el ref remote-tracking de BASE (p.ej. origin/develop) si existe, vacío
# si no. SOLO lee refs LOCALES (nada de red): un `git fetch` previo pudo dejar origin/<base> por delante de
# la <base> local. Prefiere el upstream configurado de la rama base; si no hay, prueba origin/<base>.
_bz_base_remota() {
  local ROOT="$1" base="$2" up
  up=$(git -C "$ROOT" rev-parse --abbrev-ref --verify -q "${base}@{upstream}" 2>/dev/null)
  if [ -n "$up" ] && git -C "$ROOT" rev-parse --verify -q "refs/remotes/$up" >/dev/null 2>&1; then
    printf '%s' "$up"; return 0
  fi
  git -C "$ROOT" rev-parse --verify -q "refs/remotes/origin/$base" >/dev/null 2>&1 && { printf 'origin/%s' "$base"; return 0; }
  return 1
}

# _bz_integrada ROOT BR BASE → 0 si BR está integrada a BASE por señal DIRECTA (a/e/d/c) o TRANSITIVA acotada
# de un salto (BR→X→BASE). Fija $BZ_RAZON. NO incluye (b)/upstream (eso lo decide el tail de bz_es_zombie).
# UNA definición de "integrada", aplicada tanto a la base LOCAL como a la base REMOTA (origin/<base>, señal r).
#
# (t) TRANSITIVA ACOTADA — UN SOLO salto BR → X → BASE, con evidencia POSITIVA en cada eslabón. Cierra el
# hueco del flujo mini-develop: BR se mergeó a una mini X (BR queda ANCESTRO de X) y X se SQUASHEÓ a BASE
# → los commits de BR no quedan ni de ancestro ni patch-equivalentes contra BASE y (a)/(c)/(e) fallan.
#   eslabón 1 (BR→X): X CONTIENE a BR por ancestro (`git branch --contains BR`; POSITIVO, squash-safe).
#   eslabón 2 (X→BASE): X integrada por las señales DIRECTAS de siempre (_bz_integrada_directa X BASE).
# Ambos → BR entró transitivamente (razón t). NADA se afloja: un commit de BR MÁS ALLÁ del merge a X
# rompe el ancestro → X no aparece en --contains → se cae al carril (b)/vivo de abajo (FRENA como hoy).
# Un solo salto por diseño: el eslabón 2 usa SOLO señales directas, nunca otra transitiva → sin cadenas
# ni recursión. X debe contener a BR como ancestro ESTRICTO: se excluye BR, BASE y toda rama que apunte
# al MISMO commit que BR — un hermano en el mismo tip NO es un intermediario que integró a BR (su propio
# PR/señal no debe volver zombie a BR; eso lo conserva el carril (b)/vivo).
_bz_integrada() {
  local ROOT="$1" br="$2" base="$3" modo="${4:-}" x brrev xrev
  _bz_integrada_directa "$ROOT" "$br" "$base" "$modo" && return 0   # (a)(e)(d)(c)(p si barrido) directas BR→BASE
  brrev=$(git -C "$ROOT" rev-parse --verify -q "$br^{commit}" 2>/dev/null)
  while IFS= read -r x; do
    [ -z "$x" ] && continue
    { [ "$x" = "$br" ] || [ "$x" = "$base" ]; } && continue
    xrev=$(git -C "$ROOT" rev-parse --verify -q "$x^{commit}" 2>/dev/null)
    [ -n "$brrev" ] && [ "$xrev" = "$brrev" ] && continue
    if _bz_integrada_directa "$ROOT" "$x" "$base" "$modo"; then BZ_RAZON=t; return 0; fi
  done < <(git -C "$ROOT" branch --contains "$br" --format='%(refname:short)' 2>/dev/null)
  return 1
}

bz_es_zombie() {
  local ROOT="$1" br="$2" base="$3" modo="${4:-}" up cherry baserem
  BZ_RAZON=""
  _bz_integrada "$ROOT" "$br" "$base" "$modo" && return 0   # (a)(e)(d)(c)(p si barrido) o (t) transitiva contra base LOCAL
  # (r) BASE REMOTA ADELANTADA — la <base> LOCAL puede estar atrasada respecto al remoto: hiciste `git fetch`
  # (origin/<base> ya trae el squash) pero NO `git pull` a tu <base> local. El patrón `git pull --ff-only &&
  # git branch -D <rama>` lo dispara porque el guard corre ANTES de que el pull adelante la base local. Si BR
  # está integrada en origin/<base>, su trabajo YA vive en el remoto → un `git branch -D` LOCAL no pierde
  # nada. SOLO lee refs locales (sin red); si origin/<base> no existe o también está atrasado, no matchea →
  # cae al tail (FRENA como hoy). NADA se afloja: es señal POSITIVA (el trabajo está, verificado, en la base
  # remota). Misma definición de "integrada" (directa+transitiva) que contra la base local.
  if baserem=$(_bz_base_remota "$ROOT" "$base") && [ -n "$baserem" ] && _bz_integrada "$ROOT" "$br" "$baserem" "$modo"; then
    BZ_RAZON=r; return 0
  fi
  # (b) remota borrada — NUNCA a ciegas. La ausencia de la remota NO prueba que la rama esté integrada
  # (pudo borrarse por rename/limpieza manual, o traer commits VIVOS post-merge sin pushear). Si la rama
  # tiene commits PROPIOS no equivalentes a la base (git cherry marcó algún '+'), se CONSERVA aunque su
  # remota ya no exista: el `branch -D` de los barredores es irreversible y borraría ese trabajo. Antes
  # (b) declaraba zombie sin re-chequear commits únicos → PÉRDIDA DE DATOS. El header
  # promete "conserva ante duda": aquí se hace cumplir — solo una rama SIN trabajo único cae a (b).
  # (recomputar cherry aquí: (c) vive ahora dentro de _bz_integrada_directa como var LOCAL, así que el
  #  carril (b)/indeterminado necesita su PROPIA pasada de git cherry sobre BR.)
  cherry=$(git -C "$ROOT" cherry "$base" "$br" 2>/dev/null)
  if printf '%s\n' "$cherry" | grep -q '^+'; then
    # '+' pudo ser un squash-multi YA mergeado que (d) habría cazado. Si (d) SÍ se pudo consultar
    # (host reachable, este branch simplemente no apareció como mergeado) → confianza real: vivo. Si NO
    # HAY host que consultar (nunca hubo remoto de red, p. ej. un fixture con origin local) → también vivo
    # con certeza (no es indeterminado; no es "no se pudo", es "no corresponde"). Solo cuando HABÍA un host
    # de red configurado y NO se pudo consultar (gh/glab ausentes, error) → no lo sabemos: indeterminado.
    if [ "$_BZ_D_INTENTADO" = 1 ] || [ "$_BZ_D_APLICABLE" != 1 ]; then BZ_RAZON=vivo; else BZ_RAZON=indeterminado; fi
    return 1
  fi
  up=$(git -C "$ROOT" rev-parse --abbrev-ref "$br@{upstream}" 2>/dev/null) || { BZ_RAZON=vivo; return 1; }  # nunca pusheada → conservar
  if git -C "$ROOT" ls-remote --exit-code --heads "${up%%/*}" "${up#*/}" >/dev/null 2>&1; then
    BZ_RAZON=vivo; return 1   # remota existe, sin commits propios pero tampoco huella de integración → conservar
  else
    BZ_RAZON=b; return 0      # (b) remota borrada Y sin commits únicos → zombie
  fi
}

# bz_protegida BR BASE [ACTUAL] [WT_RAMAS] → 0 si BR NUNCA debe tocarse destructivamente, pase lo que
# pase (la base de integración, la rama actual, develop/main, cualquier mini-develop Develop*, una mini de
# TEMA (epic/* epic-* integracion/* integracion-* — "valen como minis de tema con las mismas libertades",
# norma de git) o guardada a propósito keep/*, o checked-out en CUALQUIER worktree — WT_RAMAS son sus
# nombres, uno por línea).
# 1 si no. Deja la RAZÓN en $BZ_PROT_RAZON: base_actual | convencion | worktree.
#
# UNA sola definición que consumen los DOS barredores (limpiar.sh ramas y limpiar.sh worktrees), igual que
# bz_es_zombie: sin ella, un barredor sin esta protección borraría el worktree de una mini-develop con
# trabajo sin commitear o marcaría `keep/*` como zombie.
BZ_PROT_RAZON=""
bz_protegida() {
  local br="$1" base="$2" actual="${3:-}" wt_ramas="${4:-}"
  BZ_PROT_RAZON=""
  if [ "$br" = "$base" ] || { [ -n "$actual" ] && [ "$br" = "$actual" ]; }; then
    BZ_PROT_RAZON=base_actual; return 0
  fi
  case "$br" in
    develop|main|Develop*|keep/*|epic/*|epic-*|integracion/*|integracion-*) BZ_PROT_RAZON=convencion; return 0 ;;
  esac
  if [ -n "$wt_ramas" ] && printf '%s\n' "$wt_ramas" | grep -qxF "$br"; then
    BZ_PROT_RAZON=worktree; return 0
  fi
  return 1
}
