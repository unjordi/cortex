#!/usr/bin/env bash
# entorno-maquina-guard: ¿escanea solo lo que ENTRA al commit? Escenarios en repo desechable.
S="$1"; HK="$2"; export HOME="$S/h5"; rm -rf "$HOME" "$S/emg"; mkdir -p "$HOME" "$S/emg"
cd "$S/emg" && git init -q -b develop . && git config user.email a@b && git config user.name x
mkdir -p .claude/memory scripts
echo "nota neutra" > .claude/memory/estado.md
echo "uno" > scripts/a.sh
git add -A && git -c commit.gpgsign=false commit -q -m init
run() { jq -n --arg c "$1" --arg d "$S/emg" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | bash "$HK" 2>&1 | head -c 300; }
t() { out=$(run "$2"); if [ -n "$out" ]; then r=AVISA; else r=CALLA; fi; echo "$1 | esperado=$3 | real=$r"; }
# working tree trae Rosetta (alias personal) SIN stagear; el commit solo toca scripts/a.sh
printf 'colima y alias ls=eza -al y Rosetta sin condicional\n' >> .claude/memory/estado.md
echo "dos" >> scripts/a.sh; git add scripts/a.sh
t "S1 commit staged solo scripts, memoria sucia SIN stagear" 'git commit -m "fix: x"' CALLA
t "S2 commit -a (git SI sumaria la memoria tracked-modificada)" 'git commit -a -m "fix: x"' AVISA
git add .claude/memory/estado.md
t "S3 memoria con alias personal STAGED" 'git commit -m "fix: x"' AVISA
git reset -q .claude/memory/estado.md
printf 'colima, Rosetta, alias ls=eza -al\n' > .claude/memory/hilo-mental-actual.andamio.md   # UNTRACKED
t "S4 commit -a con andamio UNTRACKED (git NO lo incluye)" 'git commit -a -m "fix: x"' "AVISA solo por estado.md (tracked)"
git checkout -q .claude/memory/estado.md
t "S5 -a, memoria tracked limpia + andamio untracked" 'git commit -a -m "fix: x"' CALLA
# S6: memoria con alias STAGED pero el commit usa pathspec solo de scripts/ (git NO la incluye)
printf 'alias ls=eza -al Rosetta\n' >> .claude/memory/estado.md; git add .claude/memory/estado.md; echo tres >> scripts/a.sh
t "S6 commit con pathspec (-- scripts/a.sh); memoria staged NO entra" 'git commit -m "fix: x" -- scripts/a.sh' CALLA
