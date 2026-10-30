# Actualizar GitHub Pages y Render desde la rama del segundo parcial

Repositorio: https://github.com/bmateo637coder/SI2proy

Rama de trabajo: `feat/parcial2-saas-offline-analitica`. Se conserva `main`; los despliegues se pueden lanzar manualmente desde esta rama.

## 1. Render: servicio existente

Servicio de API conocido: `https://raices-backend-n1yy.onrender.com`.

Configurar el **servicio existente**, conservando su URL y su `DATABASE_URL` actual:

| Configuración | Valor |
|---|---|
| Repositorio | `bmateo637coder/SI2proy` |
| Branch | `feat/parcial2-saas-offline-analitica` |
| Root Directory | `backend` |
| Build Command | `pip install -r requirements.txt` |
| Start Command | `python start_render.py` |
| Health Check Path | `/api/health` |
| `PYTHON_VERSION` | `3.12.10` |

`start_render.py` aplica la migración aditiva y luego inicia Uvicorn. No ejecuta semillas ni restablece contraseñas. La migración usa un bloqueo de PostgreSQL para serializar arranques concurrentes. Si falla, el despliegue falla sin iniciar una API con esquema incompleto.

Conservar también `JWT_SECRET_KEY`, `BITACORA_FERNET_KEY`, `DEFAULT_ADMIN_PASSWORD` y las variables de respaldo existentes. Agregar `GEMINI_API_KEY` solo para activar el proveedor IA. Una clave de Render permite administrar despliegues; no es la clave de Gemini.

No importar un Blueprint que cree otra base para reemplazar la actual. `backend/render.yaml` documenta la configuración y solicita `DATABASE_URL` existente.

Verificación: `GET /api/health` debe indicar versión `2.0.0`, el SHA del commit y las funciones `saas`, `offline`, `analitica`. `GET /openapi.json` debe incluir `/api/offline/sincronizar` y `/api/saas/suscripcion`.

En el plan gratuito no se depende de un comando pre-deploy de pago: la migración se ejecuta dentro del arranque. Los respaldos SQL heredados requieren que `pg_dump` esté disponible en el entorno; no se intenta instalar paquetes del sistema con `apt-get` durante el build nativo.

## 2. GitHub Pages

El repositorio ya usa `gh-pages` como origen de Pages y la variable pública `PROD_API_URL` apunta a Render. No se coloca una API key en el frontend.

Con el backend ya actualizado:

1. En Actions, abrir **Deploy Frontend (GitHub Pages)**.
2. Ejecutar **Run workflow** seleccionando `feat/parcial2-saas-offline-analitica` y la operación `frontend` para publicar solo la web. La operación `deploy` actualiza primero Render y luego la web.
3. El workflow construye con `/SI2proy/`, prepara manifest y Service Worker, genera el fallback SPA y publica en `gh-pages`.
4. Abrir https://bmateo637coder.github.io/SI2proy/ y volver a iniciar sesión.

GitHub Pages puede devolver HTTP 404 para una ruta Angular profunda como `/SI2proy/login` aunque el fallback ejecute la aplicación. La URL raíz sirve como entrada estable.

El Service Worker conserva una versión coherente para uso offline. Después de actualizar, cerrar las pestañas previas y volver a abrir permite activar la nueva versión. No borrar IndexedDB si hay operaciones pendientes de sincronización.

## 3. Acceso para desplegar

El nombre `si2parcial` identifica una credencial en Render; el nombre por sí solo no autentica. Para despliegue asistido, conectar Render o configurar `RENDER_API_KEY` como secreto de GitHub y, si hace falta, el identificador del servicio. No subir claves, `.env`, volcados SQL o bases locales a la rama.

### Despliegue mediante GitHub Actions

El secreto `RENDER_API_KEY` se configura en **Settings > Secrets and variables > Actions > Secrets**. La variable pública `PROD_API_URL` identifica la API. El workflow busca el servicio por su URL y comprueba que pertenezca a este repositorio; no crea otro servicio ni otra base de datos.

En **Deploy Frontend (GitHub Pages)**, elegir la rama del parcial 2 y una operación:

- `inspect`: comprobar acceso y mostrar configuración y nombres de variables, sin sus valores ni cambios en Render.
- `deploy`: conservar las credenciales existentes, fijar Python 3.12.10, cambiar la rama y el comando de arranque, desplegar el SHA seleccionado y esperar a que esté activo. Solo después publica Pages.
- `frontend`: verificar que la API ya tenga las funciones del parcial 2 y publicar la web.

La operación `deploy` desactiva los despliegues automáticos en Render para evitar que otro push reemplace la versión seleccionada. Las siguientes actualizaciones se ejecutan manualmente desde este workflow. No cancelar un workflow durante la migración: esperar su resultado y comprobar Render antes de reintentar.

La comprobación final exige versión `2.0.0`, el SHA desplegado y las rutas SaaS/offline en OpenAPI. La clave de Render se utiliza exclusivamente en el job de backend, nunca en el build del frontend.

Referencias: [despliegues Render](https://render.com/docs/deploys), [comandos de arranque](https://render.com/docs/deploys#start-command), [API de despliegue](https://api-docs.render.com/reference/create-deploy).
