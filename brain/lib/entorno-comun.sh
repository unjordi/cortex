#!/usr/bin/env bash
# entorno-comun.sh — LIB de INSTALACIÓN (NO es un hook; NUNCA viaja a ~/.claude/hooks — se sourcea
# solo durante install-brain.sh/uninstall-brain.sh/test-brain.sh, igual que detectar-shells.sh).
#
# Resuelve el directorio de config de Claude HONRANDO CLAUDE_CONFIG_DIR, con la MISMA lógica que
# brain/hooks/juez-comun.sh ya usa en runtime (_juez_dir): antes cada script instalador hardcodeaba
# "$HOME/.claude" por su cuenta, ignorando la variable que el resto del cerebro (juez-comun.sh,
# dod-verificar.sh, confirmar-merge-develop.sh, limpiar-residuo.sh, bin/session-lib.js…) ya trata
# como resuelta. Efecto real del bug: con CLAUDE_CONFIG_DIR seteada, install-brain.sh escribía TODO
# el cableado en una ruta que el harness no lee — instalación 100% silenciosa y no-funcional
# (A1, auditoría 2026-09-15). Una sola fuente para los tres consumidores cierra el hueco sin que cada
# uno vuelva a resolverlo a mano y pueda re-divergir. shellcheck shell=bash
claude_config_dir() { printf '%s' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; }
