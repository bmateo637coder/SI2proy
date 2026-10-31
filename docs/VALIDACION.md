# Verificación del parcial 2

Actualizado el **31 de octubre de 2026**, America/La_Paz.

## Pruebas automáticas

La [suite completa del commit bd4a95a](https://github.com/bmateo637coder/SI2proy/actions/runs/41214051294) terminó correctamente: backend con PostgreSQL 15, Angular, Playwright y Flutter. La compilación Android usa el código móvil del commit d59d262; la actualización bd4a95a añade la autorización SaaS en el servidor sin modificar el código del APK.

| Componente | Cobertura verificada |
|---|---|
| Backend | Aislamiento por empresa y alcance global SaaS, autorizaciones, migración aditiva, planes/sucursales, reportes, interpretación generativa, transacciones y sincronización concurrente/idempotente |
| Angular y Playwright | Selección global aplicada a pantallas existentes, catálogo, reportes y exportación, sesión y operaciones offline |
| Flutter | Identidad global separada de la empresa operativa, cabeceras de alcance, selección persistente sin red, exportaciones PDF/Excel/CSV/HTML, aislamiento SQLite y recuperación/reintento sin duplicar operaciones |
| Android nativo | Login SaaS, catálogo global, reportes dinámicos y analíticos, cambio de empresa, descarga, reserva offline, recreación de app y base, recuperación de sesión, respuesta perdida, reintento y separación entre empresas |

La [compilación Android](https://github.com/bmateo637coder/SI2proy/actions/runs/41213010745) aprobó el análisis completo de Dart, las pruebas Flutter, la integración en emulador Android 35, la compilación de producción y la comprobación criptográfica de firma. GitHub rechazó solamente la publicación automática por el permiso Workflows del token de Actions. Se recuperó el mismo artefacto con [la carga verificada en Actions](https://github.com/bmateo637coder/SI2proy/actions/runs/41215153917) y se publicó mediante `scripts/publish_mobile_release.py`, usando el acceso local autorizado; no se recompiló ni alteró el APK. La ejecución original conserva el error de ese paso de publicación. El workflow actualizado admite artefactos desde la rama de trabajo, recuperación de cargas y publicación automática con un token que tenga el permiso requerido.

El análisis se ejecuta con `--no-fatal-infos`: no hay errores ni advertencias bloqueantes; se conservan sugerencias de estilo sobre llaves en condicionales. La suite Python conserva avisos de obsolescencia de dependencias heredadas.

## Android publicado

- [Descargar Raíces 2.1.0](https://github.com/bmateo637coder/SI2proy/releases/download/mobile-2.1.0-8/Raices-2.1.0.apk).
- [Versión y archivo SHA-256](https://github.com/bmateo637coder/SI2proy/releases/tag/mobile-2.1.0-8).
- Código de la compilación: `d59d262ba8f31554ac74328d3712ba1b77cffa68`.
- Firma persistente protegida por secretos cifrados de GitHub Actions; no se incorpora al repositorio.
- [Uso y pruebas de la app móvil](../mobile/README.md).

Las pruebas Android usan un servidor controlado y los plugins nativos de SQLite y almacenamiento seguro. No crean ventas ni reservas reales. La prueba cierra/reabre la base y recrea la aplicación; no sustituye una prueba manual en cada modelo de teléfono. El dictado y el diálogo para compartir archivos necesitan comprobación manual con el micrófono y las aplicaciones disponibles en el dispositivo.

## Verificación en producción

API: https://raices-backend-n1yy.onrender.com · Web: https://bmateo637coder.github.io/SI2proy/

Render confirmó `dep-dbj0dq8ae00c73csj000` como `live` con el commit `bd4a95a`. Se conserva el servicio, la base y su configuración. La verificación autenticada de lectura confirmó:

- Las tres inmobiliarias tienen catálogo: Raíces 3 propiedades, Horizonte 5 y Cúspide 5. Los catálogos de Horizonte/Cúspide contienen registros de demostración identificados como tales.
- En alcance global: 13 propiedades, 3 clientes y 10 usuarios de empresas en los reportes dinámicos; la columna inmobiliaria identifica su origen.
- Descarga offline autorizada y separada para las tres inmobiliarias.
- Los cinco reportes convencionales devuelven tablas válidas, incluso las consultas sin reservas confirmadas.
- Gemini real responde a la prueba de conexión, configura un reporte dinámico, interpreta propiedades por inmobiliaria y estado, responde al chat y genera una descripción. Las recomendaciones devuelven datos del catálogo. No se publican credenciales ni datos personales de estas comprobaciones.
- El superadministrador SaaS puede ejecutar reportes con IA en cada una de las tres empresas. En Horizonte y Cúspide se verificaron además descripciones con Gemini, recomendaciones y predicciones, conservando sus planes Básico. Las cuentas propias de esas inmobiliarias siguen sujetas a su suscripción.
- El dashboard devuelve 6 predicciones y omite 7 propiedades que no cumplen los criterios del modelo.

Estas comprobaciones no dieron de alta ni modificaron registros de negocio. La cuenta Gemini está configurada en Render; las claves no se envían al teléfono ni al navegador. Si el proveedor falla, están disponibles los reportes convencionales y el generador manual; el modo local de lenguaje natural se usa cuando no hay clave configurada.

## Alcance y límites

**Todas las inmobiliarias** aplica a catálogo, listas, reportes, analítica e IA dentro de las pantallas habituales. Los cambios y operaciones offline requieren seleccionar una empresa. La IA necesita conexión. El superadministrador puede consultar cualquier empresa o todas sin adoptar los límites de sus planes; las cuentas de cada inmobiliaria conservan los límites de su suscripción.

La sesión móvil utiliza el perfil guardado ante fallos de red/servidor; un rechazo de credenciales exige autenticarse otra vez. SQLite conserva las operaciones por API, CI e inmobiliaria. La sincronización valida permisos, suscripción, sucursal, precio, versión y disponibilidad en el servidor.

El modelo ML usa datos sintéticos con semilla 42: 1800 filas; 1350 de entrenamiento y 450 de validación. MAE 19.444,12 USD, R² 0,9659 y silhouette 0,2428 describen ese conjunto, no precisión sobre el mercado. No es una tasación profesional ni un historial de disponibilidad.

La recuperación de contraseña heredada sigue siendo informativa porque no hay SMTP configurado. Los diagramas PlantUML están disponibles como fuentes editables. Las pruebas usan bases aisladas y no reemplazan la comprobación manual del dispositivo o la instalación de la PWA.
