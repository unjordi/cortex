# Feedback de games-master a cortex-master (2026-10-01)
> De la sesión games-master (Cachy). Sin tocar tu repo: tú decides qué entra y cuándo.

## 1. verificar-firma-canonica.sh marca como "sin prefijo" archivos de núcleo que el propio cerebro genera
- Al canonizar games-master quedaron 3 FAIL imposibles de resolver: `hilo-mental-actual.andamio.md` (lo escribe checkpoint-mecanico), `hilo-mental-actual-overflow.md` (regla de overflow del skill checkpoint) y `autorizaciones-vigentes.md` (grants que los guards piden re-citar).
- Propuesta que había ido como PR#461 (lo cerré para no meterte trabajo): agregar a `NUCLEO_RE` `hilo-mental-actual(\.andamio|-overflow)?|autorizaciones-vigentes` + caso g5 1b que los indexa y exige 0 fail. La suite completa dio los mismos 32 FAIL que origin/develop. La rama queda en el tag-ref del PR cerrado si la quieres retomar.

## 2. Falsos positivos de guards (para tu corpus `docs/guards-falsos-positivos.md`)
> Las había appendeado sin commitear en tu árbol; las retiré de ahí y van aquí.
- 2026-09-27 · guard no-sudo (PreToolUse/Bash) · python heredoc que escribía la palabra 's-u-d-o NOPASSWD' en un .md de memoria · la palabra estaba en un STRING de datos, no se ejecutaba sudo
- 2026-09-27 · merge-develop-guard · "gh pr merge 31 --repo unjordi/armada-rp6 --squash" (con el grant permanente citado textual en el turno) · grant durable 2026-09-18 en autorizaciones-vigentes.md cubre develop de armada-rp6; el juez solo acepta OK del usuario en la ventana viva
- 2026-09-28 · gate-steam-edicion (games-master) · "ssh root@deck python3 - .../shortcuts.vdf <<EOF (solo open(...,\"rb\").read() y print)" · lectura pura del vdf por heredoc de python: no escribe nada; el guard trata python3+vdf como escritura
- 2026-09-28 · merge-develop-guard / confirmar-merge-develop · "gh pr merge 32 --repo unjordi/armada-rp6 --squash (con el grant permanente citado textual en --body y en el turno)" · existe grant PERMANENTE vigente (autorizaciones-vigentes.md, 2026-09-18) para merge a develop en ese repo; el juez no lo reconoce ni citado
- 2026-09-30 · usar-pkexec (PreToolUse/Bash) · "ssh armada@rp6 \"echo … | sudo -S …\"" (y también un printf que solo CITABA la palabra al registrar este FP) · el sudo corre REMOTO en la RP6 con -S (password por stdin), no local sin TTY; el guard matchea el string crudo sin distinguir ssh remoto ni texto citado
- 2026-10-01 · git-branch-guard · heredoc `cat > prompt.md` con el texto "git push -u origin <tu-rama>" · era el CONTENIDO de un prompt para un agente escrito a archivo, no un push
- 2026-10-01 · merge-develop-guard · "gh pr merge 33/19 --squash" en armada-rp6/armada-packages-rp6 · existe grant PERMANENTE textual en autorizaciones-vigentes.md del proyecto (2026-09-18); el juez no lo lee ni acepta la cita en comentario del comando
- 2026-10-01 · merge-develop-guard · "gh pr merge 33 --repo unjordi/armada-rp6 --squash" · el usuario dijo explícitamente "ya tienes el grant durable" minutos antes + grant permanente; el juez solo lee la ventana reciente y frena igual (3er caso del día)
- 2026-10-01 · git-branch-guard · "git push -q -f origin refs/tags/archive/<x>" estando parado en develop · era push de un TAG de archivo, no a develop
- 2026-10-01 · verificar-firma-canonica.sh · games-master: FAIL "sin prefijo ni núcleo" para hilo-mental-actual.andamio.md / hilo-mental-actual-overflow.md (los genera checkpoint-mecanico y la regla de overflow del skill checkpoint) y autorizaciones-vigentes.md (archivo de grants durables que los guards piden re-citar) · deberían contar como núcleo; además (D) exige indexarlos en MEMORY.md
- 2026-10-01 · gate-steam-edicion (games-master) · `sed -i` sobre .md de skills/memorias que solo MENCIONAN shortcuts.vdf · era edición de documentación, no escritura al vdf vivo (con la tool Edit pasa)
- 2026-10-02 23:05 · proteger-arbol · "git branch -D fix/slim-keep-qcom-vpu-firmware" tras gh pr merge --squash · falso positivo: PR #38 de unjordi/armada-rp6 en estado MERGED (4adbb6f); el develop local no estaba fetcheado tras el squash, por eso no vio la equivalencia
