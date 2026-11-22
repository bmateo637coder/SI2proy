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
| CU-27 | Push FCM | Activación web y bandeja | Activación Android y bandeja |
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
- Push utiliza una bandeja persistente y un trabajo periódico que entrega después de confirmar los datos en la base. El registro de prueba diferencia un mensaje guardado de un envío aceptado por FCM.
- La cotización predictiva usa el modelo académico existente cuando hay superficie, habitaciones y segmento compatibles. Si faltan, se informa que no se generó una estimación. No se presenta el precio publicado como una predicción.
- Gemini se utiliza para las funciones generativas cuando está disponible. Las plantillas, respuestas guardadas y filtros locales indican su origen. Los filtros offline son básicos; no sustituyen una interpretación generativa.

## Configuración y validación externa

Gmail y FCM requieren las credenciales del propietario. No se puede acreditar una entrega real hasta configurarlos y probar con un destinatario y dispositivo reales. Ver [CONFIGURAR_FIREBASE_GMAIL.md](CONFIGURAR_FIREBASE_GMAIL.md).

La primera descarga, la administración de suscripciones, la entrega de correos/push y Gemini requieren Internet. El mapa base depende del proveedor cartográfico; el ranking por zonas permanece disponible con los datos descargados.
