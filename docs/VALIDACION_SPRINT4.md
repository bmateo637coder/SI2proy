# Integración web y Android — 22 de noviembre de 2026

La actualización posterior **Android 3.1.0**, con centro de trabajo y administración nativa, tiene su [matriz y evidencia vigente](PARIDAD_MOVIL_3_1.md). El documento siguiente conserva el historial de integración 3.0, recuperación de la base y despliegue inicial del sprint.

Rama: `feat/sprint4-integracion-web-movil`. [PR de revisión](https://github.com/bmateo637coder/SI2proy/pull/2). La matriz de funcionalidades y sus pantallas está en [SPRINT4_INTEGRACION.md](SPRINT4_INTEGRACION.md).

## Evidencia automática

- [Backend con PostgreSQL, Angular, Playwright y Flutter](https://github.com/bmateo637coder/SI2proy/actions/runs/45018880757): aprobado, con 80 pruebas backend aprobadas.
- [Integraciones en emulador Android, compilación y firma](https://github.com/bmateo637coder/SI2proy/actions/runs/44985229394): aprobadas. Incluyen SQLite, almacenamiento seguro, catálogo/reportes offline, reintentos y el canal nativo de avisos.
- [Restauración del respaldo en PostgreSQL 16 aislado](https://github.com/bmateo637coder/SI2proy/actions/runs/45018644692): aprobada.
- [Recuperación autorizada en una base nueva gratuita](https://github.com/bmateo637coder/SI2proy/actions/runs/45018887790): aprobada.

Las pruebas nuevas comprueban aislamiento por usuario/inmobiliaria, UUID idempotentes, conflictos de versión, mantenimiento con fotos y costos, comisiones y promociones, PDF ejecutivo, ventas por zona, agenda real y auditoría cifrada persistente. Web Push comprueba firma VAPID y cifrado real antes de simular la respuesta del proveedor; no demuestra recepción final en el navegador del usuario.

## APK publicado

[Descargar Raíces 3.0.0](https://github.com/bmateo637coder/SI2proy/releases/download/mobile-3.0.0-18/Raices-3.0.0.apk) · [Versión y huella](https://github.com/bmateo637coder/SI2proy/releases/tag/mobile-3.0.0-18).

Descarga pública comprobada con HTTP 200, 62.583.682 bytes y SHA-256:

`e7c8a363d079456e98d2aee4948af1d59428769b9265c4faf13c06d98e82f95e`

El APK procede del artefacto firmado del commit `521c9b3`. Los commits posteriores de esta integración modifican recuperación/despliegue/documentación, sin cambios móviles. Conserva la firma existente para actualizar instalaciones anteriores.

## Recuperación de datos

La base indicada por la configuración antigua ya no aparecía entre los recursos de Render. Con autorización del propietario se restauró el único respaldo disponible: `backups/backup_raices_20261031_020000.sql`, rama `backups`, SHA-256 `26ddc06ab188d70e92d4844ef365a5d0e2412b9ec8b2a1cae89c6dc27fa3c779`.

Se validaron 3 inmobiliarias, 7 usuarios, 3 propiedades, 3 clientes, 1 contrato, 1 pago y 1 cuota. El respaldo contiene **cero entradas de bitácora**; no permite recuperar movimientos posteriores al 31 de octubre ni historial que solo estuviera en archivos del servicio anterior. La versión nueva persiste la auditoría cifrada en PostgreSQL.

La base nueva `raices-recuperada-20261122` usa el plan gratuito y vence el **22 de diciembre de 2026**, según Render. No se contrataron recursos pagados. La configuración anterior se conservó cifrada en el artefacto de recuperación, con retención de siete días. Es necesario descargar un respaldo actualizado antes del vencimiento.

## Producción comprobada

[Despliegue backend y web aprobado](https://github.com/bmateo637coder/SI2proy/actions/runs/45019095404). Render confirmó `dep-dc1dd4h42hec7392rpn0` como `live`, commit `4bf73f7841ae2295c3cd1f50c71aa30f15aa10f7`. `/api/health` responde correctamente e incluye `sprint4`.

- [Web actualizada](https://bmateo637coder.github.io/SI2proy/): se verificaron los 30 archivos JavaScript de la copia PWA, versión `4bf73f78`, backend de producción y service worker Web Push.
- Inicio de sesión SaaS: aprobado. Catálogo, dashboard, mapa y PDF ejecutivo responden en las tres inmobiliarias y en alcance global.
- Catálogos: Raíces conserva sus 3 propiedades; se recrearon 5 propiedades ficticias e identificadas como demostración en Horizonte y 5 en Cúspide. El alcance global devuelve las 13; los reportes de cada empresa incluyen sus propios registros.
- Favoritos, alertas, recomendaciones, feedback, mantenimiento, comisiones, promociones, visitas y configuración de avisos: consultas autenticadas aprobadas.
- Réplica para offline: descarga autenticada aprobada. Las integraciones Android verifican su almacenamiento y funcionamiento sin red.
- IA real de Gemini: chat y búsqueda semántica respondieron en modo `gemini`. La descripción comercial respondió con `plantilla_local`, identificada como alternativa. La cotización de una propiedad de demostración con características completas calculó `modelo_local`; la propiedad original sin características suficientes informó que no podía generar una tasación.

No se crearon ventas, pagos ni incidentes ficticios para aparentar actividad en los reportes. Los mapas sin coordenadas válidas conservan el ranking de zonas.

## Límites externos

La carga posterior de demostración amplió los datos a 31 propiedades y 16 contratos. Conteos y comprobaciones: [DATOS_DEMO_SPRINT4.md](DATOS_DEMO_SPRINT4.md).

- Avisos web: aceptar el permiso en Servicios → Notificaciones. Las claves VAPID se generan automáticamente; no se necesita Firebase.
- Android: activar avisos y aceptar el permiso. Consulta la bandeja aproximadamente cada 15 minutos en segundo plano y cada 45 segundos con la app abierta; Android puede retrasarla. Esta alternativa no acredita CU-27 específicamente mediante FCM. La integración FCM sigue disponible de forma opcional con credenciales del propietario.
- Gmail SMTP no está configurado ni se ha probado el envío real. Render gratuito bloquea los puertos SMTP habituales. Los comprobantes PDF se descargan y comparten; SMTP necesita cuenta emisora y alojamiento compatible.
- Gemini requiere Internet y disponibilidad del proveedor. Las respuestas de reglas, modelos académicos y plantillas identifican su origen; no se presentan como generación de Gemini.
- Offline necesita una sesión previamente validada y una copia descargada. La administración de suscripciones, la entrega externa, la primera validación de cuenta y Gemini requieren conexión. La sincronización puede detectar conflictos y requiere revisarlos.

La evidencia anterior de noviembre permanece como historial en [VALIDACION.md](VALIDACION.md).
