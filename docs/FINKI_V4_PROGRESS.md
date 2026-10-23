# FINKI V4 — estado y traspaso

Complemento del 22/10/2026 sobre la rama actual `danny`: reconocimiento local de
voz Android, OCR latino, reglas deterministas y respaldo Gemini con pausa de cuota.
Véase [FINKI_HYBRID_LOCAL.md](FINKI_HYBRID_LOCAL.md) para el flujo, pruebas, límites,
archivos y actualización del teléfono. La nota histórica siguiente se conserva.

Fecha: 22/10/2026. Rama `feat/backend-v1`. Sin commits ni push. Se conservaron todos
los cambios sin commit de Codex (V1–V4); no hubo reset, clean, checkout ni borrados.

## Qué contiene V4 (implementado por Codex, revisado por Claude)

1. «Hablar con Finki» separa captura y propuesta: `IntakeCapture` y `IntakeProposalCard`
   en `lib/v1/intake_widgets.dart`; la página `lib/v1/intake_page.dart` solo coordina.
2. Una operación sugerida destacada (botón principal «Revisar venta/gasto/…»);
   las alternativas quedan en «Cambiar tipo» (selector con descripción de cada tipo).
3. Textos breves; el detalle de privacidad está en el panel «Cómo se usan mis datos»
   (proveedor, uso del nivel gratuito de Gemini, qué no enviar, qué se conserva).
4. Consentimiento verificable: cabeceras `X-Finki-Consent: 1` y
   `X-Finki-Consent-Version: finki-v4-2026-10-22`; el backend exige el consentimiento
   (`CONSENT_REQUIRED`) y guarda versión, proveedor, fecha y usuario en `correccion_usuario`.
5. Descarte de propuestas con confirmación: comando `DESCARTAR_PROPUESTA` con
   `expected_version` (409 si cambió), idempotente, sin tocar finanzas ni evidencia.
6. Medio de pago: una propuesta sin medio deja `channel = null`; el formulario muestra
   «¿Cómo te pagaron?» (Efectivo, Yape, Plin, Transferencia, Fiado, Otro) y el campo
   «Medio de pago» es obligatorio. Ya no se asume efectivo. El registro manual sí
   conserva Efectivo como valor inicial editable.
7. Borradores manuales (`lib/v1/local_draft.dart`): almacenamiento seguro, clave
   `draft-v4:<usuario>:<negocio>:<tipo>:<registro>`; se limpian al confirmar y no
   reviven por escrituras tardías. No se usan cuando el formulario viene de una propuesta.
8. Consultas: respuesta explícita cuando no hay datos suficientes para comparar productos.

## Completado por Claude en este turno

- Texto del consentimiento: ahora indica que la entrada se envía a un **servicio de IA
  externo** (antes solo decía «procesar»). El nombre del proveedor sigue en el panel.
- Barra superior de «Hablar con Finki» con `toolbarHeight: 76`, igual que los
  formularios, para que el encabezado FINKI no se recorte con texto ampliado.
- «Ya lo registré: adjuntar comprobante» muestra un mensaje cuando no hay registros
  confirmados, en lugar de una hoja vacía.
- Prueba V4: verifica que el aviso de servicio externo esté visible a 320/360/412 px
  con texto al 160 %.
- `tool/finki-v4-verify.ps1`: ejecuta en orden analyze, pruebas Flutter, backend y,
  con `-MySql`, la suite aislada `_test`. Guarda logs en `build/tooling/finki-v4-*.log`.

## Resultados reales

| Verificación | Resultado | Dónde |
|---|---|---|
| `npm test` (repositorio en memoria) | **40/40 aprobadas** | Copia del código V4 actual, Node 22, entorno de Claude |
| MySQL aislado `_test` | 20/20 según Codex; **no re-ejecutado** por Claude | Requiere la PC |
| `flutter analyze` / `flutter test` | **Pendiente** | Claude no tuvo terminal en Windows ni SDK de Flutter |
| Compilación e instalación Android V4 | **Pendiente** | Requiere la PC y el teléfono |

No se hicieron llamadas a Gemini ni a OpenAI. `backend/.env` no se leyó ni se modificó.

## Para terminar la verificación (PowerShell, raíz del repo)

Cerrar VS Code antes (ver `ANDROID_LOW_MEMORY.md`). Mantener Laragon y el backend abiertos.

```powershell
.\tool\finki-v4-verify.ps1 -MySql
```

Si todo termina en OK, compilar e instalar sin borrar datos del teléfono:

```powershell
.\tool\flutter-local.ps1 build apk --debug --no-pub --target-platform android-arm64 --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
& D:\Android\Sdk\platform-tools\adb.exe -s 10AD370TQF002ZS reverse tcp:3000 tcp:3000
& D:\Android\Sdk\platform-tools\adb.exe -s 10AD370TQF002ZS install -r build\app\outputs\flutter-apk\app-debug.apk
& D:\Android\Sdk\platform-tools\adb.exe -s 10AD370TQF002ZS shell am start -W -n pe.pinguinos.hackathon_pinguinos_mvp/.MainActivity
```

Revisión manual en el teléfono (solo con datos de ensayo, nunca en operaciones reales):
Hablar con Finki con texto grande del sistema; abrir «Cómo se usan mis datos»;
teclado abierto sobre «O escríbelo aquí…»; con IA desactivada debe verse
«no está disponible por ahora» y «Registrar manualmente»; formulario manual: cerrar y
reabrir para ver «Recuperamos tu borrador»; Mi constancia, Historial y Fiados abren.

## Pendientes auténticos

- Ejecutar `flutter analyze` y `flutter test` sobre V4 (los últimos resultados Flutter
  documentados son de V3: 66 aprobadas).
- Compilar e instalar V4 en el Android 10AD370TQF002ZS y revisar las pantallas.
- Voz, OCR y asistente con Gemini real: requieren clave y autorización explícita;
  hoy `AI_ENABLED=0`. Las pruebas usan dobles y no validan reconocimiento real.
- Modo avión, cierre y reconexión físicos; abrir/compartir PDF en Android.
- Sin sincronización en segundo plano; sin borrado/retención automática de evidencias.
