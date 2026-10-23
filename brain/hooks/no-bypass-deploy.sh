#!/usr/bin/env bash
# no-bypass-deploy.sh — PreToolUse/Bash: AVISA (NO bloquea) cuando se corre A MANO el instalador/deploy
# de un proyecto en vez de su HERRAMIENTA OFICIAL. Mecaniza la norma "Actualiza por la herramienta real"
# (B1): el cerebro/widget se actualiza con el WIDGET (su updater ⬆), NUNCA corriendo install-brain.sh /
# install.sh a pelo — generalizado a CUALQUIER install/deploy del proyecto (deploy.sh, publish, make
# install/deploy, just deploy). Correr el script crudo se salta backup/escritura-atómica/sello-de-versión/
# re-cableado/verificación que la herramienta orquesta → deja media instalación o una versión que MIENTE.
#
# FAIL-SAFE: solo AVISA (additionalContext), jamás bloquea; ante duda NO dispara. Precisión: NO dispara
# en --dry-run/-n/--help/-h (no mutan), NI en CI (ahí el pipeline ES la herramienta), NI sobre una
# MENCIÓN entrecomillada del instalador (dato de un grep/echo/mensaje). Fail-open sin jq.
#
# dedupe doble-cableado (tier both): si soy la copia del REPO y la copia GLOBAL existe, cedo (evita el
# aviso DUPLICADO). No-debilitante: sigue avisando 1×.
_cfgh="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks"; case "$0" in "$_cfgh/"*) : ;; *) [ -f "$_cfgh/$(basename "$0")" ] && exit 0 ;; esac

command -v jq >/dev/null 2>&1 || exit 0

# CI: el pipeline ES la herramienta oficial → nunca avisamos ahí.
if [ -n "${CI:-}" ] || [ -n "${GITLAB_CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${BUILD_ID:-}" ]; then
  exit 0
fi

input=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# PRE-FILTRO barato (capa determinista, en-proceso): si el comando NO menciona NINGÚN gatillo posible
# (install/deploy/publish/make/just — 'uninstall-brain' contiene 'install'), no puede disparar → early-exit
# ANTES de gastar sed/tr/grep (~5 subprocesos) en el camino COMÚN. Conservador: filtra sobre el cmd CRUDO
# (superset de lo que verían los regex tras des-entrecomillar) → JAMÁS salta un caso que sí debería avisar;
# a lo más CONTINÚA de más (p. ej. 'deploy' dentro de comillas), y ahí el chequeo real decide. nocasematch
# (bash≥3.1, macOS-safe) para cubrir INSTALL/Deploy/etc. sin re-lowercasear aquí.
shopt -s nocasematch 2>/dev/null
case "$cmd" in *install*|*deploy*|*publish*|*make*|*just*|*kubectl*|*helm*) : ;; *) exit 0 ;; esac
shopt -u nocasematch 2>/dev/null

# Quita literales entrecomillados → una MENCIÓN del instalador (grep/echo/doc) no dispara. Unifica con la lib compartida (ejecutor/heredoc-aware: un `bash -c "install.sh"` o un
# heredoc que alimenta un intérprete con el instalador adentro ya no evade este aviso).
# shellcheck source=analizar-comando-git.sh
_ACGLIB="$(dirname "$0")/analizar-comando-git.sh"
[ -f "$_ACGLIB" ] && . "$_ACGLIB"
if command -v acg_despoja_comillas >/dev/null 2>&1; then
  unquoted=$(acg_despoja_comillas "$cmd")
else
  unquoted=$(printf '%s' "$cmd" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g")
fi

low=$(printf '%s' "$unquoted" | tr 'A-Z' 'a-z')

# Excepciones que NO mutan: --help / --dry-run[=valor] (inspección, no deploy) → calla. NO se excluye el
# bare -h (ambiguo: en muchos scripts es --host, no --help → silenciaba un deploy real `deploy.sh -h host`).
printf '%s' "$unquoted" | grep -qE '(^|[[:space:]])(--help|--dry-run(=[A-Za-z]+)?)([[:space:]]|$)' && exit 0
# -n como dry-run (make/POSIX), SALVO cuando el comando es kubectl (ahí -n = namespace, no dry-run → no calla).
if ! printf '%s' "$low" | grep -qE '(^|[^[:alnum:]_])kubectl([[:space:]]|$)'; then
  printf '%s' "$unquoted" | grep -qE '(^|[[:space:]])-n([[:space:]]|$)' && exit 0
fi

# ── Detección de EJECUCIÓN (no edición/cat) del instalador/deploy ──
# (1) BRAIN: install-brain / uninstall-brain (.sh|.ps1) corrido a mano → la vía oficial es el WIDGET.
# (2) GENÉRICO: un install/deploy/publish .sh|.ps1 ejecutado, o make/just con target install|deploy.
# El basename debe aparecer en contexto de EJECUCIÓN: tras bash/sh/zsh/pwsh, tras ./, o con ruta /…/.
# PREFIJO de EJECUCIÓN (no una mención suelta): inicio de comando, tras un separador (;&|`+espacios),
# o tras un runner (bash/sh/zsh/pwsh -file). Un espacio PELÓN NO cuenta → así `grep install-brain.sh`
# (el nombre como ARGUMENTO, no ejecución) NO dispara.
# M1: '-c[[:space:]]+' se agrega porque acg_despoja_comillas (arriba) ya REINYECTA el contenido de
# `eval "…"` / `bash|sh|zsh -c "…"` sin comillas — el texto que llega aquí para un `bash -c
# "./install-brain.sh"` es literalmente "bash -c ./install-brain.sh"; sin esta alternativa el propio
# _pfx no reconocía "-c" como prefijo de EJECUCIÓN y el aviso se perdía tras la reinyección.
# BOUNDARY (_bnd): un runner (bash/sh/zsh/pwsh/eval/-c) solo cuenta como EJECUCIÓN si es un TOKEN ENTERO,
# no el SUFIJO de un nombre de archivo. 'bootstrap.sh macos/install.sh' traía un 'sh ' (la cola de
# bootstrap.sh) que el prefijo viejo leía como el intérprete `sh` → FP sobre `ls`/`git diff` que solo
# NOMBRAN los scripts (corpus L66/L105). _bnd exige que antes del runner NO haya un char de nombre
# ([:alnum:]._): así '.sh' (precedido por '.') ya no dispara, pero '^bash', ' bash', '(bash', '/bin/bash' sí.
_bnd='(^|[^[:alnum:]._])'
# POSICIÓN DE COMANDO: inicio o tras separador, seguido de una cadena opcional de env-assignments
# (VAR=val) y/o wrappers (sudo/nohup/env/command/exec/time) que dejan el cursor en un comando fresco.
# Así `sudo ./install.sh`, `nohup ./install.sh` y `FOO=bar ./install.sh` ya cuentan como EJECUCIÓN.
_envwrap="(^|[;&|\`][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+|(sudo|nohup|env|command|exec|time)[[:space:]]+)+"
# RUNNERS que ejecutan un script: bash/sh/zsh con flags cortos opcionales entre el runner y el script
# (`bash -x install.sh`), eval, source, '.' (ejecutan en el shell actual), pwsh -file, y -c (ver M1).
_pfx="(^|[;&|\`][[:space:]]*|${_envwrap}|${_bnd}(bash|sh|zsh)([[:space:]]+-[A-Za-z]+)*[[:space:]]+|${_bnd}(eval|source|\\.)[[:space:]]+|${_bnd}pwsh[[:space:]]+-file[[:space:]]+|${_bnd}-c[[:space:]]+)"
# RUTA opcional entre el prefijo y el basename: solo cuenta si la ruta COMPLETA arranca justo tras el
# prefijo de arriba (ejecución real: ./foo.sh, /abs/path/foo.sh, bash brain/foo.sh) — antes bastaba un
# "/" SUELTO pegado al basename como prefijo, y eso disparaba sobre cualquier MENCIÓN con subcarpeta
# como ARGUMENTO de otro comando ("git add brain/install-brain.sh", "git log -- scripts/deploy.sh",
# "git show HEAD~1:brain/x.sh" → ahí el "/" queda pegado al basename pero el TOKEN no arranca en
# posición de ejecución). Exigir que la ruta entera nazca justo tras el prefijo cierra ese hueco sin
# tocar la detección real (bash/./ /abs siguen exigiendo el prefijo correcto antes del primer tramo).
_path='(\./|/)?([A-Za-z0-9_.-]+/)*'
# TERMINADOR del basename: espacio, fin, separador/operador o CIERRE de subshell/cmd-subst. Incluye ')' y '`'
# porque `(bash ./install.sh)` / `$(bash ./install.sh)` cierran el token con ')' pegado al '.sh' (sin esto
# el subshell SIN espacio antes del ')' CALLABA — BAJO heredado; `( bash … )` con espacios ya avisaba).
_end='([[:space:]]|$|[;&|`)])'
brain_re="${_pfx}${_path}(install-brain|uninstall-brain)\\.(sh|ps1)${_end}"
gen_re="${_pfx}${_path}(install|deploy|publish)\\.(sh|ps1)${_end}"
mk_re="(^|[;&|\`][[:space:]]*)(make|just)[[:space:]]+(install|deploy|publish)${_end}"
# helm/kubectl corridos a mano (la norma los nombra como deploy-a-pelo). Solo las formas MUTANTES: helm
# install|upgrade|rollback|uninstall, y kubectl apply|create|replace|delete|patch DIRIGIDO POR MANIFIESTO
# (-f/--filename/-k/--kustomize = aplicar un artefacto de deploy a mano) — NO los verbos de lectura
# (get/describe/list). --dry-run ya se excluyó arriba. Admite el wrapper sudo/env antes del binario.
_hkpfx="(^|[;&|\`][[:space:]]*|(sudo|nohup|env|command|exec|time)[[:space:]]+)"
helm_re="${_hkpfx}helm[[:space:]]+(install|upgrade|rollback|uninstall)([[:space:]]|$)"
kubectl_re="${_hkpfx}kubectl[[:space:]]+(apply|create|replace|delete|patch)([[:space:]]|$).*(-f|--filename|-k|--kustomize)([[:space:]]|=|$)"

msg=""
if printf '%s' "$low" | grep -qE "$brain_re"; then
  msg="AVISO (no-bypass-deploy): estás corriendo el instalador del CEREBRO a mano (install-brain/uninstall-brain). La vía OFICIAL para actualizar el cerebro es el WIDGET (su updater ⬆: backup + escritura atómica + re-cableado + sello de versión + verificación). Correrlo crudo se salta esos pasos y puede dejar media instalación o una versión que MIENTE sobre lo instalado. Si es un bootstrap/depuración deliberada, ignora este aviso."
elif printf '%s' "$low" | grep -qE "$gen_re" || printf '%s' "$low" | grep -qE "$mk_re"; then
  msg="AVISO (no-bypass-deploy): parece que corres un instalador/deploy a mano (install/deploy/publish). Si el proyecto tiene una vía OFICIAL para aplicar el cambio (script de release, pipeline, herramienta dedicada), úsala en vez del script crudo — se salta pasos que la herramienta orquesta (backup, atomicidad, versión, verificación). Si es deliberado (o no hay herramienta oficial), ignora este aviso."
elif printf '%s' "$low" | grep -qE "$helm_re" || printf '%s' "$low" | grep -qE "$kubectl_re"; then
  msg="AVISO (no-bypass-deploy): parece un deploy a mano con helm/kubectl (aplicar un release/manifiesto directo). Si el proyecto tiene una vía OFICIAL (pipeline de release, GitOps/ArgoCD, un script dedicado), úsala — el apply crudo se salta los pasos que esa herramienta orquesta (revisión, versión, rollback controlado). Si kubectl/helm ES la vía oficial aquí o es depuración deliberada, ignora este aviso."
fi

[ -z "$msg" ] && exit 0
jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
exit 0
