# Grabación offline controlada por el usuario — 23/10/2026

## Causas identificadas en el código anterior

`OfflineSpeech.listen` ejecutaba `break` al primer `acceptWaveForm=true` con
texto: confundía el final de una frase con el final de toda la grabación.
Además, cortaba tras ocho segundos sin palabras. El resultado llegaba a Flutter
y activaba correctamente la interpretación automática, pero antes de que el
usuario pudiera detener la sesión.

El mismo hilo leía AudioRecord y ejecutaba el decodificador; su velocidad podía
retrasar las lecturas del micrófono. Esto es un riesgo de pérdida de frames, no
una prueba de que causara cada error acústico observado. La UI mostraba Grabando
y arrancaba el contador antes de recibir confirmación de audio efectivo.

## Corrección

- AudioRecord PCM16 mono 16.000 Hz; se verifican formato, canal y frecuencia
  reales. Bloques de 1.600 muestras (~100 ms), buffer nativo de al menos 32 KB.
- Captura continua independiente del decodificador, en un hilo fuera de UI.
  Buffer privado en memoria de hasta 720.000 muestras (1,44 MB, 45 segundos).
  No se escribe audio nuevo en disco ni se envía por red.
- El evento `ready` solo se emite después de recibir el primer bloque válido,
  que también se conserva. Entonces aparecen Grabando y el contador. Esperar
  ese estado antes de hablar; la preparación del modelo no cuenta como grabación.
- Sin endpoint de Vosk ni corte por silencio en la fase de captura. Finaliza
  con Detener o con el límite nativo de 45 s; Flutter mantiene el mismo límite.
  La parada normal no detiene AudioRecord desde otro hilo: la lectura actual
  termina y se drena una cantidad acotada de frames ya disponibles antes de cerrar.
- Después se libera el micrófono y aparece «Transcribiendo tu grabación en el
  celular…». Cada muestra conservada pasa una vez al reconocedor; cada endpoint
  añade un segmento, y se añade el `finalResult` restante al terminar.
- Un token de generación invalida callbacks cancelados. Cancelar descarta el
  resultado y no crea propuesta. La cancelación también está disponible durante
  la transcripción. Permisos, desconexión, lectura interrumpida y salida de la app
  tienen mensajes específicos. No se añaden reintentos hacia Gemini.
- Vosk integrado se prefiere para esta sesión de duración manual; el servicio
  nativo sigue como alternativa si no hay modelo incluido. Algunos reconocedores
  Android finalizan solos al detectar una frase; no se promete sesión manual
  continua sobre esos servicios. El Android actual usa Vosk.
- Solo un resultado final completo dispara la propuesta local y el scroll.
  Corregir y reinterpretar mantiene el ID; confirmar sigue siendo obligatorio.

## Precisión, modelos y contexto

La lectura y el cierre ahora conservan todo el audio; no se aplican correcciones
arbitrarias del tipo «se encuentra» → «cincuenta». Las reglas reconocen diez,
veinte, veintitrés, cincuenta, ochenta, cien y las variantes comerciales probadas.
Si el importe no aparece de forma fiable, queda por completar.

El modelo pequeño español 0.42 está destinado a móvil; el modelo grande español
oficial ocupa ~1,4 GB. No se cambió de modelo ni se descargaron pesos nuevos.
Las métricas publicadas no acreditan precisión específica para este comerciante
o el acento peruano. [Modelos oficiales](https://alphacephei.com/vosk/models).

Vosk permite sustituir el vocabulario mediante gramáticas. Eso no equivale a un
sesgo suave manteniendo todo el vocabulario abierto: una lista comercial puede
excluir productos/personas o empujar hipótesis ambiguas. Se evaluó y se conserva
el decodificador abierto hasta contar con un corpus local de comparación y tasas
de error de importes. No se fuerza una gramática financiera sin esa evidencia.
[API de gramática y sample rate](https://javadoc.io/static/com.alphacephei/vosk-android/0.3.75/org/vosk/Recognizer.html),
[adaptación oficial](https://alphacephei.com/vosk/adaptation).

Como alternativa técnica existe el runtime Android sherpa-onnx con modelos
multilingües, pero no hay en esta revisión una comparación de precisión, RAM y
latencia sobre estas grabaciones. Reemplazar el runtime/modelo añadiría integración
y pruebas nativas; no se afirma que sea mejor en este teléfono ni se instala.
[Proyecto oficial](https://github.com/k2-fsa/sherpa-onnx).

## Validación automatizada

- Analyzer sin incidencias; 153 Flutter aprobadas y una omitida.
- Sesiones simuladas 3/5/10/45 s, pausas, contador desde ready, parada manual y
  límite, estado de transcripción, cancelación e interrupción conservando el texto
  anterior, cero propuestas tras cancelar, cero POST y cero operaciones en cola.
- Gasto, venta, compra, fiado, abono y números hablados; «vendí se encuentra suele
  de arroz» sigue sin importe. Reinterpretación sin duplicados conservada.
- `PcmRecording` y `decodePcm` comparten el código de producción con el diagnóstico
  Android. El modo `session` verifica muestras completas en orden durante
  3/5/10/45 s, múltiples endpoints, cola final y cancelación.
- El script `tool/test-voice-session-android.ps1 -AirplaneMode` invoca una Activity
  solo debug protegida por DUMP. Modo `mic` abre AudioRecord real y lo detiene
  a 3/5/10 s; comprueba frames capturados=decodificados. Cancela otra sesión y
  deja otra alcanzar el límite nativo de 45 s. No usa API, negocio ni propuestas.
  El reporte no conserva transcripción ambiental, solo conteos/duración/errores.
  Restaura radios y reverse en finally. Un micrófono real sin locución humana
  acredita estabilidad del flujo, no precisión de ventas/gastos hablados.

Resultados físicos, Android `10AD370TQF002ZS`, modo avión=1 y reverse retirado:

| Ensayo | Capturadas | Decodificadas | Resultado |
|---|---:|---:|---|
| Micrófono 3 s + drenaje | 51.200 | 51.200 | NO_SPEECH, sin cierre prematuro |
| Micrófono 5 s + drenaje | 83.200 | 83.200 | NO_SPEECH, sin cierre prematuro |
| Micrófono 10 s + drenaje | 163.200 | 163.200 | NO_SPEECH, sin cierre prematuro |
| Cancelar a los 3 s | — | — | Sin callback final |
| Límite nativo 45 s | 720.000 | 720.000 | NO_SPEECH, límite completo |

El resultado NO_SPEECH es esperado al grabar sin locución: no es un fallo del
ensayo de duración/muestras. La prueba del núcleo compartido también pasó en el
teléfono, verificando orden de muestras, varios endpoints y cola final. Seis
comprobaciones Android sin errores, cero propuestas u operaciones. Reporte local
ignorado: `build/tooling/voice-session-device-results.json`.

APK compilado en 311,0 s; instalación `install -r`: Success, actualización
23/10/2026 07:06:07. No hubo clean ni compilaciones simultáneas. Se reabrió FINKI,
se restauró modo avión=0, Wi-Fi=0 (estados anteriores) y se configuró reverse
tcp:3000. Express/MySQL ready. No se modificó su configuración.

Ensayo adicional en la UI Flutter real: captura visible con contador 00:42,
y una segunda sesión cancelada desde 00:09 sin «Esto entendí» ni propuesta nueva.
El primer selector del diagnóstico buscaba Grabando como nodo independiente;
Flutter lo agrupaba con el resto de la captura en accesibilidad. No lo encontró,
pero la captura PNG acreditó que seguía grabando. Se corrigió el selector y se
repitió la cancelación completa con éxito. No se confundió este fallo del selector
con un fallo del micrófono ni se modificó la aplicación por ese falso negativo.

Evidencias locales ignoradas: `build/tooling/finki-session-debug.png` (00:42),
`session-{analyze,full-tests,android}.log`, `voice-session-device-results.json`.
El usuario aún debe repetir las dos frases para valorar precisión acústica con
el nuevo flujo. No se afirma que la prueba de duración garantice mejores palabras.

### Validación humana posterior de gasto

El usuario probó el APK actualizado sin conexión y confirmó que la sesión ya no
termina sola, espera Detener y después muestra azúcar, S/23 y Gasto. Aclaró que
dictó «Gasté veintitrés soles en azúcar» (no dólares). La lectura no destructiva
de la pantalla corroboró el texto editable «gaste veintitrés soles en azúcar».
No se pulsó Revisar/Confirmar ni se registró una operación desde las herramientas.

Este caso de gasto queda validado con locución humana. Sigue pendiente repetir
«Vendí cincuenta soles de arroz» con el nuevo flujo; no se extrapola la precisión
de una frase al resto del vocabulario o a todos los ambientes.

## Prueba humana pendiente

En modo avión, Wi-Fi apagado y consentimiento externo desmarcado:

1. Pulsar Hablar y esperar «Grabando» antes de empezar.
2. Decir «Vendí cincuenta soles de arroz» durante ~3 s, con pausas. Detener.
3. Repetir «Gasté veintitrés soles en azúcar» durante 5 y 10 s, y luego compra,
   fiado y abono. Antes de Detener debe seguir grabando incluso durante pausas.
4. Esperar la transcripción y la tarjeta automática. Corregir si hace falta y
   reinterpretar; comprobar un solo pendiente. No confirmar datos ficticios.
5. Cancelar otra grabación y comprobar que no se crea una propuesta nueva.
6. La precisión y conservación de palabras iniciales/finales requieren estas
   grabaciones humanas; compilar o pasar tests con dobles no las acreditan.

Inicio, Perfil, backend, SQL, secretos y datos anteriores se conservan. Sin clean,
desinstalación, cambios de toolchain, commits ni push.
