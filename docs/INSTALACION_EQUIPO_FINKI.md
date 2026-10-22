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
| [Flutter](https://docs.flutter.dev/get-started/install/windows) | **3.47 o superior** | App móvil/web |
| Android Studio o solo el SDK de Android | opcional | Probar en un teléfono |
| Google Chrome | opcional | Probar la versión web |

Comprueba en PowerShell:

```powershell
git --version
node --version      # debe decir v22 o superior
flutter --version   # debe decir 3.47 o superior
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
git clone https://github.com/Maricarmen08/Hackathon2026-Pinguinos.git
cd Hackathon2026-Pinguinos
```

## 4. Importar la base de datos (un solo archivo)

El archivo oficial es **`database/hackathon_pinguinos_dev.sql`**. Crea la base
`hackathon_pinguinos_dev` con sus 23 tablas, 5 vistas, relaciones e índices.
No trae usuarios ni datos.

**Con HeidiSQL:**
1. Conéctate con `root`.
2. **Archivo → Cargar archivo SQL…** → elige `database\hackathon_pinguinos_dev.sql`.
3. Pulsa **Ejecutar** (F9). Ejecuta el archivo completo, no una parte.
4. Pulsa F5 en el panel izquierdo: aparece `hackathon_pinguinos_dev`.

**O con la consola de Laragon** (botón *Terminal*):
```powershell
mysql -u root -p < database\hackathon_pinguinos_dev.sql
```
(Pulsa Enter si la contraseña está vacía).

Comprueba en HeidiSQL:
```sql
SELECT table_type, COUNT(*) FROM information_schema.tables
WHERE table_schema = 'hackathon_pinguinos_dev' GROUP BY table_type;
-- BASE TABLE 23 · VIEW 5
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

**Inteligencia artificial (opcional):** la app funciona completa sin IA
(`AI_ENABLED=0`). Si el equipo decide probar Gemini, cada persona usa **su
propia clave** de Google AI Studio en su `.env`. Nunca compartas claves por
chat ni las subas a GitHub. Detalles en `docs/GEMINI_SETUP.md`.

`backend/.env` está en `.gitignore`: **no se sube a GitHub**.

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
```

**En Chrome** (puerto fijo para que el backend lo acepte):
```powershell
flutter run -d chrome --web-hostname=localhost --web-port=5173 --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

**En un teléfono Android por USB** (depuración USB activada):
```powershell
adb devices
adb reverse tcp:3000 tcp:3000
flutter run -d <ID_DEL_TELEFONO> --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```
Repite `adb reverse` cada vez que reconectes el cable. En PCs con poca memoria,
usa `.\tool\flutter-local.ps1` en lugar de `flutter` (ver `docs/ANDROID_LOW_MEMORY.md`).

**En el emulador de Android Studio:**
```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

## 10. Comprobar que todo funciona

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
| `Missing migrations` al iniciar | Importaste otro SQL. Revisa que `schema_migraciones` tenga las versiones 1 y 2. |
| `Unsupported database configuration` | MySQL no es 8.4 o `DB_NAME` no coincide. |
| `root o contraseña vacía requieren …` | Usa el usuario del paso 5, o deja `NODE_ENV=development` y `HOST=127.0.0.1`. |
| La app web no conecta (CORS) | Ejecuta Flutter con `--web-port=5173` y deja `CORS_ORIGINS=http://localhost:5173`. |
| El teléfono no conecta | Repite `adb reverse tcp:3000 tcp:3000` y verifica que Express siga abierto. |
