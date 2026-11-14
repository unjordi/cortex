---
name: estandar-pruebas
description: El estándar único de pruebas de todos los proyectos — qué tiene que cumplir una prueba para contar, las firmas de rechazo, cómo se escribe una nueva, cómo se revisa una existente, la revisión semántica de CADA ítem y la pasada de limpieza que corre en cerrar-slice y al cierre de cada épica. Úsalo al escribir o revisar cualquier prueba, al redactar las pruebas de aceptación de un mandato, y al cerrar un slice o una épica.
---

# Estándar de pruebas

La pregunta que gobierna todo: **¿el código hace lo que DEBE hacer, y se niega a hacer lo que NO debe?**
No «¿corre sin tronar?». Un verde que no significa nada es peor que no tener prueba: da confianza falsa.
La cobertura es un dato, nunca una meta: una prueba que sube la cobertura sin defender un caso de uso se retira.

## 1 · La prueba de una prueba
Un aserto entra solo si pasa las dos:
1. **Puede fallar.** Existe un estado del mundo en el que da rojo.
2. **Falla contra el código viejo.** Revertido y corrido, no supuesto; la salida se cita («con develop se pierde 4 de 4»).

## 2 · Firmas de rechazo
Si una prueba calza con alguna, se arregla o se retira.
- **R1 · No puede fallar.** Compara un valor consigo mismo o con algo derivado de sus entradas; grepea un patrón que siempre está; el oráculo es «el mejor de N candidatos» (casi cualquier salida acierta); una métrica agregada que pasa por construcción (IoU de máscaras, «no está en negro», «el archivo tiene tamaño»).
- **R2 · Mide el andamio, no el efecto.** Que el archivo existe, que la función se llamó, que el mock recibió la llamada, que salió 0, que el log trae cierta línea, que compila, que el «hola mundo» arranca, que el módulo vive en tal carpeta.
- **R3 · El escenario no se montó.** El setup falló en silencio (la entrada nunca llegó, el estado no cargó, el servicio no respondió, el bucle no corrió) y el aserto prueba el caso vacío.
- **R4 · Mide el objeto equivocado.** El número es real pero no es del sujeto: el proceso de la prueba en vez del medido; un modelo en vez de la pantalla; un oráculo que recalcula con la misma fórmula que el código probado (da igual con o sin el cambio).
- **R5 · El esperado quedó viejo o inventado.** Igualdad exacta contra un mensaje o un default que evoluciona a propósito; un fixture escrito a mano con valores que la herramienta real nunca produce.
- **R6 · El verde depende del entorno.** Pasa porque aquí hay un servicio vivo, un modelo cargado, una ruta o una sesión ssh. Lo que no se puede correr dice SKIP, nunca OK.
- **R7 · Media prueba.** Solo una dirección: rechaza lo inválido pero no comprueba que acepta lo válido, o al revés.
- **R8 · Repetida.** Ejercita lo mismo que otra (un segundo corredor de la batería, el mismo caso con el mismo insumo). Cuesta tiempo y finge cobertura.

## 3 · Cómo se escribe una prueba nueva
1. **Empieza por el caso de uso**: quién hace qué y qué debe obtener. Si no cabe en una línea, todavía no sabes qué probar.
2. **Efecto observable por el canal del usuario**: el valor devuelto, el archivo escrito, lo que sale en pantalla, la fila en la base, el paquete que llega. No el estado interno ni la llamada al mock.
3. **Las dos direcciones**: acepta lo válido y rechaza lo inválido.
4. **El negativo se mide por el efecto concreto que no debía ocurrir**, no por «algo cambió»: un hash o un diff se mueve con cualquier perturbación, incluida la de la propia prueba.
5. **Comprueba que el escenario existe** antes de aseverar sobre él: la entrada llegó, el estado cargó, el servicio respondió, el bucle corrió N veces (el resumen afirma el conteo).
6. **Oráculo exacto y determinista**: la referencia del mismo instante o estado. Si la referencia no es determinista, primero se hace determinista y se mide que repetirla dé lo mismo.
7. **Valida el instrumento** con un caso de respuesta conocida antes de creerle: un medidor mal hecho miente igual que el sistema.
8. **Fixtures capturados de la herramienta real** (`systemctl show`, `launchctl print`, la respuesta de la API), no escritos a mano.
9. **El caso que duele**, no el benigno: con dueño vivo y no solo con lock huérfano; con el archivo ajeno presente y no solo con el propio en su sitio.
10. **Lo que monta producción**: si el arranque real no llama al setup, la prueba tampoco lo llama a mano. Y lo que se verifica está **invocado desde el camino real**: un predicado o un chequeo definido que nadie llama no protege nada (definido ≠ cableado).
11. **Esperado derivado**, no transcrito (importa la constante); **nombre honesto** (dice lo que mide); **dependencia declarada** (offline y determinista, o en el carril que levanta lo que necesita).
12. **Las configuraciones que cambian el estado viajan juntas**: guardar y cargar, medir y comparar, con la misma opción; la prueba lo fija.
13. **Regresiones ancladas a un SHA fijo**, nunca a una rama que se mueve.
14. **Una contraprueba por interruptor**: cada cosa que se protege tiene su contraprueba propia, no una que apaga tres cosas.

## 4 · Fallas silenciosas: el log como contrato
Todo lo que el sistema descarta o degrada (filas, texturas, claves inválidas, reintentos, mensajes) deja un contador o un aviso, con un interruptor para provocarlo, y las pruebas de efecto fallan si el contador no está en 0. Así un verde no esconde una degradación.

## 5 · La batería y quien la espera
- La batería distingue «terminé» de «me morí»: un centinela (`trap EXIT`) que sale distinto de 0 si no llegó al final.
- Lo que monta algo real corre aislado (sandbox, copia, VM); lo que pueda tocar la máquina real va atrapado.
- Un vigilante espera la **línea de resultado** o un marcador que solo escribe el final feliz; nunca `pgrep -f` (se encuentra a sí mismo) ni «el proceso terminó» (una ayuda impresa también termina).
- «Verde» solo cuenta medido con la batería completa en la máquina donde corre lo probado.

## 6 · Mecanismo del repo
Cada repo documenta en su propio doc lo suyo: su comando de batería, la sonda sintáctica que corre en su suite (como mínimo R1 «se compara consigo mismo» y R2 «lee el fuente y lo grepea» o «solo verifica la llamada al mock») y sus casos reales. Una sonda sintáctica caza poco: acota el daño nuevo, no sustituye la lectura.

## 7 · Al revisar una prueba existente
En orden, con veredicto **por aserto**:
1. Córrela **aislada y dentro de la suite**; si difieren, ya hay R4 o R6.
2. Aplica §1 a cada aserto.
3. Busca las firmas de §2. Para R3, comprueba explícitamente que el escenario se montó.
4. Dictamina: **CONSERVAR** · **ARREGLAR** (qué aserto y con qué) · **RETIRAR** (qué deja de cubrirse; si lo que cubría importa, lo que falta es una prueba de caso de uso).
5. Lo que sobrevive queda con su nombre corregido si prometía más de lo que mide.

## 8 · Revisión semántica de CADA ítem
Cada ítem que se cierra —cada fila del plan, cada prueba nueva o arreglada, cada hallazgo resuelto— lleva **su propia** revisión semántica, hecha por quien revisa (no por quien lo construyó) y escrita junto al ítem con su resultado. Un verde no cierra un ítem; esto sí. La revisión de la épica completa (§9) va aparte y encima de las de cada ítem, nunca en su lugar.
- **Vuelve al porqué**: lee el origen del ítem y pregúntate si ese problema ya no podría repetirse. Úsalo en vivo sobre una copia como lo usaría quien lo pidió; si para entender la salida hay que excavar, no está resuelto aunque pase.
- **Formas de fallar que la prueba no fija**: ¿se recupera?, ¿castiga de más?, ¿la variante parecida en palabras pero no en sentido? Cada una es un caso nuevo, no un comentario.
- **Qué le hace al resto**: corre los recorridos vecinos que el cambio puede tocar y compara con antes.
- **Diseño contra la arquitectura**: capa correcta, sin un segundo mecanismo para lo mismo, salida accionable, valores configurables.
- **Si al relatar el cierre hay que matizar, todavía no está.**

## 9 · La pasada de limpieza
Corre **en `cerrar-slice`** sobre lo que toca el slice y **al cierre de cada épica** sobre toda la épica. Tres fases, en orden, cada una con su doc de salida y un veredicto por ítem:
1. **Re-verificar lo cerrado.** Por cada ítem ✅: qué prueba lo cerró, si mide lo que ve el usuario o un modelo, si su contraprueba falla contra el código viejo, si su revisión semántica (§8) existe y el cierre se relata sin matices. Veredicto: *sostiene* (repetido, con comando y salida) · *reabierto* (vuelve a ⬜ con lo que le falta) · *sin evidencia*.
2. **Auditar prueba por prueba** con §7. Veredicto por prueba: conservar · arreglar · nueva · retirar.
3. **Revisión semántica del código tocado**, pieza por pieza: contrato y qué hace al fallar, variantes que ninguna prueba fija, efecto sobre lo vecino, lo que solo funciona en un entorno, comentarios que dicen lo vigente. Cada hallazgo con severidad y su resolución medida.

Los hallazgos se resuelven **en la misma rebanada**, antes del merge; mandarlos «a un paso del plan» no es resolverlos, salvo que el usuario lo diga. Lo descubierto sin causa entra al plan como paso propio con criterio de cierre medible. Un paso futuro que la pasada obligue a tocar se avisa en el momento.

## 10 · Comentarios en las pruebas
Sirven para OPERAR la prueba: qué monta el escenario y por qué hace falta, qué contrato verifica, qué perilla la gobierna, dónde está el contrato vigente que replica. No llevan la historia del incidente, números de PR, fechas ni «antes/ahora»: eso va al commit y a la bitácora.
