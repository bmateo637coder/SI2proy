# Verificación del parcial 2

Fecha local: **30 de octubre de 2026**, America/La_Paz.

## Resultados ejecutados

| Verificación | Resultado |
|---|---|
| API y modelos SQLAlchemy | Importación y mapeos correctos |
| Suite backend con PostgreSQL 15 local aislado | **34 pruebas aprobadas**, incluido arranque de Render y fallo de migración |
| Integración concurrente | Un UUID concurrente produce una venta; dos UUID sobre la misma propiedad producen confirmación y conflicto |
| Atomicidad | Fallo inyectado al guardar un pago revierte contrato, pago, operación y disponibilidad; el reintento confirma correctamente |
| Migración | Repetición sin pérdida de datos; prueba de esquema previo con propiedades conservadas |
| Demostración SaaS | Dos empresas independientes, planes diferentes, usuarios y 18 propiedades por empresa en base temporal |
| Reporte contra PostgreSQL demo | 12 contratos de Raíces Demo agrupados en Casa matriz; total 1.512.000 USD |
| Dashboard contra catálogo demo | 18 predicciones sobre propiedades compatibles de la empresa autenticada |
| Unitarias Angular | **5 pruebas aprobadas** en 3 archivos |
| Playwright / Chromium | **3 pruebas aprobadas**: reinicio offline y separación de cuentas; manifest/iconos; tabla/gráfico y descargas PDF/Excel |
| Flutter / SQLite | **1 prueba aprobada**, con archivo real, cierre/reapertura, respuesta perdida y reintento sin duplicación |
| Análisis Dart de archivos modificados | **Sin problemas** en 8 archivos analizados |
| Compilación web optimizada | Correcta; shell preparado con 22 recursos |

El tamaño inicial web se redujo desde aproximadamente 1,50 MB a 594 kB al cargar el generador de reportes y sus bibliotecas bajo demanda. Persisten avisos CommonJS de bibliotecas de exportación existentes; no impiden compilar. La suite Python conserva advertencias de obsolescencia de dependencias heredadas. El análisis completo móvil inicial detectó advertencias en pantallas anteriores; la verificación final sin problemas corresponde a los archivos modificados enumerados por el comando del análisis.

Comando del análisis final móvil:

```powershell
flutter analyze --no-pub lib/data/services/offline_service.dart lib/presentation/screens/offline_screen.dart lib/presentation/providers/auth_provider.dart lib/data/services/secure_storage_service.dart lib/main.dart lib/app/router.dart lib/data/models/user_model.dart test/offline_service_test.dart
```

## Evaluación ML reproducible

Entrenamiento sintético con semilla 42: 1800 filas, 1350 entrenamiento y 450 validación. RandomForestRegressor: MAE 19.444,12 USD y R² 0,9659. KMeans con tres grupos: silhouette de validación 0,2428. Estas métricas describen el conjunto sintético, no precisión sobre el mercado inmobiliario. Los artefactos se regeneran con `python analitica_ml.py`.

## Evidencia visual

- [Operaciones offline](capturas/offline.png).
- [Reporte, tabla y gráfico](capturas/analitica.png).

Las capturas usan datos controlados de las pruebas de navegador; los reportes del backend se verificaron aparte contra PostgreSQL. No se presentan los datos de las capturas como datos productivos.

## Límites de la validación

Las pruebas automáticas usan bases aisladas y no utilizaron una cuenta externa de IA. El repositorio está actualizado en `feat/parcial2-saas-offline-analitica`; el procedimiento de publicación está en [DESPLIEGUE.md](DESPLIEGUE.md). Quedan por comprobar Gemini con una clave válida, dictado con micrófono real, instalación PWA en dispositivos y compilación/instalación APK. Los archivos PlantUML son editables; no se generaron renders UML en este entorno.

Las semillas de demostración se ejecutaron únicamente en PostgreSQL temporal local. El cluster de prueba se alojó dentro de `.venv/` y se detuvo al terminar; no comparte configuración ni puerto con la base del usuario.

## Actualización del servicio existente en Render

El 30 de octubre de 2026 se ejecutó la migración aditiva en el arranque de producción, conservando la configuración de la base existente. Render confirmó el despliegue `dep-dbietukipgvc73btqos0` como `live`, con el commit de API `94e38fcc080b`, Python 3.12.10 y `python start_render.py`.

- [Despliegue de backend y Pages](https://github.com/bmateo637coder/SI2proy/actions/runs/41115014274): ambos jobs aprobados.
- [Inspección posterior de Render](https://github.com/bmateo637coder/SI2proy/actions/runs/41115713346): rama del parcial 2, mismo servicio, mismo dominio y despliegue activo.
- [CI con controles del despliegue](https://github.com/bmateo637coder/SI2proy/actions/runs/41115376277): 39 pruebas backend, además de las suites web y móvil.
- `GET /api/health`: versión `2.0.0`, commit esperado y funciones `saas`, `offline`, `analitica`.
- `GET /openapi.json`: 55 rutas, incluidas `/api/offline/sincronizar` y `/api/saas/suscripcion`.

Las verificaciones públicas no registraron ventas, reservas ni usuarios de prueba en producción. La clave de Render permanece en GitHub Actions; no se incorpora al frontend. Render no tiene `GEMINI_API_KEY`, por lo que los reportes usan el intérprete local indicado en cada resultado.
