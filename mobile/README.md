# Raíces para Android · 2.1.0

Aplicación Flutter conectada a `https://raices-backend-n1yy.onrender.com`.

## Descargar

El workflow **Build APK Release** genera `Raices-2.1.0.apk` y su SHA-256 después del análisis de Dart, las pruebas Flutter, la integración en emulador Android y la verificación de firma. La descarga pública está en [GitHub Releases](https://github.com/bmateo637coder/SI2proy/releases). No requiere introducir una clave de Gemini en el teléfono.

## Superadministrador SaaS

La selección superior **Inmobiliaria activa** aplica a catálogo, clientes, contratos, usuarios, reportes e IA. **Todas las inmobiliarias** consulta el conjunto y etiqueta la empresa de cada registro. Para crear clientes, contratos, descripciones o realizar operaciones offline se selecciona una inmobiliaria concreta.

Los reportes dinámicos permiten elegir entidad, columnas, filtros y orden; guardar y recuperar configuraciones; dictar o escribir una solicitud; y compartir PDF, Excel, CSV y HTML generados en el dispositivo. La sección **IA y analítica**, accesible desde catálogo y perfil, reúne cinco reportes convencionales, consultas en lenguaje natural, gráficos, chat, recomendaciones, generación de descripciones y predicciones académicas. El modelo predictivo usa datos sintéticos y muestra sus limitaciones.

La IA generativa requiere conexión. El superadministrador SaaS puede usarla tanto para todas las empresas como para una inmobiliaria concreta, con independencia de su plan. Las cuentas de cada inmobiliaria conservan los límites de su suscripción. Los reportes convencionales y dinámicos permiten consultar los datos sin depender del proveedor de IA. El dictado requiere permiso del micrófono y un servicio de reconocimiento disponible; siempre se puede escribir la consulta.

## Uso offline

1. Iniciar sesión con conexión y seleccionar una inmobiliaria.
2. Abrir **Offline** y pulsar **Descargar catálogo**. Se guardan propiedades, clientes, sucursales y versiones en SQLite.
3. Sin conexión, abrir Offline para consultar la descarga y registrar reservas o ventas en efectivo para los clientes descargados. Estas operaciones permanecen pendientes hasta la confirmación del servidor.
4. Al recuperar conexión, pulsar **Sincronizar**. También se reintenta al abrir esa pantalla, volver a la app o cada 30 segundos mientras la pantalla está abierta. Si venció la sesión, iniciar sesión otra vez con la misma cuenta y sincronizar desde la inmobiliaria correspondiente.

Las descargas y operaciones quedan separadas por API, usuario e inmobiliaria. Cerrar la app o cerrar sesión conserva las operaciones locales; otra cuenta no las ve. Cambiar de inmobiliaria no traslada las operaciones a otra empresa. Cada operación conserva su UUID durante los reintentos, incluso si el servidor confirmó una venta y se perdió la respuesta. El servidor valida precio, versión, disponibilidad, sucursal y suscripción, y devuelve confirmación o conflicto. Una reserva confirmada se puede cancelar con conexión desde el historial local.

Si una inmobiliaria no tiene clientes registrados, debe registrarse un cliente con conexión antes de descargar y operar. La IA no se ejecuta sin conexión.

## Desarrollo y validación

Requiere Flutter 3.47.4 / Dart 3.13 y Android SDK con Java 17.

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter test integration_test/app_flow_test.dart -d <dispositivo-android>
flutter run --dart-define=API_BASE_URL=https://raices-backend-n1yy.onrender.com
```

Las pruebas cubren identidad global y alcance, persistencia de selección sin red, exportaciones locales, aislamiento de colas por inmobiliaria y reintentos sin duplicación. La integración Android usa el backend controlado de pruebas y SQLite/almacenamiento seguro nativos, sin crear ventas en producción. Verifica inicio de sesión, catálogo global, reportes dinámicos y analíticos, cambio de empresa, reserva sin conexión, reinicio y recuperación, pérdida de confirmación y reintento.

La distribución se firma con un almacén persistente protegido en secretos de GitHub Actions: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. No se debe rotar esa firma para actualizaciones de la misma aplicación. Para compilar una distribución local, se suministran esas credenciales como variables de entorno y `ANDROID_KEYSTORE_PATH` como ruta al almacén; sin ellas, la compilación local utiliza la firma de desarrollo.

GitHub exige permiso de escritura de Workflows para publicar una versión cuyo commit modifica workflows respecto de `main`; el token automático de Actions no ofrece ese permiso. En una rama de trabajo, el workflow conserva el APK firmado como artefacto. Se publica sin recompilar con `python scripts/publish_mobile_release.py ID_EJECUCION`, usando la credencial Git local o una variable `RELEASE_TOKEN`/`GH_TOKEN` autorizada. El script verifica el origen de la ejecución, las pruebas Android, la firma aprobada, el artefacto y su SHA-256; no reemplaza etiquetas ni archivos de una versión diferente. Opcionalmente, un secreto `RELEASE_TOKEN` con los permisos adecuados permite la publicación automática. La credencial Git local no se copia a secretos de Actions.
