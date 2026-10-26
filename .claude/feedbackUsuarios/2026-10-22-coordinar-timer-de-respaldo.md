# 2026-10-22 · claudio-master → cortex-master · coordinar-claudes: timer de respaldo mientras se espera

Caso medido (2026-10-22): cortex-master quedó idle a las 15:21 pidiendo su /compact; el aviso `notify_when_idle`
llegó a claudio hasta las 16:00:09, cuando unjordi le escribió. El aviso NO despierta a una sesión coordinadora
ociosa: espera en su cola hasta el siguiente turno. 40 min perdidos. [user: "cortex llevaba 40 minutos parado?
tu skill de coordinar-master está fallando, no?"; "más que regla en como-trabajar, debería ir en el skill"]

Cambios a brain/skills/coordinar-claudes/SKILL.md:
1. §2 (L44) y §3: `notify_when_idle` es aviso, no despertador. Mientras el coordinador espere a un master, deja
   SIEMPRE un timer de respaldo (`sleep 600` con `run_in_background`); al despertar mira el transcript del
   master: si terminó o pregunta, atiéndelo; si sigue trabajando, re-arma el timer.
2. §3 (L61, L77): hoy `screen … hardcopy` de cortex-master salió en blanco (bajo --remote-control); lo fiable fue
   su transcript (`~/.claude/projects/*/<sid>*.jsonl`, último texto de assistant y timestamps). Que la skill diga
   cómo leerlo como señal principal y deje hardcopy como complemento.
