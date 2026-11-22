# Raíces Android 3.1 — navegación y funciones de la web

La versión 3.0 agrupaba los servicios nuevos y dejaba sin formularios buena parte de la administración. La versión 3.1 incorpora un **Centro de trabajo**, accesible desde **Todo** en la barra superior o desde el menú lateral, con búsqueda por nombre y por finalidad. La búsqueda encuentra palabras con o sin tildes. El perfil también enlaza a este centro.

## Correspondencia de pantallas

| Web | Android | Acciones disponibles |
|---|---|---|
| Catálogo | Catálogo | Consultar, filtrar, ver detalles, favoritos y visitas |
| Propiedades | Gestionar propiedades | Crear, editar, eliminar, estado, fotos, características, coordenadas, agente, propietario y sucursal |
| Clientes | Clientes / administrar | Crear desde usuario, consultar, cambiar usuario asociado y eliminar cuando no hay relaciones |
| Propietarios | Propietarios | Registrar, consultar, cambiar usuario asociado y eliminar cuando no hay inmuebles |
| Agentes | Agentes | Registrar, consultar y eliminar cuando no hay relaciones |
| Contratos | Contratos y pagos | Crear, aplicar promoción vigente, consultar cuotas/saldos, pagar, compartir recibos y eliminar si el servidor lo permite |
| Usuarios | Usuarios | Crear cuentas con CI, contacto, contraseña inicial y rol; consultar datos |
| Roles | Roles y permisos | Crear roles y asignar permisos con casillas |
| Empresas | Inmobiliarias | Crear empresa y administrador; restablecer administrador con confirmación |
| Plan | Planes y suscripciones | Consultar planes y suscripciones; cambiar plan, fechas y estado; configurar límites como SaaS |
| Sucursales | Sucursales | Crear, editar, activar/desactivar, autorizar empleados y asignar propiedades |
| Vista global | Vista global SaaS | Consultar información consolidada y por inmobiliaria |
| Bitácora | Bitácora | Introducir llave y consultar auditoría; filtrar registros |
| Backup | Respaldos | Descargar/compartir SQL; seleccionar archivo SQL y confirmar restauración |
| Reportes | Reportes dinámicos | Entidades, columnas, filtros, orden, configuraciones, voz y exportaciones |
| Analítica | IA y analítica | Reportes convencionales y generativos, gráficos, modelos y predicciones |
| Dashboard gerencial | Dashboard gerencial | Cartera, ocupación, ingresos, mora, comisiones, mantenimiento, visitas y agentes; gráficos por estado, operación y mes |
| Mapa de calor | Mapa de calor de ventas | Cantidad, monto, precio por m² y ranking por zona/inmobiliaria |
| Reporte ejecutivo | Reporte ejecutivo | Ver resumen y compartir PDF/CSV con cartera, contratos, ingresos y mantenimiento |
| Favoritos y alertas | Favoritos / Alertas de búsqueda | Agregar/quitar, crear, activar/desactivar y eliminar |
| Recomendaciones | Recomendaciones | Consultar y registrar valoración/comentario |
| Búsqueda semántica | Búsqueda inteligente | Consultar inmuebles por lenguaje natural |
| Chat y herramientas IA | Asistente y cotización IA | Chat, cotización y descripción comercial |
| Visitas | Visitas | Agendar, consultar y cambiar estado conforme al rol |
| Mantenimiento | Mantenimiento | Incidencias, clasificación, fotos, responsable, categoría, urgencia, contratista, estados, costos y seguimiento |
| Costos de mantenimiento | Mantenimiento → Costos consolidados | Totales por inmueble/categoría y solicitudes abiertas |
| Mi cuenta | Mi estado de cuenta | Consultar contratos, cuotas, pagos y envío de comprobantes según configuración |
| Notificaciones | Notificaciones | Bandeja, marcar una/todas como leídas, activar avisos y prueba |
| Offline / sincronización | Sincronización / Operaciones offline | Copia local, propuestas, reservas/ventas, reintentos y revisión de conflictos |
| Perfil | Mi perfil | Datos, contraseña y cierre de sesión |

No se inventan acciones que la API web no ofrezca: por ejemplo, la gestión de usuarios crea y consulta cuentas; los contactos se editan mediante su asociación con un usuario existente. Las eliminaciones conservan las restricciones del servidor.

## Alcance y datos

El selector SaaS aparece también en Servicios y Administración. **Todas las inmobiliarias** consolida consultas; registrar cambios de una empresa requiere seleccionarla. Los formularios comprueban que la inmobiliaria no cambió durante la edición. El rol del servidor sigue siendo la autoridad; abrir un enlace no concede permisos.

El botón Offline no se superpone a los botones de crear contratos o clientes. Las secciones nuevas tienen estados de carga, errores legibles, búsqueda y actualización. Los formularios administrativos usan listas de personas/sucursales/roles, campos numéricos y selectores de fecha. Un error del servidor conserva el formulario para corregirlo.

La descarga automática incorpora las listas administrativas autorizadas, sucursales, estado de suscripción y costos consolidados. Se mantienen el login local, catálogo, reportes, contratos/pagos y las colas anteriores. Cambiar roles/permisos, cuentas, empresas, planes, propiedades administrativas o restaurar respaldos requiere Internet; esas acciones no se encolan como si estuvieran confirmadas. Las funciones externas mantienen los límites descritos en [CONFIGURAR_FIREBASE_GMAIL.md](CONFIGURAR_FIREBASE_GMAIL.md).

## Correcciones compartidas con la web

- Las fotos nuevas de propiedades se guardan en PostgreSQL y se sirven como imágenes por una URL estable; no dependen del disco temporal de Render.
- Restaurar SQL usa la conexión configurada, una sola transacción y detención ante error. Se elimina el `SET transaction_timeout` incompatible de algunos volcados de pg_dump 18. Los errores no se presentan como restauraciones exitosas. No se restauró la base de producción para probar esta función.
- Propietarios con inmuebles y clientes con contratos/visitas devuelven un conflicto explicativo al intentar eliminarlos.
- Los agentes con nombres de rol heredados, como “Agente Raíces”, conservan acceso al mantenimiento de sus inmuebles mediante su relación real de agente.

## Validación

Las pruebas nuevas verifican el alcance de formularios, creación de usuarios y selección de rol, conservación del formulario ante rechazo del servidor, búsqueda sin tildes, fotografías persistidas, autorización, restauración con transacción y protección de relaciones. El flujo Android comprueba también abrir el centro de trabajo, buscar Bitácora sin tilde y acceder a Gestión de propiedades, antes de continuar el flujo offline anterior.

Se conserva la firma Android existente para actualizar sin desinstalar ni borrar la copia local. La compilación final requiere aprobar los tests y las integraciones nativas antes de publicar el archivo.
