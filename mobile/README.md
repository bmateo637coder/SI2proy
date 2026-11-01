# Raíces para Android · 2.2.0

Aplicación Flutter conectada a `https://raices-backend-n1yy.onrender.com`.

## Descargar

El workflow **Build APK Release** genera `Raices-2.2.0.apk` y su SHA-256 después del análisis de Dart, las pruebas Flutter, la integración en emulador Android y la verificación de firma. La descarga pública está en [GitHub Releases](https://github.com/bmateo637coder/SI2proy/releases). No requiere introducir una clave de Gemini en el teléfono.

## Superadministrador SaaS

La selección superior **Inmobiliaria activa** aplica a catálogo, clientes, contratos, usuarios, reportes e IA. **Todas las inmobiliarias** consulta el conjunto y etiqueta la empresa de cada registro. Para crear clientes, contratos, descripciones o realizar operaciones offline se selecciona una inmobiliaria concreta.

Los reportes dinámicos permiten elegir entidad, columnas, filtros y orden; guardar y recuperar configuraciones; dictar o escribir una solicitud; y compartir PDF, Excel, CSV y HTML generados en el dispositivo. La sección **IA y analítica**, accesible desde catálogo y perfil, reúne cinco reportes convencionales, consultas en lenguaje natural, gráficos, chat, recomendaciones, generación de descripciones y predicciones académicas. El modelo predictivo usa datos sintéticos y muestra sus limitaciones.

La IA generativa requiere conexión. El superadministrador SaaS puede usarla tanto para todas las empresas como para una inmobiliaria concreta, con independencia de su plan. Las cuentas de cada inmobiliaria conservan los límites de su suscripción. Los reportes convencionales y dinámicos permiten consultar los datos sin depender del proveedor de IA. El dictado requiere permiso del micrófono y un servicio de reconocimiento disponible; siempre se puede escribir la consulta.

## Uso offline

1. Iniciar sesión una vez con Internet. La app descarga automáticamente la información autorizada: propiedades completas, clientes, contratos, cuotas, pagos, usuarios sin contraseñas, sucursales y reportes guardados. El superadministrador descarga todas sus inmobiliarias. Las fotos se preparan en segundo plano y su estado se muestra en Sincronización.
2. Después, sin Internet, usar las pantallas habituales de Catálogo, Clientes, Contratos, Reportes e IA y analítica. También se puede cerrar sesión y volver a entrar con la cuenta y contraseña previamente verificadas en ese teléfono. El primer acceso de una cuenta nueva requiere conexión.
3. Crear clientes a partir de los usuarios descargados, contratos, pagos, configuraciones de reportes, reservas y ventas en efectivo. Los cambios se conservan en SQLite, aparecen en las consultas locales y se identifican como pendientes. Los recibos locales son provisionales hasta que el servidor confirme el pago.
4. Al restablecerse Internet, la app sincroniza al abrirse, volver a primer plano y cada 15 segundos mientras está abierta. La copia completa se renueva aproximadamente cada minuto. Si venció la sesión, usar **Validar sesión para sincronizar**; los datos y propuestas permanecen guardados.
5. Pulsar el indicador superior para abrir **Sincronización**: última copia, fotos, pendientes, confirmaciones y conflictos. Se muestran la propuesta y los datos actuales del servidor. Se puede conservar el servidor descartando la propuesta, o revisar y registrar un cambio nuevo. Nunca se fuerzan sobrescrituras de datos que cambiaron en otro dispositivo.

Los reportes dinámicos y los cinco reportes convencionales se calculan y exportan en el teléfono; funcionan para una o todas las inmobiliarias e incluyen los movimientos locales pendientes con esa advertencia. Las reservas confirmadas y las pendientes se distinguen en columnas separadas. Las configuraciones guardadas también se sincronizan.

Las herramientas locales de texto interpretan solicitudes de cartera, ventas, ingresos, agentes y reservas. El chat local informa sobre la copia descargada, las descripciones usan plantillas y las recomendaciones usan el catálogo local. Se identifican como herramientas locales: Gemini, la prueba real del proveedor y el entrenamiento de modelos requieren Internet. Las predicciones descargadas pueden consultarse como resultados anteriores. El reconocimiento de voz depende de que el teléfono tenga un servicio de dictado disponible sin red; siempre se puede escribir.

Las descargas y colas se separan por API, cuenta, permisos e inmobiliaria. Cerrar la app o cerrar sesión conserva propuestas, pero otra cuenta no puede consultarlas. La contraseña no se guarda: el acceso local usa un verificador PBKDF2 con sal aleatoria en almacenamiento seguro, con límite de intentos. Antes de subir cambios se verifica la identidad y autorización actuales del servidor. El respaldo automático de Android está desactivado para los datos privados.

Cada cambio conserva su UUID y contenido durante los reintentos. El servidor registra el resultado en la misma transacción que la operación, detecta cambios de precio, disponibilidad, datos del contrato y pagos; resuelve los identificadores temporales de registros creados offline y evita duplicados aunque se pierda una respuesta. Una cancelación de reserva se puede solicitar sin conexión: la propiedad se libera cuando el servidor confirme el plazo y que no existen movimientos posteriores.

La copia local representa la última descarga completa más las propuestas de este teléfono; no puede conocer cambios de otros dispositivos mientras no haya conexión. El mapa base, el registro inicial de cuentas, los cambios de contraseña y los servicios externos requieren Internet. Las propuestas comerciales solo son definitivas después de sincronizar.

## Desarrollo y validación

Requiere Flutter 3.47.4 / Dart 3.13 y Android SDK con Java 17.

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter test integration_test -d <dispositivo-android>
flutter run --dart-define=API_BASE_URL=https://raices-backend-n1yy.onrender.com
```

Las pruebas cubren identidad global y alcance, persistencia de selección sin red, exportaciones locales, aislamiento de colas por inmobiliaria y reintentos sin duplicación. La integración Android usa el backend controlado de pruebas y SQLite/almacenamiento seguro nativos, sin crear ventas en producción. Verifica inicio de sesión, catálogo global, reportes dinámicos y analíticos, cambio de empresa, reserva sin conexión, reinicio y recuperación, pérdida de confirmación y reintento.

La distribución se firma con un almacén persistente protegido en secretos de GitHub Actions: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. No se debe rotar esa firma para actualizaciones de la misma aplicación. Para compilar una distribución local, se suministran esas credenciales como variables de entorno y `ANDROID_KEYSTORE_PATH` como ruta al almacén; sin ellas, la compilación local utiliza la firma de desarrollo.

GitHub exige permiso de escritura de Workflows para publicar una versión cuyo commit modifica workflows respecto de `main`; el token automático de Actions no ofrece ese permiso. En una rama de trabajo, el workflow conserva el APK firmado como artefacto. Se publica sin recompilar con `python scripts/publish_mobile_release.py ID_EJECUCION`, usando la credencial Git local o una variable `RELEASE_TOKEN`/`GH_TOKEN` autorizada. El script verifica el origen de la ejecución, las pruebas Android, la firma aprobada, el artefacto y su SHA-256; no reemplaza etiquetas ni archivos de una versión diferente. Opcionalmente, un secreto `RELEASE_TOKEN` con los permisos adecuados permite la publicación automática. La credencial Git local no se copia a secretos de Actions.

Si la carga local es lenta, usar `--prepare-only` para obtener el ID del borrador. Ejecutar **Build APK Release** con `artifact_run=ID_EJECUCION_ORIGINAL` y `release_id=ID_BORRADOR`: GitHub carga el mismo artefacto verificado sin recompilar. Después, repetir el comando local con `--release-id ID_BORRADOR` para publicar; las cargas existentes se verifican y se conservan.
