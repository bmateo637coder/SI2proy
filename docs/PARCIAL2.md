# Parcial 2 · Inmobiliaria Raíces

## 1. Aspectos generales y alcance

Se evoluciona el monorepositorio `SI2proy/backend`, `frontend` y `mobile`. Las carpetas de sprints y ZIP del directorio superior son referencias; no se sobreescriben ni se mezclan automáticamente. Se conservan los cambios locales previos.

Fuente de requisitos: `enunciado parcial2.pdf`, entregado junto al proyecto. El enunciado emplea FashionStore como ejemplo; se adapta el dominio: empresa → inmobiliaria, sucursal → oficina, producto/variante → propiedad y características, inventario → disponibilidad de una propiedad, reserva → reserva inmobiliaria, venta de contado → contrato de venta y pago en efectivo. Una propiedad tiene cantidad uno; no se inventan tallas, colores o cambios de prendas. Como adaptación del plazo de cambios se permite cancelar reservas confirmadas durante 48 horas, configurable con `RESERVA_CANCEL_HORAS`.

Objetivo: operación comercial con datos aislados por empresa, continuidad local y confirmación posterior consistente. La aceptación definitiva de una venta es responsabilidad del servidor. Los modelos ML son académicos y se entrenan con datos sintéticos identificados como tales.

## 2. Requisitos, actores y reglas de negocio

Actores: superadministrador de plataforma, administrador de inmobiliaria, agente autorizado, cliente, proveedor de IA. El superadministrador gestiona empresas y límites; las operaciones comerciales se realizan con una cuenta de la inmobiliaria. Un agente debe tener una asignación explícita a la sucursal para descargar y sincronizar sus operaciones.

| ID | Requisito y comportamiento | Implementación | Verificación |
|---|---|---|---|
| RF01 | Empresa independiente y administrador | alta atómica de empresa, suscripción, matriz y administrador en `main.py` | pruebas de permisos y empresas |
| RF02 | Básico: 2 sucursales; Profesional: 10 e IA | `saas.py`, `plan_saas`, `suscripcion_saas` | límites, cambio de plan y vencimiento |
| RF03 | Sucursales y asignaciones dentro del tenant | `/api/saas/sucursales`, usuarios y propiedades | catálogo y accesos cruzados |
| RF04 | PWA instalable, shell offline | manifest, iconos, `sw.js`, `scripts/build-pwa.mjs` | Playwright: manifest y reinicio offline |
| RF05 | Catálogo local y operaciones web persistentes | `OfflineService`, IndexedDB por servidor/empresa/usuario | pruebas unitarias y Playwright |
| RF06 | Persistencia móvil SQLite | `offline_service.dart`, tablas con claves y FK | prueba SQLite con cierre y reapertura |
| RF07 | Reservas y ventas de contado locales | `/dashboard/offline`, `/offline` móvil | cola durable y contrato compartido |
| RF08 | Idempotencia y estados de sincronización | UUID + hash de payload + unicidad tenant/UUID | reenvío, respuesta perdida y UUID reutilizado |
| RF09 | Conflictos de disponibilidad/precio/versión | bloqueo PostgreSQL y resultado durable | venta competidora, versión y precio |
| RF10 | Integridad de venta, pago y disponibilidad | una transacción en `offline.py` | rollback y concurrencia PostgreSQL |
| RF11 | Reportes por texto/voz y consultas reales | `reportes_generativos.py`, pantalla Analítica | 5 tipos, filtros, tenant, parámetros inválidos |
| RF12 | Tabla, gráfico, PDF y Excel | pantalla Analítica web | compilación y verificación de interfaz |
| RF13 | ML supervisado y no supervisado | `analitica_ml.py`, bosque aleatorio y KMeans | métricas en conjunto separado |
| RF14 | Cancelar reserva dentro de plazo | `PUT /api/offline/reservas/{uuid}/cancelar` | cancelación repetida y protección de movimientos posteriores |

Reglas críticas:

1. El tenant y el responsable de la operación deben coincidir con la sesión. Los encabezados y el payload no otorgan acceso a otra empresa.
2. El correo puede repetirse entre empresas. Si es ambiguo, login solicita `id_tenant`; el JWT fija tenant y CI. El registro público siempre crea un cliente, aunque se intente enviar otro rol.
3. UUID y contenido son inmutables. Un reenvío confirmado devuelve el comprobante anterior. Reutilizar UUID con otro contenido produce 409.
4. Solo se confirma una propiedad disponible, con precio y versión vigentes y sucursal autorizada. En venta se exige tipo Venta, cantidad uno, total igual al precio y efectivo.
5. Una venta, su contrato, cuota pagada, pago y cambio de estado se confirman juntos. Un error revierte todos esos cambios.
6. La cola no se borra al enviar. Error de comunicación, 401, 402 u otra falta de confirmación conserva la operación pendiente. Los conflictos y rechazos se conservan para revisión. Tras corregir la causa se registra una nueva operación con otro UUID.
7. Las suscripciones inactivas/vencidas bloquean escrituras operativas e IA; el administrador conserva acceso a su suscripción para regularizarla. Cambios de límites y altas de sucursal se serializan por empresa.
8. El modelo de IA solo interpreta una solicitud en parámetros tipados. No se ejecuta SQL generado ni se le proporciona acceso a la base. Las consultas dinámicas heredadas usan listas explícitas de columnas y excluyen hashes de contraseña.

### Casos de uso ICONIX

**CU-P2-01 Operar sin conexión.** Precondición: sesión validada previamente y catálogo descargado. El agente elige propiedad y cliente, registra una reserva o venta en efectivo y recibe estado local. La operación se confirma en IndexedDB/SQLite antes de mostrar éxito. Al reiniciar se recuperan datos y pendientes. Alternativas: espacio insuficiente → error sin promesa de guardado; propiedad local no disponible → impedir nueva operación.

**CU-P2-02 Sincronizar.** La aplicación marca enviando y envía el payload original. El servidor autentica, bloquea la empresa, comprueba UUID y valida reglas. Devuelve confirmada, conflicto o rechazada. El cliente guarda el comprobante. Alternativa de red: pendiente y reintento con el mismo UUID. Si el servidor confirmó pero la respuesta se perdió, el reintento devuelve el resultado anterior.

**CU-P2-03 Administrar suscripción y sucursales.** El administrador consulta su plan, establece período/estado y crea/reactiva oficinas sin superar el límite. La plataforma configura límites mediante API. Alternativa: bajar de plan con demasiadas oficinas produce 409 y conserva datos. No hay facturación ni cobro recurrente real.

**CU-P2-04 Obtener reporte.** Un usuario operativo solicita por texto o dictado un reporte Profesional, o selecciona manualmente un reporte convencional Básico. El backend valida plan, interpreta, valida esquema y ejecuta consultas del tenant. La interfaz presenta tabla y barras, y permite exportar. Solicitudes ambiguas, filtros no compatibles o proveedor no disponible producen un error explícito. Sin `GEMINI_API_KEY`, el intérprete se identifica como `reglas_locales`: no se presenta como IA generativa activa.

**CU-P2-05 Analizar inmuebles.** El usuario Profesional consulta métricas y estimaciones. Se entrena con semilla 42, partición entrenamiento/validación y escalado ajustado al entrenamiento. Se predice sobre propiedades reales compatibles del tenant; datos insuficientes se omiten e informan. Los resultados no afirman precisión de mercado.

## 3. Diseño y modelos

Los archivos UML editables están en `docs/uml/` (PlantUML): casos de uso, dominio/clases, robustez y secuencias. Sus clases y rutas corresponden a la implementación.

Arquitectura: Angular + Service Worker (shell público) + IndexedDB (datos privados particionados); Flutter + almacenamiento seguro (sesión) + SQLite (catálogo y operaciones); API FastAPI; PostgreSQL compartido. No se cachean respuestas HTTP autenticadas en el Service Worker. Las claves locales incluyen URL del servidor, tenant y CI, y las consultas locales siempre usan ese ámbito. Cerrar sesión impide consultar desde la UI los datos de la cuenta anterior; conserva pendientes para cuando esa cuenta vuelva a ingresar.

Tablas centrales nuevas: `plan_saas`, `suscripcion_saas`, `sucursal`, `usuario_sucursal`, `operacion_offline` y `cambio_replica`. `propiedad` incorpora `id_sucursal` y `version`. El resto de entidades inmobiliarias se conserva.

SQLite: snapshot, branch, client, property y operation; claves compuestas por cuenta e identificador, FK y un índice para estados pendientes. El payload JSON inmutable de la operación es el contrato de envío; no se reconstruye al reintentar. Las descargas actualizan mediante UPSERT, conservando referencias de operaciones históricas.

Rendimiento: descarga de hasta 2000 propiedades/clientes, reportes limitados a 500 grupos y 10000 pagos con necesidad de acotar fechas, dashboard hasta 500 inmuebles. Las características se precargan para evitar consultas por inmueble. El bloqueo por empresa simplifica la idempotencia concurrente en este prototipo; una producción de alto volumen necesitaría bloqueos más finos y procesamiento por lotes.

## 4. Instalación e integración

Usar Python 3.12 con las dependencias fijadas (las originales no se prepararon para Python 3.14):

```powershell
cd SI2proy/backend
py -3.12 -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements-dev.txt
# Configurar .env a partir de .env.example apuntando a SU base PostgreSQL.
.venv/Scripts/python.exe migrate_parcial2.py
.venv/Scripts/python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000
```

La migración es aditiva y repetible. En desarrollo se ejecuta explícitamente; el arranque de producción `python start_render.py` la ejecuta antes de iniciar la API. Crea planes, asigna suscripciones a empresas previas (vence en 30 días si no había fecha), crea matriz si falta, asigna propiedades sin oficina y autoriza agentes existentes en esa matriz. Revisar esas asignaciones administrativas después de migrar. Ver [despliegue](DESPLIEGUE.md).

Para una base de demostración separada, definir `DATABASE_URL` y `DEMO_PASSWORD`, luego ejecutar `seed_parcial2_demo.py`. Crea Raíces Demo (Profesional) y Horizonte Demo (Básico), con usuarios, propiedades y contratos históricos distintos. El script imprime los IDs y correos; omite empresas demo ya existentes.

```powershell
cd SI2proy/frontend
npm ci
npm run start:local
# API local: http://localhost:8000
npm run build:local
npm run preview
# PWA compilada: http://127.0.0.1:4173, con API local
```

`npm run build` conserva la API de `environment.ts`; `build:local` apunta a localhost. El Service Worker se habilita en compilación optimizada; `ng serve` de desarrollo no demuestra instalación offline. En producción se requiere HTTPS y servir las rutas SPA con fallback a `index.html`. La construcción usa rutas relativas compatibles con un subdirectorio de GitHub Pages.

```powershell
cd SI2proy/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Desde la versión móvil 2.2, las pantallas habituales usan una réplica SQLite completa descargada automáticamente. Catálogo, clientes, contratos, pagos y reportes funcionan sin red; el acceso local verifica la contraseña de una cuenta previamente validada. El indicador superior abre el centro de sincronización y conflictos. Las reservas y ventas en efectivo siguen accesibles desde el botón Offline. Ver [la guía móvil](../mobile/README.md). SQLite se dirige a Android/iOS; la PWA Angular cubre navegadores. La sesión local conserva la copia y propuestas; un token vencido exige validar de nuevo antes de sincronizar. Windows puede requerir modo desarrollador para enlaces de plugins; las pruebas de lógica/SQLite pueden ejecutarse con `flutter test --no-pub` tras resolver paquetes.

IA: configurar `GEMINI_API_KEY` y, si corresponde, `GEMINI_MODEL`. El backend no inventa una clave ni un acceso al proveedor. Ejemplos: «ventas de septiembre de 2026 por sucursal», «ingresos por semana desde 2026-09-01 hasta 2026-10-30», «cartera por estado», «ranking de agentes», «reservas por sucursal 1». Se soportan fechas ISO, este mes, este año, trimestre y nombres de meses. La cartera es actual, sin histórico por fecha; los ingresos usan fecha de pago y los contratos fecha de inicio.

ML: `python analitica_ml.py` exporta el dataset sintético y métricas a `backend/ml_artifacts/` (ignorado por Git). No se mezcla con datos reales de otras empresas ni se crean resultados estáticos para reportes comerciales.

## 5. Pruebas y resultados

```powershell
cd SI2proy/backend
.venv/Scripts/python.exe -m pytest -q
# Pruebas con PostgreSQL de desarrollo; cada caso usa un esquema temporal independiente:
$env:TEST_DATABASE_URL='postgresql://usuario:password@localhost:5432/base_pruebas'
.venv/Scripts/python.exe -m pytest -q
```

Las pruebas fuerzan un `DATABASE_URL` temporal antes de cargar `.env`; nunca usan automáticamente la base del usuario. Incluyen venta atómica, reenvíos, UUID alterado, conflictos, rollback inyectado, tenant, sucursal, vencimiento, límites, registro sin escalamiento y consultas seguras. Las pruebas concurrentes se ejecutan con PostgreSQL; SQLite no demuestra bloqueos `FOR UPDATE`.

```powershell
cd SI2proy/frontend
npm test -- --watch=false
npx playwright install chromium
npm run build
npm run test:e2e
cd ../mobile
flutter test --no-pub
flutter analyze --no-pub
```

La prueba de navegador comprueba un reinicio offline real con shell cacheado, persistencia, fallo de sincronización, reintento con UUID idéntico y separación de cuentas. La prueba SQLite cierra y abre el archivo y simula la pérdida del comprobante después de aceptar en servidor.

Los resultados ejecutados y límites de verificación se registran en `docs/VALIDACION.md`.

## 6. Correcciones y límites

Correcciones confirmadas: `dominio`/`slug` inconsistente al crear empresas; alta parcial de empresa antes de crear administrador; modificación de estado de propiedades de otra empresa por admin; asociación de usuarios de otra empresa a propietarios/clientes; selección de usuario JWT solo por correo; elevación de rol desde registro público; extracción de `password_hash` mediante reportes; recomendaciones y WebSocket sin aislamiento adecuado; navegación móvil con índices incorrectos al ocultar pestañas; pérdida de sesión móvil al reiniciar sin Internet; cálculo de cuotas que no acumulaba abonos parciales. Los modelos existentes de pagos/cuotas/reportes se conservan.

Estado operativo: la migración aditiva, el despliegue en Render, la integración real de Gemini y la publicación del APK están acreditados en [docs/VALIDACION.md](VALIDACION.md). La integración Android usa un emulador con plugins nativos; el micrófono, el dictado y las aplicaciones de compartir requieren comprobación manual en cada teléfono. El flujo de recuperación de contraseña heredado continúa siendo una respuesta informativa: no hay correo SMTP configurado. La disponibilidad histórica y la tasación de mercado no están implementadas.

Bibliografía técnica de referencia: documentación de FastAPI, SQLAlchemy 2, Angular, IndexedDB/Service Worker (MDN), Flutter/sqflite, scikit-learn, Gemini y PlantUML. Los requisitos académicos y fechas de defensa se toman del PDF entregado, no de estas referencias.
