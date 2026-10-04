# SI2proy

Sistema Inmobiliario "Raíces" — monorepo con las tres partes del proyecto.

## Estructura

| Carpeta    | Tecnología        | Descripción                                    |
|------------|-------------------|------------------------------------------------|
| `backend/` | Python + FastAPI  | API REST, autenticación JWT, PostgreSQL (SQLAlchemy) |
| `frontend/`| Angular           | Panel web (comercial / administración)          |
| `mobile/`  | Flutter           | Aplicación móvil (catálogo, perfil, clientes)   |

## Backend (`backend/`)

API FastAPI modular: `main.py` (rutas y seguridad), `schemas.py` (Pydantic),
`auth.py` (JWT + bcrypt), `database/` (modelos SQLAlchemy y conexión).

### Configuración

Copiar `.env.example` a `.env`:

```
DATABASE_URL=postgresql://usuario:password@host:5432/bd
JWT_SECRET_KEY=...
BITACORA_FERNET_KEY=...
SEED_ADMIN_PASSWORD=...
DEFAULT_ADMIN_PASSWORD=...
```

### Puesta en marcha local

```bash
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt
.venv/Scripts/python seed_local_demo.py     # crea esquema + datos demo
.venv/Scripts/python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

> Requiere una base PostgreSQL existente. `requirements.txt` incluye
> `google-generativeai` (módulo IA, exigido al arrancar) y el servidor crea la
> carpeta `uploads/` automáticamente.

### Endpoints principales

| Método | Ruta                                  | Uso                          |
|--------|---------------------------------------|------------------------------|
| POST   | `/login`                              | Iniciar sesión (JWT)         |
| GET    | `/users/me`                           | Perfil del usuario           |
| PUT    | `/users/me/password`                  | Cambiar contraseña           |
| POST   | `/forgot-password`                    | Recuperar contraseña         |
| GET/POST | `/modulo_inmuebles/clientes`        | Listar / registrar clientes  |
| PUT/DELETE | `/modulo_inmuebles/clientes/{id}`  | Editar / eliminar cliente    |

## Frontend (`frontend/`)

Aplicación Angular estándar.

```bash
npm install
ng serve       # desarrollo (http://localhost:4200)
ng build       # producción → dist/
```

## Mobile (`mobile/`)

App Flutter. La URL de la API se define en `lib/core/config/api_constants.dart`
y puede sobrescribirse en build/run:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
flutter build apk --dart-define=API_BASE_URL=https://<backend-publico>/
```

## Despliegue (gratuito)

- **Frontend:** GitHub Pages (rama `gh-pages`).
- **Backend:** Render (free web service) + PostgreSQL en Neon (tier free).
- **Mobile:** APK publicado como GitHub Release.