# Elegir imagen: formatos Yape y protección de evidencias

## Evidencias publicables

Los fixtures de `test/fixtures/yape-ocr-*.json` contienen solo datos de ensayo.
No se publica ninguna captura personal ni identificadores de una transacción
real. La evidencia anterior del diseño habitual fue sustituida íntegramente:
texto, coordenadas, nombre, teléfono, referencia, código de seguridad, fecha,
hora e importe son ahora sintéticos. La captura original queda fuera del
repositorio público y no se necesita para ejecutar las pruebas.

| Fixture | Diseño | Importe | Referencia ficticia | Fecha ficticia |
| --- | --- | --- | --- | --- |
| yape-ocr-0.json | Transferencia de ensayo | S/ 35.00 | 00458291 | 23/10/2026 |
| yape-ocr-1.json | Comprobante habitual sintético | S/ 17.00 | 00000042 | 15/01/2026 |

Ambos están marcados con `synthetic: true`. El segundo usa destinatario
«CLIENTE DEMOSTRACION», teléfono «*** *** 000» y código de seguridad «0 0 0».
Su promoción ficticia de S/ 4.90 no debe sustituir al importe principal.

## Regresiones conservadas

- El ensamblador reconstruye filas a partir de etiquetas y valores enumerados
  por bloques, sin depender del orden del texto bruto.
- «Transferencia exitosa» es un medio genérico de respaldo cuando no existe uno
  explícito. «Desde tu saldo Yape» se reconoce como YAPE; Yape + Plin sigue ambiguo.
- Se admiten N°, Nº, Nro. y Número antes de la referencia, incluso un segundo
  marcador. Se conservan los ceros iniciales.
- Un código de seguridad sin etiqueta de operación no se usa como referencia.
- Las imágenes requieren definir el tipo y revisar antes de confirmar. Reconocer
  un comprobante no registra automáticamente una venta, un gasto ni un abono.
- Las pruebas de Plin y de comprobantes incompletos siguen utilizando datos
  ficticios. No se modificó el extractor ni el comportamiento financiero.

## Validación y alcance

`test/yape_ocr_test.dart` comprueba los dos formatos, sus importes, medio, fecha,
referencia, clasificación desconocida y revisión humana. La prueba del fixture
sintético es una regresión de ensamblado y extracción; **no se presenta como una
nueva lectura física de una captura real**.

La validación previa de ML Kit en Android y las pruebas humanas sirvieron para
detectar las regresiones originales. Sus datos privados no se reproducen aquí.
Para comprobar cámara/galería deben usarse imágenes completamente ficticias,
mantener desmarcada la ayuda externa y no confirmar operaciones ficticias en
un negocio real. Ninguna prueba garantiza reconocer todos los diseños posibles.
