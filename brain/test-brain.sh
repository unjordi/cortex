#!/usr/bin/env bash
# test-brain.sh — pruebas VERSIONADAS y REPETIBLES del cerebro (claude-brain). No toca tu ~/.claude:
# todo corre contra un $HOME FALSO aislado (mktemp) que se borra al final.
#
# Cubre:
#   (a) sintaxis: `bash -n` de todos los hooks .sh + `jq empty` de todos los .json de brain/.
#   (b) gate de delegación: casos gratis / incluido / metered(overage) / metered(externo) /
#       desconocido, el ciclo gate→registrar→gate-silencioso, y la transición dentro/fuera de la
#       ventana de 5h (incluido → metered al agotarse la ventana).
#   (b5) compactación: precompact RETIRADO (ya no existe el .sh) + rehidratar-hilo inyecta/silencia
#        según exista el hilo, con gate de frescura (viejo/otra-rama → "⚠️ posiblemente OBSOLETO").
#   (c) idempotencia: install-brain.sh corrido 2× contra el $HOME falso → cada hook queda 1× en
#       settings.json y hay 1 solo bloque de normas en CLAUDE.md.
#
# NOTA anti-auto-bloqueo: este script NO escribe el literal del comando de merge de GitLab en sus
# pruebas (lo arma partido) para no disparar el guard global merge-squash-guard sobre sí mismo.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS="$SCRIPT_DIR/hooks"
INSTALLER="$SCRIPT_DIR/install-brain.sh"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  PASS: %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL: %s\n' "$1"; }

command -v jq >/dev/null 2>&1 || { echo "ERROR: se requiere jq para las pruebas"; exit 1; }

# $HOME falso aislado (se limpia al salir)
FAKEHOME="$(mktemp -d "${TMPDIR:-/tmp}/brain-test.XXXXXX")"
cleanup() { rm -rf "$FAKEHOME"; }
trap cleanup EXIT

echo "==> claude-brain test — \$HOME falso: $FAKEHOME"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (a) sintaxis: bash -n de los hooks + jq empty de los json =="
for f in "$HOOKS"/*.sh; do
  [ -e "$f" ] || continue
  if bash -n "$f" 2>/dev/null; then ok "bash -n $(basename "$f")"; else bad "bash -n $(basename "$f")"; fi
done
# también el propio instalador/desinstalador/este test
for f in "$INSTALLER" "$SCRIPT_DIR/uninstall-brain.sh" "$SCRIPT_DIR/test-brain.sh"; do
  [ -e "$f" ] || continue
  if bash -n "$f" 2>/dev/null; then ok "bash -n $(basename "$f")"; else bad "bash -n $(basename "$f")"; fi
done
while IFS= read -r j; do
  if jq empty "$j" 2>/dev/null; then ok "jq empty $(basename "$j")"; else bad "jq empty $(basename "$j")"; fi
done < <(find "$SCRIPT_DIR" -name '*.json' -type f)

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b) gate de delegación (\$HOME falso, snapshot de cuota de prueba) =="

CDIR="$FAKEHOME/.claude"
CACHE="$FAKEHOME/.cache/claude-brain"
CONS="$CDIR/delegacion-consentimiento.json"
mkdir -p "$CDIR" "$CACHE"
cp "$HOOKS/agentes-costo.json" "$CDIR/agentes-costo.json"

# escribe un state.json de prueba con el % de ventana 5h indicado (y una semanal)
write_state() {
  cat > "$CACHE/state.json" <<EOF
{
  "five_hour": { "percent": $1, "cost_usd": 2.48, "cost_cap": 45, "tokens_used": 3700000 },
  "weekly":    { "percent": 57, "cost_usd": 401,  "cost_cap": 4800 }
}
EOF
}

# corre el gate con el $HOME falso; devuelve su stdout
run_gate() {
  HOME="$FAKEHOME" XDG_CACHE_HOME="$FAKEHOME/.cache" bash "$HOOKS/delegacion-gate.sh" <<<"$1"
}
# corre el registrador (materializa el consentimiento tras un ask aprobado)
run_registrar() {
  HOME="$FAKEHOME" XDG_CACHE_HOME="$FAKEHOME/.cache" bash "$HOOKS/delegacion-registrar.sh" <<<"$1"
}
is_ask()    { printf '%s' "$1" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null 2>&1; }
is_silent() { [ -z "$(printf '%s' "$1" | tr -d '[:space:]')" ]; }

payload() { # payload <session> <subagent_type> <model>
  jq -nc --arg s "$1" --arg t "$2" --arg m "$3" \
    '{tool_name:"Task", session_id:$s, tool_input:{subagent_type:$t, model:$m}}'
}

# Casos base (sin registrar → cada uno debe PREGUNTAR en su primer encuentro)
rm -f "$CONS"; write_state 19
out="$(run_gate "$(payload S1 ollama '')")"
is_ask "$out"    && ok "gratis (local: ollama) → pregunta" || bad "gratis (local) → esperaba ask; got: $out"

out="$(run_gate "$(payload S1 '' sonnet)")"
is_ask "$out"    && ok "incluido (claude, ventana 19% < 90%) → pregunta" || bad "incluido → esperaba ask; got: $out"

write_state 99
out="$(run_gate "$(payload S1 '' sonnet)")"
is_ask "$out"    && ok "metered (claude overage, ventana 99%) → pregunta" || bad "metered overage → esperaba ask; got: $out"

out="$(run_gate "$(payload S1 '' gpt-4o)")"
is_ask "$out"    && ok "metered (API externa: gpt-4o) → pregunta" || bad "metered externo → esperaba ask; got: $out"

out="$(run_gate "$(payload S1 general-purpose '')")"
is_ask "$out"    && ok "desconocido (default token) → pregunta" || bad "desconocido → esperaba ask; got: $out"

# Un no-Task no debe incumbir al gate (silencio)
out="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | HOME="$FAKEHOME" XDG_CACHE_HOME="$FAKEHOME/.cache" bash "$HOOKS/delegacion-gate.sh")"
is_silent "$out" && ok "no-Task (Bash) → gate silencioso" || bad "no-Task → esperaba silencio; got: $out"

# Ciclo metered: gate(pregunta) → registrar → gate(silencioso) EN EL MISMO workflow
rm -f "$CONS"; write_state 99
P="$(payload WF1 '' gpt-4o)"
out="$(run_gate "$P")";      is_ask "$out"    && ok "ciclo metered · 1º gate → pregunta"        || bad "ciclo metered 1º → ask; got: $out"
run_registrar "$P"
out="$(run_gate "$P")";      is_silent "$out" && ok "ciclo metered · tras registrar → silencio" || bad "ciclo metered 2º → silencio; got: $out"
# … pero OTRO workflow (session distinta) con costo vuelve a preguntar
out="$(run_gate "$(payload WF2 '' gpt-4o)")"; is_ask "$out" && ok "ciclo metered · otro workflow → pregunta" || bad "otro workflow → ask; got: $out"

# Transición dentro/fuera de ventana: incluido (consentido por compu) → metered al agotarse
rm -f "$CONS"; write_state 19
Q="$(payload WFA '' sonnet)"
out="$(run_gate "$Q")";      is_ask "$out"    && ok "ventana · incluido 1º → pregunta"          || bad "ventana incluido 1º → ask; got: $out"
run_registrar "$Q"
out="$(run_gate "$Q")";      is_silent "$out" && ok "ventana · incluido consentido → silencio"  || bad "ventana incluido 2º → silencio; got: $out"
write_state 99   # se agota la ventana → mismo agente pasa a metered
out="$(run_gate "$Q")";      is_ask "$out"    && ok "ventana · agotada → vuelve a preguntar (metered)" || bad "ventana agotada → ask; got: $out"

# G3 — fan-out PARALELO: el 1er gate del lote pregunta; los HERMANOS (misma sesión+key, aún sin
# registrar) pasan en SILENCIO (coalescing) para gratis/incluido → mata el flood de N asks. Metered
# NO se coalesce (un fan-out de PAGO confirma cada uno: un 'no' no debe dejar correr agentes caros).
rm -f "$CONS"; rm -rf "$CDIR"/.delegacion-ask.*.lock 2>/dev/null; write_state 19
B="$(payload BATCH '' sonnet)"   # incluido (ventana 19% < 90%)
out="$(run_gate "$B")"; is_ask "$out"    && ok "G3 fan-out · 1er gate del lote → pregunta"             || bad "G3: 1er gate no preguntó; got: $out"
out="$(run_gate "$B")"; is_silent "$out" && ok "G3 fan-out · hermano del lote → silencio (coalesced)"  || bad "G3: el hermano volvió a preguntar (flood); got: $out"
rm -f "$CONS"; rm -rf "$CDIR"/.delegacion-ask.*.lock 2>/dev/null; write_state 99
M="$(payload BATCHM '' gpt-4o)"  # metered (API externa de pago)
out="$(run_gate "$M")"; is_ask "$out"    && ok "G3 · metered 1er gate → pregunta"                      || bad "G3 metered 1º → ask; got: $out"
out="$(run_gate "$M")"; is_ask "$out"    && ok "G3 · metered hermano → SIGUE preguntando (protección)" || bad "G3 metered hermano → debía seguir preguntando; got: $out"

# H6 — un ask NEGADO no persiste consentimiento (el registrar NO corre). Antes, dentro de la vieja
# ventana de 60s, el lock de coalescencia dejaba colar el reintento en SILENCIO. Ahora la ventana es
# corta (CLAUDE_DELEG_COALESCE_S): fuera de ella el lock se recicla → el reintento VUELVE a preguntar.
rm -f "$CONS"; rm -rf "$CDIR"/.delegacion-ask.*.lock 2>/dev/null; write_state 19
H6P="$(payload H6SESS '' sonnet)"   # incluido (ventana 19% < 90%)
out="$(run_gate "$H6P")"; is_ask "$out" && ok "H6 · 1er gate (usuario luego NIEGA) → pregunta" || bad "H6: 1er gate no preguntó; got: $out"
# sin registrar (= el usuario NEGÓ) + reintento FUERA de la ventana (COALESCE_S=0 recicla el lock)
out="$(HOME="$FAKEHOME" XDG_CACHE_HOME="$FAKEHOME/.cache" CLAUDE_DELEG_COALESCE_S=0 bash "$HOOKS/delegacion-gate.sh" <<<"$H6P")"
is_ask "$out" && ok "H6 · 'no' + reintento fuera de ventana → RE-pregunta (no cuela en silencio)" || bad "H6: el reintento tras negar coló en silencio; got: $out"
# y el registrar LIBERA el lock al APROBAR → la ruta feliz no deja fantasma
rm -rf "$CDIR"/.delegacion-ask.*.lock 2>/dev/null
run_gate "$H6P" >/dev/null 2>&1        # crea el lock del lote
run_registrar "$H6P"                    # aprobar → registra consentimiento + libera el lock
ls "$CDIR"/.delegacion-ask.*.lock >/dev/null 2>&1 && bad "H6: el registrar dejó el lock del lote (fantasma)" || ok "H6 · registrar libera el lock de coalescencia al aprobar (sin fantasma)"
rm -f "$CONS"; rm -rf "$CDIR"/.delegacion-ask.*.lock 2>/dev/null
write_state 19

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b1b) limite-gasto: FRENA solo con la AND (ventana agotada Y overage sin holgura) =="
write_state_lg() { cat > "$CACHE/state.json" <<EOF
{ "five_hour":{"percent":$1}, "extra_usage":{"utilization":$2,"enabled":$3} }
EOF
}
run_limite() { HOME="$FAKEHOME" XDG_CACHE_HOME="$FAKEHOME/.cache" bash "$HOOKS/limite-gasto.sh" <<<"$1"; }
is_deny()    { printf '%s' "$1" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; }
TP="$(payload WL general-purpose '')"
write_state_lg 10  100 true;  is_silent "$(run_limite "$TP")" && ok "lg: ventana fresca + overage topado → NO frena (plan cubre)"      || bad "lg: frenó con ventana fresca"
write_state_lg 100 50  true;  is_silent "$(run_limite "$TP")" && ok "lg: ventana agotada + overage con saldo → NO frena (gate pregunta)" || bad "lg: frenó teniendo saldo de overage"
write_state_lg 100 100 true;  is_deny   "$(run_limite "$TP")" && ok "lg: ventana agotada + overage topado → FRENA (sin capacidad)"      || bad "lg: NO frenó con ambos agotados"
write_state_lg 100 0   false; is_deny   "$(run_limite "$TP")" && ok "lg: ventana agotada + overage deshabilitado → FRENA"               || bad "lg: NO frenó sin overage y sin ventana"
write_state 19   # restablece el state.json de ventana para lo que siga

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b1c) merge-squash-guard: EXIGE squash si destino=develop O indeterminado (G4 + B3) =="
# Modelo canónico (decisión del usuario): squash cuando el destino es develop CONFIRMADO; main (release)
# y ramas personales/ramitas → libres. B3 (FMEA 2026-07-30): destino IRRESOLUBLE (timeout/red) → fail-safe
# EXIGE squash (antes lo dejaba pasar mientras confirmar-merge-develop sí lo trataba como develop → "merge
# a develop confirmado SIN squash"), salvo señal explícita de release-a-main en el comando.
rm -f "${TMPDIR:-/tmp}"/acg-mrdest-* 2>/dev/null   # caché de destino limpia (la lib cachea por MR-id)
MSBIN="$FAKEHOME/msbin"; mkdir -p "$MSBIN"
mock_glab() { printf '#!/usr/bin/env bash\necho '\''{"target_branch":"%s"}'\''\n' "$1" > "$MSBIN/glab"; chmod +x "$MSBIN/glab"; }
ms() { PATH="$MSBIN:$PATH" HOME="$FAKEHOME" CLAUDE_PROJECT_DIR="$FAKEHOME" bash "$HOOKS/merge-squash-guard.sh" <<<"{\"tool_input\":{\"command\":\"$1\"}}"; }
# NOTA: la lib cachea el destino por MR-id (compartido squash↔confirmar), así que cada caso usa un
# MR-id DISTINTO — si no, la caché del 1er caso (develop) contaminaría a los siguientes. En producción
# cada MR tiene su id; aquí es un artefacto de reusar mocks con el mismo número.
mock_glab develop; out="$(ms 'glab mr merge 42 --auto-merge --yes')"
is_deny "$out"   && ok "squash-guard G4: destino=develop confirmado, sin --squash → deny" || bad "squash-guard G4: no denegó merge a develop sin squash; got: $out"
mock_glab develop; out="$(ms 'glab mr merge 42 --squash --auto-merge --yes')"
is_silent "$out" && ok "squash-guard G4: develop CON --squash → pasa"                     || bad "squash-guard G4: bloqueó un merge que ya trae squash; got: $out"
mock_glab DevelopAna; out="$(ms 'glab mr merge 43 --auto-merge --yes')"
is_silent "$out" && ok "squash-guard G4: destino=rama personal → NO fuerza squash (día a día libre)" || bad "squash-guard G4: forzó squash a rama personal; got: $out"
mock_glab main; out="$(ms 'glab mr merge 44 --yes')"
is_silent "$out" && ok "squash-guard G4: destino=main (release) → NO fuerza squash"       || bad "squash-guard G4: forzó squash a un release; got: $out"
# B3: destino IRRESOLUBLE (sin id → no se puede consultar; equivale a un timeout de red) SIN --squash
# → fail-safe EXIGE squash (deny). Antes esto pasaba en silencio (el hueco B3).
out="$(ms 'glab mr merge --auto-merge --yes')"   # sin ID → destino indeterminado
is_deny "$out" && ok "squash-guard B3: destino INDETERMINADO sin --squash → deny (fail-safe exige squash)" || bad "squash-guard B3: no forzó squash con destino indeterminado; got: $out"
# B3: mismo destino irresoluble PERO ya trae --squash → pasa (nada que exigir).
out="$(ms 'glab mr merge --squash --auto-merge --yes')"
is_silent "$out" && ok "squash-guard B3: destino INDETERMINADO CON --squash → pasa" || bad "squash-guard B3: bloqueó un merge indeterminado que ya trae squash; got: $out"
# B3: destino irresoluble PERO el comando SEÑALA release-a-main explícito → NO fuerza squash (no aplasta
# el histórico de un release cuya red no se pudo consultar). Sin id → destino queda vacío igual.
out="$(ms 'glab mr merge --yes # release a main')"
is_silent "$out" && ok "squash-guard B3: indeterminado + señal 'release a main' → NO fuerza squash" || bad "squash-guard B3: forzó squash pese a la señal explícita de release; got: $out"
# H-R9-01 (FMEA r9): el binario Windows `glab.exe`/`gh.exe` rompía el gate `acg_es_merge_mr` → ambos guards
# de merge quedaban ciegos (hermano de B4 en el eje merge). (\.exe)? en el reconocimiento lo cierra.
mock_glab develop; out="$(ms 'glab.exe mr merge 48 --auto-merge --yes')"
is_deny "$out" && ok "squash-guard H-R9-01: 'glab.exe mr merge' sin --squash → deny (binario Windows)" || bad "squash-guard H-R9-01: 'glab.exe' evadió el guard de squash; got: $out"
mock_glab develop; out="$(ms 'glab.exe mr merge 49 --squash --auto-merge --yes')"
is_silent "$out" && ok "squash-guard H-R9-01: 'glab.exe mr merge --squash' → pasa (sin falso positivo)" || bad "squash-guard H-R9-01: bloqueó un glab.exe que ya trae squash; got: $out"
rm -f "${TMPDIR:-/tmp}"/acg-mrdest-* 2>/dev/null
rm -rf "$MSBIN"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b1d) git-branch-guard: push PELÓN / comillas / nombre-de-repo (H1/H11/H13) =="
GBROOT="$(mktemp -d "${TMPDIR:-/tmp}/brain-gb.XXXXXX")"; GBREPO="$GBROOT/repo"; GBHOME="$GBROOT/home"; mkdir -p "$GBREPO" "$GBHOME"
git -C "$GBREPO" init -q >/dev/null 2>&1
git -C "$GBREPO" config user.email t@t >/dev/null 2>&1; git -C "$GBREPO" config user.name tester >/dev/null 2>&1
printf 'base\n' > "$GBREPO/a.txt"; git -C "$GBREPO" add a.txt >/dev/null 2>&1; git -C "$GBREPO" commit -qm base >/dev/null 2>&1
git -C "$GBREPO" branch -M develop >/dev/null 2>&1
# HOME sin copia global → corre la copia del repo (no cede por dedupe)
gb() { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' | CLAUDE_PROJECT_DIR="$GBREPO" HOME="$GBHOME" bash "$HOOKS/git-branch-guard.sh"; }
git -C "$GBREPO" checkout -q develop >/dev/null 2>&1
printf '%s' "$(gb 'git push')"        | grep -q '"deny"' && ok "gbg H1: 'git push' pelón en develop → deny"          || bad "gbg H1: push pelón en develop NO bloqueó"
printf '%s' "$(gb 'git push --force')"| grep -q '"deny"' && ok "gbg H1: 'git push --force' pelón en develop → deny"  || bad "gbg H1: push --force pelón NO bloqueó"
printf '%s' "$(gb 'git push origin HEAD')" | grep -q '"deny"' && ok "gbg H1: 'git push origin HEAD' en develop → deny" || bad "gbg H1: push HEAD en develop NO bloqueó"
git -C "$GBREPO" checkout -q -b feat/x >/dev/null 2>&1
is_silent "$(gb 'git push')"              && ok "gbg H1: 'git push' pelón en ramita → silencio (sin falso positivo)" || bad "gbg H1: push pelón en ramita bloqueó"
is_silent "$(gb 'git push -u origin feat/x')" && ok "gbg: push explícito de la ramita → silencio"                    || bad "gbg: push de ramita bloqueó"
printf '%s' "$(gb 'git push origin develop')" | grep -q '"deny"' && ok "gbg: 'git push origin develop' explícito → deny (preservado)" || bad "gbg: push explícito a develop NO bloqueó"
# A2 (FMEA 2026-07-30): el FORCE-REFSPEC `+develop` (el `+` fuerza el push) se colaba porque el set de
# separadores no incluía '+'. El push FORZADO a base es el más peligroso → debe BLOQUEAR.
printf '%s' "$(gb 'git push -f origin +develop')" | grep -q '"deny"' && ok "gbg A2: 'git push -f origin +develop' (force-refspec) → deny" || bad "gbg A2: el force-refspec +develop se coló (bypass A2)"
printf '%s' "$(gb 'git push origin +develop')"    | grep -q '"deny"' && ok "gbg A2: 'git push origin +develop' (force-refspec, sin -f) → deny" || bad "gbg A2: +develop sin -f se coló"
printf '%s' "$(gb 'git push origin +main')"       | grep -q '"deny"' && ok "gbg A2: 'git push origin +main' (force-refspec) → deny" || bad "gbg A2: +main se coló"
is_silent "$(gb 'git push origin feat/x')"        && ok "gbg A2: 'git push origin feat/x' explícito → silencio (sin falso positivo del '+')" || bad "gbg A2: falso positivo al agregar '+' al set (bloqueó una ramita)"
is_silent "$(gb 'git commit -m "doc: no hacer git push a develop"')" && ok "gbg H13: 'git push a develop' entrecomillado → silencio" || bad "gbg H13: mención entrecomillada disparó"
is_silent "$(gb 'gh pr merge 5 -R org/develop --squash')" && ok "gbg H11: '-R org/develop' (nombre de repo) → silencio" || bad "gbg H11: -R org/develop disparó falso positivo"
# ── wave4 (FMEA post-integración 2026-07-30): evasiones de git-branch-guard CERRADAS. Parado en feat/x
# (rama NO-base): estas formas empujaban a base SIN que el fallback por rama actual disparara. ──
printf '%s' "$(gb 'git push origin "develop"')" | grep -q '"deny"' && ok "gbg A-01: destino ENTRECOMILLADO develop → deny" || bad "gbg A-01: destino entrecomillado se coló (bypass comillas)"
printf '%s' "$(gb "git push origin 'main'")"    | grep -q '"deny"' && ok "gbg A-01: destino entrecomillado main (comilla simple) → deny" || bad "gbg A-01: comilla simple se coló"
printf '%s' "$(gb 'git push --all origin')"     | grep -q '"deny"' && ok "gbg A-02: 'git push --all' → deny (empuja todas las refs, incl base)" || bad "gbg A-02: --all se coló"
printf '%s' "$(gb 'git push --mirror origin')"  | grep -q '"deny"' && ok "gbg A-02: 'git push --mirror' → deny" || bad "gbg A-02: --mirror se coló"
printf '%s' "$(gb 'git -c http.sslVerify=false push origin develop')" | grep -q '"deny"' && ok "gbg A-03: prefijo 'git -c … push develop' → deny" || bad "gbg A-03: el prefijo 'git -c' rompió la adyacencia (bypass)"
printf '%s' "$(gb 'git -C /tmp push origin main')" | grep -q '"deny"' && ok "gbg A-03: prefijo 'git -C dir push main' → deny" || bad "gbg A-03: 'git -C' se coló"
is_silent "$(gb 'git push origin "feat/x"')"    && ok "gbg A-01: ramita entrecomillada → silencio (sin falso positivo)" || bad "gbg A-01: bloqueó una ramita entrecomillada"
# N-01 (FMEA ronda 2): refspec ENTRECOMILLADO con la base a la DERECHA del ':' (residuo del raw-check de A-01).
printf '%s' "$(gb 'git push origin "HEAD:develop"')"     | grep -q '"deny"' && ok "gbg N-01: 'git push origin \"HEAD:develop\"' → deny" || bad "gbg N-01: refspec entrecomillado HEAD:develop se coló"
printf '%s' "$(gb 'git push origin "mybranch:main"')"    | grep -q '"deny"' && ok "gbg N-01: 'git push origin \"mybranch:main\"' → deny" || bad "gbg N-01: refspec entrecomillado rama:main se coló"
is_silent "$(gb 'git push origin "HEAD:feat/x"')"        && ok "gbg N-01: refspec entrecomillado a ramita → silencio (sin falso positivo)" || bad "gbg N-01: bloqueó un refspec a ramita"
# A-R3-01 (FMEA ronda 3): un push a base ENCADENADO como 2º (o Nº) subcomando. El reescrito de N-01 usaba
# `head -1` → solo miraba el PRIMER `git push …` → un `git push feat/x ; git push develop` se colaba por el 2º.
# acg_push_toca_base ahora recorre CADA subcomando (awk gsub [;&|]→\n): cualquiera que toque base BLOQUEA.
printf '%s' "$(gb 'git push origin feat/x ; git push origin develop')" | grep -q '"deny"' && ok "gbg A-R3-01: push a base ENCADENADO (2º subcomando ';') → deny" || bad "gbg A-R3-01: el push a develop encadenado se coló (head -1)"
printf '%s' "$(gb 'git push origin feat/x && git push origin main')"   | grep -q '"deny"' && ok "gbg A-R3-01: push a base encadenado ('&&', a main) → deny" || bad "gbg A-R3-01: el push a main encadenado se coló"
# Y el contraveneno: un push REAL a ramita seguido de un commit cuyo MENSAJE menciona "git push a develop"
# NO dispara — ese subcomando es el commit, su despoja borra el mensaje → es_push=no → se salta (H13 por-subcomando).
is_silent "$(gb 'git push origin feat/x && git commit -m "doc: recordar no hacer git push a develop"')" && ok "gbg A-R3-01: push a ramita + commit con 'git push a develop' en el mensaje → silencio (H13)" || bad "gbg A-R3-01: la mención en el mensaje del commit encadenado disparó (falso positivo)"
# A-R4-01 (FMEA ronda 4): git acepta MUCHAS opciones globales entre `git` y su subcomando (no solo -c/-C).
# Cada una rompía la adyacencia git+push → evadía TODO el guard. acg_normaliza_git_prefijo ahora colapsa la
# CLASE (value-eaters por espacio/= + cualquier flag dash-led). Parado en feat/x → estas empujan a base → deny.
printf '%s' "$(gb 'git --no-pager push origin develop')"     | grep -q '"deny"' && ok "gbg A-R4-01: 'git --no-pager push develop' → deny" || bad "gbg A-R4-01: '--no-pager' rompió la adyacencia (bypass)"
printf '%s' "$(gb 'git -P push origin develop')"             | grep -q '"deny"' && ok "gbg A-R4-01: 'git -P push develop' → deny" || bad "gbg A-R4-01: '-P' se coló"
printf '%s' "$(gb 'git --work-tree=/tmp push origin main')"  | grep -q '"deny"' && ok "gbg A-R4-01: 'git --work-tree=/tmp push main' (=-form) → deny" || bad "gbg A-R4-01: '--work-tree=' se coló"
printf '%s' "$(gb 'git --git-dir /tmp/foo push origin develop')" | grep -q '"deny"' && ok "gbg A-R4-01: 'git --git-dir /tmp/foo push develop' (value por espacio) → deny" || bad "gbg A-R4-01: '--git-dir <dir>' se coló"
printf '%s' "$(gb 'git --literal-pathspecs push origin main')" | grep -q '"deny"' && ok "gbg A-R4-01: 'git --literal-pathspecs push main' → deny" || bad "gbg A-R4-01: '--literal-pathspecs' se coló"
is_silent "$(gb 'git --no-pager push origin feat/x')"        && ok "gbg A-R4-01: '--no-pager push feat/x' (ramita) → silencio (sin falso positivo)" || bad "gbg A-R4-01: bloqueó una ramita con prefijo global"
# A-R5-01 (FMEA ronda 5): el VALOR de un value-eater puede ir ENTRECOMILLADO con ESPACIOS (rutas de Google
# Drive: "/Users/…/Mi unidad/repo"). El [^space]+ se cortaba en el 1er espacio → evasión total. Quote-aware.
printf '%s' "$(gb 'git -C "/Users/unjordi/Mi unidad/repo" push origin develop')" | grep -q '"deny"' && ok "gbg A-R5-01: '-C \"…/Mi unidad/…\" push develop' (valor entrecomillado con espacio) → deny" || bad "gbg A-R5-01: el valor entrecomillado con espacio rompió la adyacencia (bypass)"
printf '%s' "$(gb "git -C '/single quote path/x' push origin main")" | grep -q '"deny"' && ok "gbg A-R5-01: '-C \x27/single quote path/x\x27 push main' (comilla simple con espacio) → deny" || bad "gbg A-R5-01: comilla simple con espacio se coló"
printf '%s' "$(gb 'git --git-dir="/a b/.git" push origin develop')" | grep -q '"deny"' && ok "gbg A-R5-01: '--git-dir=\"/a b/.git\" push develop' (=-form entrecomillado) → deny" || bad "gbg A-R5-01: --git-dir= entrecomillado se coló"
printf '%s' "$(gb 'git -c a=b -C "/x y" --no-pager push origin develop')" | grep -q '"deny"' && ok "gbg A-R5-01: prefijos STACKED con valor entrecomillado → deny" || bad "gbg A-R5-01: stacking con valor entrecomillado se coló"
is_silent "$(gb 'git -C "/Users/unjordi/Mi unidad/repo" push origin feat/x')" && ok "gbg A-R5-01: '-C \"…espacio…\" push feat/x' (ramita) → silencio (sin falso positivo)" || bad "gbg A-R5-01: bloqueó una ramita con -C entrecomillado"
# A-R6-01 (FMEA ronda 6): la comilla puede ir EN MEDIO del valor (`git -c user.name="a b" push …` —
# shell-válido, cotidiano). r5 cubrió la comilla al INICIO; el valor MIXTO key="val con espacio" volvía a
# cortar en el espacio interno → evasión total. El valor se modela como SECUENCIA (char-no-comilla | run "…").
printf '%s' "$(gb 'git -c user.name="a b" push origin develop')" | grep -q '"deny"' && ok "gbg A-R6-01: '-c user.name=\"a b\" push develop' (comilla EN MEDIO) → deny" || bad "gbg A-R6-01: comilla en medio del valor rompió la adyacencia (bypass)"
printf '%s' "$(gb "git -c user.name='a b' push origin main")" | grep -q '"deny"' && ok "gbg A-R6-01: '-c user.name=\x27a b\x27 push main' (comilla simple en medio) → deny" || bad "gbg A-R6-01: comilla simple en medio se coló"
printf '%s' "$(gb 'git -c core.editor="vim -c foo" push origin develop')" | grep -q '"deny"' && ok "gbg A-R6-01: '-c core.editor=\"vim -c foo\" push develop' (valor con espacio y -c adentro) → deny" || bad "gbg A-R6-01: valor con -c interno se coló"
is_silent "$(gb 'git -c user.name="a b" push origin feat/x')" && ok "gbg A-R6-01: '-c user.name=\"a b\" push feat/x' (ramita) → silencio (sin falso positivo)" || bad "gbg A-R6-01: bloqueó una ramita con -c key entrecomillado"
is_silent "$(gb 'git commit -m "un mensaje con -C /x y push origin develop adentro"')" && ok "gbg A-R6-01: commit con 'push origin develop' DENTRO del mensaje → silencio (H13, el -c/-C va tras el subcomando)" || bad "gbg A-R6-01: falso positivo, la mención en el mensaje disparó"
# A-R7-01 (FMEA ronda 7): el espacio del valor puede ir ESCAPADO CON BACKSLASH (`git -c a=b\ c push …` — el
# shell lo tokeniza como `-c "a=b c"`). El `\` se trataba como char normal y la secuencia se cortaba en el
# espacio real → misma evasión que r5/r6 por otra vía. Se añade `\\.` (backslash+char) a la secuencia de valor.
printf '%s' "$(gb 'git -c a=b\ c push origin develop')" | grep -q '"deny"' && ok "gbg A-R7-01: '-c a=b\\ c push develop' (espacio escapado con backslash) → deny" || bad "gbg A-R7-01: el espacio escapado con backslash rompió la adyacencia (bypass)"
printf '%s' "$(gb 'git -C /a\ b push origin main')" | grep -q '"deny"' && ok "gbg A-R7-01: '-C /a\\ b push main' (espacio escapado, value-eater por espacio) → deny" || bad "gbg A-R7-01: '-C /a\\ b' se coló"
printf '%s' "$(gb 'git --work-tree=/a\ b push origin develop')" | grep -q '"deny"' && ok "gbg A-R7-01: '--work-tree=/a\\ b push develop' (=-form escapado) → deny" || bad "gbg A-R7-01: '--work-tree=/a\\ b' se coló"
is_silent "$(gb 'git -c a=b\ c push origin feat/x')" && ok "gbg A-R7-01: '-c a=b\\ c push feat/x' (ramita) → silencio (sin falso positivo)" || bad "gbg A-R7-01: bloqueó una ramita con backslash-escape"
# B4 (FMEA ronda 8): en Windows el binario es `git.exe`; rompía el `git`+espacio que exigen los detectores
# → evasión total en un OS soportado (Git Bash). Se colapsa `git.exe`→`git` en posición de ejecutable.
printf '%s' "$(gb 'git.exe push origin develop')" | grep -q '"deny"' && ok "gbg B4: 'git.exe push develop' (binario Windows) → deny" || bad "gbg B4: 'git.exe' rompió la adyacencia (bypass en Windows/Git Bash)"
printf '%s' "$(gb 'git.exe -c a=b push origin main')" | grep -q '"deny"' && ok "gbg B4: 'git.exe -c a=b push main' (con prefijo global) → deny" || bad "gbg B4: 'git.exe' + prefijo se coló"
printf '%s' "$(gb 'ls && git.exe push origin develop')" | grep -q '"deny"' && ok "gbg B4: 'ls && git.exe push develop' (encadenado) → deny" || bad "gbg B4: 'git.exe' encadenado se coló"
is_silent "$(gb 'git.exe push origin feat/x')" && ok "gbg B4: 'git.exe push feat/x' (ramita) → silencio (sin falso positivo)" || bad "gbg B4: bloqueó una ramita con git.exe"
is_silent "$(gb 'git commit -m "run git.exe push origin develop luego"')" && ok "gbg B4: 'git.exe push develop' DENTRO del mensaje → silencio (H13)" || bad "gbg B4: falso positivo, git.exe en el mensaje disparó"
rm -rf "$GBROOT"
# A-R4-01 (pelón en BASE): parado EN develop, un push pelón con prefijo global debe DENY (el fallback por
# rama actual se alcanza porque el subcomando SÍ se reconoce como push tras normalizar el prefijo).
GBROOT2="$(mktemp -d "${TMPDIR:-/tmp}/brain-gb2.XXXXXX")"; GBREPO2="$GBROOT2/repo"; GBHOME2="$GBROOT2/home"; mkdir -p "$GBREPO2" "$GBHOME2"
git -C "$GBREPO2" init -q >/dev/null 2>&1; git -C "$GBREPO2" config user.email t@t; git -C "$GBREPO2" config user.name t
git -C "$GBREPO2" commit -q --allow-empty -m init >/dev/null 2>&1; git -C "$GBREPO2" checkout -q -b develop >/dev/null 2>&1
gb2() { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' | CLAUDE_PROJECT_DIR="$GBREPO2" HOME="$GBHOME2" bash "$HOOKS/git-branch-guard.sh"; }
printf '%s' "$(gb2 'git --no-pager push')" | grep -q '"deny"' && ok "gbg A-R4-01: 'git --no-pager push' PELÓN parado EN develop → deny" || bad "gbg A-R4-01: el pelón con --no-pager en develop se coló"
printf '%s' "$(gb2 'git.exe push')" | grep -q '"deny"' && ok "gbg B4: 'git.exe push' PELÓN parado EN develop → deny" || bad "gbg B4: el pelón 'git.exe push' en develop se coló"
rm -rf "$GBROOT2"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b1e) confirmar-merge-develop: escape ANCLADO al subcomando (H3) + destino cacheado/timeout (H5) =="
# Antes NO tenía test de comportamiento. H3: el escape casaba `status|list|view` como token suelto en
# CUALQUIER parte → `glab mr merge 5 && git status` evadía el gate. H5: 2 llamadas de red idénticas +
# fail-open si el proceso lo mata el timeout del hook. La lógica ahora vive en la lib (acg_es_merge_mr,
# acg_destino_de_mr con caché por MR-id + timeout interno).
rm -f "${TMPDIR:-/tmp}"/acg-mrdest-* 2>/dev/null
CMROOT="$(mktemp -d "${TMPDIR:-/tmp}/brain-cm.XXXXXX")"; CMREPO="$CMROOT/repo"; CMHOME="$CMROOT/home"; CMBIN="$CMROOT/bin"; CMTX="$CMROOT/tx.jsonl"
mkdir -p "$CMREPO/.claude" "$CMHOME" "$CMBIN"
: > "$CMREPO/.claude/repo-compartido"                    # marca de repo compartido (gatea el candado)
git -C "$CMREPO" init -q >/dev/null 2>&1
git -C "$CMREPO" remote add origin git@gitlab.com:org/repo.git >/dev/null 2>&1   # para derivar el repo
mock_cm_glab() { printf '#!/usr/bin/env bash\necho '\''{"target_branch":"%s"}'\''\n' "$1" > "$CMBIN/glab"; chmod +x "$CMBIN/glab"; }
# cm "<cmd>" "<último mensaje del usuario>"  → corre el hook (HOME sin copia global → no cede por dedupe)
cm() {
  printf '%s\n' "{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"$2\"}]}}" > "$CMTX"
  jq -nc --arg c "$1" --arg t "$CMTX" '{tool_input:{command:$c},transcript_path:$t}' \
    | PATH="$CMBIN:$PATH" HOME="$CMHOME" CLAUDE_PROJECT_DIR="$CMREPO" bash "$HOOKS/confirmar-merge-develop.sh"
}
mock_cm_glab develop
# H3: merge REAL con un `&& git status` encadenado, SIN OK → deny (el `status` ya NO evade el gate).
is_deny "$(cm 'glab mr merge 5 --yes && git status' 'haz el cambio')" \
  && ok "cmd H3: 'glab mr merge 5 && git status' sin OK → deny (escape ya NO se dispara por token suelto)" \
  || bad "cmd H3: el token 'status' encadenado evadió el gate (fail-open)"
# H3: inspección genuina (no matchea merge|accept) → silencio.
is_silent "$(cm 'glab mr view 5' 'haz el cambio')" \
  && ok "cmd H3: 'glab mr view' (inspección) → silencio" || bad "cmd H3: bloqueó una inspección"
# Con OK explícito citado → pasa (aunque traiga el `&& git status`).
is_silent "$(cm 'glab mr merge 5 --yes && git status' 'ya lo revisé, mérgalo')" \
  && ok "cmd: merge a develop CON OK explícito → pasa" || bad "cmd: bloqueó un merge con OK citado"
# Baseline: merge a develop SIN OK → deny.
is_deny "$(cm 'glab mr merge 5 --yes' 'sigue avanzando')" \
  && ok "cmd: merge a develop sin OK ('sigue' NO cuenta) → deny" || bad "cmd: no bloqueó merge a develop sin OK"
# FIX 2026-07-20 (precisión): una autorización de RELEASE-a-main también cubre el merge INTERMEDIO a
# develop (el release pasa forzosamente por develop). Antes daba falso-negativo: "empujar el brain a
# main" frenaba el PR intermedio a develop porque el CONF_RE de develop no reconocía lenguaje de release.
is_silent "$(cm 'glab mr merge 62 --squash --yes' 'ya puedes empujar el brain a main')" \
  && ok "cmd: merge a develop con OK de RELEASE-a-main → pasa (el release cubre su paso a develop)" \
  || bad "cmd: falso-negativo — 'empujar a main' NO destrabó el merge intermedio a develop"
# ── wave4 (FMEA post-integración 2026-07-30) ──
# A-04: el id del MR puede ir DESPUÉS de un flag (`glab mr merge --yes 9`). El OK debe ligarse a ESE id.
is_deny "$(cm 'glab mr merge --yes 9' 'mergea el MR 5')" \
  && ok "cmd A-04: id tras flag ('--yes 9') → el OK del MR 5 NO autoriza el 9 (deny)" \
  || bad "cmd A-04: 'glab mr merge --yes 9' tomó el OK de OTRO MR (bypass A-04)"
is_silent "$(cm 'glab mr merge --yes 9' 'mergea el 9')" \
  && ok "cmd A-04: id tras flag con OK ligado a ESE id (9) → pasa" || bad "cmd A-04: no reconoció el OK ligado al 9"
# A-05: negaciones fuera de no/sin/nunca/jamás que traen un verbo de merge NO cuentan como OK.
is_deny "$(cm 'glab mr merge 5 --yes' 'ni se te ocurra mergear el 5')" \
  && ok "cmd A-05: 'ni se te ocurra mergear' → deny (negación reconocida)" || bad "cmd A-05: 'ni se te ocurra' pasó como OK (bypass A-05)"
is_deny "$(cm 'glab mr merge 5 --yes' 'de ninguna manera mergea el 5 ahora')" \
  && ok "cmd A-05: 'de ninguna manera mergea' → deny" || bad "cmd A-05: 'de ninguna manera' pasó como OK"
# A-R4-03 (FMEA r4): un DEFERIMIENTO/futuro que menciona "mergear el <id>" NO es un OK (DEFER_RE lo descarta).
is_deny "$(cm 'glab mr merge 5 --yes' 'espera para mergear el 5')" \
  && ok "cmd A-R4-03: 'espera para mergear el 5' (aplazamiento) → deny" || bad "cmd A-R4-03: 'espera para mergear' pasó como OK"
is_deny "$(cm 'glab mr merge 5 --yes' 'dejame ver antes de mergear el 5')" \
  && ok "cmd A-R4-03: 'déjame ver antes de mergear el 5' → deny" || bad "cmd A-R4-03: 'déjame ver antes de' pasó como OK"
is_deny "$(cm 'glab mr merge 5 --yes' 'todavia estoy revisando, luego mergea el 5')" \
  && ok "cmd A-R4-03: 'todavía revisando, luego mergea el 5' → deny" || bad "cmd A-R4-03: 'todavía revisando' pasó como OK"
is_deny "$(cm 'glab mr merge 5 --yes' 'casi listo para mergear el 5')" \
  && ok "cmd A-R4-03: 'casi listo para mergear el 5' → deny" || bad "cmd A-R4-03: 'casi listo para' pasó como OK"
# Controles anti-FP: una afirmación NO debe caer por DEFER_RE ("ya revisé, mergea"; "desde luego, mergea").
is_silent "$(cm 'glab mr merge 5 --yes' 'ya revise, mergea el 5')" \
  && ok "cmd A-R4-03: 'ya revisé, mergea el 5' → pasa (no es aplazamiento)" || bad "cmd A-R4-03: falso positivo, 'ya revisé' cayó por DEFER_RE"
is_silent "$(cm 'glab mr merge 5 --yes' 'desde luego, mergea el 5')" \
  && ok "cmd A-R4-03: 'desde luego, mergea el 5' → pasa (no colisiona con 'luego')" || bad "cmd A-R4-03: falso positivo, 'desde luego' cayó por 'luego'"
# A-R5-03 (FMEA r5, precisión segura): "déjame probar/revisar/checar … mergea el 5" es aplazamiento → deny.
# Control: "déjame mergearlo" NO cae (es intención de merge, un OK legítimo) → pasa.
is_deny "$(cm 'glab mr merge 5 --yes' 'primero dejame probar, luego mergea el 5')" \
  && ok "cmd A-R5-03: 'déjame probar … mergea el 5' (aplazamiento) → deny" || bad "cmd A-R5-03: 'déjame probar' pasó como OK"
is_silent "$(cm 'glab mr merge 5 --yes' 'dejame mergearlo el 5')" \
  && ok "cmd A-R5-03: 'déjame mergearlo' → pasa (intención de merge, no aplazamiento)" || bad "cmd A-R5-03: falso positivo, 'déjame mergearlo' cayó por DEFER_RE"
# H-R9-01 (FMEA r9): el binario Windows `glab.exe mr merge` evadía el gate → un merge a develop pasaba sin OK.
is_deny "$(cm 'glab.exe mr merge 5 --yes' 'sigue avanzando')" \
  && ok "cmd H-R9-01: 'glab.exe mr merge' a develop SIN OK → deny (binario Windows)" || bad "cmd H-R9-01: 'glab.exe' evadió confirmar-merge-develop"
is_silent "$(cm 'glab.exe mr merge 5 --yes' 'ya revisé, mergea el 5')" \
  && ok "cmd H-R9-01: 'glab.exe mr merge' a develop CON OK → pasa" || bad "cmd H-R9-01: 'glab.exe' con OK fue bloqueado"
# Blindaje (NO se afloja el camino inverso): un OK de develop NUNCA autoriza un RELEASE a main.
mock_cm_glab main
is_deny "$(cm 'glab mr merge 63 --yes' 'mérgalo a develop')" \
  && ok "cmd: 'mérgalo a develop' NO autoriza un RELEASE a main (main sigue exigiendo release explícito)" \
  || bad "cmd: AFLOJAMIENTO GRAVE — un OK de develop destrabó un release a main"
mock_cm_glab develop
# H5 (lib): caché por MR-id → la 2ª consulta NO re-llama a la red (comparte destino entre squash+confirmar).
d1=$(PATH="$CMBIN:$PATH" CLAUDE_PROJECT_DIR="$CMREPO" bash -c '. "'"$HOOKS"'/analizar-comando-git.sh"; acg_destino_de_mr "glab mr merge 123"')
mock_cm_glab main   # si re-llamara, ahora diría main; la caché debe seguir dando develop
d2=$(PATH="$CMBIN:$PATH" CLAUDE_PROJECT_DIR="$CMREPO" bash -c '. "'"$HOOKS"'/analizar-comando-git.sh"; acg_destino_de_mr "glab mr merge 123"')
{ [ "$d1" = develop ] && [ "$d2" = develop ]; } \
  && ok "cmd H5: destino cacheado por MR-id (2ª consulta lee caché, no re-llama a la red)" \
  || bad "cmd H5: la caché por MR-id no se usó (d1='$d1' d2='$d2')"
# H5 (lib): un glab COLGADO se acota por el timeout interno → devuelve vacío RÁPIDO (no fail-open por
# muerte del proceso; el consumidor cae a su fail-policy y EMITE su decisión).
printf '#!/usr/bin/env bash\nsleep 5\necho '\''{"target_branch":"develop"}'\''\n' > "$CMBIN/glab"; chmod +x "$CMBIN/glab"
SECONDS=0
dhang=$(PATH="$CMBIN:$PATH" CLAUDE_PROJECT_DIR="$CMREPO" ACG_MR_TIMEOUT=1 bash -c '. "'"$HOOKS"'/analizar-comando-git.sh"; acg_destino_de_mr "glab mr merge 456"')
dur=$SECONDS
{ [ -z "$dhang" ] && [ "$dur" -lt 4 ]; } \
  && ok "cmd H5: glab colgado → timeout interno devuelve vacío en ${dur}s (no cuelga hasta que lo maten)" \
  || bad "cmd H5: la consulta colgada NO fue acotada por timeout (dhang='$dhang' dur=${dur}s)"
rm -f "${TMPDIR:-/tmp}"/acg-mrdest-* 2>/dev/null

# ── A3 (NEGATION-BLIND) · FMEA 2026-07-30 ──
# ANTES: `grep -qiE` de CONF_RE/RELEASE_RE sin polaridad → una NEGACIÓN abría el merge. Cada caso usa un
# MR-id distinto para no contaminar la caché de destino por MR-id.
mock_cm_glab develop
is_deny "$(cm 'glab mr merge 71 --squash --yes' 'no te di autorización todavía')" \
  && ok "cmd A3: 'no te di autorización todavía' → deny (negación NO abre el merge)" \
  || bad "cmd A3: BYPASS — una negación de autorización abrió el merge a develop"
is_deny "$(cm 'glab mr merge 72 --squash --yes' 'aún no mergees eso')" \
  && ok "cmd A3: 'aún no mergees eso' → deny" \
  || bad "cmd A3: 'aún no mergees' dejó pasar el merge"
is_silent "$(cm 'glab mr merge 73 --squash --yes' 'sí, mergea')" \
  && ok "cmd A3: 'sí, mergea' → pasa (OK afirmativo, sin falso positivo)" \
  || bad "cmd A3: FALSO POSITIVO — 'sí, mergea' fue frenado"
is_silent "$(cm 'glab mr merge 74 --squash --yes' 'mergea el MR')" \
  && ok "cmd A3: 'mergea el MR' → pasa" \
  || bad "cmd A3: FALSO POSITIVO — 'mergea el MR' fue frenado"
is_silent "$(cm 'glab mr merge 75 --squash --yes' 'dale el merge')" \
  && ok "cmd A3: 'dale el merge' → pasa" \
  || bad "cmd A3: FALSO POSITIVO — 'dale el merge' fue frenado"

# ── A4 (OK TRANSITIVO) · FMEA 2026-07-30 ──
# ANTES: un OK reciente autorizaba CUALQUIER merge de la ventana. Ahora, si el OK NOMBRA un MR-id, ese id
# debe coincidir con el del comando; un OK genérico (sin id) conserva la recencia (no se endurece de más).
is_deny "$(cm 'glab mr merge 9 --squash --yes' 'mergea el MR 5')" \
  && ok "cmd A4: OK 'mergea el MR 5' + comando 'merge 9' → deny (no transitivo a otro MR)" \
  || bad "cmd A4: TRANSITIVIDAD — un OK para el MR 5 autorizó el merge del MR 9"
is_silent "$(cm 'glab mr merge 5 --squash --yes' 'mergea el 5')" \
  && ok "cmd A4: OK 'mergea el 5' + comando 'merge 5' → pasa (id coincide)" \
  || bad "cmd A4: el OK ligado al MR correcto fue frenado (falso positivo)"
is_silent "$(cm 'glab mr merge 8 --squash --yes' 'dale merge')" \
  && ok "cmd A4: OK genérico 'dale merge' + cualquier merge → pasa (recencia preservada)" \
  || bad "cmd A4: un OK genérico dejó de autorizar (endurecimiento de más)"
rm -f "${TMPDIR:-/tmp}"/acg-mrdest-* 2>/dev/null

# ── (b1f) confirmar: AUTORIZACIÓN DURABLE en disco (sobrevive compactaciones) + vocabulario "empuja/mete" ──
# El grant lo escribe el skill turno-nocturno con la CITA textual del usuario y vence_epoch; SOLO
# cubre scope=merge-develop. Caso real 2026-07-12: un OK blanket murió al compactarse el contexto.
echo ""
echo "== (b1f) confirmar-merge-develop: autorización durable (vence_epoch) + vocabulario empuja/mete =="
AUTHF="$CMREPO/.claude/memory/autorizaciones-vigentes.local.md"
mkdir -p "$CMREPO/.claude/memory"
mock_cm_glab develop
# (1) grant VIGENTE → permite el merge a develop aunque el transcript no traiga OK.
printf -- '- scope=merge-develop vence_epoch=%s vence="mañana 10am" cita="autorizo todos los merges a develop hasta mañana 10am" registrada=2026-07-18\n' "$(( $(date +%s) + 3600 ))" > "$AUTHF"
is_silent "$(cm 'glab mr merge 61 --squash --yes' 'sigue avanzando')" \
  && ok "cmd b1f: grant durable VIGENTE → merge a develop pasa (sobrevive compactación)" \
  || bad "cmd b1f: grant durable vigente NO destrabó el merge a develop"
# (2) grant VENCIDO → freno normal.
printf -- '- scope=merge-develop vence_epoch=%s vence="ayer" cita="autorizo hasta ayer" registrada=2026-07-17\n' "$(( $(date +%s) - 60 ))" > "$AUTHF"
is_deny "$(cm 'glab mr merge 62 --squash --yes' 'sigue avanzando')" \
  && ok "cmd b1f: grant VENCIDO → deny (no se estira)" \
  || bad "cmd b1f: un grant vencido dejó pasar el merge"
# (3) línea malformada (sin vence_epoch) → freno normal (fail-safe).
printf -- '- scope=merge-develop cita="sin vencimiento"\n' > "$AUTHF"
is_deny "$(cm 'glab mr merge 63 --squash --yes' 'sigue avanzando')" \
  && ok "cmd b1f: grant malformado (sin vence_epoch) → deny (fail-safe)" \
  || bad "cmd b1f: una línea malformada dejó pasar el merge"
# (4) EL MÁS IMPORTANTE: grant vigente pero destino MAIN → sigue exigiendo release súper-explícito.
printf -- '- scope=merge-develop vence_epoch=%s vence="+1h" cita="autorizo todos los merges a develop" registrada=hoy\n' "$(( $(date +%s) + 3600 ))" > "$AUTHF"
mock_cm_glab main
is_deny "$(cm 'glab mr merge 64 --yes' 'sigue avanzando')" \
  && ok "cmd b1f: grant develop vigente + destino MAIN → deny (main intacto, JAMÁS lo cubre el grant)" \
  || bad "cmd b1f: ¡el grant de develop destrabó un RELEASE a main! (aflojamiento grave)"
# (5) archivo ausente → comportamiento de siempre.
rm -f "$AUTHF"
mock_cm_glab develop
is_deny "$(cm 'glab mr merge 65 --squash --yes' 'sigue avanzando')" \
  && ok "cmd b1f: sin archivo de grants → deny normal (sin cambios de baseline)" \
  || bad "cmd b1f: sin archivo el guard dejó de frenar"
# (6) vocabulario: "empuja todo a develop" y "mete todo a develop" cuentan como OK explícito.
CMDCR2=$(grep "^CONF_RE=" "$HOOKS/confirmar-merge-develop.sh" | sed "s/^[^']*'//; s/'\$//")
printf '%s' "empuja todo lo que ya tienes a develop" | grep -qiE "$CMDCR2" && ok "cmd b1f: reconoce 'empuja todo … a develop'" || bad "cmd b1f: NO reconoce 'empuja … a develop' (falso-FRENO real)"
printf '%s' "mete todo eso a develop porfa"          | grep -qiE "$CMDCR2" && ok "cmd b1f: reconoce 'mete todo … a develop'"   || bad "cmd b1f: NO reconoce 'mete … a develop'"
printf '%s' "empújalo cuando puedas, a develop"      | grep -qiE "$CMDCR2" && ok "cmd b1f: reconoce 'empújalo … a develop'"     || bad "cmd b1f: NO reconoce 'empújalo'"
printf '%s' "no empujes nada todavía"                | grep -qiE "$CMDCR2" && bad "cmd b1f: FALSO POSITIVO con 'no empujes nada' (sin develop)" || ok "cmd b1f: 'empujes' sin develop NO dispara (acotado)"
rm -f "${TMPDIR:-/tmp}"/acg-mrdest-* 2>/dev/null
rm -rf "$CMROOT"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b2) secret-scan: bloquea un secreto staged, deja pasar lo limpio, respeta --no-verify =="
SCANREPO="$(mktemp -d "${TMPDIR:-/tmp}/brain-scan.XXXXXX")"
git -C "$SCANREPO" init -q >/dev/null 2>&1
git -C "$SCANREPO" config user.email t@t >/dev/null 2>&1
git -C "$SCANREPO" config user.name  tester >/dev/null 2>&1
# HOME sin copia global de secret-scan → la dedupe doble-cableado no cede (corre la copia bajo prueba).
scan() { printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}" \
         | HOME="$SCANREPO" CLAUDE_PROJECT_DIR="$SCANREPO" bash "$HOOKS/secret-scan.sh"; }
# (1) llave AWS falsa staged → deny
printf 'aws_key = AKIA1234567890ABCDEF\n' > "$SCANREPO/config.txt"
git -C "$SCANREPO" add config.txt >/dev/null 2>&1
o="$(scan 'git commit -m x')"
printf '%s' "$o" | grep -q '"deny"' && ok "secret-scan bloquea una llave AWS staged" || bad "secret-scan no bloqueó; got: $o"
# (2) --no-verify → pasa (escape deliberado)
o="$(scan 'git commit --no-verify -m x')"
[ -z "$o" ] && ok "secret-scan respeta --no-verify (escape)" || bad "secret-scan ignoró --no-verify; got: $o"
# (3) contenido limpio → silencio
git -C "$SCANREPO" reset -q >/dev/null 2>&1; rm -f "$SCANREPO/config.txt"
printf 'hola mundo, sin secretos\n' > "$SCANREPO/readme.txt"
git -C "$SCANREPO" add readme.txt >/dev/null 2>&1
o="$(scan 'git commit -m x')"
[ -z "$o" ] && ok "secret-scan deja pasar contenido limpio" || bad "secret-scan bloqueó limpio; got: $o"
# (4) un no-git → silencio
o="$(scan 'ls -la')"
[ -z "$o" ] && ok "secret-scan ignora comandos no-git" || bad "secret-scan reaccionó a no-git; got: $o"
# ── §D: patrones NUEVOS (JWT, connection string, Password=) vía la lib detectar-secretos ──
reset_scan() { git -C "$SCANREPO" reset -q >/dev/null 2>&1; rm -f "$SCANREPO"/*.txt 2>/dev/null; }
# (6) JWT
reset_scan; printf 'jwt: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c\n' > "$SCANREPO/j.txt"
git -C "$SCANREPO" add j.txt >/dev/null 2>&1; o="$(scan 'git commit -m x')"
printf '%s' "$o" | grep -q '"deny"' && ok "secret-scan §D: JWT (eyJ.eyJ.firma) → deny" || bad "secret-scan §D: no bloqueó un JWT; got: $o"
# (7) connection string con creds embebidas (user:pass@host)
reset_scan; printf 'db = postgres://admin:s3cr3tp4ss@db.internal:5432/prod\n' > "$SCANREPO/c.txt"
git -C "$SCANREPO" add c.txt >/dev/null 2>&1; o="$(scan 'git commit -m x')"
printf '%s' "$o" | grep -q '"deny"' && ok "secret-scan §D: connstring user:pass@host → deny" || bad "secret-scan §D: no bloqueó creds en URL; got: $o"
# (8) Password= estilo .NET con valor REAL → deny; con \$VAR de entorno → silencio (no es secreto en claro)
reset_scan; printf 'conn = "Server=db;User Id=sa;Password=Sup3rSecret!;"\n' > "$SCANREPO/p.txt"
git -C "$SCANREPO" add p.txt >/dev/null 2>&1; o="$(scan 'git commit -m x')"
printf '%s' "$o" | grep -q '"deny"' && ok "secret-scan §D: Password=<valor real> → deny" || bad "secret-scan §D: no bloqueó Password= real; got: $o"
reset_scan; printf 'conn = "Server=db;Password=${DB_PASS};"\n' > "$SCANREPO/e.txt"
git -C "$SCANREPO" add e.txt >/dev/null 2>&1; o="$(scan 'git commit -m x')"
[ -z "$o" ] && ok 'secret-scan §D: Password=${VAR} (ref de entorno) → silencio (sin falso positivo)' || bad "secret-scan §D: falso positivo con Password=\${VAR}; got: $o"
rm -rf "$SCANREPO"
# (9) §D fail-open vs fail-closed: en un NO-repo, default → fail-OPEN (silencio); STRICT=1 → fail-CLOSED (deny)
NONGIT="$(mktemp -d "${TMPDIR:-/tmp}/brain-nogit.XXXXXX")"
o="$(printf '%s' '{"tool_input":{"command":"git commit -m x"}}' | HOME="$NONGIT" CLAUDE_PROJECT_DIR="$NONGIT" bash "$HOOKS/secret-scan.sh")"
[ -z "$o" ] && ok "secret-scan §D: no-repo + default → fail-OPEN (silencio)" || bad "secret-scan §D: default no fue fail-open en no-repo; got: $o"
o="$(printf '%s' '{"tool_input":{"command":"git commit -m x"}}' | HOME="$NONGIT" CLAUDE_PROJECT_DIR="$NONGIT" CLAUDE_SECRET_SCAN_STRICT=1 bash "$HOOKS/secret-scan.sh")"
printf '%s' "$o" | grep -q '"deny"' && ok "secret-scan §D: no-repo + STRICT=1 → fail-CLOSED (deny)" || bad "secret-scan §D: STRICT no bloqueó en no-repo; got: $o"
rm -rf "$NONGIT"

# (5) G5: PRIMER push de una rama NUEVA sin upstream → antes fail-open (no escaneaba); ahora escanea lo
# que la rama AGREGA vs el merge-base con develop/main.
G5ROOT="$(mktemp -d "${TMPDIR:-/tmp}/brain-g5.XXXXXX")"; G5REPO="$G5ROOT/repo"; mkdir -p "$G5REPO"
git -C "$G5REPO" init -q >/dev/null 2>&1
git -C "$G5REPO" symbolic-ref HEAD refs/heads/main >/dev/null 2>&1
git -C "$G5REPO" config user.email t@t >/dev/null 2>&1
git -C "$G5REPO" config user.name  tester >/dev/null 2>&1
printf 'base limpia\n' > "$G5REPO/base.txt"; git -C "$G5REPO" add base.txt >/dev/null 2>&1; git -C "$G5REPO" commit -qm base >/dev/null 2>&1
git -C "$G5REPO" branch develop >/dev/null 2>&1
scan5() { printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}" | HOME="$G5REPO" CLAUDE_PROJECT_DIR="$G5REPO" bash "$HOOKS/secret-scan.sh"; }
git -C "$G5REPO" checkout -q -b feat/nueva >/dev/null 2>&1
printf 'key = AKIA1234567890ABCDEF\n' > "$G5REPO/secreto.txt"; git -C "$G5REPO" add secreto.txt >/dev/null 2>&1; git -C "$G5REPO" commit -qm add >/dev/null 2>&1
o="$(scan5 'git push -u origin feat/nueva')"
printf '%s' "$o" | grep -q '"deny"' && ok "secret-scan G5: 1er push de rama nueva (sin upstream) escanea vs merge-base → bloquea" || bad "secret-scan G5: NO bloqueó el secreto en el 1er push de rama nueva; got: $o"
git -C "$G5REPO" checkout -q main >/dev/null 2>&1; git -C "$G5REPO" checkout -q -b feat/limpia >/dev/null 2>&1
printf 'sin secretos\n' > "$G5REPO/nota.txt"; git -C "$G5REPO" add nota.txt >/dev/null 2>&1; git -C "$G5REPO" commit -qm nota >/dev/null 2>&1
o="$(scan5 'git push -u origin feat/limpia')"
[ -z "$o" ] && ok "secret-scan G5: 1er push de rama nueva LIMPIA → silencio (sin falso positivo)" || bad "secret-scan G5: falso positivo en rama nueva limpia; got: $o"
rm -rf "$G5ROOT"

# ── FMEA 2026-07-30 · A1 (idiom `git add && git commit`) + A7 (`--no-verify` en el MENSAJE) ──
echo ""
echo "== (b2c) secret-scan FMEA A1/A7: idiom 'git add && git commit' y --no-verify citado en el mensaje =="
FMEAREPO="$(mktemp -d "${TMPDIR:-/tmp}/brain-fmea.XXXXXX")"
git -C "$FMEAREPO" init -q >/dev/null 2>&1
git -C "$FMEAREPO" symbolic-ref HEAD refs/heads/main >/dev/null 2>&1
git -C "$FMEAREPO" config user.email t@t >/dev/null 2>&1
git -C "$FMEAREPO" config user.name  tester >/dev/null 2>&1
printf 'base limpia\n' > "$FMEAREPO/base.txt"; git -C "$FMEAREPO" add base.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm base >/dev/null 2>&1
# HOME sin copia global → la dedupe no cede; el input se arma con jq → escapa las comillas del mensaje.
scanf() { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' \
          | HOME="$FMEAREPO" CLAUDE_PROJECT_DIR="$FMEAREPO" bash "$HOOKS/secret-scan.sh"; }
fmeareset() { git -C "$FMEAREPO" reset -q >/dev/null 2>&1; rm -f "$FMEAREPO"/*.txt 2>/dev/null; }
# A1 (1) `git add secreto && git commit` con un AKIA en un archivo NUEVO aún NO staged → BLOQUEA
fmeareset; printf 'aws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/secreto.txt"
o="$(scanf 'git add secreto.txt && git commit -m x')"
printf '%s' "$o" | grep -q '"deny"' && ok "secret-scan A1: 'git add secreto && git commit' escanea lo que el add estagearía → bloquea" || bad "secret-scan A1: NO bloqueó el idiom add&&commit; got: $o"
# A1 (2) bypass TOTAL `git add -A && git commit && git push` con sk-ant en archivo por-venir → BLOQUEA
fmeareset; printf 'tok = sk-ant-abcdefghijklmnopqrstuvwxyz0123\n' > "$FMEAREPO/tok.txt"
o="$(scanf 'git add -A && git commit -m x && git push')"
printf '%s' "$o" | grep -q '"deny"' && ok "secret-scan A1: 'git add -A && git commit && git push' (bypass total) → bloquea" || bad "secret-scan A1: bypass total add&&commit&&push NO bloqueado; got: $o"
# A1 (3) archivo LIMPIO por el mismo idiom → PASA (sin falso positivo)
fmeareset; printf 'contenido sin secretos\n' > "$FMEAREPO/limpio.txt"
o="$(scanf 'git add limpio.txt && git commit -m x')"
[ -z "$o" ] && ok "secret-scan A1: 'git add limpio && git commit' → PASA (sin falso positivo)" || bad "secret-scan A1: falso positivo en archivo limpio; got: $o"
# A1 (4) secreto PREEXISTENTE en línea NO tocada de un archivo tracked; se cambia OTRA línea → PASA
#        (tracked: solo se escanea lo AGREGADO vs HEAD, no se re-escanea lo ya versionado).
fmeareset; printf 'aws = AKIA1234567890ABCDEF\nlinea normal\n' > "$FMEAREPO/pre.txt"
git -C "$FMEAREPO" add pre.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm pre >/dev/null 2>&1
printf 'aws = AKIA1234567890ABCDEF\nlinea CAMBIADA\n' > "$FMEAREPO/pre.txt"
o="$(scanf 'git add pre.txt && git commit -m x')"
[ -z "$o" ] && ok "secret-scan A1: secreto preexistente en línea no tocada (tracked) → PASA" || bad "secret-scan A1: falso positivo re-escaneando lo ya versionado; got: $o"
# A1 (5) commit normal con staging PREVIO (sin git add en el comando) → sigue bloqueando (no-regresión)
fmeareset; printf 'aws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/s2.txt"; git -C "$FMEAREPO" add s2.txt >/dev/null 2>&1
o="$(scanf 'git commit -m x')"
printf '%s' "$o" | grep -q '"deny"' && ok "secret-scan A1: commit normal (staging previo) sigue escaneando --cached → bloquea" || bad "secret-scan A1: regresión, commit normal ya no bloquea; got: $o"
# A1 (6) `git commit -am x` con secreto en un archivo TRACKED modificado AÚN NO staged: -a lo auto-estagea
#        al vuelo → el escaneo debe verlo (antes --cached vacío → CIEGO) → BLOQUEA
fmeareset; printf 'linea limpia\n' > "$FMEAREPO/t.txt"; git -C "$FMEAREPO" add t.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm t >/dev/null 2>&1
printf 'linea limpia\naws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/t.txt"
o="$(scanf 'git commit -am x')"
printf '%s' "$o" | grep -q '"deny"' && ok "secret-scan A1: 'git commit -am' escanea los tracked que -a auto-estagea → bloquea" || bad "secret-scan A1: 'commit -am' CIEGO al tracked modificado; got: $o"
# A1 (7) `git commit -a -m x` con cambio en tracked LIMPIO → PASA (sin falso positivo)
fmeareset; printf 'v1\n' > "$FMEAREPO/u.txt"; git -C "$FMEAREPO" add u.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm u >/dev/null 2>&1
printf 'v1\nv2 sin secretos\n' > "$FMEAREPO/u.txt"
o="$(scanf 'git commit -a -m x')"
[ -z "$o" ] && ok "secret-scan A1: 'git commit -a' con cambio limpio → PASA (sin falso positivo)" || bad "secret-scan A1: falso positivo en 'commit -a' limpio; got: $o"
# A7 (1) --no-verify DENTRO del mensaje del commit (secreto staged) → NO salta → BLOQUEA
fmeareset; printf 'aws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/s3.txt"; git -C "$FMEAREPO" add s3.txt >/dev/null 2>&1
o="$(scanf 'git commit -m "documenta el flag --no-verify"')"
printf '%s' "$o" | grep -q '"deny"' && ok "secret-scan A7: --no-verify en el MENSAJE no salta el escaneo → bloquea" || bad "secret-scan A7: --no-verify citado saltó el escaneo; got: $o"
# A7 (2) --no-verify REAL (bandera) sigue siendo escape legítimo → PASA (silencio)
o="$(scanf 'git commit --no-verify -m x')"
[ -z "$o" ] && ok "secret-scan A7: --no-verify como bandera real sigue saltando (escape legítimo)" || bad "secret-scan A7: --no-verify real dejó de saltar; got: $o"
# A-03 (FMEA post-integración): el prefijo `git -c k=v … commit` ya NO ciega el escaneo (antes rompía la
# adyacencia git+commit del gate). Secreto en un tracked modificado que -a estagearía → BLOQUEA.
fmeareset; printf 'v\n' > "$FMEAREPO/gc.txt"; git -C "$FMEAREPO" add gc.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm gc >/dev/null 2>&1
printf 'v\naws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/gc.txt"
o="$(scanf 'git -c user.email=x commit -am x')"
printf '%s' "$o" | grep -q '"deny"' && ok "secret-scan A-03: 'git -c … commit -am' escanea (prefijo ya no ciega) → bloquea" || bad "secret-scan A-03: el prefijo 'git -c' cegó el escaneo; got: $o"
# A-R4-02 (FMEA r4): las OTRAS opciones globales de git (≠ -c/-C) también rompían la adyacencia git+commit
# del gate → el escaneo NO corría. El fix generalizado de acg_normaliza_git_prefijo (compartido) las cierra.
fmeareset; printf 'v\n' > "$FMEAREPO/g2.txt"; git -C "$FMEAREPO" add g2.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm g2 >/dev/null 2>&1
printf 'v\naws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/g2.txt"
printf '%s' "$(scanf 'git --no-pager commit -am x')" | grep -q '"deny"' && ok "secret-scan A-R4-02: 'git --no-pager commit -am' escanea → bloquea" || bad "secret-scan A-R4-02: '--no-pager' cegó el escaneo; got: $(scanf 'git --no-pager commit -am x')"
printf '%s' "$(scanf 'git -P commit -am x')"         | grep -q '"deny"' && ok "secret-scan A-R4-02: 'git -P commit -am' escanea → bloquea" || bad "secret-scan A-R4-02: '-P' cegó el escaneo"
printf '%s' "$(scanf 'git --work-tree=. commit -am x')" | grep -q '"deny"' && ok "secret-scan A-R4-02: 'git --work-tree=. commit -am' escanea → bloquea" || bad "secret-scan A-R4-02: '--work-tree=' cegó el escaneo"
# A-R5-02 (FMEA r5): con el despoje ANTES de normalizar, un value-eater con valor ENTRECOMILLADO
# (`git -C "/ruta" commit`) quedaba vacío y el normalizador se comía `commit` → escaneo CIEGO (¡sin
# necesitar espacio!). Fix: normalizar el RAW (quote-aware) ANTES de despojar. Secreto en tracked que -a estagea.
fmeareset; printf 'v\n' > "$FMEAREPO/g3.txt"; git -C "$FMEAREPO" add g3.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm g3 >/dev/null 2>&1
printf 'v\naws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/g3.txt"
printf '%s' "$(scanf 'git -C "/nospace" commit -am x')"  | grep -q '"deny"' && ok "secret-scan A-R5-02: 'git -C \"/nospace\" commit -am' (valor entrecomillado sin espacio) escanea → bloquea" || bad "secret-scan A-R5-02: valor entrecomillado cegó el escaneo (despoje antes de normalizar)"
printf '%s' "$(scanf 'git -C "/a b/repo" commit -am x')" | grep -q '"deny"' && ok "secret-scan A-R5-02: 'git -C \"/a b/repo\" commit -am' (valor entrecomillado con espacio) escanea → bloquea" || bad "secret-scan A-R5-02: valor entrecomillado con espacio cegó el escaneo"
printf '%s' "$(scanf 'git --work-tree="/a b" commit -am x')" | grep -q '"deny"' && ok "secret-scan A-R5-02: 'git --work-tree=\"/a b\" commit -am' (=-form entrecomillado) escanea → bloquea" || bad "secret-scan A-R5-02: --work-tree= entrecomillado cegó el escaneo"
# A-R6-01 (FMEA r6): comilla EN MEDIO del valor de un global (`git -c user.name="a b" commit`) → mismo
# mecanismo de evasión, mismo fix (valor como secuencia). Secreto en tracked que -a estagea.
fmeareset; printf 'v\n' > "$FMEAREPO/g4.txt"; git -C "$FMEAREPO" add g4.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm g4 >/dev/null 2>&1
printf 'v\naws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/g4.txt"
printf '%s' "$(scanf 'git -c user.name="a b" commit -am x')" | grep -q '"deny"' && ok "secret-scan A-R6-01: 'git -c user.name=\"a b\" commit -am' (comilla en medio) escanea → bloquea" || bad "secret-scan A-R6-01: comilla en medio del valor cegó el escaneo"
# A-R7-01 (FMEA r7): espacio escapado con backslash en el valor global → mismo mecanismo, mismo fix.
fmeareset; printf 'v\n' > "$FMEAREPO/g5.txt"; git -C "$FMEAREPO" add g5.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm g5 >/dev/null 2>&1
printf 'v\naws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/g5.txt"
printf '%s' "$(scanf 'git -c a=b\ c commit -am x')" | grep -q '"deny"' && ok "secret-scan A-R7-01: 'git -c a=b\\ c commit -am' (espacio escapado) escanea → bloquea" || bad "secret-scan A-R7-01: el espacio escapado con backslash cegó el escaneo"
# B4 (FMEA r8): el binario Windows `git.exe commit` rompía el gate git+commit del escaneo → mismo fix (colapso git.exe→git).
fmeareset; printf 'v\n' > "$FMEAREPO/g6.txt"; git -C "$FMEAREPO" add g6.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm g6 >/dev/null 2>&1
printf 'v\naws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/g6.txt"
printf '%s' "$(scanf 'git.exe commit -am x')" | grep -q '"deny"' && ok "secret-scan B4: 'git.exe commit -am' (binario Windows) escanea → bloquea" || bad "secret-scan B4: 'git.exe' cegó el escaneo"
rm -rf "$FMEAREPO"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b2b) entorno-maquina-guard: AVISA (no bloquea) si entra algo machine-specific al .claude/memory/ del repo =="
EMREPO="$(mktemp -d "${TMPDIR:-/tmp}/brain-em.XXXXXX")"
git -C "$EMREPO" init -q >/dev/null 2>&1
git -C "$EMREPO" config user.email t@t >/dev/null 2>&1
git -C "$EMREPO" config user.name  tester >/dev/null 2>&1
mkdir -p "$EMREPO/.claude/memory"
# HOME sin copia global del guard → la dedupe no cede (corre la copia bajo prueba).
emg() { printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}" \
        | HOME="$EMREPO" CLAUDE_PROJECT_DIR="$EMREPO" bash "$HOOKS/entorno-maquina-guard.sh"; }
emreset() { git -C "$EMREPO" reset -q >/dev/null 2>&1; rm -f "$EMREPO"/.claude/memory/*.md 2>/dev/null; }
# (1) FILENAME-trampa entorno-maquina.md staged → AVISA (additionalContext, NO deny)
printf 'contenido portable\n' > "$EMREPO/.claude/memory/entorno-maquina.md"
git -C "$EMREPO" add .claude/memory/entorno-maquina.md >/dev/null 2>&1
o="$(emg 'git commit -m x')"
printf '%s' "$o" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1 \
  && ! printf '%s' "$o" | grep -q '"deny"' \
  && ok "entorno-maquina-guard: filename-trampa entorno-maquina.md → AVISA (no bloquea)" \
  || bad "entorno-maquina-guard: no avisó (o bloqueó) el filename-trampa; got: $o"
# (2) CONTENIDO machine-specific (alias + ruta de \$HOME + Rosetta sin condicional) → AVISA
emreset
printf 'alias ls=eza\nruta /Users/fulano/code/x\nSQL corre via Rosetta.\n' > "$EMREPO/.claude/memory/correr-en-local.md"
git -C "$EMREPO" add .claude/memory/correr-en-local.md >/dev/null 2>&1
o="$(emg 'git commit -m x')"
printf '%s' "$o" | grep -q 'CONTENIDO machine-specific' \
  && ok "entorno-maquina-guard: contenido machine-specific → AVISA con detalle" \
  || bad "entorno-maquina-guard: no detectó contenido machine-specific; got: $o"
# (3) contenido PORTABLE/CONDICIONAL → silencio (sin falso positivo)
emreset
printf 'Si estas en Apple Silicon usa platform: linux/amd64 (SQL via Rosetta, condicional).\nEn Windows usa Git Bash.\n' > "$EMREPO/.claude/memory/correr-en-local.md"
git -C "$EMREPO" add .claude/memory/correr-en-local.md >/dev/null 2>&1
o="$(emg 'git commit -m x')"
[ -z "$o" ] && ok "entorno-maquina-guard: contenido portable/condicional → silencio (sin falso positivo)" || bad "entorno-maquina-guard: falso positivo en contenido condicional; got: $o"
# (4) un no-commit → silencio
o="$(emg 'ls -la')"
[ -z "$o" ] && ok "entorno-maquina-guard: comando no-commit → silencio" || bad "entorno-maquina-guard: reaccionó a un no-commit; got: $o"
# (5) mención entrecomillada de 'git commit' en un grep → silencio
o="$(emg 'grep -r \"git commit\" .')"
[ -z "$o" ] && ok "entorno-maquina-guard: 'git commit' entrecomillado (grep) → silencio" || bad "entorno-maquina-guard: mordió una mención entrecomillada; got: $o"
# (6) archivo machine-specific FUERA de .claude/memory/ → silencio (fuera de alcance)
emreset
printf 'alias ls=eza\n' > "$EMREPO/notas.md"
git -C "$EMREPO" add notas.md >/dev/null 2>&1
o="$(emg 'git commit -m x')"
[ -z "$o" ] && ok "entorno-maquina-guard: archivo fuera de .claude/memory/ → silencio (fuera de alcance)" || bad "entorno-maquina-guard: reaccionó fuera de .claude/memory/; got: $o"
rm -rf "$EMREPO"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b3) proteger-arbol: avisa si un git destructivo orfanaría commits sin pushear =="
PABARE="$(mktemp -d "${TMPDIR:-/tmp}/brain-pa.XXXXXX")/remote.git"
PAREPO="$(mktemp -d "${TMPDIR:-/tmp}/brain-pa.XXXXXX")/wt"
git init --bare -q "$PABARE" >/dev/null 2>&1
git clone -q "$PABARE" "$PAREPO" >/dev/null 2>&1
git -C "$PAREPO" config user.email t@t >/dev/null 2>&1
git -C "$PAREPO" config user.name  tester >/dev/null 2>&1
printf 'base\n' > "$PAREPO/a.txt"; git -C "$PAREPO" add a.txt >/dev/null 2>&1
git -C "$PAREPO" commit -q -m base >/dev/null 2>&1
git -C "$PAREPO" push -q origin HEAD >/dev/null 2>&1
git -C "$PAREPO" branch --set-upstream-to=origin/"$(git -C "$PAREPO" rev-parse --abbrev-ref HEAD)" >/dev/null 2>&1
pa() { printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}" \
       | CLAUDE_PROJECT_DIR="$PAREPO" bash "$HOOKS/proteger-arbol.sh"; }
# sin commits en riesgo (todo pusheado) → reset --hard silencioso
o="$(pa 'git reset --hard HEAD')"
[ -z "$o" ] && ok "proteger-arbol: reset sin commits en riesgo → silencio" || bad "proteger-arbol avisó sin riesgo; got: $o"
# ahora 1 commit local SIN pushear → en riesgo
printf 'local\n' >> "$PAREPO/a.txt"; git -C "$PAREPO" add a.txt >/dev/null 2>&1
git -C "$PAREPO" commit -q -m local >/dev/null 2>&1
o="$(pa 'git reset --hard HEAD~1')"
printf '%s' "$o" | grep -q 'ORFANAR' && ok "proteger-arbol: reset --hard con commit sin pushear → AVISA" || bad "proteger-arbol NO avisó con commit en riesgo; got: $o"
# comando no-destructivo → silencio aunque haya riesgo
o="$(pa 'git status')"
[ -z "$o" ] && ok "proteger-arbol: comando no-destructivo → silencio" || bad "proteger-arbol reaccionó a no-destructivo; got: $o"
# 'git reset' entrecomillado (dato de un grep) → silencio
o="$(pa "grep -r 'git reset --hard' .")"
[ -z "$o" ] && ok "proteger-arbol: 'git reset' entrecomillado (dato) → silencio" || bad "proteger-arbol matcheó texto entrecomillado; got: $o"

# H14 — worktree AISLADO: el desastre que vigila el hook (orfanar commits del ORQUESTADOR en el árbol
# COMPARTIDO) es imposible ahí, y el workaround del bug H15 (reset --hard a la rama objetivo al arrancar)
# NO debe disparar la alarma. Montamos un worktree aislado con 1 commit adelante de su upstream (n>0).
DEFB="$(git -C "$PAREPO" rev-parse --abbrev-ref HEAD)"
PAWT="$(mktemp -d "${TMPDIR:-/tmp}/brain-pawt.XXXXXX")/iso"
git -C "$PAREPO" worktree add -q -b wtiso "$PAWT" "origin/$DEFB" >/dev/null 2>&1
git -C "$PAWT" branch --set-upstream-to=origin/"$DEFB" wtiso >/dev/null 2>&1
printf 'iso\n' >> "$PAWT/a.txt"; git -C "$PAWT" add a.txt >/dev/null 2>&1
git -C "$PAWT" commit -q -m iso >/dev/null 2>&1   # 1 commit adelante del upstream → n=1
paw() { printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}" \
        | CLAUDE_PROJECT_DIR="$PAWT" bash "$HOOKS/proteger-arbol.sh"; }
o="$(paw 'git reset --hard wtiso')"
[ -z "$o" ] && ok "proteger-arbol H14: aislado + reset a su PROPIA rama → SUPRIME (silencio)" || bad "H14: no suprimió el reset a la propia rama; got: $o"
o="$(paw 'git reset --hard develop')"
[ -z "$o" ] && ok "proteger-arbol H14: aislado + reset a una BASE (develop) → SUPRIME (workaround H15)" || bad "H14: no suprimió el reset a base; got: $o"
o="$(paw 'git reset --hard HEAD~1')"
{ printf '%s' "$o" | grep -q 'Nota (proteger-arbol)' && ! printf '%s' "$o" | grep -q 'ORFANAR'; } \
  && ok "proteger-arbol H14: aislado + OTRO objetivo → nota SUAVE (no alarma de árbol compartido)" \
  || bad "H14: aislado hacia otro objetivo no dio nota suave; got: $o"
git -C "$PAREPO" worktree remove --force "$PAWT" >/dev/null 2>&1; rm -rf "$PAWT"
rm -rf "$PABARE" "$PAREPO"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b3a2) proteger-fuente-cerebro: AVISA al editar la copia INSTALADA que TIENE fuente (regenerable) =="
# Hueco real: una regla escrita en la copia INSTALADA (~/.claude/skills|hooks) muere en el próximo
# install-brain. El guard avisa (no bloquea) si el file_path cae ahí Y existe la fuente correspondiente.
PFFIX="$(mktemp -d "${TMPDIR:-/tmp}/brain-pf.XXXXXX")"
PFH="$PFFIX/home"; PFB="$PFFIX/clon"
mkdir -p "$PFH/.claude/hooks" "$PFH/.claude/skills/cerrar-slice" "$PFB/brain/hooks" "$PFB/brain/skills/cerrar-slice"
printf 'installed\n' > "$PFH/.claude/hooks/git-branch-guard.sh"          # hook con fuente
printf 'source\n'    > "$PFB/brain/hooks/git-branch-guard.sh"
printf 'installed\n' > "$PFH/.claude/skills/cerrar-slice/SKILL.md"       # skill con fuente
printf 'source\n'    > "$PFB/brain/skills/cerrar-slice/SKILL.md"
printf 'local\n'     > "$PFH/.claude/hooks/mi-hook-local.sh"             # hook LOCAL (sin fuente)
pf() { printf '%s' "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$1\"}}" \
       | HOME="$PFH" CLAUDE_BRAIN_DIR="$PFB" bash "$HOOKS/proteger-fuente-cerebro.sh"; }
has_ctx() { printf '%s' "$1" | jq -e '.hookSpecificOutput.additionalContext | test("proteger-fuente-cerebro")' >/dev/null 2>&1; }
# (1) editar hook INSTALADO que tiene fuente → AVISA
o="$(pf "$PFH/.claude/hooks/git-branch-guard.sh")"
has_ctx "$o" && ok "proteger-fuente: editar hook instalado CON fuente → AVISA" || bad "proteger-fuente: no avisó del hook instalado; got: $o"
# (2) editar skill INSTALADA que tiene fuente → AVISA (y nombra la ruta de la fuente)
o="$(pf "$PFH/.claude/skills/cerrar-slice/SKILL.md")"
{ has_ctx "$o" && printf '%s' "$o" | jq -r '.hookSpecificOutput.additionalContext' | grep -qF "$PFB/brain/skills/cerrar-slice/SKILL.md"; } \
  && ok "proteger-fuente: editar skill instalada CON fuente → AVISA y nombra la fuente" || bad "proteger-fuente: no avisó/no nombró la fuente de la skill; got: $o"
# (3) editar hook LOCAL (sin fuente) → silencio
o="$(pf "$PFH/.claude/hooks/mi-hook-local.sh")"
[ -z "$o" ] && ok "proteger-fuente: hook local SIN fuente → silencio" || bad "proteger-fuente: avisó de un hook local; got: $o"
# (4) archivo fuera de ~/.claude/skills|hooks → silencio
o="$(pf "$PFFIX/random.txt")"
[ -z "$o" ] && ok "proteger-fuente: archivo fuera de skills|hooks → silencio (fuera de alcance)" || bad "proteger-fuente: reaccionó fuera de alcance; got: $o"
# (5) escape CLAUDE_SKIP_PROTEGER_FUENTE=1 → silencio aunque haya fuente
o="$(printf '%s' "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$PFH/.claude/hooks/git-branch-guard.sh\"}}" \
     | HOME="$PFH" CLAUDE_BRAIN_DIR="$PFB" CLAUDE_SKIP_PROTEGER_FUENTE=1 bash "$HOOKS/proteger-fuente-cerebro.sh")"
[ -z "$o" ] && ok "proteger-fuente: escape CLAUDE_SKIP_PROTEGER_FUENTE=1 → silencio" || bad "proteger-fuente: el escape no calló; got: $o"
# (6) fail-open SIN jq (PATH sin jq; bash por ruta absoluta para no depender del PATH) → silencio
BASHBIN="$(command -v bash)"
o="$(printf '%s' "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$PFH/.claude/hooks/git-branch-guard.sh\"}}" \
     | PATH="/nonexistent-dir" HOME="$PFH" CLAUDE_BRAIN_DIR="$PFB" "$BASHBIN" "$HOOKS/proteger-fuente-cerebro.sh")"
[ -z "$o" ] && ok "proteger-fuente: fail-open sin jq → silencio (no bloquea)" || bad "proteger-fuente: no falló abierto sin jq; got: $o"
# OS-parity/estático: el hook usa \$HOME y \${CLAUDE_BRAIN_DIR}, no rutas hardcodeadas de un \$HOME
grep -qE '/Users/[A-Za-z]|/home/[A-Za-z]' "$HOOKS/proteger-fuente-cerebro.sh" \
  && bad "proteger-fuente: tiene una ruta hardcodeada de \$HOME (no portable)" \
  || ok "proteger-fuente: sin rutas hardcodeadas de \$HOME (OS-parity)"
{ grep -q 'HOME/.claude' "$HOOKS/proteger-fuente-cerebro.sh" && grep -q 'CLAUDE_BRAIN_DIR' "$HOOKS/proteger-fuente-cerebro.sh"; } \
  && ok "proteger-fuente: deriva rutas de \$HOME y \${CLAUDE_BRAIN_DIR}" || bad "proteger-fuente: no usa \$HOME/\${CLAUDE_BRAIN_DIR}"
# MANIFEST bien formado con el hook nuevo (tier global, kind hook) + install-brain lo cabla
grep -qE '^proteger-fuente-cerebro[[:space:]]+global[[:space:]]+hook$' "$HOOKS/MANIFEST" \
  && ok "proteger-fuente: declarado en el MANIFEST (global hook)" || bad "proteger-fuente: falta/mal en el MANIFEST"
grep -qE 'proteger-fuente-cerebro\)[[:space:]]*echo[[:space:]]*"PreToolUse\|Edit' "$INSTALLER" \
  && ok "proteger-fuente: cableado (ev_de → PreToolUse/Edit|Write|MultiEdit, derivado del MANIFEST)" \
  || bad "proteger-fuente: NO mapeado en ev_de() de install-brain.sh (no se cablearía)"
rm -rf "$PFFIX"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b3a3) verificar-cerebro: drift-check instalada-vs-fuente (idéntica→0; difiere→la lista; local→ignora) =="
DVFIX="$(mktemp -d "${TMPDIR:-/tmp}/brain-dv.XXXXXX")"
DVH="$DVFIX/home"; DVB="$DVFIX/clon"
mkdir -p "$DVH/.claude/hooks" "$DVH/.claude/skills" "$DVB/brain/hooks" "$DVB/brain/skills"
printf '%s\n' 'alpha  global  hook' > "$DVB/brain/hooks/MANIFEST"   # MANIFEST mínimo para no ensuciar
dv() { HOME="$DVH" CLAUDE_BRAIN_DIR="$DVB" bash "$HOOKS/verificar-cerebro.sh" 2>&1; }
# Fase 1 — instalada idéntica a la fuente → 0 drift
printf 'same\n' > "$DVH/.claude/hooks/alpha.sh"
printf 'same\n' > "$DVB/brain/hooks/alpha.sh"
dvout="$(dv)"
printf '%s' "$dvout" | grep -q 'sin drift instalada-vs-fuente en hooks' \
  && ok "verificar-cerebro drift: instalada idéntica → 0 drift" || bad "verificar-cerebro drift: no reportó 'sin drift'; got: $dvout"
# Fase 2 — instalada con una línea EXTRA (y más nueva) → la lista con dirección; un local (sin fuente) → se ignora
printf 'orig\n'          > "$DVB/brain/hooks/beta.sh";  touch -t 200001010000 "$DVB/brain/hooks/beta.sh"
printf 'orig\nEXTRA\n'   > "$DVH/.claude/hooks/beta.sh"                       # difiere y es más nueva
printf 'solo-local\n'    > "$DVH/.claude/hooks/gamma.sh"                      # sin fuente → NO es este drift
dvout2="$(dv)"
printf '%s' "$dvout2" | grep -q 'drift instalada≠fuente (hooks): beta.sh' \
  && ok "verificar-cerebro drift: instalada que difiere → la LISTA" || bad "verificar-cerebro drift: no listó beta.sh; got: $dvout2"
printf '%s' "$dvout2" | grep -q 'beta.sh.*M.S NUEVA' \
  && ok "verificar-cerebro drift: distingue dirección (instalada más nueva → portar a la fuente)" || bad "verificar-cerebro drift: no marcó la dirección; got: $dvout2"
printf '%s' "$dvout2" | grep -q 'gamma.sh' \
  && bad "verificar-cerebro drift: reportó un archivo LOCAL sin fuente (falso positivo); got: $dvout2" \
  || ok "verificar-cerebro drift: archivo local sin fuente → NO se reporta"
rm -rf "$DVFIX"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b3b) limpiar-worktrees: base de integración configurable + detección por cherry (G7) =="
# Flujo mini-develop: la base es una rama PERSONAL (no develop) y las ramitas se integran por merge
# LOCAL (a veces squash) → antes quedaban zombies eternos (base fija a develop + sin detección por
# equivalencia de parche). Ahora: CLAUDE_INTEGRACION_BASE fija la base; git cherry caza el squash local.
G7ROOT="$(mktemp -d "${TMPDIR:-/tmp}/brain-g7.XXXXXX")"; G7REPO="$G7ROOT/repo"; mkdir -p "$G7REPO"
git -C "$G7REPO" init -q >/dev/null 2>&1
git -C "$G7REPO" symbolic-ref HEAD refs/heads/miDevelop >/dev/null 2>&1
git -C "$G7REPO" config user.email t@t >/dev/null 2>&1
git -C "$G7REPO" config user.name  tester >/dev/null 2>&1
printf 'base\n' > "$G7REPO/base.txt"; git -C "$G7REPO" add base.txt >/dev/null 2>&1; git -C "$G7REPO" commit -qm base >/dev/null 2>&1
# ramita MERGEADA por squash LOCAL a la rama personal (no queda de ancestro, pero su parche sí está)
git -C "$G7REPO" checkout -q -b feat/hecha >/dev/null 2>&1
printf 'x\n' > "$G7REPO/f.txt"; git -C "$G7REPO" add f.txt >/dev/null 2>&1; git -C "$G7REPO" commit -qm hecha >/dev/null 2>&1
git -C "$G7REPO" checkout -q miDevelop >/dev/null 2>&1
git -C "$G7REPO" merge --squash feat/hecha >/dev/null 2>&1; git -C "$G7REPO" commit -qm "squash feat/hecha" >/dev/null 2>&1
git -C "$G7REPO" worktree add -q "$G7ROOT/wt-hecha" feat/hecha >/dev/null 2>&1
# ramita VIVA (commits nuevos aún no integrados)
git -C "$G7REPO" checkout -q -b feat/viva miDevelop >/dev/null 2>&1
printf 'y\n' > "$G7REPO/g.txt"; git -C "$G7REPO" add g.txt >/dev/null 2>&1; git -C "$G7REPO" commit -qm viva >/dev/null 2>&1
git -C "$G7REPO" checkout -q miDevelop >/dev/null 2>&1
git -C "$G7REPO" worktree add -q "$G7ROOT/wt-viva" feat/viva >/dev/null 2>&1
out="$(cd "$G7REPO" && CLAUDE_INTEGRACION_BASE=miDevelop bash "$HOOKS/limpiar-worktrees.sh" --dry-run 2>&1)"
printf '%s' "$out" | grep -q 'zombie.*feat/hecha' && ok "G7: ramita squash-mergeada a rama personal (base configurable) → zombie por cherry" || bad "G7: no detectó zombie por cherry; got: $out"
printf '%s' "$out" | grep -q 'DEJADO.*feat/viva'  && ok "G7: ramita viva no integrada → conservada"                                     || bad "G7: no conservó la ramita viva; got: $out"
rm -rf "$G7ROOT"

# ─────────────────────────────────────────────────────────────────────────────
echo "== (b3c) limpiar-ramas: barre ramas LOCALES integradas (squash) y CONSERVA trabajo vivo + protegidas =="
# El squash rompe `git branch -d` (la rama no queda de ancestro) y `fetch --prune` no toca ramas locales
# → se acumulan. limpiar-ramas usa la MISMA lib zombie (ramas-zombie.sh) que limpiar-worktrees.
LRROOT="$(mktemp -d "${TMPDIR:-/tmp}/brain-lr.XXXXXX")"; LRREPO="$LRROOT/repo"; mkdir -p "$LRREPO"
git -C "$LRREPO" init -q >/dev/null 2>&1
git -C "$LRREPO" symbolic-ref HEAD refs/heads/miDevelop >/dev/null 2>&1
git -C "$LRREPO" config user.email t@t >/dev/null 2>&1; git -C "$LRREPO" config user.name tester >/dev/null 2>&1
printf 'base\n' > "$LRREPO/base.txt"; git -C "$LRREPO" add base.txt >/dev/null 2>&1; git -C "$LRREPO" commit -qm base >/dev/null 2>&1
# (1) rama integrada por squash local → zombie por cherry → debe borrarse
git -C "$LRREPO" checkout -q -b feat/hecha >/dev/null 2>&1
printf 'x\n' > "$LRREPO/f.txt"; git -C "$LRREPO" add f.txt >/dev/null 2>&1; git -C "$LRREPO" commit -qm hecha >/dev/null 2>&1
git -C "$LRREPO" checkout -q miDevelop >/dev/null 2>&1
git -C "$LRREPO" merge --squash feat/hecha >/dev/null 2>&1; git -C "$LRREPO" commit -qm "squash feat/hecha" >/dev/null 2>&1
# (2) rama viva con commits únicos → conservar
git -C "$LRREPO" checkout -q -b feat/viva miDevelop >/dev/null 2>&1
printf 'y\n' > "$LRREPO/g.txt"; git -C "$LRREPO" add g.txt >/dev/null 2>&1; git -C "$LRREPO" commit -qm viva >/dev/null 2>&1
# (3) rama keep/ integrada (contenido en base) PERO protegida → conservar pese a ser zombie
git -C "$LRREPO" checkout -q -b keep/respaldo miDevelop >/dev/null 2>&1
git -C "$LRREPO" checkout -q miDevelop >/dev/null 2>&1
lrout="$(cd "$LRREPO" && CLAUDE_INTEGRACION_BASE=miDevelop bash "$HOOKS/limpiar-ramas.sh" --dry-run --no-fetch 2>&1)"
printf '%s' "$lrout" | grep -q 'borraría: feat/hecha'      && ok "b3c: rama squash-integrada → se barrería"                  || bad "b3c: no marcó feat/hecha para borrar; got: $lrout"
printf '%s' "$lrout" | grep -q 'CONSERVADA.*feat/viva'     && ok "b3c: rama con trabajo sin integrar → conservada"            || bad "b3c: no conservó feat/viva; got: $lrout"
printf '%s\n' "$lrout" | grep -v '^limpiar-ramas:' | grep -q 'miDevelop' && bad "b3c: tocó la base/rama actual miDevelop; got: $lrout" || ok "b3c: la base/rama actual (miDevelop) NO se lista para borrar ni conservar"
printf '%s' "$lrout" | grep -q 'keep/respaldo' && bad "b3c: keep/respaldo NO debe tocarse (protegida)" || ok "b3c: keep/* protegida (no se lista)"
# teeth: sin la protección, keep/respaldo sería zombie (ancestro de base) — confirma que la protección es la que lo salva
git -C "$LRREPO" merge-base --is-ancestor keep/respaldo miDevelop 2>/dev/null && ok "b3c(teeth): keep/respaldo ES ancestro de base (zombie real) → solo la protección lo conserva" || bad "b3c(teeth): keep/respaldo no era ancestro (test mal armado)"
rm -rf "$LRROOT"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b3d) bz_resolver_base: AUTO-detecta la mini-develop (Develop<Usuario>) sin CLAUDE_INTEGRACION_BASE =="
# Bug real (2026-07-28): en un repo con flujo mini-develop (rama personal DevelopUnjordi sacada de develop),
# el resolver caía a `develop` porque existía local → las ramitas integradas a la MINI se veían "no
# integradas" y nunca se barrían. La base correcta del dev es su Develop<Usuario>.
RBROOT="$(mktemp -d "${TMPDIR:-/tmp}/brain-rb.XXXXXX")"; RBREPO="$RBROOT/repo"; mkdir -p "$RBREPO"
git -C "$RBREPO" init -q >/dev/null 2>&1
git -C "$RBREPO" config user.email t@t >/dev/null 2>&1; git -C "$RBREPO" config user.name tester >/dev/null 2>&1
git -C "$RBREPO" symbolic-ref HEAD refs/heads/develop >/dev/null 2>&1
printf 'base\n' > "$RBREPO/a.txt"; git -C "$RBREPO" add a.txt >/dev/null 2>&1; git -C "$RBREPO" commit -qm base >/dev/null 2>&1
git -C "$RBREPO" branch DevelopUnjordi >/dev/null 2>&1   # mini-develop sacada de develop
( . "$HOOKS/ramas-zombie.sh"
  # (1) HEAD en una ramita, con develop Y DevelopUnjordi locales → base = la MINI (no develop)
  git -C "$RBREPO" checkout -q -b feat/x DevelopUnjordi >/dev/null 2>&1
  [ "$(bz_resolver_base "$RBREPO")" = "DevelopUnjordi" ] && ok "b3d: mini-develop preferida sobre develop (HEAD en ramita)" || bad "b3d: NO detectó DevelopUnjordi; got: $(bz_resolver_base "$RBREPO")"
  # (2) HEAD parado en la propia mini → esa misma
  git -C "$RBREPO" checkout -q DevelopUnjordi >/dev/null 2>&1
  [ "$(bz_resolver_base "$RBREPO")" = "DevelopUnjordi" ] && ok "b3d: HEAD en la mini → base = la mini" || bad "b3d: HEAD en mini no se resolvió a sí misma; got: $(bz_resolver_base "$RBREPO")"
  # (3) override explícito SIEMPRE gana
  [ "$(CLAUDE_INTEGRACION_BASE=otra bz_resolver_base "$RBREPO")" = "otra" ] && ok "b3d: CLAUDE_INTEGRACION_BASE gana sobre la auto-detección" || bad "b3d: el override no ganó"
)
# (4) SIN mini-develop (flujo develop puro) → cae a develop, sin regresión
RB2="$RBROOT/repo2"; mkdir -p "$RB2"; git -C "$RB2" init -q >/dev/null 2>&1
git -C "$RB2" config user.email t@t >/dev/null 2>&1; git -C "$RB2" config user.name tester >/dev/null 2>&1
git -C "$RB2" symbolic-ref HEAD refs/heads/develop >/dev/null 2>&1
printf 'b\n' > "$RB2/a.txt"; git -C "$RB2" add a.txt >/dev/null 2>&1; git -C "$RB2" commit -qm base >/dev/null 2>&1
( . "$HOOKS/ramas-zombie.sh"
  [ "$(bz_resolver_base "$RB2")" = "develop" ] && ok "b3d: sin Develop<Usuario> local → base = develop (sin regresión)" || bad "b3d: regresión, no cayó a develop; got: $(bz_resolver_base "$RB2")"
)
rm -rf "$RBROOT"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b3e) bz_es_zombie: regla (b) 'remota borrada' NO borra a ciegas una rama con commits propios (FMEA A5) =="
# A5/MEDIO-3 (PÉRDIDA DE DATOS): la regla (b) marcaba zombie por "remota ausente" sin re-chequear si la
# rama traía commits VIVOS no integrados → limpiar-ramas/-worktrees hacían `branch -D` irreversible sobre
# trabajo real (remota borrada por rename/limpieza, o commits post-merge sin pushear). Fix: (b) solo
# declara zombie si la rama NO tiene commits propios no equivalentes a la base (git cherry sin '+').
BZROOT="$(mktemp -d "${TMPDIR:-/tmp}/brain-bz.XXXXXX")"; BZBARE="$BZROOT/remote.git"; BZREPO="$BZROOT/repo"
git init -q --bare "$BZBARE" >/dev/null 2>&1
git init -q "$BZREPO" >/dev/null 2>&1
git -C "$BZREPO" symbolic-ref HEAD refs/heads/miDevelop >/dev/null 2>&1
git -C "$BZREPO" config user.email t@t >/dev/null 2>&1; git -C "$BZREPO" config user.name tester >/dev/null 2>&1
git -C "$BZREPO" remote add origin "$BZBARE" >/dev/null 2>&1
printf 'base\n' > "$BZREPO/base.txt"; git -C "$BZREPO" add base.txt >/dev/null 2>&1; git -C "$BZREPO" commit -qm base >/dev/null 2>&1
git -C "$BZREPO" push -q -u origin miDevelop >/dev/null 2>&1
( . "$HOOKS/ramas-zombie.sh"
  # CASO 1 — remota gone CON commits propios NO equivalentes → CONSERVAR (teeth del fix A5)
  git -C "$BZREPO" checkout -q -b feat/viva miDevelop >/dev/null 2>&1
  printf 'trabajo-vivo\n' > "$BZREPO/viva.txt"; git -C "$BZREPO" add viva.txt >/dev/null 2>&1; git -C "$BZREPO" commit -qm "commit propio no integrado" >/dev/null 2>&1
  git -C "$BZREPO" push -q -u origin feat/viva >/dev/null 2>&1
  git -C "$BZREPO" push -q origin --delete feat/viva >/dev/null 2>&1   # remota borrada (rename/limpieza)
  git -C "$BZREPO" checkout -q miDevelop >/dev/null 2>&1
  # teeth: la rama SÍ tiene commit propio ('+') y su remota YA no existe → antes (b) la borraba
  git -C "$BZREPO" cherry miDevelop feat/viva 2>/dev/null | grep -q '^+' && ok "b3e(teeth): feat/viva tiene commit propio no equivalente ('+')" || bad "b3e(teeth): test mal armado, feat/viva sin '+'"
  ! git -C "$BZREPO" ls-remote --exit-code --heads origin feat/viva >/dev/null 2>&1 && ok "b3e(teeth): la remota de feat/viva YA no existe (gatillo de la regla b)" || bad "b3e(teeth): la remota seguía existiendo"
  bz_es_zombie "$BZREPO" feat/viva miDevelop && bad "b3e: A5 REGRESIÓN — remota gone CON commits únicos se declaró zombie (PÉRDIDA DE DATOS)" || ok "b3e: remota gone CON commits únicos no equivalentes → NO zombie (conserva)"
  # CASO 2 — remota gone SIN commits propios (squash-mergeada, patch-equivalente) → zombie (se barre)
  git -C "$BZREPO" checkout -q -b feat/hecha miDevelop >/dev/null 2>&1
  printf 'x\n' > "$BZREPO/f.txt"; git -C "$BZREPO" add f.txt >/dev/null 2>&1; git -C "$BZREPO" commit -qm hecha >/dev/null 2>&1
  git -C "$BZREPO" push -q -u origin feat/hecha >/dev/null 2>&1
  git -C "$BZREPO" checkout -q miDevelop >/dev/null 2>&1
  git -C "$BZREPO" merge --squash feat/hecha >/dev/null 2>&1; git -C "$BZREPO" commit -qm "squash feat/hecha" >/dev/null 2>&1   # integra su parche
  git -C "$BZREPO" push -q origin --delete feat/hecha >/dev/null 2>&1   # remota borrada al mergear
  bz_es_zombie "$BZREPO" feat/hecha miDevelop && ok "b3e: remota gone SIN commits únicos (patch-equivalente) → zombie (se barre)" || bad "b3e: no barrió una rama genuinamente integrada con remota gone"
)
rm -rf "$BZROOT"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b3f) delegacion-reporte: solo reacciona a Task, y el nudge es CONDICIONAL a mutación (FMEA MEDIO-6) =="
# MEDIO-6 (cry-wolf): antes gritaba "appenda bitácora / limpia worktree" para TODO Task, incluidos los
# read-only (búsquedas, auditorías) → el orquestador se desensibiliza. Fix: el mensaje se subordina a la
# mutación ("SI tu agente mutó… / SI fue read-only, ignóralo"). No se puede detectar la mutación fiable
# desde PostToolUse (vive en el transcript del sub-agente), así que se suaviza el texto en vez de adivinar.
dr() { printf '%s' "$1" | bash "$HOOKS/delegacion-reporte.sh"; }
is_silent "$(dr '{"tool_name":"Bash"}')" && ok "delegacion-reporte: tool no-Task → silencio" || bad "delegacion-reporte: reaccionó a un no-Task"
DROUT="$(dr '{"tool_name":"Task"}')"
printf '%s' "$DROUT" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null 2>&1 \
  && ok "delegacion-reporte: Task → emite hookSpecificOutput PostToolUse válido" || bad "delegacion-reporte: JSON PostToolUse inválido; got: $DROUT"
printf '%s' "$DROUT" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -qiE 'si .*mut|read-only' \
  && ok "delegacion-reporte: el nudge es CONDICIONAL a mutación (no un grito para todo Task)" || bad "delegacion-reporte: el nudge no quedó condicionado a mutación (cry-wolf)"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b3c) git-branch-guard: bloquea push/merge REAL a main/develop, NO una MENCIÓN entrecomillada =="
# HOME AISLADO SIN copia global del hook: si no, la cláusula de dedupe doble-cableado (la copia del
# repo CEDE cuando existe ~/.claude/hooks/…) haría que el guard salga en silencio en una máquina con el
# cerebro instalado globalmente → falso FAIL. (Igual que el gb() de b1d, que usa $GBHOME.)
mkdir -p "$FAKEHOME/_nohooks/.claude"
gbg() { printf '{"tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)" | HOME="$FAKEHOME/_nohooks" bash "$HOOKS/git-branch-guard.sh"; }
is_deny   "$(gbg 'git push origin develop')"                              && ok "gbg: push real a develop → deny (dientes intactos)"           || bad "gbg: NO bloqueó un push real a develop"
is_silent "$(gbg 'git push -u origin feat/x')"                            && ok "gbg: push a una ramita → pasa"                                || bad "gbg: bloqueó un push a ramita"
is_silent "$(gbg 'git commit -m "doc: no hagas git push a develop"')"     && ok "gbg: 'push…develop' en mensaje de commit (dato) → pasa"       || bad "gbg: bloqueó una mención entrecomillada en commit (regresión del fix de comillas)"
is_silent "$(gbg 'grep -rn "git push origin develop" .claude/')"          && ok "gbg: 'push…develop' en arg de grep (dato) → pasa"             || bad "gbg: bloqueó una frase entrecomillada en grep (regresión del fix de comillas)"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b3d) confirmar-merge-develop: el CONF_RE reconoce el imperativo 'haz merge a develop' =="
CMDCR=$(grep "CONF_RE=" "$HOOKS/confirmar-merge-develop.sh" | sed "s/^[^']*'//; s/'\$//")
printf '%s' "tonces, haz merge a develop de la rama X" | grep -qiE "$CMDCR" && ok "confirmar: reconoce 'haz merge a develop' (imperativo)" || bad "confirmar: NO reconoce 'haz merge a develop' (regresión del CONF_RE)"
printf '%s' "ya mergea eso"                            | grep -qiE "$CMDCR" && ok "confirmar: reconoce 'mergea'"                            || bad "confirmar: NO reconoce 'mergea'"
printf '%s' "sí, plz, súbelo hasta develop"            | grep -qiE "$CMDCR" && ok "confirmar: reconoce 'súbelo hasta develop' (precisión: subir/llevar/mandar → develop)" || bad "confirmar: NO reconoce 'súbelo hasta develop' (falso-FRENO)"
printf '%s' "llévalo a develop porfa"                  | grep -qiE "$CMDCR" && ok "confirmar: reconoce 'llévalo a develop'"                   || bad "confirmar: NO reconoce 'llévalo a develop'"
printf '%s' "sigue trabajando, no pares"               | grep -qiE "$CMDCR" && bad "confirmar: FALSO POSITIVO con 'sigue trabajando'"          || ok "confirmar: 'sigue/avanza' NO dispara CONF (correcto)"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b4) dod-verificar: cierre/claim-visual sin evidencia bloquea; con OK o tool de navegador, no =="
DODTX="$FAKEHOME/dod-transcript.jsonl"
dod() { # dod "<texto final asistente>" "<línea extra de tool/edit o vacío>" "<texto del USUARIO (opcional)>"
  # $3 = mensaje del USUARIO (default "haz el cambio"). ALTO-1: la marca (1)/(2) se deriva de AQUÍ, no
  # de la prosa del asistente → los tests de confirmación ponen el OK en el mensaje del usuario.
  { jq -nc --arg u "${3:-haz el cambio}" '{type:"user",message:{role:"user",content:[{type:"text",text:$u}]}}'
    [ -n "$2" ] && printf '%s\n' "$2"
    jq -nc --arg t "$1" '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:$t}]}}'
  } > "$DODTX"
  printf '%s' "{\"stop_hook_active\":false,\"transcript_path\":\"$DODTX\"}" | bash "$HOOKS/dod-verificar.sh"
}
is_block() { printf '%s' "$1" | jq -e '.decision == "block"' >/dev/null 2>&1; }
EDITR='{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Edit","input":{"file_path":"src/Foo.razor"}}]}}'
BROWSERT='{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"mcp__claude-in-chrome__navigate","input":{}}]}}'
is_block "$(dod '¡Cerrado! 🏁 el módulo quedó terminado.' "$EDITR")" && ok "dod B1: 'cerrado 🏁' + código sin OK → bloquea" || bad "dod B1 NO bloqueó cierre sin evidencia"
is_block "$(dod 'Lo dejé en preview, con tu OK lo cierro.' "$EDITR")" && bad "dod bloqueó lenguaje de estatus" || ok "dod: 'en preview / con tu OK' → no bloquea"
is_block "$(dod 'Quedó idéntico al mockup, se ve tal cual.' "$EDITR")" && ok "dod B2: claim visual sin browser-tool → bloquea (a ciegas)" || bad "dod B2 NO bloqueó claim visual a ciegas"
o="$(dod 'En Chrome se ve como el mockup.' "$BROWSERT")"; is_block "$o" && bad "dod B2 bloqueó con browser-tool presente; got: $o" || ok "dod B2: claim visual + browser-tool → no bloquea"
# ALTO-1 (FMEA 2026-07-30): la marca (1)/(2) se deriva del MENSAJE DEL USUARIO, no de la prosa de Claude.
# (a) confirmación GENUINA del usuario en SU mensaje → no bloquea.
is_block "$(dod 'Quedó listo el módulo.' "$EDITR" 'sí, lo validé en QA y diste el ok, ciérralo')" && bad "dod ALTO-1: bloqueó con (1) confirmación del USUARIO en su mensaje" || ok "dod ALTO-1: confirmación del USUARIO en su mensaje → no bloquea"
# (b) AUTO-ATESTIGUAMIENTO: Claude NARRA que el usuario confirmó, pero el usuario NO lo dijo → bloquea.
is_block "$(dod 'El usuario ya confirmó y dio el visto bueno; quedó listo el módulo.' "$EDITR")" && ok "dod ALTO-1: Claude narra 'el usuario confirmó' sin que el usuario lo dijera → bloquea (no se auto-atestigua)" || bad "dod ALTO-1: el auto-atestiguamiento de Claude satisfizo el candado (bug ALTO-1)"
# (c) imperativo de cierre del usuario ("sí, quedó, ciérralo") → no bloquea.
is_block "$(dod 'Quedó terminado el módulo.' "$EDITR" 'sí, quedó, ciérralo')" && bad "dod ALTO-1: bloqueó con autorización expresa de cierre del usuario ('ciérralo')" || ok "dod ALTO-1: 'sí, quedó, ciérralo' del usuario → no bloquea"
# P1 (precisión): una PREGUNTA no es un cierre, aunque traiga léxico de cierre → NO dispara
is_block "$(dod '¿ya quedó terminado el módulo?' "$EDITR")" && bad "dod P1: bloqueó una PREGUNTA (falso positivo del UUID)" || ok "dod P1: pregunta con léxico de cierre → no bloquea"
is_block "$(dod 'Terminé el fix. ¿Lo cierro y abro el MR?' "$EDITR")" && bad "dod P1: bloqueó una oferta que termina preguntando" || ok "dod P1: mensaje que termina en pregunta → no bloquea"
# G1 (precisión): una pregunta co-ubicada NO debe salvar un CLAIM de cierre AFIRMADO en el mismo
# mensaje (la evasión "Listo, quedó terminado. ¿Reviso algo más?"). El claim se evalúa sobre el texto
# SIN los tramos ¿…?: si el cierre está afirmado FUERA de la pregunta, se bloquea igual.
is_block "$(dod 'Listo, quedó terminado el módulo. ¿Reviso algo más?' "$EDITR")" && ok "dod G1: claim afirmado + pregunta aparte → bloquea (no se salva por la pregunta)" || bad "dod G1: la pregunta co-ubicada salvó un cierre afirmado (evasión)"
is_block "$(dod 'Todo quedó funcionando y en producción. ¿Avanzo con el siguiente?' "$EDITR")" && ok "dod G1: cierre afirmado + pregunta neutra → bloquea" || bad "dod G1: una pregunta neutra evadió un cierre afirmado"
# H4 (precisión): un ESTATUS DÉBIL (deferir/avisar/consultar) co-ubicado NO salva un CLAIM afirmado —
# antes "Listo, quedó terminado. Dime si reviso algo más." se salvaba con "dime si".
is_block "$(dod 'Listo, quedó terminado. Dime si reviso algo más.' "$EDITR")" && ok "dod H4: claim afirmado + estatus débil ('dime si') → bloquea (no lo salva)" || bad "dod H4: un estatus débil salvó un cierre afirmado (evasión)"
# H4 (contrapeso, NO sobre-disparar): el léxico PRESCRITO de downgrade escapa AUNQUE haya palabra de
# cierre — "quedó terminado pero lo dejo EN PREVIEW, a tu revisión" es honesto, no un falso LISTO.
is_block "$(dod 'El módulo quedó terminado, pero lo dejo en preview, a tu revisión.' "$EDITR")" && bad "dod H4: bloqueó el léxico de downgrade PRESCRITO (falso positivo)" || ok "dod H4: 'quedó terminado … en preview / a tu revisión' → no bloquea (downgrade explícito)"
# H4: un estatus débil SIN claim de cierre sigue escapando (es puro estatus/espera)
is_block "$(dod 'Voy avanzando; te aviso cuando termine.' "$EDITR")" && bad "dod H4: bloqueó estatus débil sin claim" || ok "dod H4: estatus débil sin claim → no bloquea"
# G2(a): editar por Bash (sed -i / redirección) SÍ es "tocar código" aunque no haya "file_path".
BASHSED='{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"sed -i \"s/a/b/\" src/Foo.cs"}}]}}'
BASHREDIR='{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"cat > src/Bar.razor <<EOF\ncontenido\nEOF"}}]}}'
BASHREAD='{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"dotnet build 2>/dev/null | tee build.log"}}]}}'
is_block "$(dod 'Listo, quedó terminado el módulo.' "$BASHSED")" && ok "dod G2a: edición por 'sed -i' (sin file_path) cuenta como código → bloquea" || bad "dod G2a: 'sed -i' evadió el candado (no detectó código tocado)"
is_block "$(dod 'Listo, quedó terminado el módulo.' "$BASHREDIR")" && ok "dod G2a: redirección '> Bar.razor' cuenta como código → bloquea" || bad "dod G2a: redirección a código evadió el candado"
is_block "$(dod 'Listo, quedó terminado el módulo.' "$BASHREAD")" && bad "dod G2a: falso positivo — build+tee a .log/dev-null no es tocar código" || ok "dod G2a: build/tee a .log|/dev/null → NO cuenta como código (sin falso positivo)"
# G2(b): el bloqueo de QA-visual-a-ciegas NO se suprime por la palabra "screenshot" en PROSA;
# solo un tool_use REAL de navegador lo evita (estructura, no substring).
is_block "$(dod 'Quedó igual al mockup. No corrí screenshot, pero confío en que se ve bien.' "$EDITR")" && ok "dod G2b: 'screenshot' en prosa (sin browser-tool) → sigue bloqueando (a ciegas)" || bad "dod G2b: la palabra 'screenshot' en prosa suprimió el bloqueo visual"
# P2a (precisión): un PASO MECÁNICO del proceso ("checkpoint hecho", "push hecho", "MR abierto",
# "memoria actualizada") NO es un cierre de entregable → no dispara (caso real 2026-07-15: el freno
# saltó por "✅ Listo — checkpoint hecho"). Se enmascara la frase mecánica y el claim se evalúa
# sobre el residuo.
is_block "$(dod '✅ Checkpoint hecho' "$EDITR")" && bad "dod P2a: bloqueó '✅ Checkpoint hecho' (paso mecánico, falso positivo)" || ok "dod P2a: '✅ Checkpoint hecho' → no bloquea (paso mecánico)"
is_block "$(dod '✅ Listo — checkpoint hecho, hilo volcado.' "$EDITR")" && bad "dod P2a: bloqueó '✅ Listo — checkpoint hecho' (el caso real del 2026-07-15)" || ok "dod P2a: '✅ Listo — checkpoint hecho, hilo volcado' → no bloquea (caso real)"
is_block "$(dod 'Push hecho a la ramita, MR abierto.' "$EDITR")" && bad "dod P2a: bloqueó 'push hecho…MR abierto' (proceso git, falso positivo)" || ok "dod P2a: 'push hecho a la ramita, MR abierto' → no bloquea (proceso git)"
is_block "$(dod 'Memoria actualizada y bitácora al día. ✅ Hecho el commit.' "$EDITR")" && bad "dod P2a: bloqueó 'memoria actualizada / bitácora al día / hecho el commit'" || ok "dod P2a: 'memoria actualizada, bitácora al día, hecho el commit' → no bloquea"
# P2a FAIL-SAFE: si la frase mezcla paso mecánico Y claim de ENTREGABLE, el claim manda → bloquea.
is_block "$(dod 'Push hecho y la feature ya funciona.' "$EDITR")" && ok "dod P2a fail-safe: 'push hecho Y la feature ya funciona' → bloquea (el claim de entregable manda)" || bad "dod P2a fail-safe: el paso mecánico tapó un claim de entregable (evasión)"
is_block "$(dod 'MR abierto y el endpoint quedó terminado.' "$EDITR")" && ok "dod P2a fail-safe: 'MR abierto Y el endpoint quedó terminado' → bloquea" || bad "dod P2a fail-safe: 'MR abierto' tapó el cierre del endpoint (evasión)"
# P2b (precisión): celebración SIN entregable no dispara por sí sola — 🎉 dejó de ser gatillo
# standalone ("quedó el día" no es "quedó listo/terminado" → no hay claim textual); 🏁 sigue siendo cierre.
is_block "$(dod '🎉 ¡Qué bonito quedó el día!' "$EDITR")" && bad "dod P2b: bloqueó celebración sin entregable ('🎉 qué bonito quedó el día')" || ok "dod P2b: '🎉 ¡qué bonito quedó el día!' → no bloquea (celebración sin entregable)"
is_block "$(dod '¡Genial! ¡Vamos! ✨🚀' "$EDITR")" && bad "dod P2b: bloqueó interjecciones/emojis sin claim" || ok "dod P2b: interjecciones + emojis sin claim → no bloquea"
is_block "$(dod '🎉 El módulo quedó listo.' "$EDITR")" && ok "dod P2b fail-safe: '🎉 el módulo quedó listo' → bloquea (el claim textual dispara solo)" || bad "dod P2b fail-safe: el 🎉 dejó pasar un cierre de entregable"
# Dientes intactos: cierres de ENTREGABLE reales siguen exigiendo la marca (1)/(2).
is_block "$(dod 'El módulo de auth quedó listo.' "$EDITR")" && ok "dod dientes: 'el módulo de auth quedó listo' → sigue bloqueando" || bad "dod dientes: dejó pasar 'el módulo de auth quedó listo' (aflojado)"
is_block "$(dod 'Ya funciona el widget.' "$EDITR")" && ok "dod dientes: 'ya funciona el widget' → sigue bloqueando" || bad "dod dientes: dejó pasar 'ya funciona el widget' (aflojado)"
is_block "$(dod 'Terminamos la migración.' "$EDITR")" && ok "dod dientes: 'terminamos la migración' → sigue bloqueando" || bad "dod dientes: dejó pasar 'terminamos la migración' (aflojado)"
# ALTO-2 (FMEA 2026-07-30): un fan-out (tool Task) edita en el transcript del SUB-AGENTE, invisible aquí
# → un Task en el turno cuenta como POSIBLE código tocado y entra al gate de evidencia (1)/(2).
TASKT='{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Task","input":{}}]}}'
is_block "$(dod 'La ola quedó lista y en producción.' "$TASKT")" && ok "dod ALTO-2: claim de cierre + solo un Task (sin evidencia/OK) → bloquea (Task = posible código)" || bad "dod ALTO-2: un fan-out (Task) evadió el candado (ciego al sub-agente)"
is_block "$(dod 'La ola quedó lista.' "$TASKT" 'sí, ya la validé, ciérrala')" && bad "dod ALTO-2: bloqueó con Task + OK del usuario" || ok "dod ALTO-2: Task + confirmación del usuario → no bloquea"
# MEDIO-1 (FMEA 2026-07-30): los meta-tokens ('definición de listo') se subordinan al claim.
is_block "$(dod 'Quedó 100% listo — cumplida la definición de listo.' "$EDITR")" && ok "dod MEDIO-1: claim de cierre + 'definición de listo' → bloquea (el meta-token ya no lo salva)" || bad "dod MEDIO-1: el meta-token 'definición de listo' salvó un cierre afirmado (evasión)"
is_block "$(dod '¿Cuál es tu definición de listo?' "$EDITR")" && bad "dod MEDIO-1: bloqueó una meta-pregunta sin claim ('¿cuál es tu definición de listo?')" || ok "dod MEDIO-1: meta-pregunta sin claim → no bloquea (escapa)"
# BAJO-2 (FMEA 2026-07-30): la máscara MECH ya no se come un claim del entregable cuando nombra "rama".
is_block "$(dod 'La rama de pagos quedó lista y funcionando.' "$EDITR")" && ok "dod BAJO-2: 'la rama de pagos quedó lista' → bloquea (la máscara MECH ya no come el claim del entregable)" || bad "dod BAJO-2: la máscara MECH se comió un claim genuino ('la rama de pagos quedó lista')"
rm -f "$DODTX"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b5) compactación: precompact RETIRADO + rehidratar-hilo (inyecta + gate de staleness) =="
# precompact-volcar-estado se RETIRÓ (2026-07): PreCompact no puede inyectar contexto ni pedir acción
# (no hay turno antes de compactar) → era peso muerto. El "no perder el hilo" lo hacen checkpoint
# (escribe) + rehidratar-hilo (relee) + aviso-contexto (watermark). Verificamos que ya NO exista.
[ ! -f "$HOOKS/precompact-volcar-estado.sh" ] && ok "precompact-volcar-estado retirado (ya no existe)" || bad "precompact aún existe (debía retirarse)"

# rehidratar-hilo (SessionStart): con hilo → inyecta additionalContext; sin/vacío → silencio
RHROOT="$(mktemp -d "${TMPDIR:-/tmp}/brain-rh.XXXXXX")"
mkdir -p "$RHROOT/.claude/memory"
rh() { printf '%s' '{"source":"resume"}' | CLAUDE_PROJECT_DIR="$RHROOT" bash "$HOOKS/rehidratar-hilo.sh"; }
is_silent "$(rh)" && ok "rehidratar-hilo: sin hilo-mental-actual.md → silencio" || bad "rehidratar-hilo: esperaba silencio sin hilo"
: > "$RHROOT/.claude/memory/hilo-mental-actual.md"
is_silent "$(rh)" && ok "rehidratar-hilo: hilo vacío → silencio" || bad "rehidratar-hilo: esperaba silencio con hilo vacío"
printf '# Hilo mental actual\n## En qué estamos AHORA\nMARCA_HILO_XYZ\n' > "$RHROOT/.claude/memory/hilo-mental-actual.md"
rhout="$(rh)"
printf '%s' "$rhout" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null 2>&1 \
  && ok "rehidratar-hilo: emite hookSpecificOutput SessionStart válido" || bad "rehidratar-hilo: JSON SessionStart inválido; got: $rhout"
printf '%s' "$rhout" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'MARCA_HILO_XYZ' \
  && ok "rehidratar-hilo: el cuerpo del hilo viaja en additionalContext" || bad "rehidratar-hilo: no encontré el cuerpo del hilo"

# staleness (A): hilo FRESCO → encabezado normal
printf '# Hilo mental actual\n> Última actualización: 2026-07-13 · rama %s\nMARCA_FRESCO\n' \
  "$(git -C "$RHROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo sinrepo)" \
  > "$RHROOT/.claude/memory/hilo-mental-actual.md"
printf '%s' "$(rh)" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'HILO MENTAL ACTUAL' \
  && ok "rehidratar-hilo: hilo fresco → encabezado normal" || bad "rehidratar-hilo: esperaba encabezado normal en fresco"
# staleness (B): mtime ANTIGUO (> umbral) → OBSOLETO
touch -t 202001010000 "$RHROOT/.claude/memory/hilo-mental-actual.md" 2>/dev/null
printf '%s' "$(rh)" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'OBSOLETO' \
  && ok "rehidratar-hilo: hilo viejo (mtime > umbral) → OBSOLETO" || bad "rehidratar-hilo: esperaba OBSOLETO en viejo"
# staleness (C): fresco pero de OTRA rama → OBSOLETO (umbral alto aísla la edad)
RHGIT="$(mktemp -d "${TMPDIR:-/tmp}/brain-rhg.XXXXXX")"
git -C "$RHGIT" init -q >/dev/null 2>&1; git -C "$RHGIT" config user.email t@t >/dev/null 2>&1
git -C "$RHGIT" config user.name tester >/dev/null 2>&1; git -C "$RHGIT" checkout -q -b rama-actual >/dev/null 2>&1
mkdir -p "$RHGIT/.claude/memory"
printf '# Hilo mental actual\n> Última actualización: 2026-07-13 · rama otra-rama-vieja\nMARCA_RAMA\n' > "$RHGIT/.claude/memory/hilo-mental-actual.md"
rhbranch="$(printf '%s' '{"source":"resume"}' | HILO_STALE_HORAS=100000 CLAUDE_PROJECT_DIR="$RHGIT" bash "$HOOKS/rehidratar-hilo.sh")"
printf '%s' "$rhbranch" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'OBSOLETO' \
  && ok "rehidratar-hilo: hilo de OTRA rama → OBSOLETO (aunque fresco)" || bad "rehidratar-hilo: esperaba OBSOLETO por rama; got: $rhbranch"
# staleness (A8): hilo de la rama ACTUAL con mtime VIEJO (>12h) → NO obsoleto (la vigencia la manda la
# rama, no el reloj). Antes, una sesión larga (>12h) en la misma rama enterraba su PROPIO hilo vigente.
RHSAME="$(mktemp -d "${TMPDIR:-/tmp}/brain-rhs.XXXXXX")"
git -C "$RHSAME" init -q >/dev/null 2>&1; git -C "$RHSAME" config user.email t@t >/dev/null 2>&1
git -C "$RHSAME" config user.name tester >/dev/null 2>&1; git -C "$RHSAME" checkout -q -b trabajo-actual >/dev/null 2>&1
printf 'x\n' > "$RHSAME/a.txt"; git -C "$RHSAME" add a.txt >/dev/null 2>&1; git -C "$RHSAME" commit -qm base >/dev/null 2>&1   # rama con commit → HEAD nombrado (no unborn)
mkdir -p "$RHSAME/.claude/memory"
printf '# Hilo mental actual\n> Última actualización: 2026-07-13 · rama trabajo-actual\nMARCA_SAME\n' > "$RHSAME/.claude/memory/hilo-mental-actual.md"
touch -t 202001010000 "$RHSAME/.claude/memory/hilo-mental-actual.md" 2>/dev/null   # 6 años → age stale por reloj
rhsame="$(printf '%s' '{"source":"resume"}' | CLAUDE_PROJECT_DIR="$RHSAME" bash "$HOOKS/rehidratar-hilo.sh")"
rhsame_ctx="$(printf '%s' "$rhsame" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)"
printf '%s' "$rhsame_ctx" | grep -q 'POSIBLEMENTE OBSOLETO' \
  && bad "rehidratar-hilo A8: hilo de la rama ACTUAL con mtime 13h+ se marcó OBSOLETO por edad (falso positivo)" \
  || ok "rehidratar-hilo A8: hilo de la rama actual con mtime viejo → NO obsoleto (vigencia por rama)"
printf '%s' "$rhsame_ctx" | grep -q 'HILO MENTAL ACTUAL' \
  && ok "rehidratar-hilo A8: encabezado normal (rehidrata el hilo vigente pese a la edad)" || bad "rehidratar-hilo A8: no reinyectó con encabezado normal; got: $rhsame_ctx"
rm -rf "$RHSAME"
rm -rf "$RHGIT" "$RHROOT"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b5b) aviso-drift-cerebro: drift por-repo vs fuente única (stub del sync; throttle; fail-open) =="
ADFIX="$(mktemp -d "${TMPDIR:-/tmp}/brain-ad.XXXXXX")"
ADROOT="$ADFIX/repo"; ADHOME="$ADFIX/home"; ADBRAIN="$ADFIX/clon"
mkdir -p "$ADROOT/.claude/hooks" "$ADHOME" "$ADBRAIN/brain"
ad() { printf '%s' '{"source":"startup"}' | HOME="$ADHOME" CLAUDE_BRAIN_DIR="$ADBRAIN" CLAUDE_PROJECT_DIR="$ADROOT" bash "$HOOKS/aviso-drift-cerebro.sh"; }
# (1) repo SIN cerebro por-repo → silencio (no estorba en repos ajenos)
is_silent "$(ad)" && ok "aviso-drift: repo no-brained → silencio" || bad "aviso-drift: habló en un repo sin cerebro"
# (2) brained pero SIN clon canónico (no hay sincronizar-cerebro.sh) → silencio (fail-open)
: > "$ADROOT/.claude/hooks/.brain-version"
is_silent "$(ad)" && ok "aviso-drift: sin clon canónico → silencio (fail-open)" || bad "aviso-drift: habló sin fuente única disponible"
# (3) sync LIMPIO (stub 0+0) → silencio y cachea el chequeo
printf '#!/usr/bin/env bash\necho "==> resumen: 0 nuevos · 0 a actualizar · 9 ya al día · 7 hooks cableados (kind=hook)"\n' > "$ADBRAIN/brain/sincronizar-cerebro.sh"
is_silent "$(ad)" && ok "aviso-drift: sin drift → silencio" || bad "aviso-drift: habló sin drift"
# (4) throttle: ahora el stub reporta DRIFT, pero el stamp fresco (chequeo limpio reciente) lo salta
printf '#!/usr/bin/env bash\necho "  NUEVO      secret-scan.sh (hook)"\necho "  ACTUALIZA  dod-verificar.sh (hook)  [10 líneas ±]"\necho "==> resumen: 1 nuevos · 1 a actualizar · 7 ya al día · 7 hooks cableados (kind=hook)"\n' > "$ADBRAIN/brain/sincronizar-cerebro.sh"
is_silent "$(ad)" && ok "aviso-drift: throttle — chequeo limpio reciente → no re-chequea" || bad "aviso-drift: el throttle no respetó el stamp fresco"
# (5) sin stamp → DETECTA el drift e inyecta additionalContext de SessionStart con el detalle
rm -rf "$ADHOME/.claude/memory/.drift-cerebro"
adout="$(ad)"
printf '%s' "$adout" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null 2>&1 \
  && ok "aviso-drift: emite hookSpecificOutput SessionStart válido" || bad "aviso-drift: JSON inválido; got: $adout"
printf '%s' "$adout" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'DRIFT DEL CEREBRO' \
  && ok "aviso-drift: el aviso nombra el DRIFT" || bad "aviso-drift: no encontré el aviso de drift"
printf '%s' "$adout" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'secret-scan' \
  && ok "aviso-drift: el aviso trae el DETALLE (archivos atrás)" || bad "aviso-drift: el aviso no detalla los archivos"
# (6) el drift NO se cachea → la siguiente sesión vuelve a avisar (insistente hasta sanar)
printf '%s' "$(ad)" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'DRIFT DEL CEREBRO' \
  && ok "aviso-drift: con drift NO cachea — re-avisa en la siguiente sesión" || bad "aviso-drift: cacheó un chequeo CON drift (se calló)"
# (7) el aviso ADEMÁS trae el NUDGE de la DUPLA; sin AGENTS.md → rama "sin firma" (sugiere instanciar)
adout="$(ad)"
printf '%s' "$adout" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'DUPLA' \
  && ok "aviso-drift: el aviso trae el nudge de la DUPLA" || bad "aviso-drift: no apareció el nudge de la dupla"
printf '%s' "$adout" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'NO tiene instanciado' \
  && ok "aviso-drift (sin firma): dupla en rama 'sin firma' → sugiere instanciar el esquema" || bad "aviso-drift: no tomó la rama sin-firma"
# (8) con AGENTS.md (esquema firma+detalle instanciado) → la dupla apunta CONTRA la firma
printf '# contrato\n' > "$ADROOT/AGENTS.md"
printf '%s' "$(ad)" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'CONTRA la firma' \
  && ok "aviso-drift (con firma): AGENTS.md presente → dupla CONTRA la firma" || bad "aviso-drift: con AGENTS.md no tomó la rama con-firma"
rm -rf "$ADFIX"

# ── (b5b2) FIX costura #2: aviso-drift DETECTA el drift de CABLEADO (hooks presentes SIN cablear).
# Antes era CIEGO al wiring: solo sumaba nuevos+act+ret → un repo con "0 nuevos · 0 a actualizar · N
# cableado faltante" se veía "al día" (bug LIVE comprobado en la plantilla: 3 hooks sin cablear → 0
# drift). Ahora sincronizar reporta "N cableado faltante" y aviso-drift lo cuenta como drift.
ADWFIX="$(mktemp -d "${TMPDIR:-/tmp}/brain-adw.XXXXXX")"
ADWROOT="$ADWFIX/repo"; ADWHOME="$ADWFIX/home"; ADWBRAIN="$ADWFIX/clon"
mkdir -p "$ADWROOT/.claude/hooks" "$ADWHOME" "$ADWBRAIN/brain"
: > "$ADWROOT/.claude/hooks/.brain-version"
adw() { printf '%s' '{"source":"startup"}' | HOME="$ADWHOME" CLAUDE_BRAIN_DIR="$ADWBRAIN" CLAUDE_PROJECT_DIR="$ADWROOT" bash "$HOOKS/aviso-drift-cerebro.sh"; }
# resumen SOLO con cableado faltante>0 (0 nuevos/act/ret) — el caso que antes daba total=0 → "al día"
printf '#!/usr/bin/env bash\necho "==> resumen: 0 nuevos · 0 a actualizar · 10 ya al día · 0 retirado(s) del cerebro · 10 hooks cableados (kind=hook) · 3 cableado faltante"\n' > "$ADWBRAIN/brain/sincronizar-cerebro.sh"
printf '%s' "$(adw)" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'DRIFT DEL CEREBRO' \
  && ok "aviso-drift: cuenta el CABLEADO FALTANTE como drift (antes: ciego → 'al día')" || bad "aviso-drift: sigue CIEGO al cableado faltante (lo dio por al día)"
# control: sin cableado faltante y sin otros drifts → silencio (no falso positivo)
rm -rf "$ADWHOME/.claude/memory/.drift-cerebro"
printf '#!/usr/bin/env bash\necho "==> resumen: 0 nuevos · 0 a actualizar · 10 ya al día · 0 retirado(s) del cerebro · 10 hooks cableados (kind=hook) · 0 cableado faltante"\n' > "$ADWBRAIN/brain/sincronizar-cerebro.sh"
is_silent "$(adw)" && ok "aviso-drift: 0 cableado faltante y sin otros drifts → silencio (no falso positivo)" || bad "aviso-drift: habló con 0 drift (falso positivo)"
rm -rf "$ADWFIX"

# ── (b5c) aviso-drift v2: AUTO-APPLY en la mini-develop (Develop<Usuario>) · aviso en ramita ──
AD2FIX="$(mktemp -d "${TMPDIR:-/tmp}/brain-ad2.XXXXXX")"
AD2REPO="$AD2FIX/repo"; AD2HOME="$AD2FIX/home"; AD2BRAIN="$AD2FIX/clon"
mkdir -p "$AD2REPO/.claude/hooks" "$AD2HOME" "$AD2BRAIN/brain"
git -C "$AD2REPO" init -q >/dev/null 2>&1
git -C "$AD2REPO" config user.email t@t >/dev/null 2>&1; git -C "$AD2REPO" config user.name Tester >/dev/null 2>&1
: > "$AD2REPO/.claude/hooks/.brain-version"
git -C "$AD2REPO" add -A >/dev/null 2>&1; git -C "$AD2REPO" commit -qm base >/dev/null 2>&1
# stub del sync: dry-run reporta drift; con --apply ESCRIBE el hook nuevo en el repo destino
cat > "$AD2BRAIN/brain/sincronizar-cerebro.sh" <<'STUB'
#!/usr/bin/env bash
repo="$1"
[ "${2:-}" = "--apply" ] && printf 'x\n' > "$repo/.claude/hooks/hook-nuevo.sh"
echo "  NUEVO      hook-nuevo.sh (hook)"
echo "==> resumen: 1 nuevos · 0 a actualizar · 8 ya al día · 7 hooks cableados (kind=hook)"
STUB
ad2() { printf '%s' '{"source":"startup"}' | HOME="$AD2HOME" CLAUDE_BRAIN_DIR="$AD2BRAIN" CLAUDE_PROJECT_DIR="$AD2REPO" bash "$HOOKS/aviso-drift-cerebro.sh"; }
# (1) en una RAMITA (no mini): NO auto-aplica — avisa y no crea commits
git -C "$AD2REPO" checkout -q -b feat/x >/dev/null 2>&1
n0=$(git -C "$AD2REPO" rev-list --count HEAD)
printf '%s' "$(ad2)" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'DRIFT DEL CEREBRO' \
  && ok "aviso-drift v2: en ramita → AVISA (no auto-aplica)" || bad "aviso-drift v2: en ramita no avisó"
{ [ "$(git -C "$AD2REPO" rev-list --count HEAD)" = "$n0" ] && [ ! -f "$AD2REPO/.claude/hooks/hook-nuevo.sh" ]; } \
  && ok "aviso-drift v2: en ramita NO tocó el árbol ni commiteó" || bad "aviso-drift v2: ¡escribió/commiteó en una ramita de feature!"
# (2) en la MINI-DEVELOP con .claude/ limpio: auto-aplica + commit (push sin remoto → tolerado)
git -C "$AD2REPO" checkout -q -b DevelopTester >/dev/null 2>&1
ad2out="$(ad2)"
printf '%s' "$ad2out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'AUTO-SINCRONIZADO' \
  && ok "aviso-drift v2: en mini-develop limpia → AUTO-SINCRONIZA y lo anuncia" || bad "aviso-drift v2: no auto-sincronizó en la mini; got: $ad2out"
{ [ -f "$AD2REPO/.claude/hooks/hook-nuevo.sh" ] && git -C "$AD2REPO" log -1 --format=%s | grep -q 'auto-sync'; } \
  && ok "aviso-drift v2: el apply escribió y el commit de auto-sync existe" || bad "aviso-drift v2: falta el archivo aplicado o el commit"
[ -z "$(git -C "$AD2REPO" status --porcelain)" ] \
  && ok "aviso-drift v2: el árbol quedó LIMPIO tras el auto-sync (todo commiteado)" || bad "aviso-drift v2: dejó el árbol sucio"
# (3) en la mini pero con .claude/ SUCIO: no auto-aplica (solo avisa, no mezcla cambios)
printf 'sucio\n' >> "$AD2REPO/.claude/hooks/.brain-version"
printf '%s' "$(ad2)" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'DRIFT DEL CEREBRO' \
  && ok "aviso-drift v2: mini con .claude/ sucio → solo avisa (no mezcla cambios)" || bad "aviso-drift v2: auto-aplicó sobre un .claude/ sucio"
rm -rf "$AD2FIX"

# ── (b5c2) FIX costura #1: el auto-apply STAGEA settings.json (no solo .claude/hooks). Antes
# `git add .claude/hooks` dejaba el cambio de CABLEADO (settings.json) sin commitear → el wiring nunca
# viajaba. Ahora `git add -A .claude/` cubre hooks + settings.json + podas. Stub que --apply reescribe
# AMBOS (hook + settings.json, como register_hook).
AD3FIX="$(mktemp -d "${TMPDIR:-/tmp}/brain-ad3.XXXXXX")"
AD3REPO="$AD3FIX/repo"; AD3HOME="$AD3FIX/home"; AD3BRAIN="$AD3FIX/clon"
mkdir -p "$AD3REPO/.claude/hooks" "$AD3HOME" "$AD3BRAIN/brain"
git -C "$AD3REPO" init -q >/dev/null 2>&1
git -C "$AD3REPO" config user.email t@t >/dev/null 2>&1; git -C "$AD3REPO" config user.name Tester >/dev/null 2>&1
: > "$AD3REPO/.claude/hooks/.brain-version"
printf '{"hooks":{}}' > "$AD3REPO/.claude/settings.json"
git -C "$AD3REPO" add -A >/dev/null 2>&1; git -C "$AD3REPO" commit -qm base >/dev/null 2>&1
git -C "$AD3REPO" checkout -q -b DevelopTester >/dev/null 2>&1
cat > "$AD3BRAIN/brain/sincronizar-cerebro.sh" <<'STUB'
#!/usr/bin/env bash
repo="$1"
if [ "${2:-}" = "--apply" ]; then
  printf 'x\n' > "$repo/.claude/hooks/hook-nuevo.sh"
  printf '{"hooks":{"SessionStart":[{"hooks":[{"command":"bash \\"${CLAUDE_PROJECT_DIR}/.claude/hooks/hook-nuevo.sh\\""}]}]}}' > "$repo/.claude/settings.json"
fi
echo "  NUEVO      hook-nuevo.sh (hook)"
echo "==> resumen: 1 nuevos · 0 a actualizar · 8 ya al día · 0 retirado(s) del cerebro · 8 hooks cableados (kind=hook) · 0 cableado faltante"
STUB
ad3out="$(printf '%s' '{"source":"startup"}' | HOME="$AD3HOME" CLAUDE_BRAIN_DIR="$AD3BRAIN" CLAUDE_PROJECT_DIR="$AD3REPO" bash "$HOOKS/aviso-drift-cerebro.sh")"
printf '%s' "$ad3out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'AUTO-SINCRONIZADO' \
  && ok "aviso-drift FIX#1: auto-sincroniza en la mini (apply+commit)" || bad "aviso-drift FIX#1: no auto-sincronizó; got: $ad3out"
[ -z "$(git -C "$AD3REPO" status --porcelain)" ] \
  && ok "aviso-drift FIX#1: árbol LIMPIO tras el auto-sync (settings.json commiteado, no sin stagear)" || bad "aviso-drift FIX#1: settings.json quedó SIN commitear (árbol sucio): $(git -C "$AD3REPO" status --porcelain)"
git -C "$AD3REPO" show --name-only --format= HEAD 2>/dev/null | grep -q 'settings.json' \
  && ok "aviso-drift FIX#1: el commit de auto-sync INCLUYE settings.json (el cableado viaja)" || bad "aviso-drift FIX#1: el commit NO incluyó settings.json (el cableado no viajaría)"
rm -rf "$AD3FIX"

# ── (b5c3) C2 FMEA: guard ANTI-REGRESIÓN — fuente ($BRAIN_DIR) DETRÁS de su origin/main → NO auto-aplica.
# El sync copia FUENTE→repo; una fuente stale REGRESARÍA el brain y el push la propagaría. La fuente aquí
# es un repo git con HEAD un commit ATRÁS de su ref origin/main (manipulado directo, sin baile de remotos
# ni dependencia del nombre de rama default) → fuente_stale=1 → cae al AVISO.
AD4FIX="$(mktemp -d "${TMPDIR:-/tmp}/brain-ad4.XXXXXX")"
AD4BRAIN="$AD4FIX/clon"; AD4REPO="$AD4FIX/repo"; AD4HOME="$AD4FIX/home"
git init -q "$AD4BRAIN" >/dev/null 2>&1
git -C "$AD4BRAIN" config user.email t@t >/dev/null 2>&1; git -C "$AD4BRAIN" config user.name Tester >/dev/null 2>&1
git -C "$AD4BRAIN" checkout -q -B main >/dev/null 2>&1
mkdir -p "$AD4BRAIN/brain"
printf 'v1\n' > "$AD4BRAIN/marca.txt"; git -C "$AD4BRAIN" add -A >/dev/null 2>&1; git -C "$AD4BRAIN" commit -qm v1 >/dev/null 2>&1
AD4A=$(git -C "$AD4BRAIN" rev-parse HEAD)
printf 'v2\n' >> "$AD4BRAIN/marca.txt"; git -C "$AD4BRAIN" commit -qam v2 >/dev/null 2>&1
git -C "$AD4BRAIN" update-ref refs/remotes/origin/main "$(git -C "$AD4BRAIN" rev-parse HEAD)" >/dev/null 2>&1  # origin/main = v2
git -C "$AD4BRAIN" reset --hard "$AD4A" -q >/dev/null 2>&1                                                    # HEAD = v1 (1 atrás)
# stub del sync (reporta drift; con --apply escribiría) — igual al de b5c
cat > "$AD4BRAIN/brain/sincronizar-cerebro.sh" <<'STUB'
#!/usr/bin/env bash
repo="$1"
[ "${2:-}" = "--apply" ] && printf 'x\n' > "$repo/.claude/hooks/hook-nuevo.sh"
echo "  NUEVO      hook-nuevo.sh (hook)"
echo "==> resumen: 1 nuevos · 0 a actualizar · 8 ya al día · 0 retirado(s) del cerebro · 8 hooks cableados (kind=hook) · 0 cableado faltante"
STUB
mkdir -p "$AD4REPO/.claude/hooks" "$AD4HOME"
git -C "$AD4REPO" init -q >/dev/null 2>&1
git -C "$AD4REPO" config user.email t@t >/dev/null 2>&1; git -C "$AD4REPO" config user.name Tester >/dev/null 2>&1
: > "$AD4REPO/.claude/hooks/.brain-version"
git -C "$AD4REPO" add -A >/dev/null 2>&1; git -C "$AD4REPO" commit -qm base >/dev/null 2>&1
git -C "$AD4REPO" checkout -q -b DevelopTester >/dev/null 2>&1
n0=$(git -C "$AD4REPO" rev-list --count HEAD)
ad4out="$(printf '%s' '{"source":"startup"}' | HOME="$AD4HOME" CLAUDE_BRAIN_DIR="$AD4BRAIN" CLAUDE_PROJECT_DIR="$AD4REPO" bash "$HOOKS/aviso-drift-cerebro.sh")"
printf '%s' "$ad4out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'DRIFT DEL CEREBRO' \
  && ok "C2: fuente detrás de origin/main → NO auto-aplica (avisa en vez de regresar)" || bad "C2: auto-aplicó desde una fuente STALE; got: $ad4out"
{ [ "$(git -C "$AD4REPO" rev-list --count HEAD)" = "$n0" ] && [ ! -f "$AD4REPO/.claude/hooks/hook-nuevo.sh" ]; } \
  && ok "C2: fuente stale → NO commiteó ni escribió (no empujó regresión)" || bad "C2: ¡commiteó/escribió desde una fuente stale!"
printf '%s' "$ad4out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'anti-regresión' \
  && ok "C2: el aviso EXPLICA la fuente stale (nota anti-regresión)" || bad "C2: el aviso no menciona la fuente stale"
rm -rf "$AD4FIX"

# ── (b5c4) sA3 FMEA: el patrón de mini-develop es Develop+MAYÚSCULA. Una rama 'Development' (Develop+
# minúscula) NO es mini-develop → NO auto-aplica (antes 'Develop?*' la casaba y le hacía auto-push).
AD5FIX="$(mktemp -d "${TMPDIR:-/tmp}/brain-ad5.XXXXXX")"
AD5REPO="$AD5FIX/repo"; AD5HOME="$AD5FIX/home"; AD5BRAIN="$AD5FIX/clon"
mkdir -p "$AD5REPO/.claude/hooks" "$AD5HOME" "$AD5BRAIN/brain"
git -C "$AD5REPO" init -q >/dev/null 2>&1
git -C "$AD5REPO" config user.email t@t >/dev/null 2>&1; git -C "$AD5REPO" config user.name Tester >/dev/null 2>&1
: > "$AD5REPO/.claude/hooks/.brain-version"
git -C "$AD5REPO" add -A >/dev/null 2>&1; git -C "$AD5REPO" commit -qm base >/dev/null 2>&1
cat > "$AD5BRAIN/brain/sincronizar-cerebro.sh" <<'STUB'
#!/usr/bin/env bash
repo="$1"
[ "${2:-}" = "--apply" ] && printf 'x\n' > "$repo/.claude/hooks/hook-nuevo.sh"
echo "  NUEVO      hook-nuevo.sh (hook)"
echo "==> resumen: 1 nuevos · 0 a actualizar · 8 ya al día · 0 retirado(s) del cerebro · 8 hooks cableados (kind=hook) · 0 cableado faltante"
STUB
ad5() { printf '%s' '{"source":"startup"}' | HOME="$AD5HOME" CLAUDE_BRAIN_DIR="$AD5BRAIN" CLAUDE_PROJECT_DIR="$AD5REPO" bash "$HOOKS/aviso-drift-cerebro.sh"; }
git -C "$AD5REPO" checkout -q -b Development >/dev/null 2>&1   # Develop + minúscula = NO es mini-develop
n0=$(git -C "$AD5REPO" rev-list --count HEAD)
printf '%s' "$(ad5)" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'DRIFT DEL CEREBRO' \
  && ok "sA3: rama 'Development' (Develop+minúscula) → AVISA, NO la trata como mini-develop" || bad "sA3: 'Development' recibió trato de mini-develop"
{ [ "$(git -C "$AD5REPO" rev-list --count HEAD)" = "$n0" ] && [ ! -f "$AD5REPO/.claude/hooks/hook-nuevo.sh" ]; } \
  && ok "sA3: 'Development' → NO auto-push (regex Develop[A-Z] cerró el falso positivo)" || bad "sA3: ¡auto-push sobre 'Development'!"
rm -rf "$AD5FIX"

# ── (b5c5) sA3 FMEA: el commit del auto-sync va ACOTADO a .claude/ (git commit -o) — NO barre cambios
# staged AJENOS del usuario (p. ej. src/ a medio trabajar) al commit de auto-sync.
AD6FIX="$(mktemp -d "${TMPDIR:-/tmp}/brain-ad6.XXXXXX")"
AD6REPO="$AD6FIX/repo"; AD6HOME="$AD6FIX/home"; AD6BRAIN="$AD6FIX/clon"
mkdir -p "$AD6REPO/.claude/hooks" "$AD6REPO/src" "$AD6HOME" "$AD6BRAIN/brain"
git -C "$AD6REPO" init -q >/dev/null 2>&1
git -C "$AD6REPO" config user.email t@t >/dev/null 2>&1; git -C "$AD6REPO" config user.name Tester >/dev/null 2>&1
: > "$AD6REPO/.claude/hooks/.brain-version"; printf 'base\n' > "$AD6REPO/src/foo.txt"
git -C "$AD6REPO" add -A >/dev/null 2>&1; git -C "$AD6REPO" commit -qm base >/dev/null 2>&1
git -C "$AD6REPO" checkout -q -b DevelopTester >/dev/null 2>&1
cat > "$AD6BRAIN/brain/sincronizar-cerebro.sh" <<'STUB'
#!/usr/bin/env bash
repo="$1"
[ "${2:-}" = "--apply" ] && printf 'x\n' > "$repo/.claude/hooks/hook-nuevo.sh"
echo "  NUEVO      hook-nuevo.sh (hook)"
echo "==> resumen: 1 nuevos · 0 a actualizar · 8 ya al día · 0 retirado(s) del cerebro · 8 hooks cableados (kind=hook) · 0 cableado faltante"
STUB
# el usuario tiene un cambio AJENO staged FUERA de .claude/ (no debe entrar al commit de auto-sync)
printf 'trabajo a medias\n' >> "$AD6REPO/src/foo.txt"; git -C "$AD6REPO" add src/foo.txt >/dev/null 2>&1
ad6out="$(printf '%s' '{"source":"startup"}' | HOME="$AD6HOME" CLAUDE_BRAIN_DIR="$AD6BRAIN" CLAUDE_PROJECT_DIR="$AD6REPO" bash "$HOOKS/aviso-drift-cerebro.sh")"
printf '%s' "$ad6out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'AUTO-SINCRONIZADO' \
  && ok "sA3: auto-sincroniza aunque haya cambios ajenos staged fuera de .claude/" || bad "sA3: no auto-sincronizó; got: $ad6out"
git -C "$AD6REPO" show --name-only --format= HEAD 2>/dev/null | grep -q 'src/foo.txt' \
  && bad "sA3: ¡el commit de auto-sync BARRIÓ src/foo.txt (commit sin acotar)!" || ok "sA3: el commit de auto-sync NO incluyó src/foo.txt (acotado a .claude/ con -o)"
git -C "$AD6REPO" diff --cached --name-only 2>/dev/null | grep -q 'src/foo.txt' \
  && ok "sA3: el cambio ajeno del usuario sigue staged intacto (no se lo llevó el auto-sync)" || bad "sA3: se perdió el staging del cambio ajeno del usuario"
rm -rf "$AD6FIX"

# ── (b5d) sembrar-mini-develop: crea la rama desde origin/develop sin tocar el worktree ──
SMFIX="$(mktemp -d "${TMPDIR:-/tmp}/brain-sm.XXXXXX")"
SMBARE="$SMFIX/remoto.git"; SMREPO="$SMFIX/clon"
git init -q --bare "$SMBARE" >/dev/null 2>&1
git clone -q "$SMBARE" "$SMREPO" >/dev/null 2>&1
git -C "$SMREPO" config user.email t@t >/dev/null 2>&1; git -C "$SMREPO" config user.name Tester >/dev/null 2>&1
printf 'base\n' > "$SMREPO/a.txt"; git -C "$SMREPO" add a.txt >/dev/null 2>&1; git -C "$SMREPO" commit -qm base >/dev/null 2>&1
git -C "$SMREPO" branch -M develop >/dev/null 2>&1; git -C "$SMREPO" push -qu origin develop >/dev/null 2>&1
git -C "$SMREPO" checkout -q -b feat/trabajo >/dev/null 2>&1   # parado en una ramita (no debe moverse)
smout=$(CLAUDE_PROJECT_DIR="$SMREPO" bash "$SCRIPT_DIR/sembrar-mini-develop.sh" 2>&1)
git -C "$SMREPO" ls-remote --exit-code origin DevelopTester >/dev/null 2>&1 \
  && ok "sembrar-mini: creó DevelopTester en el remoto desde origin/develop (nombre derivado del git user)" \
  || bad "sembrar-mini: no creó la rama remota; out: $smout"
[ "$(git -C "$SMREPO" rev-parse --abbrev-ref HEAD)" = "feat/trabajo" ] \
  && ok "sembrar-mini: NO movió la rama actual del worktree" || bad "sembrar-mini: cambió la rama del usuario"
smout2=$(CLAUDE_PROJECT_DIR="$SMREPO" bash "$SCRIPT_DIR/sembrar-mini-develop.sh" 2>&1)
printf '%s' "$smout2" | grep -q "ya existe" && ok "sembrar-mini: idempotente (2ª corrida no duplica)" || bad "sembrar-mini: la 2ª corrida no fue idempotente; out: $smout2"
smout3=$(CLAUDE_PROJECT_DIR="$SMREPO" bash "$SCRIPT_DIR/sembrar-mini-develop.sh" develop 2>&1) && rc3=0 || rc3=$?
{ [ "$rc3" -ne 0 ] && printf '%s' "$smout3" | grep -q "rama base"; } \
  && ok "sembrar-mini: rechaza 'develop' como nombre de mini (protege las bases)" || bad "sembrar-mini: aceptó develop como mini"
rm -rf "$SMFIX"

# ── (b5e) barrer-ramas: TRIGGER throttled del barrido de ramas (fail-open, lanza, throttle) ──
echo ""
echo "== (b5e) barrer-ramas: da trigger al barrido (fail-open sin git/remoto; lanza; throttle) =="
BRFIX="$(mktemp -d "${TMPDIR:-/tmp}/brain-br.XXXXXX")"
BRHOME="$BRFIX/home"; BRHOOKS="$BRFIX/hooks"; BRREPO="$BRFIX/repo"
mkdir -p "$BRHOME" "$BRHOOKS" "$BRREPO"
# Copia el hook + un STUB de limpiar-ramas junto a él: dirname resuelve a ESTA carpeta → usa el stub (sin red).
cp "$HOOKS/barrer-ramas.sh" "$BRHOOKS/barrer-ramas.sh"
printf '#!/usr/bin/env bash\ntouch "%s/.barrido"\n' "$BRFIX" > "$BRHOOKS/limpiar-ramas.sh"; chmod +x "$BRHOOKS/limpiar-ramas.sh"
br() { printf '%s' '{"source":"startup"}' | HOME="$BRHOME" CLAUDE_PROJECT_DIR="$BRREPO" bash "$BRHOOKS/barrer-ramas.sh"; }
# (1) no es repo git → silencio (fail-open, no estorba)
is_silent "$(br)" && ok "barrer-ramas: no-git → silencio" || bad "barrer-ramas: habló fuera de un repo git"
git -C "$BRREPO" init -q >/dev/null 2>&1
# (2) repo SIN remoto → silencio (sin remoto no hay ramas squasheadas-y-borradas que barrer)
is_silent "$(br)" && ok "barrer-ramas: repo sin remoto → silencio" || bad "barrer-ramas: habló sin remoto"
git -C "$BRREPO" remote add origin /tmp/fake-no-red >/dev/null 2>&1   # URL fake: el hook nunca la contacta
# (3) con remoto y sin stamp → LANZA: SessionStart válido + escribe el stamp de throttle
brout="$(br)"
printf '%s' "$brout" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null 2>&1 \
  && ok "barrer-ramas: con remoto y sin throttle → emite SessionStart válido" || bad "barrer-ramas: JSON inválido; got: $brout"
printf '%s' "$brout" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'Barriendo ramas' \
  && ok "barrer-ramas: el aviso anuncia el barrido" || bad "barrer-ramas: el aviso no menciona el barrido"
brslug=$(printf '%s' "$BRREPO" | cksum | awk '{print $1}')
[ -f "$BRHOME/.claude/memory/.barrer-ramas/$brslug" ] \
  && ok "barrer-ramas: escribió el stamp de throttle" || bad "barrer-ramas: no escribió el stamp"
# (4) throttle: 2ª corrida inmediata → silencio (stamp fresco)
is_silent "$(br)" && ok "barrer-ramas: throttle — 2ª corrida inmediata → silencio" || bad "barrer-ramas: no respetó el throttle"
rm -rf "$BRFIX"

# ── (b5g) recordar-cosechar: nudge "trabajaste y no cosechaste" (fail-open; heurístico; throttle; cosechado→silencio) ──
echo ""
echo "== (b5g) recordar-cosechar: nudge de cosecha (fail-open sin git; hubo trabajo+sin cosechar → avisa; throttle; cosechado → silencio) =="
RCFIX="$(mktemp -d "${TMPDIR:-/tmp}/brain-rc.XXXXXX")"
RCHOME="$RCFIX/home"; RCREPO="$RCFIX/repo"
mkdir -p "$RCHOME" "$RCREPO"
rc() { printf '%s' '{}' | HOME="$RCHOME" CLAUDE_PROJECT_DIR="$RCREPO" bash "$HOOKS/recordar-cosechar.sh"; }
# (1) no es repo git → silencio (fail-open)
is_silent "$(rc)" && ok "recordar-cosechar: no-git → silencio" || bad "recordar-cosechar: habló fuera de un repo git"
git -C "$RCREPO" init -q >/dev/null 2>&1
git -C "$RCREPO" config user.email t@t >/dev/null 2>&1; git -C "$RCREPO" config user.name tester >/dev/null 2>&1
# (2) repo con sistema de memoria pero SIN trabajo (sin commits recientes, sin cambios de código) → silencio
mkdir -p "$RCREPO/.claude/memory"
is_silent "$(rc)" && ok "recordar-cosechar: sin trabajo sustantivo → silencio" || bad "recordar-cosechar: habló sin trabajo"
# (3) hubo trabajo (archivo de código sin commitear) y aprendizajes.md sin tocar → AVISA + escribe stamp del día
printf 'class X {}\n' > "$RCREPO/Foo.cs"
rcout="$(rc)"
printf '%s' "$rcout" | jq -e '.hookSpecificOutput.hookEventName == "Stop"' >/dev/null 2>&1 \
  && ok "recordar-cosechar: trabajo sin cosechar → emite Stop válido" || bad "recordar-cosechar: JSON inválido; got: $rcout"
printf '%s' "$rcout" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'cosechar-sesion' \
  && ok "recordar-cosechar: el aviso sugiere /cosechar-sesion" || bad "recordar-cosechar: el aviso no nombra la skill"
rcslug=$(printf '%s' "$RCREPO" | cksum | awk '{print $1}')
[ -f "$RCHOME/.claude/memory/.recordar-cosechar/$rcslug" ] \
  && ok "recordar-cosechar: escribió el stamp del día" || bad "recordar-cosechar: no escribió el stamp"
# (4) throttle: 2ª corrida el mismo día → silencio
is_silent "$(rc)" && ok "recordar-cosechar: throttle — 2ª corrida mismo día → silencio" || bad "recordar-cosechar: no respetó el throttle diario"
# (5) cosechado (aprendizajes.md modificado sin commitear) → silencio aunque haya trabajo (limpiamos el stamp)
rm -rf "$RCHOME/.claude/memory/.recordar-cosechar"
printf '## 2026-07-21 · aportó: unjordi · algo\nprosa\n\n' >> "$RCREPO/.claude/memory/aprendizajes.md"
is_silent "$(rc)" && ok "recordar-cosechar: ya se cosechó (log tocado) → silencio" || bad "recordar-cosechar: avisó aunque ya se había cosechado"
rm -rf "$RCFIX"

# ── (b5h) recordar-unificar-cerebro: gemelo hacia arriba (fail-open; delta≥umbral → avisa; en develop → silencio; throttle) ──
echo ""
echo "== (b5h) recordar-unificar-cerebro: aviso de aprendizajes sin unificar (fail-open; delta vs origin/develop; umbral; throttle) =="
RUFIX="$(mktemp -d "${TMPDIR:-/tmp}/brain-ru.XXXXXX")"
RUHOME="$RUFIX/home"; RUREPO="$RUFIX/repo"
mkdir -p "$RUHOME" "$RUREPO"
ru() { printf '%s' '{"source":"startup"}' | HOME="$RUHOME" CLAUDE_PROJECT_DIR="$RUREPO" bash "$HOOKS/recordar-unificar-cerebro.sh"; }
# (1) no es repo git → silencio (fail-open)
is_silent "$(ru)" && ok "recordar-unificar: no-git → silencio" || bad "recordar-unificar: habló fuera de un repo git"
git -C "$RUREPO" init -q >/dev/null 2>&1
git -C "$RUREPO" config user.email t@t >/dev/null 2>&1; git -C "$RUREPO" config user.name tester >/dev/null 2>&1
mkdir -p "$RUREPO/.claude/memory"
printf 'base\n' > "$RUREPO/.claude/memory/aprendizajes.md"
git -C "$RUREPO" add -A >/dev/null 2>&1; git -C "$RUREPO" commit -qm base >/dev/null 2>&1
git -C "$RUREPO" branch -M develop >/dev/null 2>&1
# (2) sin origin/develop → silencio (fail-open, no hay base de comparación)
is_silent "$(ru)" && ok "recordar-unificar: sin origin/develop → silencio" || bad "recordar-unificar: habló sin base origin/develop"
git -C "$RUREPO" update-ref refs/remotes/origin/develop "$(git -C "$RUREPO" rev-parse HEAD)" >/dev/null 2>&1
# (3) parado EN develop → silencio (no es una mini que unificar)
is_silent "$(ru)" && ok "recordar-unificar: en develop → silencio" || bad "recordar-unificar: avisó estando en develop"
# rama personal con delta en .claude/ (aprendizaje nuevo)
git -C "$RUREPO" checkout -q -b DevelopTester >/dev/null 2>&1
printf 'aprendizaje nuevo\n' >> "$RUREPO/.claude/memory/aprendizajes.md"
git -C "$RUREPO" add -A >/dev/null 2>&1; git -C "$RUREPO" commit -qm cosecha >/dev/null 2>&1
# (4) delta ≥ umbral (bajamos el umbral de archivos a 1) → AVISA + stamp; nombra unificar y aprendizajes
ruout="$(printf '%s' '{"source":"startup"}' | HOME="$RUHOME" CLAUDE_PROJECT_DIR="$RUREPO" RECORDAR_UNIFICAR_ARCHIVOS=1 bash "$HOOKS/recordar-unificar-cerebro.sh")"
printf '%s' "$ruout" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null 2>&1 \
  && ok "recordar-unificar: delta ≥ umbral → emite SessionStart válido" || bad "recordar-unificar: JSON inválido; got: $ruout"
printf '%s' "$ruout" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'unificar-cerebro' \
  && ok "recordar-unificar: el aviso sugiere /unificar-cerebro" || bad "recordar-unificar: el aviso no nombra la skill"
printf '%s' "$ruout" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'aprendizajes' \
  && ok "recordar-unificar: el aviso resalta aprendizajes.md en el delta" || bad "recordar-unificar: no mencionó aprendizajes"
ruslug=$(printf '%s' "$RUREPO" | cksum | awk '{print $1}')
[ -f "$RUHOME/.claude/memory/.recordar-unificar/$ruslug" ] \
  && ok "recordar-unificar: escribió el stamp del día" || bad "recordar-unificar: no escribió el stamp"
# (5) throttle: 2ª corrida mismo día → silencio
is_silent "$(printf '%s' '{"source":"startup"}' | HOME="$RUHOME" CLAUDE_PROJECT_DIR="$RUREPO" RECORDAR_UNIFICAR_ARCHIVOS=1 bash "$HOOKS/recordar-unificar-cerebro.sh")" \
  && ok "recordar-unificar: throttle — 2ª corrida mismo día → silencio" || bad "recordar-unificar: no respetó el throttle diario"
# (6) bajo umbral (subimos umbrales muy alto) → silencio aunque haya delta (limpiamos el stamp)
rm -rf "$RUHOME/.claude/memory/.recordar-unificar"
is_silent "$(printf '%s' '{"source":"startup"}' | HOME="$RUHOME" CLAUDE_PROJECT_DIR="$RUREPO" RECORDAR_UNIFICAR_ARCHIVOS=99 RECORDAR_UNIFICAR_DIAS=999 bash "$HOOKS/recordar-unificar-cerebro.sh")" \
  && ok "recordar-unificar: delta bajo umbral → silencio" || bad "recordar-unificar: avisó bajo el umbral"
rm -rf "$RUFIX"

# ── (b5f) verificar-cerebro: DOCTOR de instalación por-máquina (sano→exit 0, roto→exit 1) ──
echo ""
echo "== (b5f) verificar-cerebro: doctor por-máquina (hooks instalados+cableados+jq) =="
VCFIX="$(mktemp -d "${TMPDIR:-/tmp}/brain-vc.XXXXXX")"
VCHOME="$VCFIX/home"; VCBRAIN="$VCFIX/clon"
mkdir -p "$VCHOME/.claude/hooks" "$VCBRAIN/brain/hooks"
# MANIFEST minimal CONTROLADO: un hook global (se exige instalado+cableado) + un script (no se exige cableado)
printf '%s\n' 'foo   global  hook' 'baz   global  script' > "$VCBRAIN/brain/hooks/MANIFEST"
vc() { HOME="$VCHOME" CLAUDE_BRAIN_DIR="$VCBRAIN" bash "$HOOKS/verificar-cerebro.sh" "${1:-}"; }
# (1) SANO: foo.sh instalado + cableado en settings.json → exit 0 y dice "sano"
: > "$VCHOME/.claude/hooks/foo.sh"
printf '{"hooks":{"SessionStart":[{"hooks":[{"command":"bash foo.sh"}]}]}}' > "$VCHOME/.claude/settings.json"
vout="$(vc 2>&1)"; vrc=$?
{ [ "$vrc" = 0 ] && printf '%s' "$vout" | grep -q 'sano'; } \
  && ok "verificar-cerebro: instalación sana → exit 0" || bad "verificar-cerebro: esperaba sano/0; rc=$vrc; out=$vout"
# (2) ROTO: el hook existe pero NO está cableado en settings.json → exit 1 y lo señala
printf '{"hooks":{}}' > "$VCHOME/.claude/settings.json"
vout2="$(vc 2>&1)"; vrc2=$?
{ [ "$vrc2" = 1 ] && printf '%s' "$vout2" | grep -q 'NO cableado'; } \
  && ok "verificar-cerebro: hook sin cablear → exit 1 + lo señala" || bad "verificar-cerebro: esperaba fallo/1 por cableado; rc=$vrc2"
# (3) ROTO: falta el .sh instalado → exit 1
rm -f "$VCHOME/.claude/hooks/foo.sh"
printf '{"hooks":{"SessionStart":[{"hooks":[{"command":"bash foo.sh"}]}]}}' > "$VCHOME/.claude/settings.json"
if vc >/dev/null 2>&1; then bad "verificar-cerebro: esperaba fallo/1 por .sh faltante"; else ok "verificar-cerebro: hook sin instalar → exit 1"; fi
rm -rf "$VCFIX"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b6) aviso-contexto: mide TOKENS del usage, avisa al subir de banda, debounce, y se re-arma al bajar el ctx (compact) =="
# Techo=100 → bandas: t1=76 (ℹ️) · t2=88 (⚠️) · t3=95 (🚨). El ctx = suma del ÚLTIMO usage del transcript.
ACROOT="$(mktemp -d "${TMPDIR:-/tmp}/brain-ac.XXXXXX")/r"
mkdir -p "$ACROOT/.claude/memory"
ACTX="$ACROOT/transcript.jsonl"
# Escribe un transcript cuyo ÚLTIMO usage suma $1 tokens (en cache_read); primera línea sin usage.
gen_ctx() { printf '%s\n%s\n' '{"type":"user","message":{"role":"user"}}' "{\"message\":{\"usage\":{\"cache_read_input_tokens\":$1}}}" > "$ACTX"; }
ac() { printf '%s' "{\"transcript_path\":\"$ACTX\"}" | AVISO_CONTEXTO_CEILING_TOKENS=100 CLAUDE_PROJECT_DIR="$ACROOT" bash "$HOOKS/aviso-contexto.sh"; }
has_aviso() { printf '%s' "$1" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null 2>&1; }
o="$(printf '%s' '{"transcript_path":"/no/existe"}' | AVISO_CONTEXTO_CEILING_TOKENS=100 CLAUDE_PROJECT_DIR="$ACROOT" bash "$HOOKS/aviso-contexto.sh")"
is_silent "$o" && ok "aviso-contexto: sin transcript → silencio" || bad "aviso-contexto reaccionó sin transcript; got: $o"
printf '%s\n' '{"type":"user"}' > "$ACTX"
is_silent "$(ac)" && ok "aviso-contexto: transcript sin usage → silencio (fail-open)" || bad "aviso-contexto reaccionó sin usage"
gen_ctx 50; is_silent "$(ac)" && ok "aviso-contexto: ctx bajo la banda 1 → silencio" || bad "aviso-contexto avisó bajo el techo"
gen_ctx 80; has_aviso "$(ac)" && ok "aviso-contexto: cruza banda 1 → avisa" || bad "aviso-contexto NO avisó al cruzar banda 1"
o="$(ac)"; is_silent "$o" && ok "aviso-contexto: misma banda → debounce (silencio)" || bad "aviso-contexto re-avisó la misma banda; got: $o"
gen_ctx 90; has_aviso "$(ac)" && ok "aviso-contexto: banda mayor → vuelve a avisar" || bad "aviso-contexto NO re-avisó en banda mayor"
gen_ctx 50; is_silent "$(ac)" && ok "aviso-contexto: ctx bajó (compact) → silencio (re-arma)" || bad "aviso-contexto avisó justo tras bajar el ctx"
gen_ctx 80; has_aviso "$(ac)" && ok "aviso-contexto: vuelve a subir tras el compact → avisa de nuevo" || bad "aviso-contexto NO avisó tras re-subir"
# Robustez: un usage de SIDECHAIN (subagente) al final NO debe contaminar la medición del hilo principal.
printf '%s\n%s\n' "{\"message\":{\"usage\":{\"cache_read_input_tokens\":50}}}" '{"isSidechain":true,"message":{"usage":{"cache_read_input_tokens":999}}}' > "$ACTX"
is_silent "$(ac)" && ok "aviso-contexto: ignora el usage de sidechain (mide el hilo principal)" || bad "aviso-contexto contó el usage del sidechain"
rm -rf "$(dirname "$ACROOT")"
# Escalada de urgencia por banda: 1=heads-up (holgura) · 2=checkpoint-ahora · ≥3=INMINENTE + re-checkpoint
AC2="$(mktemp -d "${TMPDIR:-/tmp}/brain-ac2.XXXXXX")/r"; mkdir -p "$AC2/.claude/memory"; AC2TX="$AC2/t.jsonl"
gen2() { printf '%s\n' "{\"message\":{\"usage\":{\"cache_read_input_tokens\":$1}}}" > "$AC2TX"; }
ac2msg() { printf '%s' "{\"transcript_path\":\"$AC2TX\"}" | AVISO_CONTEXTO_CEILING_TOKENS=100 CLAUDE_PROJECT_DIR="$AC2" bash "$HOOKS/aviso-contexto.sh" | jq -r '.hookSpecificOutput.additionalContext // empty'; }
gen2 80; m="$(ac2msg)"   # 80/100 = banda 1
{ printf '%s' "$m" | grep -qi 'holgura' && ! printf '%s' "$m" | grep -q 'INMINENTE'; } \
  && ok "aviso escalada: banda 1 → heads-up (holgura, NO inminente)" || bad "aviso escalada: banda 1 no fue heads-up; got: $m"
gen2 96; m="$(ac2msg)"   # 96/100 = banda 3
{ printf '%s' "$m" | grep -q 'INMINENTE' && printf '%s' "$m" | grep -q 'DE NUEVO'; } \
  && ok "aviso escalada: banda ≥3 → INMINENTE + ORDENA re-checkpoint (DE NUEVO)" || bad "aviso escalada: banda ≥3 no ordenó re-checkpoint; got: $m"
rm -rf "$(dirname "$AC2")"

# (b6b) TECHO DERIVADO (sin override): ventana (settings "[1m]"→1M / si no→200K) × pct de auto-compact
# (CLAUDE_AUTOCOMPACT_PCT_OVERRIDE, o default 92). El override manual AVISO_CONTEXTO_CEILING_TOKENS se
# desactiva aquí (env -u) para ejercitar la DERIVACIÓN. Antídoto al bug del techo fijo 660K (2026-07-27).
# $1=model (a settings.json del proyecto, que gana) · $2=pct (o "unset") · $3=ctx → imprime el mensaje.
ac3() {
  local root; root="$(mktemp -d "${TMPDIR:-/tmp}/brain-ac3.XXXXXX")/r"; mkdir -p "$root/.claude/memory"
  printf '{"model":"%s"}' "$1" > "$root/.claude/settings.json"
  printf '%s\n' "{\"message\":{\"usage\":{\"cache_read_input_tokens\":$3}}}" > "$root/t.jsonl"
  local pctenv="-u CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"; [ "$2" != unset ] && pctenv="CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=$2"
  printf '%s' "{\"transcript_path\":\"$root/t.jsonl\"}" \
    | env -u AVISO_CONTEXTO_CEILING_TOKENS $pctenv CLAUDE_PROJECT_DIR="$root" bash "$HOOKS/aviso-contexto.sh" \
    | jq -r '.hookSpecificOutput.additionalContext // empty'
  rm -rf "$(dirname "$root")"
}
# 1M @ 70% → techo 700K. ctx 600K = 85% → banda 1 (holgura) y el mensaje cita el techo real ~700K.
m="$(ac3 'opus[1m]' 70 600000)"
{ printf '%s' "$m" | grep -q '700K' && printf '%s' "$m" | grep -qi 'holgura'; } \
  && ok "aviso techo derivado: 1M @ 70% → techo ~700K, ctx 600K = banda 1 (holgura)" \
  || bad "aviso techo derivado 1M@70% mal; got: $m"
# ...y a 500K (<76% de 700K) NO grita (el techo fijo 660K daría 75.7%, casi banda 1 — la derivación NO).
[ -z "$(ac3 'opus[1m]' 70 500000)" ] \
  && ok "aviso techo derivado: 1M @ 70%, ctx 500K → silencio (sin gritar temprano)" \
  || bad "aviso techo derivado 1M@70% gritó a 500K"
# Modelo sin [1m] y SIN override de pct → ventana 200K, default 92% → techo 184K. ctx 150K = banda 1.
m="$(ac3 'opus' unset 150000)"
{ printf '%s' "$m" | grep -q '184K' && printf '%s' "$m" | grep -qi 'holgura'; } \
  && ok "aviso techo derivado: 200K @ 92% (default) → techo ~184K, ctx 150K = banda 1" \
  || bad "aviso techo derivado 200K@92% mal; got: $m"
[ -z "$(ac3 'opus' unset 100000)" ] \
  && ok "aviso techo derivado: 200K @ 92%, ctx 100K → silencio" \
  || bad "aviso techo derivado 200K@92% gritó a 100K"

# (b6c) ROBUSTEZ de runtime (bug 2026-07-28): la detección de ventana falla en runtime (settings a medio
# escribir / timing / $HOME distinto) → cae al default chico de 200K → falso "🚨 INMINENTE". AUTO-CORRECCIÓN
# por invariante FÍSICO: el contexto no cabe en una ventana MENOR que él mismo → si el ctx MEDIDO supera la
# ventana detectada, ésta se promueve a 1M (única mayor conocida). ac3 con un modelo SIN "[1m]" simula la
# detección que "falla" y cae a 200K.
# Repro EXACTO del bug: ctx=381K, ventana mal-detectada en 200K, pct=70 → antes gritaba INMINENTE al 272%
# del techo 140K; ahora 381K>200K → promueve a 1M → techo 700K → 54% → banda 0 → silencio.
[ -z "$(ac3 'opus' 70 381000)" ] \
  && ok "aviso robustez: ctx 381K > ventana detectada 200K → auto-corrige a 1M → silencio (NO falso INMINENTE)" \
  || bad "aviso robustez: ctx 381K con ventana mal-detectada gritó (regresión del bug 2026-07-28)"
# La auto-corrección SOLO sube: una sesión GENUINA de 200K con el ctx DENTRO de la ventana sigue avisando
# (no la sobre-suprime). ctx 135K < 200K → sin promoción → techo 140K@70% → 135K ≥ t3(133K) → banda 3.
{ printf '%s' "$(ac3 'opus' 70 135000)" | grep -q 'INMINENTE'; } \
  && ok "aviso robustez: ctx 135K < ventana 200K → sin promoción → sigue avisando (no sobre-suprime)" \
  || bad "aviso robustez: la auto-corrección suprimió un aviso legítimo de una sesión de 200K"
# Escape hatch AVISO_CONTEXTO_WINDOW_TOKENS: fija la VENTANA a mano (sobre la derivación del modelo).
# Ventana 1M forzada @ 70% → techo 700K; ctx 381K = 54% → silencio, aunque el modelo NO diga "[1m]".
acwin() {
  local root; root="$(mktemp -d "${TMPDIR:-/tmp}/brain-acw.XXXXXX")/r"; mkdir -p "$root/.claude/memory"
  printf '{"model":"opus"}' > "$root/.claude/settings.json"
  printf '%s\n' "{\"message\":{\"usage\":{\"cache_read_input_tokens\":$2}}}" > "$root/t.jsonl"
  printf '%s' "{\"transcript_path\":\"$root/t.jsonl\"}" \
    | env -u AVISO_CONTEXTO_CEILING_TOKENS \
        AVISO_CONTEXTO_WINDOW_TOKENS="$1" CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70 CLAUDE_PROJECT_DIR="$root" \
        bash "$HOOKS/aviso-contexto.sh" | jq -r '.hookSpecificOutput.additionalContext // empty'
  rm -rf "$(dirname "$root")"
}
[ -z "$(acwin 1000000 381000)" ] \
  && ok "aviso escape hatch: AVISO_CONTEXTO_WINDOW_TOKENS=1M @ 70% → techo 700K, ctx 381K → silencio" \
  || bad "aviso escape hatch: AVISO_CONTEXTO_WINDOW_TOKENS no respetó la ventana forzada"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b7) dedupe doble-cableado: la copia REPO cede si existe la GLOBAL; corre si no =="
DDNO="$(mktemp -d "${TMPDIR:-/tmp}/brain-ddno.XXXXXX")"
DDYES="$(mktemp -d "${TMPDIR:-/tmp}/brain-ddyes.XXXXXX")"; mkdir -p "$DDYES/.claude/hooks"
cp "$HOOKS/git-branch-guard.sh" "$DDYES/.claude/hooks/git-branch-guard.sh"
DDCMD='{"tool_name":"Bash","tool_input":{"command":"git push origin develop"}}'
o="$(printf '%s' "$DDCMD" | HOME="$DDNO" bash "$HOOKS/git-branch-guard.sh")"
printf '%s' "$o" | grep -q '"deny"' && ok "dedupe: SIN copia global → la copia repo CORRE (bloquea push a develop)" || bad "dedupe: repo debía bloquear sin global; got: $o"
o="$(printf '%s' "$DDCMD" | HOME="$DDYES" bash "$HOOKS/git-branch-guard.sh")"
is_silent "$o" && ok "dedupe: CON copia global → la copia repo CEDE (silencio; la global maneja)" || bad "dedupe: repo debía ceder con global; got: $o"
rm -rf "$DDNO" "$DDYES"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (b8) recordar-dashboard: merge-base cae a origin/develop en clon sin develop local (G8) =="
# Sin ref LOCAL develop/main (clon fresco / default con otro nombre) el merge-base fallaba y la revisión
# doc=realidad se auto-anulaba en silencio. Ahora cae a origin/develop|origin/main.
G8ROOT="$(mktemp -d "${TMPDIR:-/tmp}/brain-g8.XXXXXX")"; G8HOME="$G8ROOT/home"; mkdir -p "$G8HOME"
BARE8="$G8ROOT/bare.git"; SRC8="$G8ROOT/src"
git init --bare -q -b develop "$BARE8" >/dev/null 2>&1
git clone -q "$BARE8" "$SRC8" >/dev/null 2>&1
git -C "$SRC8" config user.email t@t >/dev/null 2>&1; git -C "$SRC8" config user.name tester >/dev/null 2>&1
printf 'base\n' > "$SRC8/base.txt"; git -C "$SRC8" add base.txt >/dev/null 2>&1; git -C "$SRC8" commit -qm base >/dev/null 2>&1
git -C "$SRC8" push -q origin develop >/dev/null 2>&1
git -C "$SRC8" checkout -q -b feat/g8 develop >/dev/null 2>&1
git -C "$SRC8" branch -D develop >/dev/null 2>&1   # simula clon fresco: solo queda origin/develop
mkdir -p "$SRC8/src"; printf 'x=1\n' > "$SRC8/src/foo.js"; git -C "$SRC8" add src/foo.js >/dev/null 2>&1; git -C "$SRC8" commit -qm code >/dev/null 2>&1
out="$(printf '%s' '{"tool_input":{"command":"git push -u origin feat/g8"}}' | (cd "$SRC8" && HOME="$G8HOME" bash "$HOOKS/recordar-dashboard.sh"))"
printf '%s' "$out" | grep -q 'doc=realidad' && ok "G8: sin develop local → merge-base cae a origin/develop → doc=realidad activo" || bad "G8: la revisión doc=realidad se auto-anuló (no cayó a origin/develop); got: $out"
rm -rf "$G8ROOT"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (c) idempotencia: install-brain.sh 2× contra el \$HOME falso =="
FAKEHOME2="$(mktemp -d "${TMPDIR:-/tmp}/brain-inst.XXXXXX")"
HOME="$FAKEHOME2" bash "$INSTALLER" >/dev/null 2>&1
HOME="$FAKEHOME2" bash "$INSTALLER" >/dev/null 2>&1
GSET2="$FAKEHOME2/.claude/settings.json"
GCLAUDE2="$FAKEHOME2/.claude/CLAUDE.md"

for pat in git-branch-guard merge-squash-guard confirmar-merge-develop recordar-dashboard proteger-arbol rehidratar-hilo aviso-contexto delegacion-gate delegacion-registrar; do
  n="$(jq --arg p "$pat" '[.hooks[]?[]? | select(([.hooks[]?.command]|join(" "))|test($p))] | length' "$GSET2" 2>/dev/null)"
  if [ "$n" = "1" ]; then ok "settings.json: $pat cableado 1× (idempotente)"; else bad "settings.json: $pat aparece ${n:-?}× (esperaba 1)"; fi
done
b="$(grep -c 'BEGIN claude-brain' "$GCLAUDE2" 2>/dev/null || echo 0)"
e="$(grep -c 'END claude-brain'   "$GCLAUDE2" 2>/dev/null || echo 0)"
{ [ "$b" = "1" ] && [ "$e" = "1" ]; } && ok "CLAUDE.md: 1 solo bloque de normas (BEGIN/END)" || bad "CLAUDE.md: BEGIN=$b END=$e (esperaba 1/1)"
# la skill y la lib deben haber quedado instaladas
[ -f "$FAKEHOME2/.claude/skills/cerrar-slice/SKILL.md" ] && ok "skill cerrar-slice instalada" || bad "falta skill cerrar-slice"
[ -f "$FAKEHOME2/.claude/skills/checkpoint/SKILL.md" ]   && ok "skill checkpoint instalada"   || bad "falta skill checkpoint"
[ -f "$FAKEHOME2/.claude/skills/rehidratar-hilo/SKILL.md" ] && ok "skill rehidratar-hilo instalada (gemelo manual del hook)" || bad "falta skill rehidratar-hilo"
[ -f "$FAKEHOME2/.claude/skills/turno-nocturno/SKILL.md" ] && ok "skill turno-nocturno instalada (protocolo del turno de noche)" || bad "falta skill turno-nocturno"
[ -f "$FAKEHOME2/.claude/skills/diagramar/SKILL.md" ] && ok "skill diagramar instalada (dot2yed para editar · Mermaid para GitHub)" || bad "falta skill diagramar"
[ -f "$FAKEHOME2/.claude/skills/auditar-proceso-algoritmo/SKILL.md" ] && ok "skill auditar-proceso-algoritmo instalada (auditor experto read-only)" || bad "falta skill auditar-proceso-algoritmo"
[ -f "$FAKEHOME2/.claude/hooks/rehidratar-hilo.sh" ]     && ok "hook rehidratar-hilo instalado" || bad "falta hook rehidratar-hilo"
[ -f "$FAKEHOME2/.claude/hooks/aviso-contexto.sh" ]      && ok "hook aviso-contexto instalado"  || bad "falta hook aviso-contexto"
[ -f "$FAKEHOME2/.claude/hooks/delegacion-comun.sh" ]    && ok "lib delegacion-comun.sh instalada" || bad "falta lib delegacion-comun.sh"
[ -f "$FAKEHOME2/.claude/hooks/analizar-comando-git.sh" ] && ok "lib analizar-comando-git.sh instalada" || bad "falta lib analizar-comando-git.sh"
[ -f "$FAKEHOME2/.claude/hooks/detectar-secretos.sh" ] && ok "lib detectar-secretos.sh instalada" || bad "falta lib detectar-secretos.sh"
# sello de VERSIÓN del brain instalado en ~/.claude/.brain-version (lo lee el tab Cerebro del widget)
# Contrato de 2 líneas: L1 = "<PREFIJO>.<count>" (PREFIJO = brain/VERSION seguido de '.' y dígitos);
# L2 = fecha "YYYY-MM-DD". La versión auto-incrementa (count) → ya NO es igual a brain/VERSION.
_stamp="$FAKEHOME2/.claude/.brain-version"
_pref="$(cat "$SCRIPT_DIR/VERSION")"
_l1="$(sed -n '1p' "$_stamp" 2>/dev/null)"
_l2="$(sed -n '2p' "$_stamp" 2>/dev/null)"
if [ -f "$_stamp" ] \
   && printf '%s' "$_l1" | grep -Eq "^$(printf '%s' "$_pref" | sed 's/[.]/\\./g')\.[0-9]+$" \
   && printf '%s' "$_l2" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  ok "sello .brain-version estampado en ~/.claude (L1 '$_l1' casa PREFIJO.count · L2 '$_l2' es fecha)"
else
  bad "~/.claude/.brain-version ausente o formato inválido (L1='$_l1' L2='$_l2'; esperaba '$_pref.<num>' + fecha)"
fi

# Bonus: el desinstalador deja settings.json sin las entradas del cerebro y sin el bloque de normas
if [ -f "$SCRIPT_DIR/uninstall-brain.sh" ]; then
  HOME="$FAKEHOME2" bash "$SCRIPT_DIR/uninstall-brain.sh" >/dev/null 2>&1
  left="$(jq '[.hooks[]?[]? | select(([.hooks[]?.command]|join(" "))|test("git-branch-guard|merge-squash-guard|recordar-dashboard|delegacion-gate|delegacion-registrar"))] | length' "$GSET2" 2>/dev/null)"
  [ "${left:-x}" = "0" ] && ok "uninstall: 0 entradas del cerebro en settings.json" || bad "uninstall: quedan ${left:-?} entradas"
  grep -q 'BEGIN claude-brain' "$GCLAUDE2" && bad "uninstall: quedó el bloque de normas" || ok "uninstall: bloque de normas removido"
  [ -f "$FAKEHOME2/.claude/hooks/git-branch-guard.sh" ] && bad "uninstall: quedó git-branch-guard.sh" || ok "uninstall: hooks globales removidos"
fi
rm -rf "$FAKEHOME2"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (c2) refresh de normas: un bloque VIEJO se REEMPLAZA en su lugar =="
FAKEHOME3="$(mktemp -d "${TMPDIR:-/tmp}/brain-refresh.XXXXXX")"
mkdir -p "$FAKEHOME3/.claude"
G3="$FAKEHOME3/.claude/CLAUDE.md"
printf 'mi config a mano (antes)\n\n<!-- BEGIN claude-brain -->\nNORMA VIEJA OBSOLETA\n<!-- END claude-brain -->\n\nmi config a mano (despues)\n' > "$G3"
HOME="$FAKEHOME3" bash "$INSTALLER" >/dev/null 2>&1
grep -q 'NORMA VIEJA OBSOLETA' "$G3" && bad "refresh: quedó la norma vieja (no reemplazó)" || ok "refresh: la norma vieja fue reemplazada"
grep -q 'Definición de' "$G3" && ok "refresh: el bloque nuevo quedó" || bad "refresh: falta el bloque nuevo"
n3="$(grep -c 'BEGIN claude-brain' "$G3" 2>/dev/null || echo 0)"
[ "$n3" = "1" ] && ok "refresh: 1 solo bloque tras refrescar" || bad "refresh: $n3 bloques (esperaba 1)"
{ grep -q 'mi config a mano (antes)' "$G3" && grep -q 'mi config a mano (despues)' "$G3"; } \
  && ok "refresh: conserva la config del usuario alrededor del bloque" || bad "refresh: se comió config del usuario"
rm -rf "$FAKEHOME3"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (d) los .ps1 son ASCII puro (Windows PowerShell 5.1 lee un .ps1 sin BOM como ANSI, no UTF-8, =="
echo "==     y un no-ASCII -acento, em-dash, emoji- le rompe la tokenización. caso real: un Windows ajeno) =="
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if command -v perl >/dev/null 2>&1; then
  # perl (no grep): determinista e igual en GNU/BSD/ugrep/Git-Bash. Sale 1 si hay algún byte >0x7F.
  ps1_noascii=0
  while IFS= read -r f; do
    if perl -0777 -ne 'exit(/[^\x00-\x7F]/ ? 1 : 0)' "$f" 2>/dev/null; then
      :   # ASCII limpio
    else
      bad "ASCII: $f tiene bytes no-ASCII (romperá PowerShell 5.1)"; ps1_noascii=1
    fi
  done < <(find "$REPO_ROOT" -name '*.ps1' -not -path '*/.git/*' -not -path '*/build/*')
  [ "$ps1_noascii" = 0 ] && ok "ASCII: todos los .ps1 son ASCII puro (a prueba de PowerShell 5.1)"
else
  echo "  (perl no disponible -> salto el guard ASCII de .ps1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (e) sin referencias circulares NUEVAS entre elementos del cerebro =="
# Allowlist de pares bidireccionales BENIGNOS conocidos (skill<->hook enforcement / lib<->consumidor /
# hooks-hermanos). Un par NUEVO fuera de aqui = posible referencia circular -> revisalo (peor que una
# contradiccion). El test COMPUTA los pares en cada corrida, no depende de contarlos a mano.
CE_ALLOW="analizar-comando-git|git-branch-guard
analizar-comando-git|merge-squash-guard
analizar-comando-git|confirmar-merge-develop
confirmar-merge-develop|git-branch-guard
confirmar-merge-develop|merge-squash-guard
detectar-secretos|secret-scan
cerrar-slice|merge-squash-guard
cerrar-slice|recordar-dashboard
delegacion-comun|delegacion-gate
delegacion-comun|delegacion-registrar
delegacion-gate|limite-gasto
delegacion-reporte|orquestar-fanout
cerrar-slice|checkpoint
cerrar-slice|rehidratar-hilo
checkpoint|rehidratar-hilo
aviso-contexto|rehidratar-hilo
aviso-contexto|checkpoint
aviso-drift-cerebro|barrer-ramas
limpiar-ramas|limpiar-worktrees
limpiar-ramas|ramas-zombie
limpiar-worktrees|ramas-zombie
cosechar-sesion|recordar-cosechar
recordar-unificar-cerebro|unificar-cerebro
cosechar-sesion|unificar-cerebro
proteger-fuente-cerebro|verificar-cerebro
auditar-coherencia-cerebro|auditar-suficiencia-operativa"
ce_els=()
for d in "$SCRIPT_DIR"/skills/*/; do [ -d "$d" ] && ce_els+=("$(basename "$d")"); done
for h in "$HOOKS"/*.sh; do [ -e "$h" ] && ce_els+=("$(basename "$h" .sh)"); done
ce_fileof() { if [ -f "$SCRIPT_DIR/skills/$1/SKILL.md" ]; then echo "$SCRIPT_DIR/skills/$1/SKILL.md"; elif [ -f "$HOOKS/$1.sh" ]; then echo "$HOOKS/$1.sh"; fi; }
ce_new=0
for x in "${ce_els[@]}"; do
  fx="$(ce_fileof "$x")"; [ -z "$fx" ] && continue
  for y in "${ce_els[@]}"; do
    [[ "$x" < "$y" ]] || continue
    fy="$(ce_fileof "$y")"; [ -z "$fy" ] && continue
    if grep -qw "$y" "$fx" 2>/dev/null && grep -qw "$x" "$fy" 2>/dev/null; then
      if ! printf '%s\n' "$CE_ALLOW" | grep -qxF "$x|$y"; then
        bad "ref bidireccional NUEVA (¿circular?): $x <-> $y — revísala (o agrégala al allowlist si es benigna)"; ce_new=1
      fi
    fi
  done
done
[ "$ce_new" = 0 ] && ok "sin referencias circulares nuevas (los pares bidireccionales presentes son los benignos del allowlist)"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (e2) drift-check: el MANIFEST es la FUENTE ÚNICA — install/uninstall/sincronizar coinciden (A4) =="
MF="$HOOKS/MANIFEST"
if [ ! -f "$MF" ]; then
  bad "drift: falta el MANIFEST ($MF)"
else
  # (1) todo *.sh de brain/hooks está declarado en el manifiesto (ningún hook queda fuera de la fuente única)
  miss_mf=0
  for f in "$HOOKS"/*.sh; do
    b="$(basename "$f" .sh)"
    awk '$1!~/^#/ && NF>=3{print $1}' "$MF" | grep -qxF "$b" || { bad "drift: $b.sh NO está en el MANIFEST (hook sin tier declarado)"; miss_mf=1; }
  done
  [ "$miss_mf" = 0 ] && ok "drift: todo *.sh de brain/hooks está declarado en el MANIFEST"
  # (2) toda entrada del manifiesto tiene su archivo
  miss_file=0
  for b in $(awk '$1!~/^#/ && NF>=3{print $1}' "$MF"); do
    [ -f "$HOOKS/$b.sh" ] || { bad "drift: el MANIFEST lista '$b' pero falta $HOOKS/$b.sh"; miss_file=1; }
  done
  [ "$miss_file" = 0 ] && ok "drift: toda entrada del MANIFEST tiene su .sh"
  # (3) install-brain DERIVA GLOBAL del manifiesto (no una lista hardcodeada paralela) y no está vacía
  derived="$(awk '$1!~/^#/ && NF>=3 && ($2=="global"||$2=="both"){print $1".sh"}' "$MF")"
  if grep -q "awk.*global.*both.*MANIFEST\|MANIFEST.*awk" "$INSTALLER" && [ -n "$derived" ]; then
    ok "drift: install-brain deriva GLOBAL_HOOKS del MANIFEST (fuente única, no lista paralela)"
  else
    bad "drift: install-brain NO deriva del MANIFEST (¿volvió a una lista hardcodeada?)"
  fi
  # (4) install-brain DERIVA el cableado del MANIFEST (ya NO 16 register_hook hardcode) y cada
  #     {global,both} kind=hook tiene su EVENTO en la tabla ev_de() → se cablea. Si un hook nuevo del
  #     MANIFEST no está en ev_de(), el instalador lo SALTA (avisa) → este drift-check lo caza.
  grep -qE 'WIRE_HOOKS=.*awk.*(global.*both|both.*global).*MANIFEST' "$INSTALLER" \
    && ok "drift: install-brain deriva el CABLEADO del MANIFEST (ev_de + loop, no lista hardcodeada)" \
    || bad "drift: install-brain NO deriva el cableado del MANIFEST (¿volvió a register_hook hardcode?)"
  evblock="$(awk '/^ev_de\(\)/,/^}/' "$INSTALLER")"
  miss_wire=0
  for b in $(awk '$1!~/^#/ && NF>=3 && ($2=="global"||$2=="both") && $3=="hook"{print $1}' "$MF"); do
    printf '%s' "$evblock" | grep -qw "$b" || { bad "drift: '$b' es {global,both} hook pero NO tiene evento en ev_de() de install-brain (no se cablearía)"; miss_wire=1; }
  done
  [ "$miss_wire" = 0 ] && ok "drift: cada hook {global,both} del MANIFEST tiene evento en ev_de() de install-brain (se cablea)"
  # (5) uninstall-brain también deriva del manifiesto (no una 3ª lista que driftee)
  grep -q "MANIFEST" "$SCRIPT_DIR/uninstall-brain.sh" 2>/dev/null \
    && ok "drift: uninstall-brain también deriva del MANIFEST" \
    || bad "drift: uninstall-brain NO referencia el MANIFEST (lista paralela)"
  # (6) sincronizar-cerebro existe y los archivos de tier {repo,both} que desplegaría están presentes
  if [ -f "$SCRIPT_DIR/sincronizar-cerebro.sh" ]; then
    miss_repo=0
    for b in $(awk '$1!~/^#/ && NF>=3 && ($2=="repo"||$2=="both"){print $1}' "$MF"); do
      [ -f "$HOOKS/$b.sh" ] || { bad "drift: sincronizar desplegaría '$b' pero falta su .sh"; miss_repo=1; }
    done
    [ "$miss_repo" = 0 ] && ok "drift: sincronizar-cerebro existe y todos sus archivos {repo,both} están presentes"
  else
    bad "drift: falta sincronizar-cerebro.sh (la ruta de despliegue por-repo)"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
echo "== (e3) drift-check WIDGET: el catálogo curado del widget coincide con el MANIFEST + skills (antídoto al que un hook nuevo caiga en OTROS y a una skill sin tile) =="
# El widget (Windows/C#, macOS/Swift, plasmoid/QML) trae un catálogo CURADO de piezas del cerebro:
#   (1) los conjuntos known-global / known-repo que clasifican cada hook (si un hook NO está aquí,
#       cae en la sección "OTROS" → drift real que ya nos mordió), y
#   (2) los tiles de display (uno por hook/skill). Esta 3ª lista quedaba FUERA del drift-check e2.
# Invariante: known-global == MANIFEST{global,both}·hook · known-repo == MANIFEST{repo}·hook ·
#             y todo hook del MANIFEST + toda skill de brain/skills tiene un tile en el archivo de display.
ROOT="$SCRIPT_DIR/.."
if [ ! -f "$MF" ]; then
  bad "drift-widget: falta el MANIFEST"
else
  mf_global=$(awk '$1!~/^#/ && NF>=3 && ($2=="global"||$2=="both") && $3=="hook"{print $1}' "$MF" | sort -u)
  mf_repo=$(awk '$1!~/^#/ && NF>=3 && $2=="repo" && $3=="hook"{print $1}' "$MF" | sort -u)
  mf_hooks=$(printf '%s\n%s\n' "$mf_global" "$mf_repo" | grep -v '^$' | sort -u)
  wskills=$(for d in "$SCRIPT_DIR"/skills/*/; do [ -f "${d}SKILL.md" ] && basename "$d"; done | sort -u)
  # quoted tokens con al menos un guion (todos los hooks lo tienen → no captura keywords ni comentarios)
  qtok() { grep -oE '"[a-z][a-z0-9]*(-[a-z0-9]+)+"' | tr -d '"' | sort -u; }
  cmp_set() {  # label  what  got  want
    if [ "$3" = "$4" ]; then ok "drift-widget[$1]: $2 == MANIFEST"
    else bad "drift-widget[$1]: $2 DIFIERE de MANIFEST · sobran/faltan: $(comm -3 <(printf '%s\n' "$3") <(printf '%s\n' "$4") | tr '\t' '~' | tr '\n' ' ')"; fi
  }
  cover() {  # label  display_file
    miss=0
    for n in $mf_hooks $wskills; do
      grep -qF "\"$n\"" "$2" || { bad "drift-widget[$1]: '$n' (MANIFEST/skill) sin tile en $(basename "$2")"; miss=1; }
    done
    [ "$miss" = 0 ] && ok "drift-widget[$1]: todo hook del MANIFEST y toda skill tienen tile"
  }
  # (Windows / C#) known-sets en BrainInspector.cs · tiles en PopupForm.cs
  CS="$ROOT/windows/src/ClaudeBrain/BrainInspector.cs"; CSD="$ROOT/windows/src/ClaudeBrain/PopupForm.cs"
  if [ -f "$CS" ] && [ -f "$CSD" ]; then
    cmp_set win "known-global" "$(sed -n '/KnownGlobalHooks = new()/,/};/p' "$CS" | qtok)" "$mf_global"
    cmp_set win "known-repo"   "$(sed -n '/KnownRepoHooks = new()/,/};/p'   "$CS" | qtok)" "$mf_repo"
    cover   win "$CSD"
  else bad "drift-widget[win]: no encuentro BrainInspector.cs / PopupForm.cs"; fi
  # (macOS / Swift) known-sets en BrainInspector.swift · tiles en PopoverView.swift
  SW="$ROOT/macos/Sources/ClaudeBrain/BrainInspector.swift"; SWD="$ROOT/macos/Sources/ClaudeBrain/PopoverView.swift"
  if [ -f "$SW" ] && [ -f "$SWD" ]; then
    cmp_set mac "known-global" "$(sed -n '/knownGlobalHooks: Set<String> = \[/,/\]/p' "$SW" | qtok)" "$mf_global"
    cmp_set mac "known-repo"   "$(sed -n '/knownRepoHooks: Set<String> = \[/,/\]/p'   "$SW" | qtok)" "$mf_repo"
    cover   mac "$SWD"
  else bad "drift-widget[mac]: no encuentro BrainInspector.swift / PopoverView.swift"; fi
  # (plasmoid / QML) known-sets y tiles en el mismo main.qml
  QML="$ROOT/src/plasmoid/contents/ui/main.qml"
  if [ -f "$QML" ]; then
    cmp_set qml "known-global" "$(grep 'brainGlobalHooks:' "$QML" | qtok)" "$mf_global"
    cmp_set qml "known-repo"   "$(grep 'brainRepoHooks:'   "$QML" | qtok)" "$mf_repo"
    cover   qml "$QML"
  else bad "drift-widget[qml]: no encuentro main.qml"; fi
fi

# ─────────────────────────────────────────────────────────────────────────────
echo "== (e5) sincronizar: los hooks RETIRADOS (lista RETIRED) se podan SOLOS; los huérfanos propios se conservan =="
# precompact-volcar-estado quedó cableado en repos y ROMPE el CLI. Antes solo --prune-orphans lo quitaba
# (y borraba TODO huérfano, incluso hooks propios). Ahora: lista brain/hooks/RETIRED → un huérfano
# RETIRADO se de-cablea+borra en cualquier --apply (seguro: el brain lo declaró muerto); un huérfano
# DESCONOCIDO (posible hook propio) se CONSERVA salvo --prune-orphans.
SYNC="$SCRIPT_DIR/sincronizar-cerebro.sh"; RETIRED="$SCRIPT_DIR/hooks/RETIRED"
grep -qxF "precompact-volcar-estado" "$RETIRED" 2>/dev/null \
  && ok "e5: RETIRED lista precompact-volcar-estado (el que rompía el CLI)" \
  || bad "e5: precompact-volcar-estado NO está en brain/hooks/RETIRED"
E5T="$(mktemp -d "${TMPDIR:-/tmp}/brain-e5.XXXXXX")"; mkdir -p "$E5T/.claude/hooks"
printf 'exit 0\n' > "$E5T/.claude/hooks/precompact-volcar-estado.sh"   # RETIRADO, colgado
printf 'exit 0\n' > "$E5T/.claude/hooks/mi-hook-propio.sh"              # huérfano DESCONOCIDO (propio)
printf '{"hooks":{"PreToolUse":[{"hooks":[{"command":"bash \\"${CLAUDE_PROJECT_DIR}/.claude/hooks/precompact-volcar-estado.sh\\""}]}]}}' > "$E5T/.claude/settings.json"
bash "$SYNC" "$E5T" --apply >/dev/null 2>&1
[ ! -f "$E5T/.claude/hooks/precompact-volcar-estado.sh" ] \
  && ok "e5: --apply (sin --prune-orphans) BORRÓ el hook retirado" \
  || bad "e5: el hook retirado sobrevivió al --apply"
grep -q precompact "$E5T/.claude/settings.json" 2>/dev/null \
  && bad "e5: el hook retirado sigue CABLEADO en settings.json" \
  || ok "e5: el hook retirado quedó DE-CABLEADO del settings.json"
[ -f "$E5T/.claude/hooks/mi-hook-propio.sh" ] \
  && ok "e5: el huérfano DESCONOCIDO (hook propio) se CONSERVÓ (no se borró sin --prune-orphans)" \
  || bad "e5: ¡se borró un huérfano propio sin --prune-orphans!"
# dry-run cuenta el retirado como drift (para que aviso-drift lo flagee)
bash "$SYNC" "$E5T" 2>/dev/null | grep -qE '==> resumen:.*[1-9][0-9]* retirado' \
  && ok "e5: el dry-run REPORTA el retirado en el resumen (aviso-drift lo cuenta como drift)" \
  || ok "e5: (sin retirados pendientes tras el apply — esperado)"
rm -rf "$E5T"

# ─────────────────────────────────────────────────────────────────────────────
echo "== (e6) FIX #2: sincronizar REPORTA 'cableado faltante' (hook presente sin cablear) → aviso-drift deja de ser ciego al wiring =="
E6T="$(mktemp -d "${TMPDIR:-/tmp}/brain-e6.XXXXXX")"; mkdir -p "$E6T/.claude/hooks"
printf '{}' > "$E6T/.claude/settings.json"
# dry-run sobre un repo con settings.json VACÍO → todos los {repo,both} kind=hook están SIN cablear
bash "$SYNC" "$E6T" 2>/dev/null | grep -qE '==> resumen:.*[1-9][0-9]* cableado faltante' \
  && ok "e6: dry-run REPORTA cableado faltante>0 cuando el settings.json no cablea los hooks" \
  || bad "e6: el resumen NO reporta el cableado faltante (aviso-drift seguiría ciego al wiring)"
# tras --apply (cablea todos) → cableado faltante baja a 0
bash "$SYNC" "$E6T" --apply >/dev/null 2>&1
bash "$SYNC" "$E6T" 2>/dev/null | grep -qE '==> resumen:.*· 0 cableado faltante' \
  && ok "e6: tras --apply el cableado faltante baja a 0 (ya cablea todos)" \
  || bad "e6: tras --apply sigue reportando cableado faltante>0"
rm -rf "$E6T"

# ─────────────────────────────────────────────────────────────────────────────
echo "== (e7) FIX #3: install-brain DERIVA el cableado del MANIFEST y cablea EXACTAMENTE los {global,both} kind=hook (mismos hooks/eventos que el hardcode anterior) =="
E7H="$(mktemp -d "${TMPDIR:-/tmp}/brain-e7.XXXXXX")"
HOME="$E7H" bash "$INSTALLER" >/dev/null 2>&1
if [ -f "$E7H/.claude/settings.json" ]; then
  wired=$(jq -r '.hooks[]?[]?.hooks[]?.command' "$E7H/.claude/settings.json" 2>/dev/null | grep -oE '/[a-z-]+\.sh' | sed 's#/##; s#\.sh##' | sort -u)
  want=$(awk '$1!~/^#/ && NF>=3 && ($2=="global"||$2=="both") && $3=="hook"{print $1}' "$MF" | sort -u)
  if [ "$wired" = "$want" ]; then ok "e7: install-brain cablea EXACTAMENTE los {global,both} kind=hook del MANIFEST (ni de más ni de menos)"
  else bad "e7: el set cableado DIFIERE del MANIFEST · sobran/faltan: $(comm -3 <(printf '%s\n' "$wired") <(printf '%s\n' "$want") | tr '\t' '~' | tr '\n' ' ')"; fi
  # el EVENTO de cada uno es el correcto (los 4 grupos: Bash, Task, SessionStart sin-matcher, PostToolUse sin-matcher)
  ev_of() { jq -r --arg n "$1" '.hooks | to_entries[] | .key as $k | .value[] | select((([.hooks[]?.command]|join(" "))) | test("/"+$n+"\\.sh")) | ($k + "|" + (.matcher // ""))' "$E7H/.claude/settings.json"; }
  [ "$(ev_of git-branch-guard)"   = "PreToolUse|Bash" ]  && ok "e7: git-branch-guard → PreToolUse/Bash"        || bad "e7: git-branch-guard evento incorrecto: $(ev_of git-branch-guard)"
  [ "$(ev_of delegacion-reporte)" = "PostToolUse|Task" ] && ok "e7: delegacion-reporte → PostToolUse/Task"     || bad "e7: delegacion-reporte evento incorrecto: $(ev_of delegacion-reporte)"
  [ "$(ev_of barrer-ramas)"       = "SessionStart|" ]    && ok "e7: barrer-ramas → SessionStart/(sin matcher)" || bad "e7: barrer-ramas evento incorrecto: $(ev_of barrer-ramas)"
  [ "$(ev_of aviso-contexto)"     = "PostToolUse|" ]     && ok "e7: aviso-contexto → PostToolUse/(sin matcher)" || bad "e7: aviso-contexto evento incorrecto: $(ev_of aviso-contexto)"
else
  bad "e7: install-brain no generó settings.json"
fi
rm -rf "$E7H"

echo "== (e4) Windows: bootstrap.ps1 exporta CLAUDE_BRAIN_DIR (los hooks bash hallan la fuente) =="
# En Windows el clon-fuente vive en %LOCALAPPDATA%\claude-brain-repo, NO en ~/.claude-brain (default de
# Mac/Linux). Si bootstrap.ps1 no exporta CLAUDE_BRAIN_DIR, el hook bash aviso-drift-cerebro cae a
# $HOME/.claude-brain (inexistente) y el auto-sync por-repo falla MUDO. Guard de regresión.
BPS="$SCRIPT_DIR/../bootstrap.ps1"
if [ -f "$BPS" ]; then
  grep -q "SetEnvironmentVariable('CLAUDE_BRAIN_DIR'" "$BPS" \
    && ok "e4: bootstrap.ps1 exporta CLAUDE_BRAIN_DIR (User env)" \
    || bad "e4: bootstrap.ps1 NO exporta CLAUDE_BRAIN_DIR → en Windows el auto-sync del cerebro falla mudo"
  # y debe guardarlo en FORWARD-SLASH (bash se atraganta con los backslashes de Windows)
  grep -qE "dirBash = .dir -replace|CLAUDE_BRAIN_DIR', .\\\$dirBash" "$BPS" \
    && ok "e4: la ruta se exporta en forward-slash (no backslashes que rompen bash)" \
    || bad "e4: CLAUDE_BRAIN_DIR podría exportarse con backslashes (bash no los resuelve)"
else
  bad "e4: no encuentro bootstrap.ps1"
fi
# e4b (C1, FMEA post-integración 2026-07-30): la instalación MANUAL de Windows (install-brain.ps1 sin pasar
# por bootstrap.ps1) también debe exportar CLAUDE_BRAIN_DIR, o el auto-sync cae MUDO por ese camino.
IBPS="$SCRIPT_DIR/install-brain.ps1"
if [ -f "$IBPS" ]; then
  { grep -q "SetEnvironmentVariable('CLAUDE_BRAIN_DIR'" "$IBPS" && grep -qE "RepoRoot -replace" "$IBPS"; } \
    && ok "e4b: install-brain.ps1 exporta CLAUDE_BRAIN_DIR (RepoRoot en forward-slash) — instalación manual Win no queda muda" \
    || bad "e4b: install-brain.ps1 NO exporta CLAUDE_BRAIN_DIR → instalación manual en Windows falla mudo (C1)"
else
  bad "e4b: no encuentro install-brain.ps1"
fi

# ─────────────────────────────────────────────────────────────────────────────
# (e6) COHERENCIA DE RUTAS CROSS-OS — batch de paridad que FALLA si se olvida un OS.
# Aserciones ESTÁTICAS sobre el fuente (estilo e4): cada instalador/updater/lector de las 3 GUIs
# (bash/PowerShell · Swift/macOS · C#/Windows · QML/KDE) mantiene el MISMO contrato de rutas. Origen:
# docs/auditoria-procesos-fmea-2026-07-30.md, ANEXO "Coherencia de RUTAS cross-OS".
PR="$SCRIPT_DIR/.."

echo ""
echo "== (e6.1) install-brain.ps1 sigue siendo LANZADOR DELGADO (delega en bash install-brain.sh) =="
IBPS="$SCRIPT_DIR/install-brain.ps1"
if [ -f "$IBPS" ]; then
  { grep -qF 'install-brain.sh' "$IBPS" && grep -qF '$bashExe' "$IBPS"; } \
    && ok "e6.1: install-brain.ps1 delega en bash …/install-brain.sh" \
    || bad "e6.1: install-brain.ps1 NO delega en bash install-brain.sh (¿dejó de ser lanzador delgado?)"
  # NO reimplementa el cableado (no toca ~/.claude/hooks ni estampa .brain-version — eso es del .sh)
  grep -qE '\.brain-version|\.claude[/\\]hooks|/hooks/[A-Za-z]' "$IBPS" \
    && bad "e6.1: install-brain.ps1 parece CABLEAR por su cuenta (menciona hooks/.brain-version)" \
    || ok "e6.1: install-brain.ps1 NO cabla por su cuenta (sin lógica de hooks/.brain-version)"
else bad "e6.1: no encuentro install-brain.ps1"; fi

echo ""
echo "== (e6.2) bootstrap.ps1 alinea a main con 'checkout -B main origin/main' (== bootstrap.sh), no 'pull --ff-only' =="
BPS2="$PR/bootstrap.ps1"; BSH2="$PR/bootstrap.sh"
if [ -f "$BPS2" ] && [ -f "$BSH2" ]; then
  grep -qF 'checkout -B main origin/main' "$BPS2" \
    && ok "e6.2: bootstrap.ps1 usa 'checkout -B main origin/main'" \
    || bad "e6.2: bootstrap.ps1 NO usa 'checkout -B main origin/main' (regresión de robustez H3)"
  grep -qF 'pull --ff-only' "$BPS2" \
    && bad "e6.2: bootstrap.ps1 aún tiene 'pull --ff-only' (rompe si el clon quedó en rama borrada)" \
    || ok "e6.2: bootstrap.ps1 ya NO usa 'pull --ff-only'"
  grep -qF 'checkout -B main origin/main' "$BSH2" \
    && ok "e6.2: bootstrap.sh usa 'checkout -B main origin/main' (patrón de referencia)" \
    || bad "e6.2: bootstrap.sh NO usa 'checkout -B main origin/main' (¿cambió la referencia?)"
else bad "e6.2: no encuentro bootstrap.ps1 / bootstrap.sh"; fi

echo ""
echo "== (e6.3) ningún .sh/.ps1/.swift/.cs/.qml de envío hardcodea un \$HOME absoluto (/Users/·/home/·C:\\Users) =="
# Excepciones legítimas: entorno-maquina-guard.sh (su razón de ser ES detectar esas rutas) y
# test-brain.sh (este harness trae fixtures deliberados con /Users/fulano). Se ignoran comentarios de
# línea completa (# en sh/ps1, // en swift/cs/qml) y los dirs de build (obj/bin).
hp_hits=""
while IFS= read -r f; do
  case "$f" in */entorno-maquina-guard.sh|*/test-brain.sh) continue;; esac
  if sed -E 's://.*$::; s:^[[:space:]]*#.*$::' "$f" 2>/dev/null \
       | grep -qE '/Users/[A-Za-z0-9._-]+|/home/[A-Za-z0-9._-]+|[A-Za-z]:[\\/]Users'; then
    hp_hits="${hp_hits:+$hp_hits }${f#"$PR"/}"
  fi
done < <(cd "$PR" && git ls-files '*.sh' '*.ps1' '*.swift' '*.cs' '*.qml' | grep -vE '/(obj|bin)/' | sed "s|^|$PR/|")
[ -z "$hp_hits" ] \
  && ok "e6.3: sin rutas \$HOME absolutas hardcodeadas en código de envío (todas parametrizadas)" \
  || bad "e6.3: home absoluto hardcodeado en: $hp_hits"

echo ""
echo "== (e6.4) los 3 updaters resuelven la ruta del clon con FALLBACK + marca (paridad resolveClonePath, H2) =="
# H2 portado a QML (2026-07-30): antes el plasmoid confiaba CIEGO en version.json.repo (un path horneado
# en otra máquina / repo movido habilitaba un auto-update que hacía cd a una ruta muerta). Ahora los 3
# updaters prueban candidatos [embebido → $CLAUDE_BRAIN_DIR → clon canónico] y toman el 1º con su marca.
Q4="$PR/src/plasmoid/contents/ui/main.qml"
S4="$PR/macos/Sources/ClaudeBrain/Updater.swift"
C4="$PR/windows/src/ClaudeBrain/Updater.cs"
if [ -f "$Q4" ]; then
  { grep -qF 'resolveRepoPath' "$Q4" && grep -qF 'CLAUDE_BRAIN_DIR' "$Q4" && grep -qF '.claude-brain' "$Q4" && grep -qF 'install.sh' "$Q4"; } \
    && ok "e6.4[qml]: main.qml resuelve el clon con fallback (\$CLAUDE_BRAIN_DIR / ~/.claude-brain) + marca install.sh" \
    || bad "e6.4[qml]: main.qml NO resuelve el clon con fallback (H2 sin portar → confía ciego en version.json.repo)"
else bad "e6.4[qml]: no encuentro main.qml"; fi
if [ -f "$S4" ]; then
  { grep -qF 'resolveClonePath' "$S4" && grep -qF 'CLAUDE_BRAIN_DIR' "$S4" && grep -qF '.claude-brain' "$S4" && grep -qF 'macos/install.sh' "$S4"; } \
    && ok "e6.4[swift]: Updater.swift resuelve el clon con fallback + marca macos/install.sh" \
    || bad "e6.4[swift]: Updater.swift perdió el fallback de resolveClonePath"
else bad "e6.4[swift]: no encuentro Updater.swift"; fi
if [ -f "$C4" ]; then
  { grep -qF 'ResolveClonePath' "$C4" && grep -qF 'CLAUDE_BRAIN_DIR' "$C4" && grep -qF 'claude-brain-repo' "$C4" && grep -qF 'install.ps1' "$C4"; } \
    && ok "e6.4[cs]: Updater.cs resuelve el clon con fallback + marca windows/install.ps1" \
    || bad "e6.4[cs]: Updater.cs perdió el fallback de ResolveClonePath"
else bad "e6.4[cs]: no encuentro Updater.cs"; fi

echo ""
echo "== (e6.5) los updaters escapan/citan la ruta del clon en el cd/Set-Location (fix H5) =="
QML5="$PR/src/plasmoid/contents/ui/main.qml"
SW5="$PR/macos/Sources/ClaudeBrain/Updater.swift"
CS5="$PR/windows/src/ClaudeBrain/Updater.cs"
if [ -f "$QML5" ]; then
  { grep -qF 'cd " + shq(repo)' "$QML5" && ! grep -qF "cd '\" + repo" "$QML5"; } \
    && ok "e6.5[qml]: el cd del update escapa la ruta con shq()" \
    || bad "e6.5[qml]: el cd del update NO usa shq() (una ruta con ' se partiría — regresión H5)"
else bad "e6.5[qml]: no encuentro main.qml"; fi
if [ -f "$SW5" ]; then
  grep -qF "cd '\\(repoPath)'" "$SW5" \
    && ok "e6.5[swift]: el cd cita la ruta del clon entre comillas" \
    || bad "e6.5[swift]: el cd NO cita la ruta del clon"
else bad "e6.5[swift]: no encuentro Updater.swift"; fi
if [ -f "$CS5" ]; then
  grep -qF '_repoPath.Replace(' "$CS5" \
    && ok "e6.5[cs]: la ruta del clon se escapa (Replace de comillas) en el script de update" \
    || bad "e6.5[cs]: la ruta del clon NO se escapa en el script de update"
else bad "e6.5[cs]: no encuentro Updater.cs"; fi

echo ""
echo "== (e6.6) los 4 lectores leen .brain-version desde <home>/.claude =="
V6="$PR/macos/Sources/ClaudeBrain/BrainInspector.swift $PR/windows/src/ClaudeBrain/BrainInspector.cs $PR/src/plasmoid/contents/brain-scan.sh $SCRIPT_DIR/install-brain.sh"
v6miss=""
for f in $V6; do
  { [ -f "$f" ] && grep -qF '.brain-version' "$f" && grep -qF '.claude' "$f"; } \
    || v6miss="${v6miss:+$v6miss }$(basename "$f")"
done
[ -z "$v6miss" ] \
  && ok "e6.6: swift/cs/brain-scan.sh/install-brain.sh leen .brain-version bajo ~/.claude" \
  || bad "e6.6: lectores de .brain-version sin <home>/.claude: $v6miss"

echo ""
echo "== (e6.7) los .ps1 de arranque puentean HOME <-> USERPROFILE (fix H1) =="
for f in "$PR/bootstrap.ps1" "$SCRIPT_DIR/install-brain.ps1"; do
  { [ -f "$f" ] && grep -qE '\$env:HOME *= *\$env:USERPROFILE' "$f"; } \
    && ok "e6.7: $(basename "$f") exporta HOME=%USERPROFILE% antes de invocar bash" \
    || bad "e6.7: $(basename "$f") NO puentea HOME<->USERPROFILE (bash instalaría en un ~/.claude que el widget no lee)"
done

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (e6) MANIFEST bien formado: 3 campos · tier ∈ {global,repo,both} · kind ∈ {hook,lib,script} =="
# El MANIFEST es la FUENTE ÚNICA; una línea mal formada (2 campos, tier/kind con typo) haría que las
# rutas que DERIVAN de él (install/sincronizar/drift-check) clasifiquen mal o salten un hook en silencio.
MF="$HOOKS/MANIFEST"
if [ ! -f "$MF" ]; then
  bad "e6: falta el MANIFEST ($MF)"
else
  mf_bad=0
  while read -r name tier kind extra; do
    [ -z "$name" ] && continue                       # línea en blanco
    case "$name" in \#*) continue;; esac             # comentario
    if [ -z "$kind" ] || [ -n "$extra" ]; then
      bad "e6: línea sin EXACTAMENTE 3 campos: '$name $tier $kind $extra'"; mf_bad=1; continue
    fi
    case "$tier" in global|repo|both) ;; *) bad "e6: tier inválido '$tier' (entrada $name)"; mf_bad=1;; esac
    case "$kind" in hook|lib|script) ;; *) bad "e6: kind inválido '$kind' (entrada $name)"; mf_bad=1;; esac
  done < "$MF"
  [ "$mf_bad" = 0 ] && ok "e6: toda línea del MANIFEST tiene 3 campos con tier ∈ {global,repo,both} y kind ∈ {hook,lib,script}"
fi

# ─────────────────────────────────────────────────────────────────────────────
echo "== (e6b) install-brain: EXACTAMENTE 8 hooks en PreToolUse/Bash + aviso-contexto en PostToolUse =="
# El fan-out de guards sobre Bash es un set CERRADO de 8; aviso-contexto es el 9º pero va en PostToolUse
# (casa toda tool). El cableado se DERIVA del MANIFEST vía ev_de() en install-brain.sh → verificamos ese
# mapeo (no líneas register_hook literales: el instalador las colapsó a un loop). Si alguien agrega/quita
# un guard de Bash del mapeo, este test lo caza.
want_bash="git-branch-guard merge-squash-guard confirmar-merge-develop secret-scan recordar-dashboard entorno-maquina-guard rama-vieja proteger-arbol"
want_bash_sorted="$(printf '%s\n' $want_bash | sort | tr '\n' ' ' | sed 's/ *$//')"
got_bash="$(grep -E '\) *echo *"PreToolUse\|Bash"' "$INSTALLER" | sed -E 's/\).*//' | tr '|' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -vE '^$' | sort | tr '\n' ' ' | sed 's/ *$//')"
if [ "$got_bash" = "$want_bash_sorted" ]; then
  ok "e6b: ev_de() mapea EXACTAMENTE los 8 guards de PreToolUse/Bash"
else
  bad "e6b: el set PreToolUse/Bash de ev_de() cambió · got:[$got_bash] want:[$want_bash_sorted]"
fi
grep -qE 'aviso-contexto\) *echo *"PostToolUse\|"' "$INSTALLER" \
  && ok "e6b: aviso-contexto mapeado a PostToolUse (el 9º, NO en Bash)" \
  || bad "e6b: aviso-contexto NO está en PostToolUse"

# ─────────────────────────────────────────────────────────────────────────────
echo "== (e6c) doc=realidad: cada kind=hook del MANIFEST aparece en el árbol del README (sA2/B1) =="
# El árbol del README omitía recordar-cosechar/recordar-unificar-cerebro/barrer-ramas → doc que miente.
RM="$SCRIPT_DIR/README.md"
if [ ! -f "$RM" ] || [ ! -f "$MF" ]; then
  bad "e6c: falta README.md o MANIFEST"
else
  miss_rm=0
  for b in $(awk '$1!~/^#/ && NF>=3 && $3=="hook"{print $1}' "$MF"); do
    grep -qF "\`$b.sh\`" "$RM" || { bad "e6c: el hook '$b' del MANIFEST NO aparece en el árbol del README"; miss_rm=1; }
  done
  [ "$miss_rm" = 0 ] && ok "e6c: todo kind=hook del MANIFEST está documentado en el README"
fi
# e6c2 (B1, FMEA post-integración 2026-07-30): el árbol del README RAÍZ es la FUENTE que gen-leyenda-arbol
# parsea para la leyenda de los flowcharts, y NADIE lo vigilaba contra el MANIFEST → drifteó (faltaban 4
# hooks → leyenda incompleta). Formato de árbol = nombre pelón (sin `.sh`), dentro del bloque 🔒 Hooks Forzosos.
RMROOT="$SCRIPT_DIR/../README.md"
if [ -f "$RMROOT" ] && [ -f "$MF" ]; then
  arbol_root=$(awk '/^🔒[[:space:]]+Hooks[[:space:]]+Forzosos/{c=1} c&&/^```/{exit} c' "$RMROOT")
  miss_root=0
  for b in $(awk '$1!~/^#/ && NF>=3 && $3=="hook"{print $1}' "$MF"); do
    printf '%s' "$arbol_root" | grep -qF "$b" || { bad "e6c2: el hook '$b' del MANIFEST NO está en el árbol del README RAÍZ (la leyenda de los flowcharts lo omitiría)"; miss_root=1; }
  done
  [ "$miss_root" = 0 ] && ok "e6c2: todo kind=hook del MANIFEST está en el árbol del README RAÍZ (leyenda de flowcharts completa)"
else
  bad "e6c2: falta el README RAÍZ ($RMROOT) o el MANIFEST"
fi
# e6c3 (C5, FMEA post-integración 2026-07-30): el generador de la leyenda NO tenía test → un cambio de
# formato del árbol del README lo rompía en SILENCIO (leyenda vacía). Corre el generador y afirma 4 familias
# + suficientes filas de pieza (no-vacío).
GEN="$SCRIPT_DIR/../docs/flowcharts/gen-leyenda-arbol.sh"
if [ -f "$GEN" ]; then
  genout=$(bash "$GEN" 2>/dev/null)
  fams=$(printf '%s' "$genout" | grep -oE '🔒 Hooks Forzosos|🔔 Automático|📜 Normas|💡 Skills' | sort -u | grep -c .)
  rows=$(printf '%s' "$genout" | grep -cE '<tr><td bgcolor.*</td><td bgcolor')
  { [ "$fams" -eq 4 ] && [ "$rows" -ge 20 ]; } \
    && ok "e6c3: gen-leyenda-arbol emite las 4 familias + $rows filas (no vacío)" \
    || bad "e6c3: gen-leyenda-arbol salió incompleto (familias=$fams, filas=$rows) — ¿cambió el formato del árbol del README?"
else bad "e6c3: no encuentro gen-leyenda-arbol.sh"; fi

# ─────────────────────────────────────────────────────────────────────────────
echo "== (e6d) wiring FIELD-check: un settings.json semilla cabla TODOS los kind=hook {repo,both} (C1) =="
# e2(4) valida la FÁBRICA (register_hook en install-brain). Esto valida el RESULTADO: corre
# sincronizar-cerebro contra un repo semilla y verifica que su settings.json REAL cablee cada hook
# {repo,both} — cierra el hueco C1 (drift de cableado invisible entre manifiesto y settings desplegado).
SYNC2="$SCRIPT_DIR/sincronizar-cerebro.sh"
if [ ! -f "$SYNC2" ] || [ ! -f "$MF" ]; then
  bad "e6d: falta sincronizar-cerebro.sh o MANIFEST"
else
  E6D="$(mktemp -d "${TMPDIR:-/tmp}/brain-e6d.XXXXXX")"
  bash "$SYNC2" "$E6D" --apply >/dev/null 2>&1
  SET6D="$E6D/.claude/settings.json"
  if [ ! -f "$SET6D" ]; then
    bad "e6d: sincronizar --apply no creó $SET6D"
  else
    miss_wire=0
    for b in $(awk '$1!~/^#/ && NF>=3 && ($2=="repo"||$2=="both") && $3=="hook"{print $1}' "$MF"); do
      grep -qF "$b.sh" "$SET6D" || { bad "e6d: '$b' ({repo,both} hook) NO quedó cableado en el settings.json semilla"; miss_wire=$((miss_wire+1)); }
    done
    [ "$miss_wire" = 0 ] && ok "e6d: settings.json semilla cabla TODOS los kind=hook {repo,both} del MANIFEST (0 cableado faltante)"
  fi
  rm -rf "$E6D"
fi

# ─────────────────────────────────────────────────────────────────────────────
echo "== (e6e) .brain-version bien formado: 2 líneas · v=<PREFIJO>.<count> (count real ≠0) · fecha =="
# Contrato de DOS LÍNEAS (install-brain / sincronizar): l1 = <PREFIJO>.<commit-count> · l2 = YYYY-MM-DD.
# El widget del cerebro LEE este estampado; un formato roto = versión mal mostrada.
if [ ! -f "$SYNC2" ]; then
  bad "e6e: falta sincronizar-cerebro.sh"
else
  E6E="$(mktemp -d "${TMPDIR:-/tmp}/brain-e6e.XXXXXX")"
  bash "$SYNC2" "$E6E" --apply >/dev/null 2>&1
  BV="$E6E/.claude/hooks/.brain-version"
  if [ ! -f "$BV" ]; then
    bad "e6e: sincronizar --apply no estampó .brain-version en $BV"
  else
    nlines="$(grep -c '' "$BV")"
    l1="$(sed -n '1p' "$BV")"; l2="$(sed -n '2p' "$BV")"
    [ "$nlines" = 2 ] && ok "e6e: .brain-version tiene 2 líneas" || bad "e6e: .brain-version tiene $nlines líneas (esperaba 2)"
    if printf '%s' "$l1" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
      ok "e6e: la versión ($l1) casa <PREFIJO>.<count> (num.num.num)"
    else
      bad "e6e: la versión '$l1' NO casa el formato num.num.num"
    fi
    cnt="${l1##*.}"
    if [ -n "$cnt" ] && [ "$cnt" -gt 0 ] 2>/dev/null; then
      ok "e6e: el commit-count del estampado es real (=$cnt, no 0)"
    else
      bad "e6e: el commit-count del estampado es 0/ausente ('$l1')"
    fi
    printf '%s' "$l2" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' \
      && ok "e6e: la 2ª línea es una fecha YYYY-MM-DD ($l2)" \
      || bad "e6e: la 2ª línea NO es una fecha YYYY-MM-DD ('$l2')"
  fi
  rm -rf "$E6E"
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (e8) installer: la migración de rebrand barre el bloque PATH viejo 'claude-quota' del rc =="
# Regresión: la migración claude-quota→claude-brain limpiaba cache/launchd/app pero NO el bloque PATH
# viejo del rc (marcador '(claude, claude-quota-fetch)') → al actualizar quedaba un 2º bloque PATH
# duplicado (inofensivo, pero cruft). ensure_path_local_bin (en install.sh y macos/install.sh) ahora
# lo barre. Se extrae la función y se corre contra un rc falso con el bloque viejo.
OLD_LINE='# claude-brain: ~/.local/bin en el PATH (claude, claude-quota-fetch)'
CASE_LINE='case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
for inst in "$SCRIPT_DIR/../install.sh" "$SCRIPT_DIR/../macos/install.sh"; do
  iname="$(basename "$(dirname "$inst")")/$(basename "$inst")"
  if [ ! -f "$inst" ]; then bad "e8: no encuentro el instalador $iname"; continue; fi
  EP="$(mktemp -d "${TMPDIR:-/tmp}/brain-ep.XXXXXX")"
  { printf '%s\n' 'export FOO=1' ''; printf '%s\n' "$OLD_LINE" "$CASE_LINE" 'alias ll=ls'; } > "$EP/.zshrc"
  fn="$(sed -n '/^ensure_path_local_bin()/,/^}/p' "$inst")"
  ( eval "$fn"; HOME="$EP" ensure_path_local_bin ) >/dev/null 2>&1
  onew="$(grep -c 'claude-brain-fetch' "$EP/.zshrc" 2>/dev/null)"; onew="${onew:-0}"
  oold="$(grep -c 'claude-quota-fetch' "$EP/.zshrc" 2>/dev/null)"; oold="${oold:-0}"
  oali="$(grep -c 'alias ll=ls' "$EP/.zshrc" 2>/dev/null)"; oali="${oali:-0}"
  if [ "$oold" -eq 0 ] && [ "$onew" -eq 1 ] && [ "$oali" -eq 1 ]; then
    ok "e8: $iname barre el marcador viejo y deja 1 bloque nuevo, sin tocar el resto"
  else
    bad "e8: $iname — viejo=$oold nuevo=$onew alias=$oali (esperado viejo=0 nuevo=1 alias=1)"
  fi
  ( eval "$fn"; HOME="$EP" ensure_path_local_bin ) >/dev/null 2>&1
  onew2="$(grep -c 'claude-brain-fetch' "$EP/.zshrc" 2>/dev/null)"; onew2="${onew2:-0}"
  if [ "$onew2" -eq 1 ]; then ok "e8: $iname idempotente (2ª corrida sigue en 1 bloque)"; else bad "e8: $iname NO idempotente (nuevo=$onew2)"; fi
  rm -rf "$EP"
done

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "== (e9) PARIDAD widget: hover en botones del pie + ↻ fuerza el chequeo de versión (3 plataformas) =="
# Antídoto a que un fix de UI del widget aterrice en 1 plataforma y no en las otras (norma dura: la
# paridad SIEMPRE se revisa). Chequeo ESTRUCTURAL por-plataforma de los DOS comportamientos.
SW_PV="$SCRIPT_DIR/../macos/Sources/ClaudeBrain/PopoverView.swift"
SW_UP="$SCRIPT_DIR/../macos/Sources/ClaudeBrain/Updater.swift"
QML9="$SCRIPT_DIR/../src/plasmoid/contents/ui/main.qml"
WPF="$SCRIPT_DIR/../windows/src/ClaudeBrain/PopupForm.cs"
WUP="$SCRIPT_DIR/../windows/src/ClaudeBrain/Updater.cs"

# --- Fix A: HOVER en los botones del pie del riel ---
grep -q 'hoverHighlight' "$SW_PV" 2>/dev/null && ok "e9: macOS — hover en botones del pie (hoverHighlight)" || bad "e9: macOS SIN hover en el pie"
grep -qE 'PC3\.ToolButton' "$QML9" 2>/dev/null && ok "e9: KDE — botones del pie PC3.ToolButton (hover nativo)" || bad "e9: KDE sin PC3.ToolButton"
grep -q '_hoverBottom' "$WPF" 2>/dev/null && ok "e9: Windows — hover del pie trackeado (_hoverBottom)" || bad "e9: Windows SIN hover del pie"

# --- Fix B: el ↻ (refresh) FUERZA el chequeo de versión saltando el throttle de 15 min ---
{ grep -q 'func forceCheck' "$SW_UP" && grep -q 'forceCheck' "$SW_PV"; } 2>/dev/null \
  && ok "e9: macOS — ↻ fuerza chequeo (Updater.forceCheck + botón)" || bad "e9: macOS — ↻ no fuerza chequeo"
{ grep -q 'ForceCheck' "$WUP" && grep -q 'ForceCheck' "$WPF"; } 2>/dev/null \
  && ok "e9: Windows — ↻ fuerza chequeo (Updater.ForceCheck + click)" || bad "e9: Windows — ↻ no fuerza chequeo"
kfr="$(awk '/function forceRefresh/{c=1} c{print} c&&/^    }/{exit}' "$QML9" 2>/dev/null)"
{ printf '%s' "$kfr" | grep -q 'updLastCheck = 0' && printf '%s' "$kfr" | grep -q 'checkUpdate()'; } \
  && ok "e9: KDE — forceRefresh fuerza checkUpdate (updLastCheck=0)" || bad "e9: KDE — forceRefresh no fuerza chequeo"

# --- Fix C: BADGE ⬆/🩹 en la pestaña Cerebro (el aviso se ve DESDE CUALQUIER pestaña) ---
grep -qE 'railButton\(5,.*badge:.*heal:' "$SW_PV" 2>/dev/null && ok "e9: macOS — badge en la pestaña Cerebro" || bad "e9: macOS SIN badge en la tab"
grep -q 'brainIncomplete' "$QML9" 2>/dev/null && ok "e9: KDE — badge en la pestaña Cerebro (brainIncomplete)" || bad "e9: KDE SIN badge en la tab"
grep -q 'BrainMissing' "$WPF" 2>/dev/null && ok "e9: Windows — badge en la pestaña Cerebro (BrainMissing)" || bad "e9: Windows SIN badge en la tab"

# --- Fix D: HEAL HONESTO (mensaje según completitud REAL, no exit code — install-brain.sh sale 0 sin jq) ---
grep -q 'sigue incompleto' "$SW_PV" 2>/dev/null && ok "e9: macOS — heal honesto (según completitud)" || bad "e9: macOS heal NO honesto"
grep -q 'brainHealVerifying' "$QML9" 2>/dev/null && ok "e9: KDE — heal honesto (re-scan + verdict real)" || bad "e9: KDE heal NO honesto"
grep -q 'sigue incompleto' "$WPF" 2>/dev/null && ok "e9: Windows — heal honesto (según completitud)" || bad "e9: Windows heal NO honesto"

# ─────────────────────────────────────────────────────────────────────────────
# e10: install.ps1 (Windows) detecta la CLI ESPECIFICAMENTE, no la app de escritorio.
# Bug real (Windows "Asistente Dir"): 'claude' resolvia a AppData\Local\AnthropicClaude\claude.exe
# (la app de escritorio, que NO escribe ~/.claude/.credentials.json) -> el instalador la confundia con
# la CLI y se saltaba exponer .local\bin -> OAuth sin credenciales. El fix: helper que EXCLUYE la app,
# prepend del dir de la CLI al PATH (gana a la app), y auth status contra el binario de la CLI.
WPS1="$SCRIPT_DIR/../windows/install.ps1"
grep -q 'AnthropicClaude' "$WPS1" 2>/dev/null \
  && ok "e10: install.ps1 — excluye la app de escritorio al detectar la CLI (AnthropicClaude)" \
  || bad "e10: install.ps1 — NO distingue la CLI de la app de escritorio"
grep -q 'Resolve-ClaudeCli' "$WPS1" 2>/dev/null \
  && ok "e10: install.ps1 — helper Resolve-ClaudeCli (fuente única de detección de la CLI)" \
  || bad "e10: install.ps1 — sin helper de detección específica de la CLI"
grep -q 'al frente del PATH' "$WPS1" 2>/dev/null \
  && ok "e10: install.ps1 — pone la CLI al FRENTE del PATH (gana a la app)" \
  || bad "e10: install.ps1 — no antepone la CLI en el PATH (la app la taparia)"
grep -qE '& \$cli auth status' "$WPS1" 2>/dev/null \
  && ok "e10: install.ps1 — auth status contra el binario de la CLI (no el que resuelva 'claude')" \
  || bad "e10: install.ps1 — auth status no apunta a la CLI específica"

# e11: RACE del asset 'windows-latest'. Al DESCARGAR el exe, version.json debe reflejar el 'build-sha:'
# real del asset (que puede ir detras de main mientras el runner reconstruye), NO el HEAD del clon —
# si no, el widget se cree al dia con un exe viejo y su cerebro empaquetado cuenta hooks de menos
# (el "(5)" fantasma). Fix: leer build-sha del cuerpo del release y estampar ese sha efectivo.
grep -q 'effSha' "$WPS1" 2>/dev/null \
  && ok "e11: install.ps1 — usa sha EFECTIVO (del asset, no HEAD) para el version.json" \
  || bad "e11: install.ps1 — estampa siempre HEAD del clon (RACE del rolling)"
grep -q 'build-sha: (\[0-9a-f\]+)' "$WPS1" 2>/dev/null \
  && ok "e11: install.ps1 — lee el build-sha del cuerpo del release 'windows-latest'" \
  || bad "e11: install.ps1 — no lee el build-sha del release (no detecta asset rancio)"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> resultado: $PASS PASS · $FAIL FAIL"
[ "$FAIL" -eq 0 ]
