# FINKI — Identidad y revisión local

El punto de entrada funcional es `lib/main.dart` y la interfaz V1 en `lib/v1/`.
Se preservan los contratos de Express, las sesiones y los comandos financieros.
Las antiguas pantallas V0.1 que no están conectadas a este punto de entrada no sustituyen la aplicación V1.

## Pantallas y navegación

- Bienvenida separada con Comenzar y Ya tengo cuenta.
- Registro e ingreso con validaciones, errores de API, visibilidad y longitud de contraseña.
- Carga sin demora artificial y creación/selección del negocio.
- Inicio con ventas, cobros, pagos, pendientes, cuentas y actividad real.
- Formularios de venta, gasto, compra, abono, cuenta, categoría, tercero y negocio.
- Historial con búsqueda y filtro por tipo; fiados con total, abonado y pendiente.
- Reportes con resultado simplificado, promedio y barras de ventas por meses completos.
- Perfil con datos existentes, selección de negocio y cierre de sesión.

La navegación es Inicio / Historial / Fiados / Reportes / Perfil.
El contenido se limita a 640 px y los formularios a 480 px; el acceso público a 440 px.
El resto de la ventana mantiene un fondo tranquilo, sin convertir la app en un panel de escritorio.

## Sistema de diseño

| Uso | Token |
|---|---|
| Acción principal | Azul `#185FC9` |
| Texto y resumen principal | Marino `#102F5C` |
| Único apoyo de marca | Cian `#09AFDC` |
| Fondo / superficie | `#F4F8FE` / blanco |
| Texto secundario / borde | `#566B85` / `#DCE8F6` |
| Éxito / advertencia / error | `#087F71` / `#865800` / `#CC4058` |

Roboto es la familia de Flutter, sin descarga de fuentes externas mediante nuevas dependencias.
Jerarquías de 30/26/20 px, importes de 25/34 px con reducción proporcional para montos largos.
Espaciados de 4/8/16/24/32 px, radios 14/16/20/24 px y sombras discretas.
`finki_components.dart` centraliza tarjetas financieras, secciones, avisos, vacíos, carga y el aviso de IA futura.
Los controles y diálogos utilizan el tema Material 3 común.

## Recursos y archivos

- `lib/core/theme/app_theme.dart`: colores, tipografía y estados de controles.
- `lib/ui/widgets/finki_brand.dart`: logo completo y encabezado compacto con rostro.
- `lib/ui/widgets/finki_components.dart`: componentes compartidos.
- `lib/v1/app.dart`: pantallas públicas, inicio, historial, fiados, reportes y perfil.
- `lib/v1/forms.dart`: presentación de todos los formularios existentes.
- `lib/main.dart`: título FINKI.
- `pubspec.yaml`: recursos locales de branding.
- `assets/branding/finki_logo.png`: original conservado.
- `assets/branding/finki_logo_display.png`: versión de 800 × 600 para bienvenida/carga.
- `assets/branding/finki_robot.png`: recorte proporcional de la cabeza original, 320 × 320 con espacio transparente.
- `web/favicon.png`: rostro de 64 × 64 con fondo claro.
- `web/icons/`: íconos normales y maskable de 192/512 px.
- `web/index.html` y `web/manifest.json`: nombre FINKI y URLs de iconos versionadas para renovar caché.
- `android/app/src/main/AndroidManifest.xml`: etiqueta FINKI, mismo identificador de paquete.
- `android/app/src/main/res/mipmap-*/ic_launcher.png`: cinco densidades del rostro; sin generar APK.
- `test/redesign_test.dart`, `test/home_test.dart`, `test/widget_test.dart`, `test/financial_forms_test.dart`: navegación, contratos y desplazamiento de formularios.
- `tool/serve-finki-web.cjs`: vista local de la compilación web con menor consumo de memoria.

El logo completo se usa en bienvenida/carga. El rostro acompaña encabezados, menú y estados vacíos.
No se crea una mascota nueva. Se conserva el original y se derivan recortes y tamaños de forma mecánica.

## Datos y límites funcionales

Las ventas incluyen contado y fiado. Los cobros de ventas y pagos operativos son indicadores diferentes.
Un abono conserva el comando de cobro/pago y su aplicación a la operación original; no crea otra venta.
El resultado se etiqueta como simplificado y se explica su fórmula, sin presentarlo como utilidad contable.
Las barras utilizan los meses completos entregados por la API; no se agregan meses ni importes ficticios.
Los importes conservan céntimos con BigInt; la conversión a double se limita a la proporción gráfica.
Voz, OCR y PDF se muestran como próximos, sin botones que simulen ejecutarlos.
La futura constancia no certifica ingresos ni garantiza crédito.

## Comprobaciones

Resultado de esta entrega: `pub get` correcto, analizador sin incidencias, 30 pruebas aprobadas (incluida lectura real de API) y compilación web final correcta.
Chrome abrió bienvenida, login y registro sin enviar formularios; se revisaron las capturas de 390×844 y la bienvenida de 320×640.
La comprobación desde el propio navegador confirmó título FINKI, manifiesto FINKI, cuatro iconos, favicon 64×64 y backend `ready` con el origen local.
Los 60 archivos de backend/base de datos se compararon por hash con el inicio de esta tarea, sin cambios.
La vista final usa la compilación web y el servidor local liviano para evitar mantener el compilador Flutter en memoria.

Las pruebas de widgets usan HTTP y almacenamiento en memoria, exclusivamente dentro de `test/`.
Los nombres e importes de sus capturas están identificados como prueba visual; no se importan a MySQL.
Cubren 320×640, 390×844, 768×1024 y 1280×900, navegación privada, detalle de fiados y todos los formularios con teclado.
El recorrido de Chrome se limita a bienvenida, login y registro sin enviar formularios.
La prueba real de API usa solo GET de salud y consulta protegida sin sesión.
El recorrido privado con una cuenta real y los cambios de escritura quedan para el usuario.

Capturas opcionales: `build/tooling/redesign-*.png` (ignoradas por Git).
Las de `redesign-chrome-*` provienen del navegador; las restantes son widgets aislados.

```powershell
.\tool\flutter-local.ps1 pub get
.\tool\flutter-local.ps1 analyze --no-pub
.\tool\flutter-local.ps1 test --no-pub --concurrency=1 --dart-define=RUN_LIVE_API=true
.\tool\flutter-local.ps1 build web --no-pub --no-wasm-dry-run --dart2js-optimization=O1 --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
node .\tool\serve-finki-web.cjs
```

Abrir `http://localhost:5173/` en Chrome. Express debe estar escuchando en `127.0.0.1:3000`.
No iniciar dos servidores sobre 5173 simultáneamente.
Para volver al desarrollo con recarga, detener solo el proceso de vista local e iniciar:

```powershell
.\tool\flutter-local.ps1 run -d chrome --web-hostname=localhost --web-port=5173 --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

Se conserva la rama actual y sus cambios anteriores. No se realizan commits ni push.
