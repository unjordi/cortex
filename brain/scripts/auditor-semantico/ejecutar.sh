#!/usr/bin/env bash
# ejecutar.sh — Auditor Semántico, Capa 1 (chequeos deterministas).
#
# Corre cada script de checks/*.sh contra ESTE repo (la plantilla, o cualquier
# proyecto clonado de ella) y agrega el resultado. Cada check es una heurística
# nacida de un hallazgo REAL de una auditoría — ver README.md de esta carpeta
# para el modelo completo (Capa 1 determinista + Capa 2 semántica con LLM).
#
# MOTOR GENÉRICO (vive en claude-brain/brain/scripts/): el runner y lib-formato.sh
# son agnósticos de stack. Los checks/*.sh que vienen de fábrica son EJEMPLOS de la
# plantilla .NET (permisos de endpoints, auditoría por ruta, Dapper/DateOnly, grid
# homologado) — cada repo AFINA su propio catálogo a su stack/dominio (ver README).
#
# Uso:
#   ./scripts/auditor-semantico/ejecutar.sh              # todos los checks
#   ./scripts/auditor-semantico/ejecutar.sh 02 04         # solo esos números
#
# Salida: humana por stdout; exit 0 si todos limpios, exit 1 si algún check
# reportó hallazgos (para gatear CI). Los hallazgos son heurísticas — pueden
# tener falsos positivos; revísalos, no los asumas ciertos a ciegas.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKS_DIR="$DIR/checks"
cd "$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null || echo "$DIR/../..")"

# PREFIX = prefijo del proyecto .NET (directorio "*.domain"). Los checks .NET de ejemplo lo
# usan para localizar el proyecto; los checks agnósticos lo ignoran. NO es fatal si no existe
# (un repo no-.NET, o uno sin ese layout, puede seguir corriendo sus propios checks): se avisa
# y se deja vacío en vez de abortar — el motor es genérico, el layout .NET es solo del ejemplo.
PREFIX=$(find . -maxdepth 1 -type d -name "*.domain" | head -1 | sed 's|./||;s|\.domain||')
export PREFIX

echo "═══════════════════════════════════════════════════════════"
echo " Auditor Semántico — Capa 1 (chequeos deterministas)"
if [ -n "$PREFIX" ]; then
	echo " Proyecto detectado: ${PREFIX}"
else
	echo " (sin prefijo *.domain — repo no-.NET o layout distinto; los checks .NET de ejemplo"
	echo "  no encontrarán nada. Afina tu propio catálogo en checks/ — ver README.md)"
fi
echo "═══════════════════════════════════════════════════════════"
echo

filtro_num=("$@")

total=0
fallas=0
resumen=()

for check in "$CHECKS_DIR"/*.sh; do
	[ -f "$check" ] || continue
	nombre="$(basename "$check" .sh)"
	numero="${nombre%%-*}"

	if [ "${#filtro_num[@]}" -gt 0 ]; then
		encontrado=0
		for f in "${filtro_num[@]}"; do
			[ "$f" = "$numero" ] && encontrado=1
		done
		[ "$encontrado" -eq 1 ] || continue
	fi

	total=$((total + 1))
	echo "── ${nombre} ──"
	if bash "$check"; then
		resumen+=("✅ ${nombre}")
	else
		resumen+=("❌ ${nombre}")
		fallas=$((fallas + 1))
	fi
	echo
done

echo "═══ Resumen ═══"
if [ "${#resumen[@]}" -eq 0 ]; then
	echo "(ningún check corrió — revisa el filtro pasado como argumento)"
else
	printf '%s\n' "${resumen[@]}"
fi
echo

resultado=0
if [ "$fallas" -gt 0 ]; then
	echo "${fallas} de ${total} check(s) con candidatos a revisión semántica (NO bugs confirmados —"
	echo "Capa 1 jamás confirma uno). Revísalos con Capa 2 antes de decidir si son bug o excepción."
	echo "Son heurísticas: puede haber falsos positivos — si uno es recurrente, ajusta el check"
	echo "(no lo ignores en silencio; documenta la excepción en el código si aplica)."
	resultado=1
else
	echo "${total}/${total} checks sin candidatos."
fi

echo
echo "───────────────────────────────────────────────────────────"
echo "Esto fue SOLO la Capa 1 (determinista). La Capa 2 del auditor semántico se ejecuta"
echo "con la skill 'auditor-semantico' (un LLM con criterio — Claude), NO aquí: es"
echo "inherentemente no determinista, por eso no hay forma de correrla en CI ni en bash."
echo "Un CI/local en verde de este script NO significa \"código auditado del todo\"."
echo "───────────────────────────────────────────────────────────"

exit "$resultado"
