# Predicciones y conversión multimoneda

Las dos funciones tienen pantalla web y pantalla nativa Android. En web se abren desde el menú lateral; en Android, desde **Todo → Centro de trabajo**, buscando **predicción** o **multimoneda**. Conservan las funciones anteriores de precios académicos, reportes e IA.

## Predicción de ventas y demanda

- Web: `/dashboard/predicciones`. Android: `/predicciones`. API: `GET /api/predicciones`.
- El selector SaaS aplica a una empresa o a todas. Las cuentas de inmobiliaria conservan sus permisos y el requisito de plan con analítica; la cuenta SaaS puede auditar cualquier empresa.
- Ventas: cantidad mensual de contratos de venta según fecha de inicio. Demanda: visitas no canceladas según fecha programada. Esta última es un indicador de interés, no una medición de toda la demanda del mercado.
- Se usan hasta 24 meses completos; se excluyen el mes en curso y las fechas futuras. El horizonte visible puede ser de 1, 3 o 6 meses.
- El modelo supervisado **Ridge** usa tendencia, estacionalidad mensual y el valor anterior. La validación temporal vuelve a entrenar solo con los meses anteriores a cada mes evaluado. Se compara su MAE con un promedio móvil de tres meses; se usa el método con menor error. La pantalla muestra ambos errores y el método elegido.
- Si una serie no tiene al menos seis meses y seis eventos, se informa **Historial insuficiente**. No se generan ventas ficticias como si fueran datos de la empresa.
- **Escenario académico de demostración** entrena sobre 24 meses sintéticos reproducibles, claramente identificados y separados de las transacciones. No agrega contratos ni visitas a la base.
- Se puede consultar el historial y exportar la proyección CSV. Sin red se consulta el último cálculo descargado para ese usuario y alcance; actualizar el entrenamiento requiere conexión.

La serie real de la base de presentación puede ser insuficiente aunque tenga numerosos contratos recientes: cantidad de contratos y cantidad de meses de historia son requisitos distintos. Para mostrar el flujo completo del modelo, seleccionar el escenario académico.

## Conversión multimoneda y tipo de cambio

- Web: `/dashboard/moneda`. Android: `/moneda`. API: `GET /api/moneda` y `POST /api/moneda/convertir`.
- Monedas: USD, BOB, EUR, BRL, CLP y PEN. Permite conversión directa, inversa y entre dos monedas distintas de USD.
- Se utiliza el acceso abierto de [ExchangeRate-API](https://www.exchangerate-api.com/docs/free), con atribución visible, actualización diaria y sin otra clave. Las tasas se guardan en PostgreSQL y en la copia local autorizada de cada cliente.
- Se muestran la fuente, fecha de actualización y estado vencido. Si el proveedor falla, se conserva la última tasa con su fecha; si nunca se descargó, se muestra el error. No se inventa una tasa de emergencia. Los reintentos al proveedor tienen espera para evitar saturarlo.
- El usuario también puede ingresar una tasa manual para el par seleccionado. Se identifica como manual y se descarta al invertir o cambiar monedas; no altera la referencia de otros usuarios.
- La conversión utiliza aritmética decimal o enteros de precisión arbitraria y redondeo a dos decimales. No se usa coma flotante binaria para calcular el importe final.
- Sin conexión se puede convertir con la última descarga o con una tasa manual. Las tasas son indicativas del proveedor, no una cotización oficial del BCB ni una promesa de precio de una entidad financiera.
- **Los precios, contratos y pagos existentes permanecen expresados en USD.** El conversor no modifica saldos ni registra pagos en otra moneda.

La tabla `tipo_cambio_snapshot` se agrega mediante la migración idempotente existente. No se elimina ni se reinicia ninguna tabla anterior.

## Verificación

Las pruebas nuevas comprueban aislamiento entre inmobiliarias, exclusión del mes incompleto, historial insuficiente, reproducción del escenario académico, validación temporal, conversiones cruzadas y redondeo, rechazo de importes inválidos, caché persistente, fallo del proveedor y tasas vencidas. Los flujos de navegador comprueban la conversión offline en teléfono, la selección de demostración y la descarga CSV. Las pruebas Flutter comprueban ambas pantallas y el cambio de monedas en una pantalla estrecha; el flujo Android las abre desde el centro de trabajo.
