#!/usr/bin/env bash
# lib-formato.sh — formato común de salida de los checks de Capa 1.
#
# Por qué existe: un check de Capa 1 NUNCA puede confirmar un bug semántico — no entiende
# intención de negocio, solo reconoce un patrón de texto. Si el log dice simplemente
# "N hallazgo(s)", alguien que lo lea SIN el contexto de esta conversación (un humano que
# solo pega el log, o un Claude/LLM sin memoria al que se lo pegan) puede leerlo como un
# veredicto ya juzgado. Este formato lo hace imposible de malinterpretar aun fuera de
# contexto: separa "lo que Capa 1 puede confirmar" (SIEMPRE cero, por diseño) de
# "candidatos que alguien con criterio debe revisar".
#
# Uso desde un check:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib-formato.sh"
#   echo "${archivo}:${linea}: <descripción del patrón> ${SUFIJO_REVISAR_CAPA2}"
#   ...
#   reportar_candidatos "$hallazgos"
#   exit $?

SUFIJO_REVISAR_CAPA2="— revisar semántica de negocio con Capa 2 (skill auditor-semantico) antes de decidir si es bug o excepción documentada"

reportar_candidatos() {
	local n="${1:?reportar_candidatos requiere el conteo de candidatos}"
	echo "RESULTADO: 0 hallazgo(s) semánticos CONFIRMADOS por Capa 1 (no puede confirmarlos — es determinista, no entiende intención de negocio)"
	echo "RESULTADO: ${n} candidato(s) a revisión semántica con Capa 2"
	if [ "$n" -gt 0 ]; then
		return 1
	fi
	return 0
}
