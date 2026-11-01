# Verificación del parcial 2

Actualizado el **1 de noviembre de 2026**, America/La_Paz.

## Pruebas automáticas

La [suite completa](https://github.com/bmateo637coder/SI2proy/actions/runs/41324151384) del commit `e24575e` aprobó backend con PostgreSQL 15, Angular, Playwright y Flutter. Las pruebas del servidor cubren permisos y aislamiento SaaS, reportes, transacciones concurrentes, UUID idempotentes, dependencias de registros creados offline y cuotas positivas cuyo total coincide en centavos. Flutter verifica acceso local con contraseña, alcance global/empresa, reportes con filtros y fechas, pagos fraccionados, persistencia, reintentos, cancelaciones y conflictos.

La [compilación de distribución](https://github.com/bmateo637coder/SI2proy/actions/runs/41324153368) aprobó el análisis Dart, los tests Flutter, las dos integraciones Android con SQLite y almacenamiento seguro nativos, la compilación de producción y la firma. Se verifican la descarga automática, el catálogo habitual y los reportes sin red, el login local tras cerrar sesión, la persistencia de cambios y la presentación de conflictos. La prueba anterior de reservas conserva la recreación de app/base y la respuesta perdida sin duplicar operaciones.

El análisis usa `--no-fatal-infos`: conserva sugerencias de estilo y avisos de obsolescencia de dependencias heredadas. Las pruebas no crean ventas ni reservas reales. El emulador no sustituye la comprobación manual de micrófono, dictado y aplicaciones de compartir en cada teléfono.

## Android publicado

- [Descargar Raíces 2.2.0](https://github.com/bmateo637coder/SI2proy/releases/download/mobile-2.2.0-13/Raices-2.2.0.apk).
- [Versión y SHA-256](https://github.com/bmateo637coder/SI2proy/releases/tag/mobile-2.2.0-13).
- Código de la compilación: `e24575eda9a6da127bf7ef3e74ad11e37f13f2ca`.
- SHA-256 del APK: `7c72a3030d6a71319687117ed0214af32d2830687282335fb6262aa80e967d35`.
- Firma persistente, compatible con la actualización de la versión 2.1.0.
- [Uso y límites de la app móvil](../mobile/README.md).

El archivo se publica desde el artefacto verificado mediante `scripts/publish_mobile_release.py`; la recuperación de carga no recompila ni cambia el APK. Las credenciales y el almacén de firma permanecen fuera del repositorio.

## Verificación en producción

API: https://raices-backend-n1yy.onrender.com · Web: https://bmateo637coder.github.io/SI2proy/

Render confirmó `dep-dbjm6dflk1mc739lvmo0` como `live` con el código `e24575e`. Se conservan el servicio, la base y los registros existentes. La copia `/api/replica/datos` exige autenticación y contiene los mismos identificadores que las pantallas online:

| Inmobiliaria | Propiedades | Clientes | Contratos |
|---|---:|---:|---:|
| Raíces | 3 | 3 | 1 |
| Horizonte | 5 | 0 | 0 |
| Cúspide | 5 | 0 | 0 |

La copia global contiene 13 propiedades completas, 3 clientes, 1 contrato con cuotas/pagos, 10 usuarios de empresas sin hashes de contraseñas, 3 propietarios, 3 agentes y 3 sucursales. La descarga de una empresa no incluye registros de otras. Las huellas de registros permiten detectar cambios antes de aplicar una propuesta local. Estas comprobaciones fueron de lectura y no modificaron datos de negocio.

La comprobación del 31 de octubre verificó Gemini real en consultas, reportes y descripciones, así como el acceso SaaS a todas las empresas sin adoptar el plan Básico de Horizonte/Cúspide. Esa configuración se conserva; las claves nunca se incluyen en el APK. Los reportes dinámicos y convencionales de la versión 2.2 se calculan también sin el proveedor mediante la copia local.

## Alcance y límites

**Todas las inmobiliarias** aplica a las consultas habituales, reportes, analítica y herramientas locales. Las propuestas de escritura requieren una inmobiliaria concreta. El teléfono descarga automáticamente información autorizada y fotos, conserva la última copia completa y superpone sus cambios pendientes. El indicador superior muestra última copia, descarga de fotos, pendientes y conflictos.

La sincronización se ejecuta al abrir/reanudar la app y cada 15 segundos mientras está abierta. Las propuestas conservan UUID y dependencias; se validan permisos, suscripción y estado actual del servidor. Si venció el token, se exige validar sesión para subir cambios y se conserva el acceso a la copia local. Un conflicto conserva el registro del servidor y la propuesta para revisión; descartar una propuesta descarta también los cambios que dependan de ella.

Gemini, el entrenamiento de modelos, el primer acceso de una cuenta, los cambios de contraseña y servicios externos requieren Internet. Sin red hay reportes, reglas explícitas de texto, plantillas, consultas locales y predicciones previamente descargadas. Las reservas pendientes se distinguen de las confirmadas y los recibos locales son provisionales.

El modelo predictivo sigue usando datos sintéticos: sus métricas describen el conjunto académico y no una tasación del mercado. La recuperación de contraseña heredada es informativa porque no hay SMTP. La copia no puede conocer cambios de otros dispositivos mientras no haya conexión.
