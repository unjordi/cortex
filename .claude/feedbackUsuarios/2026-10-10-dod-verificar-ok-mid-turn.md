# dod-verificar no ve el OK escrito a media vuelta

- Origen: axon-master, 2026-10-10 (housekeeping del backlog de axon; hallazgo original del 2026-09 en la rama `fix/tuning-confirmar-merge-develop`, ya superada por el overhaul de guards #438).
- `brain/hooks/dod-verificar.sh:217-229` recorta el turno y toma el texto del usuario solo de mensajes `role=user`/`type:user`. El CLI persiste un mensaje escrito a media vuelta como `attachment`/`queued_command`, no como turno `type:user` → un OK real del usuario dado mid-turn no entra al eje MARCA.
- Mismo fix que se aplicó al juez de merge en su momento: incluir `queued_command` como texto del usuario. Es un candado de supervisión: pide el OK explícito de unjordi para ESE control.
- Pendiente aparte de la misma rama: `ACG_MR_TIMEOUT=6s` podría quedar corto para `glab api` (sin medir).
