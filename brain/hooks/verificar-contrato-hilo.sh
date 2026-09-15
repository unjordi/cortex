#!/usr/bin/env bash
# verificar-contrato-hilo.sh — PostToolUse/{Edit,Write,MultiEdit}: llama a `verificar_hilo`
# (contrato-hilo.sh) CADA VEZ que se escribe hilo-mental-actual.md, en vez de depender de que el
# modelo se acuerde de correrla a mano.
#
# POR QUÉ EXISTE (M3, auditoría 2026-09-15): contrato-hilo.sh ya trae `verificar_hilo()` — un
# verificador REAL, medido contra 9 hilos de ~/code (2/9 sin footer) — pero NINGÚN evento la disparaba
# sola: solo corría si el modelo, seleccionado por la prosa del skill `checkpoint`, se acordaba de
# invocarla a mano (`. ~/.claude/hooks/contrato-hilo.sh && verificar_hilo …`). Una función de
# verificación que solo un recordatorio en Markdown dispara es código MUERTO disfrazado de candado:
# tres pasadas de auditoría independientes reprodujeron que un checkpoint sin la invocación manual deja
# el hilo inauditable SIN que nada lo señale. Este hook cierra ese hueco con el MISMO patrón que ya usa
# `proteger-fuente-cerebro.sh` (PreToolUse/Edit|Write|MultiEdit, global, solo avisa por additionalContext,
# fail-open) — no es un diseño nuevo, es el patrón existente aplicado al archivo que le faltaba.
#
# AVISA, NUNCA BLOQUEA: PostToolUse ya no puede deshacer la escritura, y el checkpoint puede escribir el
# hilo en pasos intermedios (MultiEdit) antes de completar el footer — bloquear a medio-escribir sería un
# falso positivo garantizado. El valor está en que la ausencia del footer deje RASTRO visible, no en
# impedir la escritura.
#
# Escape: env CLAUDE_SKIP_VERIFICAR_HILO=1. Vive en brain/hooks/ (fuente); tier `global` (solo
# ~/.claude/hooks, lo instala el bootstrap) → sin cláusula de dedupe (no viaja por-repo).

[ "${CLAUDE_SKIP_VERIFICAR_HILO:-}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

fp=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$fp" ] && exit 0

# Solo nos importa hilo-mental-actual.md (el contrato NO aplica a otras memorias). Case en vez de un
# grep: más barato, dispara en CADA Edit/Write/MultiEdit.
case "$fp" in
  */hilo-mental-actual.md|hilo-mental-actual.md) : ;;
  *) exit 0 ;;
esac
[ -f "$fp" ] || exit 0

_selfdir="$(dirname "$0")"
[ -f "$_selfdir/contrato-hilo.sh" ] || exit 0   # lib ausente (instalación parcial) → fail-open, sin rastro falso
# shellcheck source=contrato-hilo.sh
. "$_selfdir/contrato-hilo.sh"

_motivos="$(verificar_hilo "$fp" 2>&1 1>/dev/null)"
[ -z "$_motivos" ] && exit 0   # contrato cumplido → silencio (nada que avisar)

MSG="AVISO (verificar-contrato-hilo): $fp no cumple el contrato del footer que rehidratar-hilo necesita para juzgar vigencia:
$_motivos
Esto NO bloquea el checkpoint — pero un hilo inauditable se presentará como '⚠️ POSIBLEMENTE OBSOLETO' la próxima vez que se retome, aunque esté vigente. Agrega la 2a línea: '> Última actualización: <AAAA-MM-DD> · rama <rama> · nivel <ligero|COMPLETO>'. (Escape: CLAUDE_SKIP_VERIFICAR_HILO=1.)"

jq -n --arg m "$MSG" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}'
exit 0
