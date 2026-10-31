# Correcciones de acceso, reportes e IA

La API de producción conserva los datos de Raíces Inmobiliaria. Se comprobó mediante
una sesión autenticada que contiene 3 propiedades, 3 clientes, 1 agente y 1 propietario.
Las otras dos empresas estaban vacías al realizar el diagnóstico.
Posteriormente se agregaron cinco propiedades de demostración a Horizonte y cinco
a Cúspide, con fotografías ilustrativas y descripciones que identifican los datos
ficticios.

## Uso como superadministrador

1. Iniciar sesión y seleccionar la inmobiliaria en la barra superior.
2. Abrir Clientes, Propiedades, Contratos y Pagos o Reportes y analítica.
3. Para probar los datos existentes, seleccionar Raíces Inmobiliaria.

La opción **Todas las inmobiliarias** es un alcance de consulta compartido por las
pantallas existentes. No cambia la ruta: el catálogo muestra las propiedades de
todas las empresas; Propiedades, Clientes, Propietarios, Agentes, Contratos, Usuarios
y Sucursales muestran sus registros con la inmobiliaria de origen. Los filtros de
cada pantalla se aplican sobre el conjunto seleccionado.

La selección se conserva al recargar y viaja como `X-Tenant-Scope: all`, nunca como
un ID de empresa. El servidor solo permite ese alcance al superadministrador.
Las escrituras comerciales requieren una empresa concreta y se rechazan antes de
modificar datos si se intenta realizarlas con alcance global. Las credenciales del
usuario permanecen sin cambios. La vista `/admin/vista-global` sigue disponible
como resumen opcional, sin redirigir el catálogo ni los reportes.

Los reportes dinámicos incluyen automáticamente la columna `inmobiliaria` en la
tabla y en PDF, Excel, CSV y HTML. Los reportes convencionales y generativos
conservan los grupos separados por inmobiliaria, y la analítica identifica la
empresa de cada predicción. El superadministrador puede consultar la plataforma
completa; las cuentas de empresa conservan los permisos de su suscripción.
El modo offline, el guardado de configuraciones y las operaciones de escritura
requieren una inmobiliaria concreta para evitar asignaciones ambiguas.

La selección viaja como `X-Tenant-ID`. El servidor valida la empresa y crea un
contexto temporal por petición; no modifica el usuario ni sus credenciales. Una cuenta
de inmobiliaria no puede usar este encabezado para acceder a otra empresa. El cambio
de empresa reinicia formularios y cachés; las operaciones offline permanecen separadas
por empresa y usuario. Un 401 cierra la sesión y explica que hay que autenticarse de nuevo.

## Reportes

Los reportes dinámicos validan columnas, operadores y valores antes de consultar.
Incluyen propiedades, usuarios y clientes registrados; los clientes no se confunden
con todos los usuarios. El límite predeterminado es 500 registros, con un aviso si el
resultado se recorta. Los reportes guardados se separan por usuario y empresa.

CSV protege textos que podrían interpretarse como fórmulas. HTML escapa los valores
de la base de datos. PDF conserva ceros y Excel exporta los resultados de la consulta.
Los reportes agregados admiten filtros manuales y lenguaje natural.

## Gemini

Guardar `GEMINI_API_KEY` en **Render → raices-backend → Environment**. Si el nombre
ya existe, editar su valor; no crear otra fila. La variable solo se activa después
de desplegar. No se guarda en GitHub Pages ni en el código del frontend.

El modelo predeterminado es `gemini-3.5-flash-lite`, configurable mediante
`GEMINI_MODEL`. Google limita el acceso de proyectos nuevos a los modelos 2.5;
consultar su [documentación de modelos](https://ai.google.dev/gemini-api/docs/deprecations).
En Reportes y analítica, **Comprobar conexión con Gemini** realiza una petición real.
La suscripción seleccionada debe estar activa y habilitar el plan Profesional.

Los errores de clave, permisos, modelo o cuota se muestran sin revelar secretos.
Las descripciones y los reportes de voz no simulan respuestas de Gemini. El chat
identifica expresamente su ayuda local cuando no hay clave. El intérprete local de
reportes agregados sigue identificado como `reglas_locales`.

## Aprendizaje automático

El modelo académico sigue entrenándose con datos sintéticos, con esa limitación
visible en el dashboard. En Propiedades se pueden editar superficie, habitaciones y
segmento de zona. Los registros sin esos datos se omiten; no se inventan valores para
forzar predicciones. Se reconocen nombres anteriores como Cuartos, Metros Cuadrados,
Superficie y Dormitorios. Las predicciones se calculan en lote.

## Regresiones cubiertas

- Cambio de contraseña en la ruta correcta y persistencia para el superadministrador.
- Registro de agentes por empresa y eliminación protegida cuando existe historial.
- Agentes y propietarios respetan la inmobiliaria seleccionada en la navegación.
- Superadministrador con empresa elegida, contexto sin persistencia y aislamiento.
- Sesión vencida con redirección y aviso; cambio de empresa sin datos anteriores.
- Filtros inválidos, columnas sensibles, listado real de clientes y reportes guardados.
- Fallos de Gemini sin secretos, configuración de IA validada y fechas inválidas.
- Edición sin perder descripciones, características analíticas y atributos numéricos vacíos.
- Generación de reportes y descargas PDF/Excel desde el navegador.

Los tests usan bases aisladas. No modifican los datos de producción ni regeneran semillas.

La recuperación automática por correo requiere configurar un proveedor de correo.
La pantalla informa esta limitación y remite al administrador, sin afirmar que se
envió un mensaje que el sistema todavía no puede enviar.
