import 'package:flutter/material.dart';

import '../../data/models/user_model.dart';

String workspaceSearch(String value) {
  var result = value.toLowerCase();
  for (final entry in {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  }.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}

class WorkspaceModule {
  const WorkspaceModule(
    this.title,
    this.subtitle,
    this.group,
    this.path,
    this.icon,
  );
  final String title, subtitle, group, path;
  final IconData icon;
}

List<WorkspaceModule> workspaceModules(UserModel? user) => [
  const WorkspaceModule(
    'Conversión multimoneda',
    'USD, BOB, EUR, BRL, CLP y PEN; tasas con fecha',
    'Operaciones',
    '/moneda',
    Icons.currency_exchange,
  ),
  if (user?.isAdministrator == true || user?.canOperateOffline == true)
    const WorkspaceModule(
      'Predicción de ventas y demanda',
      'Proyección mensual, historial y validación ML',
      'Clientes e IA',
      '/predicciones',
      Icons.trending_up,
    ),
  const WorkspaceModule(
    'Mapa de propiedades',
    'Ubicación y ficha de los inmuebles',
    'Inmuebles',
    '/mapa',
    Icons.map_outlined,
  ),
  const WorkspaceModule(
    'Catálogo',
    'Explorar inmuebles y agendar visitas',
    'Inmuebles',
    '/catalogo',
    Icons.home_work_outlined,
  ),
  if (user?.canSeePropiedades == true)
    const WorkspaceModule(
      'Gestionar propiedades',
      'Crear, editar, fotos, ubicación y estado',
      'Inmuebles',
      '/gestion/propiedades',
      Icons.real_estate_agent_outlined,
    ),
  if (user?.canSeePropietarios == true)
    const WorkspaceModule(
      'Propietarios',
      'Registrar y administrar propietarios',
      'Inmuebles',
      '/gestion/propietarios',
      Icons.key_outlined,
    ),
  if (user?.canSeeAgentes == true)
    const WorkspaceModule(
      'Agentes',
      'Equipo comercial de cada inmobiliaria',
      'Inmuebles',
      '/gestion/agentes',
      Icons.support_agent,
    ),
  if (user?.canSeeClientes == true)
    const WorkspaceModule(
      'Clientes',
      'Crear, consultar, editar y eliminar',
      'Operaciones',
      '/gestion/clientes',
      Icons.people_outline,
    ),
  if (user?.canSeeContratos == true)
    const WorkspaceModule(
      'Contratos y pagos',
      'Cuotas, saldos y comprobantes',
      'Operaciones',
      '/contratos',
      Icons.description_outlined,
    ),
  const WorkspaceModule(
    'Visitas',
    'Agenda, confirmaciones y seguimiento',
    'Operaciones',
    '/servicios?seccion=Visitas',
    Icons.event_available,
  ),
  const WorkspaceModule(
    'Mantenimiento',
    'Incidencias, fotos, contratistas y costos',
    'Operaciones',
    '/servicios?seccion=Mantenimiento',
    Icons.handyman_outlined,
  ),
  const WorkspaceModule(
    'Mi estado de cuenta',
    'Contratos, pagos y recibos',
    'Operaciones',
    '/servicios?seccion=Mi%20cuenta',
    Icons.receipt_long_outlined,
  ),
  const WorkspaceModule(
    'Favoritos',
    'Los inmuebles que te interesan',
    'Clientes e IA',
    '/servicios?seccion=Favoritos',
    Icons.favorite_outline,
  ),
  const WorkspaceModule(
    'Alertas de búsqueda',
    'Avisos según tus preferencias',
    'Clientes e IA',
    '/servicios?seccion=Alertas',
    Icons.notifications_active_outlined,
  ),
  const WorkspaceModule(
    'Búsqueda inteligente',
    'Describe el inmueble que buscas',
    'Clientes e IA',
    '/servicios?seccion=B%C3%BAsqueda',
    Icons.manage_search,
  ),
  const WorkspaceModule(
    'Recomendaciones',
    'Sugerencias, valoraciones y comentarios',
    'Clientes e IA',
    '/servicios?seccion=Recomendaciones',
    Icons.recommend_outlined,
  ),
  const WorkspaceModule(
    'Asistente y cotización IA',
    'Chat, tasación y descripción comercial',
    'Clientes e IA',
    '/servicios?seccion=Asistente%20e%20IA',
    Icons.auto_awesome,
  ),
  if (user?.canSeeReportes == true) ...[
    const WorkspaceModule(
      'Reportes dinámicos',
      'Filtros, voz, PDF, Excel, CSV y HTML',
      'Reportes y gerencia',
      '/reportes',
      Icons.table_chart_outlined,
    ),
    const WorkspaceModule(
      'IA y analítica',
      'Reportes convencionales, gráficos y modelos',
      'Reportes y gerencia',
      '/ia',
      Icons.query_stats,
    ),
    const WorkspaceModule(
      'Dashboard gerencial',
      'Cartera, ingresos y rendimiento del equipo',
      'Reportes y gerencia',
      '/servicios?seccion=Gerencia',
      Icons.dashboard_outlined,
    ),
    const WorkspaceModule(
      'Mapa de calor de ventas',
      'Zonas, montos y cantidad de ventas',
      'Reportes y gerencia',
      '/servicios?seccion=Mapa%20de%20ventas',
      Icons.map_outlined,
    ),
    const WorkspaceModule(
      'Reporte ejecutivo',
      'Indicadores consolidados y exportación',
      'Reportes y gerencia',
      '/servicios?seccion=Reporte%20ejecutivo',
      Icons.picture_as_pdf_outlined,
    ),
  ],
  if (user?.isAdministrator == true || user?.esAgente == true) ...[
    const WorkspaceModule(
      'Comisiones',
      'Pendientes y liquidaciones comerciales',
      'Administración',
      '/servicios?seccion=Comisiones',
      Icons.payments_outlined,
    ),
    const WorkspaceModule(
      'Promociones',
      'Descuentos y vigencias comerciales',
      'Administración',
      '/servicios?seccion=Promociones',
      Icons.local_offer_outlined,
    ),
    const WorkspaceModule(
      'Planes y suscripciones',
      'Vigencia, estado y límites del servicio',
      'Administración',
      '/gestion/planes',
      Icons.workspace_premium_outlined,
    ),
    const WorkspaceModule(
      'Sucursales',
      'Sedes, empleados y asignación de inmuebles',
      'Administración',
      '/gestion/sucursales',
      Icons.account_tree_outlined,
    ),
  ],
  if (user?.canSeeUsuarios == true)
    const WorkspaceModule(
      'Usuarios',
      'Crear cuentas y asignar roles',
      'Administración',
      '/gestion/usuarios',
      Icons.person_add_alt,
    ),
  if (user?.canSeeRoles == true)
    const WorkspaceModule(
      'Roles y permisos',
      'Crear roles y configurar accesos',
      'Administración',
      '/gestion/roles',
      Icons.admin_panel_settings_outlined,
    ),
  if (user?.idRol == 1) ...[
    const WorkspaceModule(
      'Inmobiliarias',
      'Empresas y administradores de la plataforma',
      'Plataforma SaaS',
      '/gestion/empresas',
      Icons.apartment,
    ),
    const WorkspaceModule(
      'Vista global SaaS',
      'Comparar actividad entre inmobiliarias',
      'Plataforma SaaS',
      '/gestion/global',
      Icons.public,
    ),
    const WorkspaceModule(
      'Bitácora',
      'Consultar auditoría con tu llave',
      'Plataforma SaaS',
      '/gestion/bitacora',
      Icons.policy_outlined,
    ),
    const WorkspaceModule(
      'Respaldos',
      'Descargar y restaurar archivos SQL',
      'Plataforma SaaS',
      '/gestion/respaldos',
      Icons.backup_outlined,
    ),
  ],
  const WorkspaceModule(
    'Notificaciones',
    'Bandeja y avisos del dispositivo',
    'Mi espacio',
    '/servicios?seccion=Notificaciones',
    Icons.notifications_none,
  ),
  const WorkspaceModule(
    'Sincronización',
    'Copia local, pendientes y conflictos',
    'Mi espacio',
    '/sincronizacion',
    Icons.sync,
  ),
  const WorkspaceModule(
    'Sincronización de servicios',
    'Revisar cambios de favoritos y mantenimiento',
    'Mi espacio',
    '/servicios?seccion=Sincronizaci%C3%B3n%20de%20servicios',
    Icons.cloud_sync_outlined,
  ),
  if (user?.idRol == 1 || user?.canOperateOffline == true)
    const WorkspaceModule(
      'Operaciones offline',
      'Reservas y ventas pendientes de confirmar',
      'Mi espacio',
      '/offline',
      Icons.offline_bolt_outlined,
    ),
  const WorkspaceModule(
    'Mi perfil',
    'Cuenta, contraseña y cierre de sesión',
    'Mi espacio',
    '/profile',
    Icons.account_circle_outlined,
  ),
];
