# Instalar FINKI desde cero (equipo Pingüinos)

Esta guía es para instalar FINKI en tu propia computadora con Windows. Al final
tendrás tu propia base de datos vacía, el backend funcionando y la app abierta.
Tu cuenta y tu negocio los creas tú desde la app.

> **Importante:** importar el mismo SQL en varias computadoras crea bases
> **separadas**. Lo que registres en tu PC no aparece en la de otra integrante.
> Para compartir datos en tiempo real se necesita **un solo servidor central**
> (un backend y un MySQL compartidos, por ejemplo en la nube) al que se conecten
> todas las apps. Eso no está configurado todavía.

---

## 1. Requisitos

| Programa | Versión | Para qué |
|---|---|---|
| Windows 10 u 11 | 64 bits, 8 GB de RAM como mínimo | — |
| [Git](https://git-scm.com/download/win) | cualquiera reciente | Clonar el repositorio |
| [Laragon](https://laragon.org/download/) | con **MySQL 8.4** | Base de datos |
| [Node.js](https://nodejs.org/) | **22 o superior** (LTS) | Backend Express |
| [Flutter](https://docs.flutter.dev/get-started/install/windows) | **3.47.7**, versión comprobada | App móvil/web |
| Android Studio o SDK de Android | necesario para Android | Instalar las plataformas/Build Tools que solicite Flutter |
| Google Chrome | opcional | Probar la versión web |

Comprueba en PowerShell:

```powershell
git --version
node --version      # debe decir v22 o superior
flutter --version   # versión comprobada: 3.47.7
flutter doctor -v
```

## 2. Abrir Laragon e iniciar MySQL

1. Abre **Laragon**.
2. Menú **Laragon → MySQL → Version** y comprueba que sea **8.4.x**. Si no
   aparece, descarga MySQL 8.4 desde dev.mysql.com, descomprímelo en
   `C:\laragon\bin\mysql\` y elígelo en ese menú.
3. Pulsa **Start All** (o solo MySQL). Debe quedar en verde.
4. Abre **Database** (HeidiSQL) desde Laragon. Usuario `root`; la contraseña
   está vacía en una instalación nueva de Laragon, salvo que tú la hayas cambiado.

## 3. Clonar el repositorio

```powershell
cd D:\              # o la carpeta que prefieras
git clone --branch danny --single-branch https://github.com/Maricarmen08/Hackathon2026-Pinguinos.git
cd Hackathon2026-Pinguinos
git branch --show-current   # debe decir danny
```

La versión descrita en esta guía se prepara en **`danny`**. Clonarla después de
que el equipo confirme su publicación: antes del push solo está disponible la
versión anterior. `main` puede conservar otra versión hasta que el equipo apruebe
su integración. No cambies de rama ni hagas merge para seguir esta instalación.
Si ya tienes un clon con cambios locales, consérvalo y consulta al equipo antes
de actualizar; no uses reset, clean ni sobrescribas tu trabajo.

## 4. Importar la base de datos (un solo archivo)

El archivo oficial es **`database/hackathon_pinguinos_dev.sql`**. Crea la base
`hackathon_pinguinos_dev` con sus 24 tablas, 5 vistas, relaciones e índices.
No trae usuarios ni datos.

**Con HeidiSQL:**
1. Conéctate con `root`.
2. **Archivo → Cargar archivo SQL…** → elige `database\hackathon_pinguinos_dev.sql`.
3. Pulsa **Ejecutar** (F9). Ejecuta el archivo completo, no una parte.
4. Pulsa F5 en el panel izquierdo: aparece `hackathon_pinguinos_dev`.

**O desde PowerShell**, en la raíz del repositorio, con `mysql.exe` en PATH
(puedes abrir la terminal de Laragon):
```powershell
mysql.exe --host=127.0.0.1 --port=3306 --user=root --password --default-character-set=utf8mb4 --execute="SOURCE database/hackathon_pinguinos_dev.sql"
```
Escribe tu contraseña cuando la solicite (Enter si está vacía). No la pongas
en el comando ni la compartas. Usa `SOURCE` con barras `/`; la redirección `<`
no funciona en PowerShell. Si `mysql.exe` no está en PATH, usa el ejecutable de
tu instalación de Laragon con `& 'ruta/completa/mysql.exe'` y los mismos argumentos,
o utiliza HeidiSQL. No ejecutes este paso sobre una base ya instalada.

Comprueba en HeidiSQL:
```sql
SELECT table_type, COUNT(*) FROM information_schema.tables
WHERE table_schema = 'hackathon_pinguinos_dev' GROUP BY table_type;
-- BASE TABLE 24 · VIEW 5
```

> Si aparece **«Can't create database … database exists» (error 1007)**, ya
> tienes esa base. El archivo se detiene a propósito para **no tocar tus datos**.
> No la borres para «reinstalar»: pregunta antes en el equipo.

No importes otros `.sql` de la carpeta `database/` (ver la sección *Archivos SQL*).

## 5. Crear un usuario de MySQL para la app (recomendado)

En HeidiSQL, con `root`, ejecuta esto **cambiando la contraseña por una tuya**:

```sql
CREATE USER 'pinguinos_app'@'127.0.0.1' IDENTIFIED BY 'escribe-aqui-tu-propia-clave';
GRANT SELECT, INSERT, UPDATE ON hackathon_pinguinos_dev.* TO 'pinguinos_app'@'127.0.0.1';
```

Así la app no usa `root`. FINKI nunca borra filas: solo necesita esos tres permisos.
(Solo en tu PC el backend también acepta `root` sin contraseña con
`NODE_ENV=development` y `HOST=127.0.0.1`, pero es mejor el usuario propio).

## 6. Configurar `backend/.env`

```powershell
cd backend
npm.cmd install
npm.cmd run configure
```

`configure` crea `backend/.env` con **secretos JWT nuevos y propios de tu PC**.
Ábrelo con el Bloc de notas y completa solo:

```dotenv
DB_USER=pinguinos_app
DB_PASSWORD=la-clave-que-pusiste-en-el-paso-5
```

Si prefieres copiarlo a mano, usa `backend/.env.example` como plantilla y genera
dos secretos distintos para `JWT_SECRET` y `JWT_REFRESH_SECRET`:
```powershell
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

**Ayuda externa de IA (opcional):** con `AI_ENABLED=0` funcionan los formularios,
las reglas locales, la voz/OCR locales en Android y las consultas deterministas
del negocio. El acceso a registros y su sincronización requiere el backend;
los datos locales en caché pueden estar desactualizados. Si el equipo decide probar Gemini, cada persona usa **su
propia clave** de Google AI Studio en su `.env`. Nunca compartas claves por
chat ni las subas a GitHub. Detalles en `docs/GEMINI_SETUP.md`.

`backend/.env` está en `.gitignore`: **no se sube a GitHub**.
Tampoco se comparten `.env.test`, secretos JWT, claves API ni el directorio privado
del backend. Si ya existe `.env`, `configure` no lo sobrescribe: revisa tu copia
local en lugar de borrarla. El correo asociado permite acceso con contraseña,
pero no se acredita titularidad del buzón ni se ofrece recuperación por correo.

## 7. Comprobar la conexión del backend

Desde `backend/`:

```powershell
npm.cmd run check:db
```

Debe decir `PASS: conexión MySQL 8.4 …`. Si dice `ER_ACCESS_DENIED_ERROR`,
revisa usuario y contraseña. Si dice `ER_BAD_DB_ERROR`, falta el paso 4.

## 8. Iniciar Express

```powershell
npm.cmd start
```

Deja esa ventana abierta. En el navegador, `http://127.0.0.1:3000/api/v1/health/ready`
debe mostrar `{"status":"ready"}`.

## 9. Ejecutar Flutter

Abre **otra** ventana de PowerShell en la raíz del repositorio:

```powershell
flutter pub get
flutter doctor --android-licenses   # solo si faltan las licencias del SDK
```

**En Chrome** (puerto fijo para que el backend lo acepte):
```powershell
flutter run -d chrome --web-hostname=localhost --web-port=5173 --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

**En un teléfono Android por USB** (depuración USB activada):
```powershell
adb devices
adb reverse tcp:3000 tcp:3000
$deviceId = 'REEMPLAZA_POR_EL_ID_QUE_MUESTRA_ADB'
flutter run -d $deviceId --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```
Repite `adb reverse` cada vez que reconectes el cable. En PCs con poca memoria,
usa `.\tool\flutter-local.ps1` en lugar de `flutter` (ver `docs/ANDROID_LOW_MEMORY.md`).

**En el emulador de Android Studio:**
```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

### Voz offline, OCR y límites de Android

- La APK comprobada es **debug arm64**, con Android mínimo API 24 (Android 7.0).
  Usa un teléfono compatible y concede permiso de micrófono solo al utilizar voz.
- El modelo español **Vosk pequeño 0.42 ya está incluido** en
  `android/app/src/main/assets/vosk-model-small-es-0.42.zip`; no hay que descargarlo
  en el teléfono. No lo borres, descomprimas dentro del repositorio ni lo sustituyas.
  El archivo pesa **39.817.833 bytes**; Gradle verifica este SHA-256 antes de compilar:
  `09b239888f633ef2f0b4e09736e3d9936acfd810bc65d53fad45261762c6511f`.
- Conserva `VOSK_LICENSE.txt` y `VOSK_NOTICE.txt` junto al modelo (Apache 2.0).
  Puedes comprobarlo con `Get-FileHash android/app/src/main/assets/vosk-model-small-es-0.42.zip -Algorithm SHA256`.
- Gradle obtiene **Vosk Android 0.3.75** y **JNA 5.18.1**. La primera compilación
  necesita internet para herramientas y dependencias; no equivale a necesitar
  internet para reconocer voz después. Flutter ya declara el puente de ML Kit
  y sus dependencias en `pubspec.yaml` / `pubspec.lock`; usa `flutter pub get`.
- En el primer uso, FINKI verifica y extrae el modelo en almacenamiento privado
  (unos 60,3 MB extraídos, además de la APK). Necesita espacio y memoria disponibles.
  La preparación puede tardar; espera a que indique que está grabando.
- Se prefiere el reconocedor nativo **on-device** cuando Android admite español;
  Vosk proporciona el respaldo local. No se envía audio a Gemini automáticamente.
  La ayuda por internet requiere conexión y consentimiento explícito.
- ML Kit latino va incluido para OCR local. Voz y OCR locales son funciones de
  **Android**; Chrome no sustituye esa validación. Vosk puede transcribir mal,
  especialmente con ruido: corrige la propuesta y revísala antes de confirmar.
  El límite de grabación actual es 45 segundos; no se confirma ningún movimiento
  solo por terminar de hablar o reconocer una imagen.
- Para comprobar independencia de red, usa modo avión y Wi-Fi apagado. El cable
  USB con `adb reverse` todavía permite llegar al backend: una respuesta del backend
  por USB no demuestra por sí sola que el reconocimiento fue local.
- En equipos de poca RAM sigue [ANDROID_LOW_MEMORY.md](ANDROID_LOW_MEMORY.md):
  una sola tarea Flutter/Gradle, sin clean ni eliminación de cachés. No actualices
  Flutter/Gradle/Kotlin por tu cuenta para resolver avisos de versiones futuras.

Detalles de la implementación y las pruebas: [FINKI_OFFLINE_FINAL.md](FINKI_OFFLINE_FINAL.md)
y [FINKI_VOICE_SESSION_FIX.md](FINKI_VOICE_SESSION_FIX.md). Sus apartados históricos
no sustituyen los requisitos actuales de esta guía. El backend necesita permiso
para escribir su almacenamiento privado (fotografías/evidencias/PDF), que nunca
debe servirse como carpeta pública ni incluirse en GitHub.

## 10. Comprobar que todo funciona

Realiza este recorrido solo en **tu instalación nueva** o en un negocio de ensayo;
no introduzcas operaciones ficticias en el negocio real de otra integrante.

1. En la app pulsa **«Soy nuevo · Registrarme»** y crea **tu** cuenta
   (contraseña de 12 caracteres como mínimo).
2. Crea tu negocio.
3. Registra una venta al contado de S/ 10 → aparece en Inicio e Historial.
4. Registra una venta **fiada** de S/ 100 a un cliente → en Pendientes debe
   verse S/ 100. Abona S/ 40 → queda S/ 60.
5. Registra un gasto y una compra.
6. Abre **Mi constancia** y genera el PDF.

Si todo eso funciona, tu instalación está lista.

### Validación automática (opcional, para quien mantiene la base)

Crea una base **temporal** `hackathon_pinguinos_install_check`, importa el SQL
único, compara su estructura con tu `hackathon_pinguinos_dev` **sin modificarla**
y ejecuta el recorrido real de la API (registro, negocio, ventas, fiados, abonos,
pagos, constancia PDF e IA con un proveedor de prueba, sin llamadas externas):

```powershell
.\tool\finki-verify-install.ps1 -DropAfter
```

Pide la contraseña de `root` (Enter si está vacía). Debe terminar con
`RESULTADO: instalación nueva validada.` Sin `-DropAfter` la base temporal se
conserva para inspección; contiene solo datos de ensayo.

---

## Archivos SQL de la carpeta `database/`

| Archivo | ¿Importar? | Para qué sirve |
|---|---|---|
| `hackathon_pinguinos_dev.sql` | **Sí, el único** | Instalación completa y vacía |
| `migrations/001_*.sql`, `002_*.sql` | No | Historial de la estructura; el SQL único se genera a partir de ellos y el backend de pruebas los lee. No editarlos. |
| `seeds/001_demo_data.sql` | No | Datos ficticios opcionales para revisar reportes |
| `tests/*.sql`, `queries/*.sql` | No | Mantenimiento y consultas de verificación |
| `schema.sql` | **Nunca** | Versión antigua V0.1; contiene `DROP TABLE` |

## Problemas frecuentes

| Mensaje | Solución |
|---|---|
| `database exists` (1007) al importar | Ya tienes la base. No la borres; usa la que tienes. |
| `Missing migrations` al iniciar | Importaste otro SQL. Revisa que `schema_migraciones` tenga las versiones 1, 2 y 3. |
| `Unsupported database configuration` | MySQL no es 8.4 o `DB_NAME` no coincide. |
| `root o contraseña vacía requieren …` | Usa el usuario del paso 5, o deja `NODE_ENV=development` y `HOST=127.0.0.1`. |
| La app web no conecta (CORS) | Ejecuta Flutter con `--web-port=5173` y deja `CORS_ORIGINS=http://localhost:5173`. |
| El teléfono no conecta | Repite `adb reverse tcp:3000 tcp:3000` y verifica que Express siga abierto. |
| Falta el modelo offline o falla su hash | Confirma que clonaste la versión publicada de `danny` y que el ZIP tiene el tamaño/hash indicados; no sustituyas el modelo por otro. |

## Acceso adicional con Google

Preparado pero deshabilitado hasta configurar OAuth y aplicar la migración 003. Ver [GOOGLE_SIGN_IN_FINKI.md](GOOGLE_SIGN_IN_FINKI.md). El SQL único actualizado instala las tres versiones en una base nueva; no reimportarlo sobre datos existentes. El registro tradicional sigue disponible.
