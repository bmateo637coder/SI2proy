# Avisos automáticos y configuración opcional de Gmail/Firebase

## Activar avisos sin crear cuentas

- **Web:** Servicios → Notificaciones → Activar en este navegador. Acepta el permiso. El backend genera y conserva sus claves VAPID cifradas en la base; no necesitas Firebase ni variables nuevas.
- **Android:** Servicios → Notificaciones → Activar avisos. Acepta el permiso. La app consulta la bandeja en primer plano y programa una tarea nativa cada 15 minutos aproximadamente en segundo plano. Android puede retrasarla por ahorro de batería; forzar la detención desde Ajustes la suspende hasta volver a abrir la app. Esta alternativa es consulta periódica, no entrega FCM inmediata.
- Pulsa **Enviar prueba** y comprueba que aparece en las notificaciones del sistema. Cerrar sesión cancela los avisos del teléfono y la suscripción del navegador.
- Cada dispositivo Android obtiene una credencial revocable que solo permite leer la bandeja propia, con caducidad de 90 días y renovación al activar/reabrir la app con sesión en línea. Se guarda cifrada mediante Android Keystore.
- La bandeja de la aplicación se conserva aunque se rechace el permiso o no haya Internet. La entrega de mensajes nuevos requiere conexión y que el backend está activo.

Firebase queda como integración opcional para entrega FCM en Android. La sección siguiente sirve si el docente exige demostrar específicamente FCM. Gmail sí requiere una cuenta emisora y su contraseña de aplicación.


Estas variables se guardan en Render → servicio de backend → **Environment**. No se agregan a GitHub ni a los archivos públicos. La aplicación muestra qué integraciones faltan sin afirmar que se envió un mensaje.

## Gmail

1. Abre tu cuenta de Google y activa la verificación en dos pasos.
2. Crea una contraseña de aplicación en https://myaccount.google.com/apppasswords.
3. Configura en Render:

| Variable | Valor |
|---|---|
| `SMTP_HOST` | `smtp.gmail.com` |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | Tu dirección Gmail completa |
| `SMTP_PASSWORD` | Contraseña de aplicación de Google |

4. Guarda y despliega. En web o móvil abre Servicios → Mi estado de cuenta, selecciona un pago existente y pulsa enviar comprobante. El destinatario es el cliente del contrato, no una dirección arbitraria.
5. Comprueba que el correo llegó con el PDF adjunto. Sin configuración la API devuelve 503 con instrucciones; si Gmail rechaza el envío devuelve 502.

Documentación: https://support.google.com/accounts/answer/185833.

## Firebase

1. Crea un proyecto en https://console.firebase.google.com/.
2. En Configuración del proyecto → General, registra una aplicación **Web**. Copia su objeto de configuración como JSON válido en `FIREBASE_WEB_CONFIG`.
3. En Cloud Messaging → Configuración web → Certificados de Web Push, genera un par de claves. Guarda la clave pública como `FIREBASE_VAPID_KEY`.
4. Registra una aplicación **Android** con paquete `com.inmobiliaria.inmobiliaria_mobile`. Descarga `google-services.json`.
5. Crea `FIREBASE_ANDROID_CONFIG` con estos valores públicos del archivo:

```json
{
  "apiKey": "client[0].api_key[0].current_key",
  "appId": "client[0].client_info.mobilesdk_app_id",
  "messagingSenderId": "project_info.project_number",
  "projectId": "project_info.project_id",
  "storageBucket": "project_info.storage_bucket"
}
```

Los textos anteriores indican de dónde copiar los valores reales; no son valores de configuración utilizables. Si el archivo tiene varios clientes, usa el del paquete de esta app. Android inicializa Firebase con estas opciones obtenidas del backend y no necesita incorporar una clave privada en el APK.

6. En Configuración del proyecto → Cuentas de servicio, genera la clave privada del SDK Admin. Guarda el **contenido JSON completo** como `FIREBASE_SERVICE_ACCOUNT_JSON` en Render. No la pegues en el chat ni la incluyas en el repositorio. Esta clave solo pertenece al backend.
7. Verifica que Cloud Messaging API HTTP v1 está habilitada en el proyecto. Guarda y despliega las variables.
8. Instala la versión Android actualizada. Inicia sesión y abre Servicios → Notificaciones → Activar push. Autoriza el permiso del sistema. En web, activa push desde Servicios y autoriza el navegador.
9. Pulsa Enviar prueba. Comprueba la recepción con la app en primer plano y en segundo plano. Una prueba visible solo en la bandeja no acredita un push real.

La configuración web y Android debe corresponder al mismo proyecto que la cuenta de servicio. `GET /api/notificaciones/config` devuelve únicamente opciones públicas y estados; nunca la clave del SDK Admin ni la contraseña SMTP.

Documentación oficial:

- https://firebase.google.com/docs/cloud-messaging/flutter/get-started
- https://firebase.google.com/docs/cloud-messaging/web/get-started

## Entrega y reintentos

Las notificaciones se guardan primero en la base. El backend intenta entregar las pendientes cada 30 segundos y limita los intentos fallidos. Sin Firebase o sin un dispositivo registrado conserva la bandeja. Los tokens se asocian a la cuenta activa del dispositivo; cerrar sesión intenta retirarlos. No se requieren variables Firebase al compilar el APK.
