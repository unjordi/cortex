#!/usr/bin/env bash
# 01-permisos-endpoints-mutantes.sh
#
# Hallazgo que lo originó: auditoría de MegaFlux (2026-07-15) — todos los endpoints
# mutantes revisados SÍ estaban gateados, pero es justo el tipo de regresión silenciosa
# que un unit test no atrapa (el test mockea el service, no pasa por el pipeline HTTP
# de autorización) y que rompe seguridad si alguien copia-pega un controller nuevo sin
# el atributo.
#
# Qué verifica: todo método de controller con [HttpPost]/[HttpPut]/[HttpDelete]/[HttpPatch]
# debe tener un [Authorize(Policy = ...)] en su propio bloque de atributos (no basta con
# [Authorize] a secas de la clase, que solo exige "estar logueado").
#
# Heurística de líneas: acumula el bloque de atributos que precede a cada firma de método
# y exige que contenga "[Authorize(Policy". Reconoce TAMBIÉN el patrón de policy a nivel de
# CLASE (un solo `[Authorize(Policy=...)]` para todo el controller, en vez de uno por método
# — igual de válido; confirmado real en MegaFlux/RolesController, 2026-07-15, que generaba
# 3 falsos positivos hasta que se agregó este reconocimiento): si el atributo aparece ANTES
# de la línea `class ... : ControllerBase`, se asume que cubre TODOS los métodos del archivo
# y no se exige nada por método.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib-formato.sh"

hallazgos=0

controllers=$(find . -path "*/${PREFIX}.webapi/Controllers" -o -path "*.webapi/Controllers" 2>/dev/null | sort -u)
[ -z "$controllers" ] && controllers=$(find . -type d -iname "Controllers" 2>/dev/null | grep -i webapi)

for dir in $controllers; do
	[ -d "$dir" ] || continue
	while IFS= read -r -d '' archivo; do
		linea_clase=$(grep -nE "^[ \t]*(public|internal)[ \t]+(sealed[ \t]+)?class[ \t]" "$archivo" | head -1 | cut -d: -f1)
		linea_policy=$(grep -nE "^[ \t]*\[Authorize\(Policy" "$archivo" | head -1 | cut -d: -f1)
		if [ -n "$linea_clase" ] && [ -n "$linea_policy" ] && [ "$linea_policy" -lt "$linea_clase" ]; then
			continue
		fi
		awk -v archivo="$archivo" -v sufijo="$SUFIJO_REVISAR_CAPA2" '
			BEGIN { tiene_authorize_policy = 0; linea_http = 0 }
			/^[ \t]*\[Http(Post|Put|Delete|Patch)(\(|\])/ {
				linea_http = NR
				tiene_authorize_policy = 0
				next
			}
			# [AllowAnonymous] (p.ej. login) o [Authorize(Policy=...)] satisfacen el chequeo.
			/^[ \t]*\[/ {
				if ($0 ~ /\[Authorize\(Policy/ || $0 ~ /\[AllowAnonymous\]/) tiene_authorize_policy = 1
				next
			}
			# Excepción documentada: comentario "auditor-semantico:" dentro del bloque de
			# atributos — endpoint de autoservicio o similar, decidido a propósito (no un olvido).
			/^[ \t]*\/\// {
				if ($0 ~ /auditor-semantico:/) tiene_authorize_policy = 1
				next
			}
			# primera línea no-atributo/no-comentario tras un [HttpXxx] mutante = firma del método
			linea_http > 0 {
				if (tiene_authorize_policy == 0) {
					print archivo ":" linea_http ": método mutante sin [Authorize(Policy = ...)]/[AllowAnonymous] ni excepción documentada " sufijo
				}
				linea_http = 0
				tiene_authorize_policy = 0
			}
		' "$archivo"
	done < <(find "$dir" -maxdepth 1 -name "*.cs" -print0)
done > /tmp/auditor-semantico-01.out 2>/dev/null

hallazgos=$(wc -l < /tmp/auditor-semantico-01.out | tr -d ' ')
if [ "$hallazgos" -gt 0 ]; then
	cat /tmp/auditor-semantico-01.out
fi
rm -f /tmp/auditor-semantico-01.out

reportar_candidatos "$hallazgos"
exit $?
