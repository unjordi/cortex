#!/bin/bash
# Prueba la excepción de merge-develop-guard para syncs de upstream contra PRs REALES de unjordi/armada-rp6.
# #40 = sync de upstream (historia ajena) · #39 = PR normal (sin merge commit ajeno).
H=~/.claude/hooks/merge-develop-guard.sh; T=$(mktemp -d); fail=0
mk_tr(){ jq -nc --arg t "$1" '{type:"user",message:{role:"user",content:$t}}' > "$T/$2.jsonl"; }
mk_tr 'autorizo --merge (sin squash) del PR #40 a develop' auth40
mk_tr 'autorizo --merge (sin squash) del PR #39 a develop' auth39
mk_tr 'haz el merge del 40 porfa' sinfrase
run(){ jq -nc --arg c "$1" --arg t "$T/$2.jsonl" --arg d "$PWD" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d,transcript_path:$t}' | bash "$H" 2>/dev/null; }
esquash(){ printf '%s' "$1" | grep -q 'SQUASHEA a UN commit'; }
check(){ local desc=$1 esperado=$2 out=$3; if esquash "$out"; then r=deny-squash; else r=pasa-squash; fi
  [ "$r" = "$esperado" ] && echo "ok   $desc ($r)" || { echo "FAIL $desc: esperaba $esperado, dio $r"; fail=1; }; }
check "#40 sync + --merge + frase del usuario" pasa-squash "$(run 'gh pr merge 40 --merge --repo unjordi/armada-rp6' auth40)"
check "#40 sync + --merge SIN frase"          deny-squash "$(run 'gh pr merge 40 --merge --repo unjordi/armada-rp6' sinfrase)"
check "#40 sync SIN --merge (sin flag)"       deny-squash "$(run 'gh pr merge 40 --repo unjordi/armada-rp6' auth40)"
check "#39 normal + --merge + frase"          deny-squash "$(run 'gh pr merge 39 --merge --repo unjordi/armada-rp6' auth39)"
check "#40 frase de OTRO PR (#39)"            deny-squash "$(run 'gh pr merge 40 --merge --repo unjordi/armada-rp6' auth39)"
rm -rf "$T"; echo "fail=$fail"; exit $fail
