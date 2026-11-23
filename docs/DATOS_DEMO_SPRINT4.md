# Datos de demostración cargados el 22 de noviembre de 2026

La carga se ejecutó sobre la API de producción a solicitud del propietario. Los registros nuevos usan `[DEMO S4]`, cuentas ficticias `@example.com` y CI con prefijo `S4D`. Las imágenes son ilustrativas y las coordenadas aproximadas; no representan ofertas ni daños reales.

## Datos disponibles

| Inmobiliaria | Propiedades | Clientes | Contratos | Incidencias | Visitas | Ventas en mapa |
|---|---:|---:|---:|---:|---:|---:|
| Raíces | 11 | 6 | 6 | 4 | 2 | 3 |
| Horizonte | 13 | 3 | 5 | 4 | 2 | 3 |
| Cúspide | 13 | 3 | 5 | 4 | 2 | 3 |
| Total | 37 | 12 | 16 | 12 | 6 | 9 |

Se conservan las 13 propiedades anteriores. La carga inicial agregó 18 propiedades, 9 clientes y 15 contratos. La revisión final agregó seis inmuebles ficticios disponibles y geolocalizados, tres en Horizonte y tres en Cúspide, conservando las 31 propiedades existentes. No se modificaron planes ni suscripciones. El alcance de catálogos y mapas está documentado en [REVISION_FINAL.md](REVISION_FINAL.md).

También hay:

- 13 pagos en total, con escenarios pagados, parciales y con cuotas pendientes/vencidas; 16 comisiones, tres de ellas liquidadas.
- 3 promociones vigentes y 6 configuraciones de reportes, dos por inmobiliaria.
- 12 incidencias en estados Asignada, En progreso, Resuelta y Cerrada, con responsable y contratista ficticios; 12 fotos ilustrativas y 24 costos. Costo de mantenimiento total: 4.170.
- 12 favoritos, 12 valoraciones de recomendaciones y 5 alertas de búsqueda entre el superadministrador y las cuentas ficticias. Las preferencias personales de otras cuentas se conservaron.
- 80 notificaciones persistidas al generar la copia de seguridad: alertas, visitas, mantenimiento y comisiones. Esta cifra es una instantánea y puede crecer con nuevas acciones.

Las tres ventas por empresa tienen coordenadas y se distribuyen en dos zonas de demostración para comparar volumen y monto en el mapa. Los registros ficticios participan en los indicadores y reportes del sistema.

## Verificación y respaldo

Se comprobaron por API el catálogo y el dashboard de cada inmobiliaria, el catálogo global de 31 propiedades, las nueve ventas del mapa y la exportación PDF ejecutiva. Las huellas de las propiedades anteriores coincidieron antes y después de la carga.

Se descargó una copia PostgreSQL completa a `backend/.venv/backup_despues_demo_20261122.sql`, fuera de Git. Se verificaron sus conteos en 14 tablas. Tamaño: 2.001.490 bytes; SHA-256 `e13a6b91635c89a1bccffeed3abc2fbb61fbea2b0e8c927841d1c65c42170818`. Contiene datos y hashes privados y no se publicó en el repositorio.

La base gratuita de Render vence el **22 de diciembre de 2026**. Esa fecha corresponde a PostgreSQL, no a la publicación de archivos de GitHub Pages. La web puede seguir abriendo después del vencimiento, pero necesita una base activa para sus funciones online.

## Volver a ejecutar la carga

El script [populate_sprint4_demo.py](../scripts/populate_sprint4_demo.py) utiliza los endpoints habituales y conserva las validaciones, auditoría y notificaciones. Busca sus propios registros antes de crearlos y no borra datos anteriores. Las cuentas ficticias usan contraseñas aleatorias conservadas en el archivo privado de estado; no se restablecen contraseñas durante un reintento.

Requiere `DEMO_ADMIN_EMAIL` y `DEMO_ADMIN_PASSWORD` en el entorno del proceso. No poner sus valores en el repositorio ni en comandos públicos. Vista previa:

```sh
python scripts/populate_sprint4_demo.py --api-url https://raices-backend-n1yy.onrender.com --state-file backend/.venv/demo-sprint4-state.json
```

Agregar `--apply` ejecuta la carga. Conservar el archivo privado de estado para reintentos; no compartirlo ni subirlo a Git. No ejecutar esta carga automáticamente al desplegar o iniciar el backend.

Los datos ya están disponibles en web y Android. Para consultar la nueva copia offline, abrir la app con Internet y sincronizar; no hace falta reinstalar el APK.
