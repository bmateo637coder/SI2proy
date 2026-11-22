# Revisión para presentación final

Revisión del 22 de noviembre de 2026 sobre la rama `feat/sprint4-integracion-web-movil`. Complementa la [matriz de funciones nativas](PARIDAD_MOVIL_3_1.md) y la [configuración de servicios externos](CONFIGURAR_FIREBASE_GMAIL.md).

## Correcciones

| Área | Problema corregido | Resultado |
| --- | --- | --- |
| Mapa Android de propiedades | Coordenadas inventadas para inmuebles sin ubicación, centrado automático en el teléfono, fichas que podían desbordarse | Solo coordenadas válidas; encuadre de toda la cartera seleccionada, zoom y fichas desplazables; acceso desde Catálogo y Centro de trabajo; sin pedir GPS para consultar propiedades |
| Mapa Android de ventas | Se centraba únicamente en la primera zona y carecía de controles y detalle | Encuadre de todas las zonas, intensidad con radios en metros, leyenda, consulta por zona y pantalla ampliada |
| Web en teléfonos | El menú lateral restaba espacio al contenido y ocultaba partes del análisis | Menú desplegable, selector de inmobiliaria adaptable, mapas y dashboard en una columna, tarjetas y filtros sin desbordamiento horizontal |
| Catálogo web | Errores solo en consola, respuestas antiguas al cambiar filtros y rangos inválidos | Carga y errores visibles, cancelación de consultas anteriores y validación de precio/superficie |
| Fichas recomendadas | Podían perder los detalles completos después de filtrar | Conservación de los datos consultados, descripción visible, ficha adaptable y cierre con Escape |
| Análisis de zonas web | Resumen IA anterior permanecía al cambiar de métrica; coordenadas inválidas podían romper el dibujo | Cancelación de solicitudes anteriores, limpieza del resumen y validación de coordenadas; encuadre y ajuste al cambiar tamaño |
| Servicios Android | Una respuesta demorada podía mostrarse bajo otra sección | Cada carga comprueba que sigue correspondiendo a la sección actual; los cambios en curso bloquean navegación incompatible |
| Clientes, contratos y pagos Android | Una respuesta de la empresa anterior podía modificar el estado de la nueva | Separación entre solicitudes y alcance; descarte de confirmaciones antiguas y de respuestas tras cerrar el proveedor |
| Copia de datos móvil | La serialización de propiedades omitía descripción, coordenadas y características | Conservación de esos campos y de la inmobiliaria al serializar; los clientes conservan también su inmobiliaria |
| Datos de demostración | El catálogo de Horizonte y Cúspide carecía de inmuebles disponibles con coordenadas | Se añadieron seis propiedades ficticias con coordenadas aproximadas, tres por empresa, sin modificar las 31 propiedades existentes |

## Datos comprobados por API

La revisión incluye también [predicción temporal de ventas/demanda y conversión multimoneda](PREDICCIONES_MONEDA.md), con pantallas web y nativas, consulta offline de la última descarga, pruebas de alcance y aritmética decimal.

La consulta administrativa y los reportes incluyen inmuebles de todos los estados. El catálogo público muestra los disponibles; por eso sus cantidades son diferentes.

| Alcance | Cartera / reporte | Catálogo disponible | Disponibles ubicados | Clientes | Contratos | Incidencias |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Raíces | 11 | 6 | 3 | 6 | 6 | 4 |
| Horizonte | 13 | 8 | 3 | 3 | 5 | 4 |
| Cúspide | 13 | 8 | 3 | 3 | 5 | 4 |
| Todas | 37 | 22 | 9 | 12 | 16 | 12 |

Los registros nuevos llevan `[DEMO S4]`, dirección ficticia y descripción de demostración. Las coordenadas son aproximadas e ilustrativas. Los inmuebles heredados sin coordenadas continúan en el catálogo y se informa que no aparecen en el mapa. Se guardó un respaldo privado antes de la carga y se compararon las huellas de los registros anteriores. No se restauró ni reinició producción.

## Recorrido de presentación

1. Entrar con una cuenta autorizada, esperar la descarga inicial y seleccionar **Todas las inmobiliarias**. Mostrar el catálogo, las empresas y los reportes consolidados.
2. En Android abrir **Mapa de propiedades** desde Catálogo, usar **Ver todas las ubicaciones**, tocar un inmueble y abrir su ficha. Cambiar de empresa para comprobar el alcance.
3. Abrir **Mapa de ventas**, cambiar entre cierres, monto y precio por m²; ampliar el mapa y tocar una zona. Abrir Gerencia para comparar cartera, ingresos y mantenimiento.
4. Generar un reporte dinámico y exportarlo. Mostrar búsqueda natural, recomendaciones y feedback; distinguir los cálculos locales de la generación externa.
5. Preparar la copia local con Internet, desconectar y volver a entrar con la misma cuenta. Consultar catálogo y reportes; registrar una operación autorizada. Reconectar, sincronizar y revisar el resultado o el conflicto sin repetir el registro.
6. Abrir **Predicción de ventas y demanda**. Mostrar el historial real y, si resulta insuficiente, cambiar al escenario académico identificado. Comparar los errores del modelo y exportar la proyección. Abrir **Conversión multimoneda**, convertir un monto, invertir el par y comprobar la fuente y fecha; probar la última descarga sin conexión.

## Evidencia de la revisión

Código verificado y desplegado: `6ba6e97e371db766262b1dab3f437ff5f79f1771`.

- [Pruebas de backend, web y Flutter](https://github.com/bmateo637coder/SI2proy/actions/runs/45082253509): 94 pruebas de backend, 12 unitarias web, 16 flujos de navegador y 28 pruebas Flutter; construcción web aprobada.
- [Análisis Dart e integración Android](https://github.com/bmateo637coder/SI2proy/actions/runs/45082263962/job/137392838541): tres flujos nativos con servidor controlado de pruebas, SQLite y almacenamiento seguro. El recorrido abre los mapas, las fichas y ambos módulos nuevos desde el centro de trabajo, y conserva las pruebas de reportes, alcance, reinicio offline y conflictos.
- [Despliegue de API y web](https://github.com/bmateo637coder/SI2proy/actions/runs/45082481780). Se comprobó la salud de la API con el commit indicado y se recorrió el sitio publicado con una cuenta autorizada: catálogo global, mapa, dashboard, reporte de 37 filas, descargas PDF/Excel, reporte por lenguaje natural, tasas del proveedor y predicciones. También se comprobó la consulta/exportación del pronóstico descargado sin Internet. Sin excepciones JavaScript en esos recorridos.
- Capturas: [mapa en escritorio](capturas/final-mapa-escritorio.png), [mapa en teléfono](capturas/final-mapa-telefono.png), [predicciones](capturas/final-predicciones.png), [multimoneda](capturas/final-moneda.png).

Se guardó fuera de Git un respaldo posterior a la carga de los seis inmuebles: 2.409.244 bytes, SHA-256 `ae78c7fc6124c05569bc97fe8656f6cf39a6af019469edc28eb95dd7af3fd2bc`. Contiene datos privados y no forma parte de la publicación.

## Límites que se mantienen

- Las teselas del mapa base necesitan conexión; los datos descargados, coordenadas y fichas locales se conservan. No se ofrece una descarga completa de cartografía offline.
- Gemini y Gmail dependen de conexión y credenciales válidas. Las herramientas locales se identifican como tales. No se confirma envío SMTP si la cuenta no está configurada.
- Los avisos Android sin Firebase consultan periódicamente la bandeja. Android puede retrasarlos; no equivalen a entrega FCM inmediata. La integración FCM específica sigue necesitando la configuración del propietario.
- Las operaciones administrativas que requieren servidor, como cambiar roles, empresas o restaurar SQL, conservan ese requisito. La copia local y las operaciones admitidas se detallan en la matriz de paridad.
- La base gratuita recuperada vence el 22 de diciembre de 2026. Esa fecha corresponde a la base de datos, no a GitHub Pages. Debe migrarse o renovarse antes de vencer para mantener el acceso a datos.

## Descarga Android 3.2.0

[Descargar Raíces 3.2.0](https://github.com/bmateo637coder/SI2proy/releases/download/mobile-3.2.0-33/Raices-3.2.0.apk) · [Versión y checksum](https://github.com/bmateo637coder/SI2proy/releases/tag/mobile-3.2.0-33).

- Código: `6ba6e97e371db766262b1dab3f437ff5f79f1771`; incluye las correcciones de mapas y los módulos nuevos.
- Paquete: `com.inmobiliaria.inmobiliaria_mobile`; versión `3.2.0`; compilación `2533`; Android mínimo 7.0 (API 24).
- Tamaño del APK: 63.695.522 bytes.
- SHA-256: `4d339e927a42873a1af6ff4b05b7fb86be2577a4505f5c2a4b5572f34581c3b0`.
- Certificado de firma SHA-256: `bf728aa48472f871efb796107ebeb25e3c4484a843232952bb915bf12953ecd2`, igual a la versión anterior. Se verificó también con `apksigner` local.

Instalar encima de la versión anterior, sin borrar los datos. Abrir con Internet para descargar las funciones y datos nuevos antes de probar el modo offline. El archivo publicado procede del artefacto firmado de la misma ejecución que aprobó las pruebas nativas; no se recompila para cargarlo a la versión pública.
