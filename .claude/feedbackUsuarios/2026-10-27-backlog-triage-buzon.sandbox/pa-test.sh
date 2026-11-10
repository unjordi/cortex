#!/usr/bin/env bash
# Prueba de proteger-autorizaciones contra los FPs de la nota 2026-10-27 y controles positivos.
S="$1"; HK="$2"; export HOME="$S/h4"; mkdir -p "$HOME"
run() { jq -n --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' | bash "$HK" 2>&1 | head -c 400; }
t() { out=$(run "$2"); if printf '%s' "$out" | grep -q 'deny\|BLOQUEADO'; then r=FRENA; else r=PASA; fi; echo "$1 | esperado=$3 | real=$r"; }
G='autorizaciones-vigentes'
t "FP1 heredoc python escribe SKILL.md" $'python3 - <<EOF\nopen(".claude/skills/m/SKILL.md","w").write("x")\nEOF' PASA
t "FP2 glob memory/*.md escribe los que contienen texto" $'python3 - <<EOF\nimport glob\nfor f in glob.glob("memory/*.md"):\n    s=open(f).read()\n    if "x" in s: open(f,"w").write(s)\nEOF' PASA
t "FP3 heredoc escribe projects/aud.md" $'python3 - <<EOF\nopen(".claude/projects/aud.md","w").write("x")\nEOF' PASA
t "FP6 solo MENCIONA el nombre en texto escrito a otro archivo" "cat >> docs/nota.md <<EOF
el guard bloquea ${G}.local.md por error
EOF" PASA
t "FP7 echo que menciona, redirige a otro archivo" "echo 'ver ${G}.local.md' >> docs/guards-falsos-positivos.md" PASA
t "TP1 python open append al grant" "python3 -c \"open('.claude/memory/${G}.local.md','a').write('x')\"" FRENA
t "TP2 echo >> grant" "echo x >> .claude/memory/${G}.md" FRENA
t "TP3 tee grant" "echo x | tee .claude/memory/${G}.local.md" FRENA
t "TP4 sed -i grant" "sed -i 's/a/b/' .claude/memory/${G}.local.md" FRENA
t "OK lectura cat" "cat .claude/memory/${G}.local.md" PASA
