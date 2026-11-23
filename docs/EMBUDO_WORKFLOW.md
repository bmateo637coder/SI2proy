# Embudo comercial y workflow inteligente

Web: `/dashboard/oportunidades` y `/dashboard/workflow-ia`. Flutter: centro de trabajo, buscar «Kanban» o «workflow».

El embudo permite crear, editar y archivar oportunidades con contacto, cliente, inmueble, agente responsable, importe USD, probabilidad, próximo contacto y notas. Las etapas son Nuevo, Contactado, Visita, Negociacion, Ganado y Perdido. Web permite arrastrar tarjetas y ambas plataformas ofrecen un selector accesible de etapa. Ganado fija la probabilidad en 100%; Perdido en 0%. Los totales abierto y ponderado excluyen cierres. El cierre comercial no crea un contrato, un pago ni una venta contable.

El workflow recibe una consulta y una oportunidad opcional, clasifica categoría y urgencia y crea tres tareas con fechas de seguimiento. Gemini se utiliza si está configurado; en caso de fallo se aplican reglas locales identificadas. Un operador revisa, completa o reabre las tareas. Se conservan usuario, fecha e historial. Crear planes respeta el permiso IA de la suscripción; SaaS conserva su acceso global.

Una o todas las inmobiliarias: lectura consolidada con etiqueta por empresa, sin mezclar referencias. Para escribir se selecciona una empresa concreta. Solo administradores y agentes autorizados acceden a estos módulos.

## Sin conexión

Las listas y opciones se descargan automáticamente al iniciar sesión y seleccionar el alcance. Se necesita esa primera descarga por cuenta e inmobiliaria. Se pueden crear oportunidades, moverlas, editarlas, archivarlas y crear planes con reglas locales. También se pueden marcar tareas. Los cambios se guardan en IndexedDB (web) o SQLite (Flutter), incluidos los vínculos a oportunidades todavía no sincronizadas.

Al reconectar se envían comandos con UUID, recibo transaccional y versión. Un conflicto conserva la versión del servidor y permite revisar/reaplicar desde «Sincronizar servicios». No se sobrescribe en silencio. El servidor reclasifica el plan pendiente al sincronizarlo; Gemini requiere conexión. Los límites del plan y permisos se validan de nuevo al sincronizar.

## Validación

Pruebas de backend: aislamiento SaaS, referencias entre empresas, permisos, estados, historial, archivado, conflictos, idempotencia y tareas sin crear contratos. Navegador: Kanban en 375 px, creación/movimiento offline y sincronización, workflow local y tareas. Flutter: presentación en 360 px y cola SQLite con dependencias y versiones. El recorrido Android abre ambos módulos desde el centro de trabajo.

La migración agrega únicamente `crm_oportunidad` y `crm_workflow`. No reemplaza ni elimina datos existentes.

## Revisión adicional

Se corrigió el descarte de dependencias en varios niveles (oportunidad → workflow → cambios de tareas), sin afectar propuestas independientes ni otras cuentas. Se bloquea descartar o reproponer mientras hay una sincronización en curso. También se normalizan Ganado/Perdido en las proyecciones offline.

Las eliminaciones de inmuebles, clientes, agentes y propietarios ahora detectan referencias restrictivas y devuelven un conflicto legible. Las fotos y características propias se eliminan correctamente junto con un inmueble sin historial asociado. Las modificaciones SaaS antiguas respetan la inmobiliaria seleccionada, incluso si se proporciona un ID de otra empresa.

Datos de presentación: nueve oportunidades ficticias y tres workflows (tres oportunidades y un workflow por inmobiliaria), con nueve tareas. Se conservaron los 37 inmuebles y 16 contratos anteriores. La carga `scripts/populate_commercial_demo.py` es explícita, aditiva e idempotente.

## Evidencia de la versión publicada

[Pruebas completas](https://github.com/bmateo637coder/SI2proy/actions/runs/45088275003): 100 backend, 12 unitarias web, 18 recorridos de navegador y 31 Flutter. Backend y web publicados desde `badb70da5ec7d7a6e87d279bb206415a59020cec`.

Se comprobó por API y navegador el catálogo disponible (22), cartera administrativa (37), 12 clientes, 16 contratos, reportes PDF/Excel y por lenguaje natural, mapas, dashboard, predicciones y multimoneda. Se completó una tarea ficticia y se repitió su comando con el mismo UUID; el servidor devolvió el recibo sin duplicar el cambio.

Capturas: [Kanban escritorio](capturas/crm-kanban-desktop.png), [Kanban 375 px](capturas/crm-kanban-phone.png), [workflow escritorio](capturas/crm-workflow-desktop.png), [workflow 375 px](capturas/crm-workflow-phone.png).

## Recorrido para presentar

1. Entrar como SaaS y seleccionar «Todas las inmobiliarias». Abrir Kanban: se muestran las nueve oportunidades con su empresa y sus importes, sin permitir cambios ambiguos.
2. Elegir una inmobiliaria. Crear un prospecto, asignar un cliente/inmueble/responsable, programar un contacto y mover la tarjeta a Visita. Consultar su historial.
3. Abrir workflow, escribir una consulta urgente y vincular la oportunidad. Revisar categoría, prioridad, método de clasificación y tres tareas. Completar una tarea y consultar el historial.
4. Después de la primera descarga, desconectar Internet y repetir la creación/movimiento de una oportunidad y generación de tareas locales. Se muestran como pendientes.
5. Reconectar y abrir Sincronizar servicios. Si otra persona cambió el registro, revisar la versión del servidor y decidir si reaplicar o descartar. Descartar una oportunidad pendiente elimina sus propuestas dependientes y conserva las independientes.

[Validación Android nativa](https://github.com/bmateo637coder/SI2proy/actions/runs/45089603160/job/137415937819): tres suites aprobadas en su primer intento, con procesos Flutter aislados y DDS habilitado. Incluye el recorrido de los dos módulos nuevos, almacenamiento seguro, SQLite tras reinicio, dependencias, conflictos y avisos nativos. [CI del mismo código](https://github.com/bmateo637coder/SI2proy/actions/runs/45089571575) también aprobado.

## APK Android 3.3.0

[Descargar Raíces 3.3.0](https://github.com/bmateo637coder/SI2proy/releases/download/mobile-3.3.0-38/Raices-3.3.0.apk) · [Versión y checksum](https://github.com/bmateo637coder/SI2proy/releases/tag/mobile-3.3.0-38).

- Fuente: `a2612304b07933e01b66c8cb8c8f837f6f2a5ff1`.
- Paquete: `com.inmobiliaria.inmobiliaria_mobile`, versión `3.3.0`, compilación `2638`, Android mínimo API 24.
- Tamaño: 64.023.250 bytes.
- SHA-256: `17d65f316afa1ae36cb828f8a9c29bc81892c86396eb81243296953e1b8caafb`.
- Certificado SHA-256: `bf728aa48472f871efb796107ebeb25e3c4484a843232952bb915bf12953ecd2`, igual al APK anterior; verificado con apksigner local.

Se distribuye el mismo archivo firmado y verificado por Actions, sin recompilarlo para su publicación. Instalar encima de la versión anterior conserva SQLite y la cola pendiente.

La descarga pública se verificó sin autenticación: HTTP 200, tamaño completo y SHA-256 idéntico al artefacto firmado. La versión está publicada, fuera de borrador.
