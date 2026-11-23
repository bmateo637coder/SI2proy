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
