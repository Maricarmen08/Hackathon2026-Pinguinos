# Hackathon2026-Pinguinos
Repositorio oficial del equipo Pinguino de Madagascar para la Hackathon 2026

Aplicación Flutter Android V1: consulta [ejecución, recorrido y límites](docs/FLUTTER_ANDROID_V1.md).

**Instalar en una PC nueva:** sigue [docs/INSTALACION_EQUIPO_FINKI.md](docs/INSTALACION_EQUIPO_FINKI.md).
La base de datos se crea importando un solo archivo: `database/hackathon_pinguinos_dev.sql`.

La rama oficial del equipo es **`main`**. Para instalar la versión integrada:

```powershell
git clone --branch main https://github.com/Maricarmen08/Hackathon2026-Pinguinos.git
cd Hackathon2026-Pinguinos
```

La rama **`danny`** se utiliza para desarrollar. Sus cambios se revisan e integran
en **`main`** mediante un **Pull Request de `danny` hacia `main`**. La clonación de
`danny` descrita en la guía de instalación corresponde al trabajo de desarrollo;
para la versión oficial utiliza `main`. Conserva cualquier cambio local antes de
actualizar un clon existente.

El modelo español Vosk ya está incluido en el proyecto, con licencia y checksum;
consulta los requisitos Android y de voz offline en la misma guía de instalación.
