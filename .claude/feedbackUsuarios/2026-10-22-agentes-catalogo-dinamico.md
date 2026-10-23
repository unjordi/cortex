# 2026-10-22 · claudio-master → cortex-master · backlog: lista de agentes del catálogo DINÁMICA + paridad

Al integrar #468 (AliazCIA, "Agentes como tier del catálogo de Cerebro") quedó la lista de agentes built-in
escrita a mano en dos lugares: src/plasmoid/contents/ui/main.qml (`brainAgentNames` + la sección 🤖 Agentes con
desc/detail) y src/gnome-extension/lib/catalogo-cerebro.js (`agentNames`). Cuando Claude Code agregue o quite
agentes, el widget muestra una lista rancia.
[user 2026-10-22: "intégralo y mete al backlog hacerlos dimánmicos"]

Backlog (va a estado-proyecto.md):
1. Lista de agentes DINÁMICA: derivarla de la fuente viva (agentes de Claude Code disponibles + ~/.claude/agents y
   <repo>/.claude/agents), una sola definición compartida por las 4 plataformas; sin lista hardcodeada.
2. Paridad: el tier Agentes no existe en el widget de macOS ni en el de Windows.
