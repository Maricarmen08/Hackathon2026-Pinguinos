# Ajuste visual final de Perfil y fotografía

Fecha: 23/10/2026. Se conserva la rama `danny` y el funcionamiento de fotografía
que el titular ya validó personalmente en Android. No se modifica backend,
MySQL, autenticación, contraseñas, secretos ni documentos PDF.

## Presentación

- Información personal agrupa «Editar mis datos» y «Cambiar fotografía» en una
  sola tarjeta blanca, con divisor discreto, iconos/textos y flechas alineados.
- Fotografía de perfil muestra un círculo de 160 píxeles lógicos, tanto para la
  foto guardada como para el encuadre previo. Se conservan selección, ajuste y
  confirmación; el archivo guardado sigue siendo el mismo PNG seguro de 256 × 256.
- Las acciones de galería y cámara tienen 12 píxeles de separación. Confirmar
  tiene su propio espacio; eliminar aparece solo si hay una foto guardada.
- El texto técnico/de privacidad queda al final con tipografía secundaria,
  altura de línea legible y sin un gran bloque vacío alrededor del avatar.
- La pestaña inferior Perfil conserva etiqueta, área táctil e indicador activo.
  Con fotografía usa un círculo de 24 píxeles; sin foto mantiene el icono anterior.

## Sincronización y privacidad

`ProfilePhotoState` es compartido por las tres ubicaciones y está asociado a la
instancia del cliente API y al usuario autenticado. Una carga concurrente se
comparte; guardar, reemplazar o eliminar actualiza inmediatamente a los tres
observadores. Ya no se necesita desmontar el avatar mediante una clave/revisión
para que se vea una foto nueva.

Se reutiliza exactamente la caché cifrada anterior `cache:<usuario>:/perfil/foto`;
no hay copias persistentes nuevas. El parámetro opcional `useCache` del cliente
permite que esta carga gestione su propia clave capturada al iniciar la petición.
Por defecto sigue siendo `true` en las demás llamadas; la autenticación y las
consultas financieras conservan su comportamiento.

Al cambiar de cuenta o cerrar sesión se borra la foto de la memoria visible. Una
respuesta tardía de la cuenta anterior o una carga anterior al último guardado
no puede reemplazar la imagen actual ni escribirse en la caché de otra cuenta.
La reapertura recupera la foto del servidor o de la caché propia si no hay red.

## Pruebas automáticas

- Una carga compartida entre vistas; guardar, reemplazar y eliminar.
- Reapertura de un cliente nuevo sin conexión y lectura de la misma caché.
- Cierre/cambio de usuario; respuesta HTTP tardía y guardado de una cuenta anterior.
- Tres ubicaciones con la misma imagen; actualización y vuelta al avatar por defecto.
- Diseño a 320, 390 y 714 píxeles: círculo, separación de botones, eliminación
  condicional y ausencia de desbordamientos.
- Se conservaron las pruebas anteriores de cámara/galería simuladas, confirmación,
  normalización y flujo financiero. No se hicieron escrituras en datos personales
  reales ni en MySQL.

Resultado: **178 pruebas Flutter aprobadas, dos pruebas específicas de dispositivo
omitidas**. Análisis estático sin incidencias.

## Archivos de este ajuste

- `lib/v1/app.dart`
- `lib/v1/profile_photo_page.dart`
- `lib/v1/profile_photo_state.dart` (nuevo)
- `lib/v1/api_client.dart` (opción de caché, sin cambios de autenticación)
- `test/profile_photo_visual_test.dart` (nuevo)
- `docs/FINKI_PROFILE_VISUAL_FINAL.md` (este documento)

## Instalación y comprobación física

APK debug arm64 compilada en 266,7 segundos siguiendo `ANDROID_LOW_MEMORY.md`.
`adb install -r`: **Success**. Inicio de MainActivity: **Status ok**, sin
desinstalar ni limpiar datos. Sesión Danny / Bodega Finki Demo conservada.

Se inspeccionaron en Android la tarjeta unificada, el divisor y la alineación,
el círculo y la separación de botones, el texto secundario y la ocultación de
«Eliminar fotografía» sin imagen. Se alternó Inicio / Reportes / Perfil varias
veces y se cerró/reabrió el proceso sin borrar almacenamiento. Perfil y sesión
se recuperaron correctamente; Inicio mantuvo las ventas de hoy S/ 70.00.

En el estado observado de esta cuenta no había fotografía guardada: se comprobó
el avatar predeterminado. No se guardó, reemplazó ni eliminó una foto personal
para realizar esta revisión. La actualización simultánea de las tres imágenes y
la persistencia con fotografía se verificaron en las pruebas aisladas descritas
arriba; el titular ya había confirmado previamente el guardado real. No se debe
confundir esa prueba simulada con un guardado nuevo en su cuenta Android.

La comparación de los archivos privados de fotografía no detectó cambios. En
los últimos 600 registros del proceso Android consultados no se encontraron
excepciones no controladas ni desbordamientos. Se mantiene `danny`; sin commits
ni push. No se detectaron problemas funcionales en las comprobaciones realizadas.

Capturas: `build/tooling/certificate-profile-visual-main.png`,
`certificate-profile-visual-photo.png`, `certificate-profile-visual-reopened.png`.
Resultados: `build/tooling/profile-visual-flutter-tests.log` y
`profile-visual-targeted.log`.
