# Integración de los sprints 3 y 4

La numeración de esta matriz corresponde a la imagen entregada por el equipo. El documento de 267 páginas contiene otras revisiones de la numeración; no deben confundirse con la tabla CU-22 a CU-37.

Los directorios de entrega `SI2-Backend-feature-anticretico-y-contrato-venta` y `SI2-Frontend-feature-anticretico-y-contrato-venta` están fuera del repositorio. La integración conserva el esquema publicado, cuya clave de usuario es el CI, la selección SaaS de todas las inmobiliarias y la réplica offline anterior. Los módulos de fidelización, mantenimiento, clasificación y bandeja se adaptaron desde esas entregas; no se reemplazó la base ni se ejecutaron semillas.

| Caso | Función | Web | Flutter Android |
|---|---|---|---|
| CU-22 | Planes y suscripciones | Plan y sucursales | Servicios → Plan y suscripción |
| CU-23 | Cotizar con IA | Servicios → Cotizar | Servicios → Asistente e IA |
| CU-24 | Descripción comercial | Propiedades / Servicios | Asistente e IA |
| CU-25 | Promociones y descuentos | Promociones / nuevo contrato | Promociones / nuevo contrato |
| CU-26 | Comprobante por Gmail | Servicios → Estado de cuenta | Mi cuenta → comprobante |
| CU-27 | Notificaciones | Web Push VAPID sin cuentas externas y bandeja | Avisos periódicos nativos sin Firebase; integración FCM opcional |
| CU-28 | Estado de cuenta | Servicios → Estado de cuenta | Mi cuenta |
| CU-29 | Comisiones | Comisiones | Comisiones |
| CU-30 | Incidencias con fotos | Mantenimiento | Mantenimiento |
| CU-31 | Seguimiento, costos y contratistas | Detalle de mantenimiento | Detalle de mantenimiento |
| CU-32 | Favoritos | Favoritos y búsqueda | Favoritos y búsqueda |
| CU-33 | Alertas personalizadas | Favoritos y alertas | Alertas |
| CU-34 | Búsqueda semántica | Servicios → Búsqueda | Búsqueda |
| CU-35 | Recomendaciones | Servicios → Recomendaciones | Recomendaciones |
| CU-36 | Chat asistente | Servicios → Asistente | Asistente e IA |
| CU-37 | Reporte ejecutivo | Servicios → PDF/CSV | Reporte ejecutivo → PDF |
| Adicional | Mapa de ventas por zona | Mapa de ventas | Mapa de ventas |
| Adicional | Feedback de recomendaciones | Valoración y comentario | Valoración y comentario |
| Adicional | Dashboard gerencial | Dashboard gerencial | Gerencia |

## Reglas importantes

- El mapa agrega exclusivamente contratos de **Venta**, separa la inmobiliaria y respeta el alcance SaaS. No inventa coordenadas: las zonas sin georreferenciación aparecen en el ranking. Las coordenadas y la zona geográfica se editan en Propiedades. El segmento usado por el modelo académico se conserva aparte.
- Los favoritos y el feedback pertenecen a la cuenta. Las valoraciones bajas excluyen el inmueble de las próximas recomendaciones; las positivas aportan al perfil de preferencias.
- Las fotos se guardan en PostgreSQL y se devuelven como imágenes en los datos autorizados; sobreviven a un despliegue en Render.
- Los cambios nuevos usan recibos por UUID en la misma transacción de negocio. Web usa IndexedDB; Android, SQLite. La revisión de conflictos permite descartar la propuesta o volver a proponerla contra la versión mostrada. Si vuelve a cambiar el servidor, se vuelve a detectar el conflicto.
- Push web utiliza VAPID con claves cifradas generadas automáticamente y una bandeja persistente. El trabajo entrega después de confirmar los datos. Android consulta la bandeja aproximadamente cada 15 minutos en segundo plano y cada 45 segundos con la app activa; no se presenta esta consulta como FCM inmediato. La credencial Android solo permite leer la bandeja propia y se revoca al cambiar de cuenta o cerrar sesión.
- La cotización predictiva usa el modelo académico existente cuando hay superficie, habitaciones y segmento compatibles. Si faltan, se informa que no se generó una estimación. No se presenta el precio publicado como una predicción.
- Gemini se utiliza para las funciones generativas cuando está disponible. Las plantillas, respuestas guardadas y filtros locales indican su origen. Los filtros offline son básicos; no sustituyen una interpretación generativa.

## Configuración y validación externa

Los avisos habituales no necesitan configurar cuentas externas. Gmail y la integración específica FCM sí requieren las credenciales del propietario. La recepción final debe comprobarse aceptando el permiso del navegador o teléfono; la aceptación del proveedor no demuestra por sí sola que apareció en pantalla. Ver [CONFIGURAR_FIREBASE_GMAIL.md](CONFIGURAR_FIREBASE_GMAIL.md).

La primera descarga, la administración de suscripciones, la entrega de correos/push y Gemini requieren Internet. El mapa base depende del proveedor cartográfico; el ranking por zonas permanece disponible con los datos descargados.


## Correcciones adicionales

- Agendar una visita persiste realmente el turno y notifica al cliente y al agente; detecta disponibilidad y choques de agenda. Las propuestas offline se validan al sincronizar.
- Las comisiones liquidadas impiden eliminar su contrato.
- La bitácora nueva se conserva cifrada en PostgreSQL. Cuando el servicio anterior responde, el despliegue respalda su historial cifrado y lo importa con control de duplicados. La recuperación autorizada del 22 de noviembre usó el respaldo disponible, que contiene cero entradas históricas; ver [VALIDACION_SPRINT4.md](VALIDACION_SPRINT4.md).
- Pruebas de integración de dominio: aislamiento por cuenta e inmobiliaria, alertas sin duplicados, mantenimiento con fotos/costos, promociones, ventas por zona, reportes PDF, visitas, recibos UUID, conflicto de versiones y auditoría persistente.
- Avisos: pruebas de credenciales limitadas y revocación; Web Push comprueba firma VAPID y cifrado del mensaje real antes de simular la respuesta del proveedor. Esa prueba no acredita recepción en un navegador del usuario.
