#!/usr/bin/env bash
# 02-ruta-id-para-auditoria.sh
#
# Hallazgo que lo originó: auditoría de MegaFlux (2026-07-15) — `SucesosController` usaba
# `{sucesoId:guid}` e `InspeccionesController` usaba `{inspeccionId:guid}` en sus rutas
# mutantes. `FiltroRegistroActividad.OnActionExecutionAsync` (Plantilla.webapi/Filters/)
# solo sabe leer el id auditado de `ActionArguments["id"]` (o de `IContextoUsoRequest.EntidadId`
# si el controller lo fija a mano). Resultado real: TODA mutación de esos dos agregados quedó
# auditada con EntidadId = null — exactamente el caso que el negocio pedía cubrir ("que quede
# quién borró QUÉ").
#
# Qué verifica: todo [HttpPost]/[HttpPut]/[HttpDelete]/[HttpPatch] cuya ruta trae un placeholder
# ({xxx} o {xxx:tipo}) distinto de "id" debe, en ese mismo archivo, o bien fijar
# `EntidadId = ` explícitamente (override manual), o traer el comentario de excepción
# documentada `auditor-semantico:` cerca de la línea de ruta.
#
# Falso positivo esperado: un placeholder que NO es el id de la entidad auditada (p.ej. un
# sub-recurso con dos ids en la ruta) — en ese caso documenta con el comentario de excepción
# en vez de ignorar el hallazgo.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib-formato.sh"

hallazgos=0
out=/tmp/auditor-semantico-02.out
: > "$out"

controllers=$(find . -type d -iname "Controllers" 2>/dev/null | grep -i webapi)

for dir in $controllers; do
	[ -d "$dir" ] || continue
	for archivo in "$dir"/*.cs; do
		[ -f "$archivo" ] || continue
		tiene_override=0
		grep -q "EntidadId[ \t]*=" "$archivo" && tiene_override=1

		while IFS=: read -r linea contenido; do
			# extrae el nombre del placeholder: {xxx} o {xxx:tipo}
			param=$(echo "$contenido" | grep -oE '\{[a-zA-Z]+(:[a-zA-Z]+)?\}' | head -1 | sed -E 's/[{}]//g; s/:.*//')
			[ -z "$param" ] && continue
			param_lower=$(echo "$param" | tr '[:upper:]' '[:lower:]')
			[ "$param_lower" = "id" ] && continue

			if [ "$tiene_override" -eq 1 ]; then
				continue
			fi
			# excepción documentada: comentario auditor-semantico en una ventana de ±3 líneas
			ventana=$(sed -n "$((linea > 3 ? linea - 3 : 1)),$((linea + 3))p" "$archivo")
			if echo "$ventana" | grep -q "auditor-semantico:"; then
				continue
			fi

			echo "${archivo}:${linea}: ruta con placeholder '{${param}}' (≠ id) sin EntidadId explícito ni excepción documentada — FiltroRegistroActividad auditará esta mutación con EntidadId=null ${SUFIJO_REVISAR_CAPA2}" >> "$out"
		done < <(grep -noE '\[Http(Post|Put|Delete|Patch)\("[^"]*\{[a-zA-Z]+(:[a-zA-Z]+)?\}[^"]*"\)\]' "$archivo")
	done
done

hallazgos=$(wc -l < "$out" | tr -d ' ')
if [ "$hallazgos" -gt 0 ]; then
	cat "$out"
fi
rm -f "$out"

reportar_candidatos "$hallazgos"
exit $?
