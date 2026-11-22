import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/services/api_error.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/sprint4_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/company_scope.dart';
import '../../widgets/workspace_form.dart';

class ManagementScreenTitles {
  static bool allowed(String module, UserModel? user) => switch (module) {
    'propiedades' => user?.canSeePropiedades == true,
    'clientes' => user?.canSeeClientes == true,
    'propietarios' => user?.canSeePropietarios == true,
    'agentes' => user?.canSeeAgentes == true,
    'usuarios' => user?.canSeeUsuarios == true,
    'roles' => user?.canSeeRoles == true,
    'planes' ||
    'sucursales' => user?.isAdministrator == true || user?.esAgente == true,
    'empresas' || 'global' || 'bitacora' || 'respaldos' => user?.idRol == 1,
    _ => false,
  };
}

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({required this.module, super.key});
  final String module;
  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  static const titles = {
    'propiedades': 'Gestión de propiedades',
    'clientes': 'Clientes',
    'propietarios': 'Propietarios',
    'agentes': 'Agentes',
    'usuarios': 'Usuarios',
    'roles': 'Roles y permisos',
    'empresas': 'Inmobiliarias',
    'global': 'Vista global SaaS',
    'planes': 'Planes y suscripciones',
    'sucursales': 'Sucursales',
    'bitacora': 'Bitácora',
    'respaldos': 'Respaldos',
  };
  static const paths = {
    'propiedades': '/modulo_inmuebles/propiedades',
    'clientes': '/modulo_inmuebles/clientes',
    'propietarios': '/modulo_inmuebles/propietarios',
    'agentes': '/modulo_inmuebles/agentes',
    'usuarios': '/gestion_usuarios/usuarios',
    'roles': '/roles',
    'empresas': '/admin/empresas',
    'global': '/admin/vista-global/resumen',
    'planes': '/api/saas/planes',
    'sucursales': '/api/saas/sucursales',
    'respaldos': '/admin/backup/estado',
  };
  dynamic data;
  dynamic subscription;
  bool loading = true;
  String error = '', query = '';
  final auditKey = TextEditingController();
  AuthProvider get auth => context.read<AuthProvider>();
  Sprint4Service get service => context.read<Sprint4Service>();
  String get module => widget.module;
  bool get administrator => auth.user?.isAdministrator == true;
  bool get canChange =>
      administrator || (module == 'propiedades' && auth.user?.esAgente == true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  @override
  void dispose() {
    auditKey.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = '';
    });
    try {
      if (module == 'bitacora') {
        if (auditKey.text.trim().isNotEmpty) {
          final response = await context.read<Dio>().get(
            '/admin/bitacora',
            queryParameters: {'dev_key': auditKey.text.trim()},
            options: service.options(service.scope),
          );
          data = response.data;
        }
      } else {
        data = await service.get(paths[module]!);
        if (module == 'planes')
          subscription = await service.get(
            auth.allTenants
                ? '/admin/vista-global/resumen'
                : '/api/saas/suscripcion',
          );
      }
    } catch (e) {
      if (mounted) error = apiError(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> request(
    String method,
    String path,
    dynamic body, {
    bool scoped = true,
    String? expectedScope,
  }) async {
    if (expectedScope != null && expectedScope != auth.scopeKey)
      throw StateError(
        'Cambió la inmobiliaria. Cierra el formulario y vuelve a abrirlo.',
      );
    if (scoped && !auth.canWrite)
      throw StateError(
        'Selecciona una inmobiliaria concreta para guardar cambios.',
      );
    if (auth.localSession || auth.needsOnlineLogin || service.offline)
      throw StateError(
        'Esta acción administrativa requiere conexión. Tu copia local permanece disponible.',
      );
    await context.read<Dio>().request(
      path,
      data: body,
      options: service.options(service.scope).copyWith(method: method),
    );
    if (module == 'empresas') await auth.loadCompanies();
  }

  Future<void> edit(
    String title,
    List<WorkspaceField> fields,
    Future<void> Function(Map<String, String>) save, {
    Map<String, dynamic> initial = const {},
  }) async {
    final scope = auth.scopeKey;
    await workspaceForm(context, title, fields, (v) async {
      if (scope != auth.scopeKey)
        throw StateError(
          'Cambió la inmobiliaria. Vuelve a abrir el formulario.',
        );
      await save(v);
    }, initial: initial);
    if (mounted) await load();
  }

  Future<void> action(Future<void> Function() work) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = '';
    });
    try {
      await work();
    } catch (e) {
      if (mounted) error = apiError(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<bool> confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> remove(Map row) async {
    if (!await confirm(
      'Eliminar registro',
      'Se eliminará ${row['titulo'] ?? row['nombre'] ?? 'este registro'}. El servidor verificará sus relaciones antes de permitirlo.',
    ))
      return;
    await action(() async {
      final keys = {
        'propiedades': 'id_propiedad',
        'clientes': 'id_cliente',
        'propietarios': 'id_propietario',
        'agentes': 'id_agente',
      };
      await request('DELETE', '${paths[module]}/${row[keys[module]]}', null);
    });
    if (mounted && error.isEmpty) await load();
  }

  Future<Map<String, String>> choices(
    String path,
    String id,
    String title,
  ) async {
    final values = await service.get(path) as List;
    return {
      for (final row in values)
        '${row[id]}':
            '${row[title] ?? row[id]}${row['inmobiliaria'] == null ? '' : ' · ${row['inmobiliaria']}'}',
    };
  }

  Future<void> createUser() async {
    final values = await service.get('/roles') as List;
    if (!mounted) return;
    final roles = {
      for (final r in values.where(
        (r) =>
            r['id_tenant'] == null ||
            r['id_tenant'] == auth.operationUser?.idTenant,
      ))
        '${r['id_rol']}': '${r['nombre']}',
    };
    await edit(
      'Registrar usuario',
      [
        const WorkspaceField('ci', 'CI'),
        const WorkspaceField('nombre', 'Nombre completo'),
        const WorkspaceField('correo', 'Correo electrónico'),
        const WorkspaceField('telefono', 'Teléfono', required: false),
        WorkspaceField('id_rol', 'Rol', choices: roles),
        const WorkspaceField('password', 'Contraseña inicial', secret: true),
      ],
      (v) => request('POST', paths[module]!, {
        ...v,
        'id_rol': int.parse(v['id_rol']!),
        'id_tenant': auth.operationUser!.idTenant,
      }),
    );
  }

  Future<void> person([Map? row]) async {
    final users = await choices('/gestion_usuarios/usuarios', 'ci', 'nombre');
    if (!mounted) return;
    await edit(
      row == null ? 'Registrar ${titles[module]}' : 'Cambiar usuario asociado',
      [
        WorkspaceField(
          'ci_usuario',
          'Usuario de la inmobiliaria',
          choices: users,
        ),
      ],
      (v) => request(
        row == null ? 'POST' : 'PUT',
        '${paths[module]}${row == null ? '' : '/${row[module == 'clientes' ? 'id_cliente' : 'id_propietario']}'}',
        v,
      ),
      initial: row == null ? {} : Map<String, dynamic>.from(row),
    );
  }

  Future<void> property([Map? row]) async {
    final owners = await choices(
      '/modulo_inmuebles/propietarios',
      'id_propietario',
      'nombre',
    );
    final agents = await choices(
      '/modulo_inmuebles/agentes',
      'id_agente',
      'nombre',
    );
    final branches = await choices(
      '/api/saas/sucursales',
      'id_sucursal',
      'nombre',
    );
    if (!mounted) return;
    final attrs = {
      for (final a in (row?['caracteristicas'] as List? ?? []))
        '${a['nombre']}': '${a['valor']}',
    };
    const fields = {
      'superficie': 'Metros Cuadrados',
      'habitaciones': 'Cuartos',
      'banos': 'Baños',
      'zona': 'Zona',
      'zona_geo': 'Zona geográfica',
      'latitud': 'Latitud',
      'longitud': 'Longitud',
      'tipo': 'Tipo inmueble',
    };
    final initial = <String, dynamic>{
      ...row ?? {},
      for (final f in fields.entries) f.key: attrs[f.value] ?? '',
      'imagenes': (row?['imagenes'] as List? ?? [])
          .map((i) => i is Map ? i['url'] : i)
          .join('\n'),
    };
    await edit(
      row == null ? 'Nueva propiedad' : 'Editar propiedad',
      [
        const WorkspaceField('titulo', 'Título'),
        const WorkspaceField(
          'descripcion',
          'Descripción',
          required: false,
          multiline: true,
        ),
        const WorkspaceField('direccion', 'Dirección'),
        const WorkspaceField('precio', 'Precio', number: true),
        const WorkspaceField(
          'tipo_operacion',
          'Operación',
          choices: {
            'Venta': 'Venta',
            'Alquiler': 'Alquiler',
            'Anticretico': 'Anticrético',
          },
        ),
        WorkspaceField('id_propietario', 'Propietario', choices: owners),
        WorkspaceField('id_agente', 'Agente', choices: agents),
        WorkspaceField('id_sucursal', 'Sucursal', choices: branches),
        const WorkspaceField('tipo', 'Tipo de inmueble', required: false),
        const WorkspaceField(
          'superficie',
          'Superficie (m²)',
          number: true,
          required: false,
        ),
        const WorkspaceField(
          'habitaciones',
          'Habitaciones',
          number: true,
          required: false,
        ),
        const WorkspaceField('banos', 'Baños', number: true, required: false),
        const WorkspaceField(
          'zona',
          'Segmento del modelo',
          required: false,
          choices: {
            'Económica': 'Económica',
            'Estándar': 'Estándar',
            'Premium': 'Premium',
          },
        ),
        const WorkspaceField('zona_geo', 'Zona geográfica', required: false),
        const WorkspaceField(
          'latitud',
          'Latitud',
          number: true,
          required: false,
        ),
        const WorkspaceField(
          'longitud',
          'Longitud',
          number: true,
          required: false,
        ),
        const WorkspaceField(
          'imagenes',
          'URLs de fotos (una por línea)',
          required: false,
          multiline: true,
        ),
      ],
      (v) async {
        final price = double.parse(v['precio']!.replaceAll(',', '.'));
        if (price <= 0) throw StateError('El precio debe ser mayor que cero.');
        for (final coord in ['latitud', 'longitud']) {
          if (v[coord]!.isNotEmpty &&
              double.parse(v[coord]!.replaceAll(',', '.')).abs() >
                  (coord == 'latitud' ? 90 : 180))
            throw StateError('Coordenadas fuera de rango.');
        }
        final updated = <String, String>{...attrs};
        for (final f in fields.entries) {
          updated.remove(f.value);
          if (v[f.key]!.isNotEmpty) updated[f.value] = v[f.key]!;
        }
        await request(
          row == null ? 'POST' : 'PUT',
          '${paths[module]}${row == null ? '' : '/${row['id_propiedad']}'}',
          {
            for (final k in [
              'titulo',
              'descripcion',
              'direccion',
              'tipo_operacion',
            ])
              k: v[k],
            'precio': price,
            for (final k in ['id_propietario', 'id_agente', 'id_sucursal'])
              k: int.parse(v[k]!),
            'imagenes': v['imagenes']!
                .split('\n')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList(),
            'caracteristicas': [
              for (final a in updated.entries)
                {'nombre': a.key, 'valor': a.value},
            ],
          },
        );
      },
      initial: initial,
    );
  }

  Future<void> attachPropertyPhoto(Map row) async {
    if (!auth.canWrite)
      throw StateError('Selecciona la inmobiliaria del inmueble.');
    final scope = auth.scopeKey;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;
    if (scope != auth.scopeKey)
      throw StateError('Cambió la inmobiliaria. Vuelve a abrir la propiedad.');
    final response = await context.read<Dio>().post(
      '/upload',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          await file.readAsBytes(),
          filename: file.name,
        ),
      }),
      options: service.options(service.scope),
    );
    final photos = [
      for (final image in row['imagenes'] as List? ?? [])
        image is Map ? image['url'] : image,
      response.data['url'],
    ];
    await request(
      'PUT',
      '/modulo_inmuebles/propiedades/${row['id_propiedad']}',
      {
        for (final k in [
          'id_propietario',
          'id_agente',
          'id_sucursal',
          'titulo',
          'descripcion',
          'direccion',
          'precio',
          'tipo_operacion',
          'caracteristicas',
        ])
          k: row[k],
        'imagenes': photos,
      },
      expectedScope: scope,
    );
    await load();
  }

  Future<void> rolePermissions(Map row) async {
    final permissions = await service.get('/permisos') as List;
    if (!mounted) return;
    final selected = Set<int>.from(
      (row['permisos'] as List? ?? []).whereType<int>(),
    );
    final scope = auth.scopeKey;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => StatefulBuilder(
          builder: (c, update) => Scaffold(
            appBar: AppBar(title: Text('Permisos · ${row['nombre']}')),
            body: ListView(
              children: [
                for (final p in permissions)
                  CheckboxListTile(
                    title: Text('${p['descripcion'] ?? p['codigo']}'),
                    subtitle: Text('${p['codigo']}'),
                    value: selected.contains(p['id_permiso']),
                    onChanged: (v) => update(() {
                      if (v == true) {
                        selected.add(p['id_permiso'] as int);
                      } else {
                        selected.remove(p['id_permiso']);
                      }
                    }),
                  ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await request(
                          'PUT',
                          '/roles/${row['id_rol']}/permisos',
                          selected.toList(),
                          scoped: false,
                          expectedScope: scope,
                        );
                        if (c.mounted) Navigator.pop(c);
                      } catch (e) {
                        if (c.mounted)
                          ScaffoldMessenger.of(
                            c,
                          ).showSnackBar(SnackBar(content: Text(apiError(e))));
                      }
                    },
                    child: const Text('Guardar permisos'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> subscriptionForm() async {
    final plans = await choices('/api/saas/planes', 'codigo', 'nombre');
    if (!mounted) return;
    final current = subscription is Map && !auth.allTenants
        ? Map<String, dynamic>.from(subscription as Map)
        : <String, dynamic>{};
    await edit(
      'Actualizar suscripción',
      [
        WorkspaceField('codigo_plan', 'Plan', choices: plans),
        const WorkspaceField('inicio', 'Inicio', date: true),
        const WorkspaceField('vencimiento', 'Vencimiento', date: true),
        const WorkspaceField(
          'estado',
          'Estado',
          choices: {
            'activa': 'Activa',
            'suspendida': 'Suspendida',
            'cancelada': 'Cancelada',
          },
        ),
      ],
      (v) => request(
        'PUT',
        '/api/saas/suscripcion/${auth.operationUser!.idTenant}',
        v,
      ),
      initial: current,
    );
  }

  Future<void> branchAssignment(Map row, bool employee) async {
    final values = employee
        ? await choices('/gestion_usuarios/usuarios', 'ci', 'nombre')
        : await choices(
            '/modulo_inmuebles/propiedades',
            'id_propiedad',
            'titulo',
          );
    if (!mounted) return;
    await edit(
      employee
          ? 'Autorizar empleado en ${row['nombre']}'
          : 'Asignar inmueble a ${row['nombre']}',
      [
        WorkspaceField(
          'value',
          employee ? 'Empleado' : 'Propiedad',
          choices: values,
        ),
      ],
      (v) => request(
        employee ? 'POST' : 'PUT',
        employee
            ? '/api/saas/sucursales/${row['id_sucursal']}/usuarios'
            : '/api/saas/propiedades/${v['value']}/sucursal',
        employee
            ? {'ci_usuario': v['value']}
            : {'id_sucursal': row['id_sucursal']},
      ),
    );
  }

  Future<void> create() async {
    switch (module) {
      case 'propiedades':
        await property();
      case 'clientes':
      case 'propietarios':
      case 'agentes':
        await person();
      case 'usuarios':
        await createUser();
      case 'roles':
        await edit('Crear rol', [
          const WorkspaceField('nombre', 'Nombre del rol'),
        ], (v) => request('POST', '/roles', v, scoped: false));
      case 'empresas':
        await edit('Crear inmobiliaria y administrador', [
          const WorkspaceField('nombre', 'Nombre de la inmobiliaria'),
          const WorkspaceField('slug', 'Identificador (minúsculas y guiones)'),
          const WorkspaceField('admin_ci', 'CI del administrador'),
          const WorkspaceField('admin_nombre', 'Nombre del administrador'),
          const WorkspaceField('admin_correo', 'Correo del administrador'),
          const WorkspaceField('admin_telefono', 'Teléfono', required: false),
        ], (v) => request('POST', '/admin/empresas', v, scoped: false));
      case 'sucursales':
        await edit(
          'Nueva sucursal',
          [
            const WorkspaceField('nombre', 'Nombre'),
            const WorkspaceField('direccion', 'Dirección', required: false),
          ],
          (v) =>
              request('POST', '/api/saas/sucursales', {...v, 'activa': true}),
        );
    }
  }

  Future<void> backup(bool restore) async {
    if (restore) {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sql'],
        withData: true,
      );
      if (selection == null || !mounted) return;
      final file = selection.files.single;
      if (!await confirm(
        'Restaurar base de datos',
        'Se reemplazará la información de toda la plataforma por ${file.name}. Descarga antes un respaldo y verifica el archivo. Esta acción afecta a todas las inmobiliarias.',
      ))
        return;
      await request(
        'POST',
        '/admin/restore',
        FormData.fromMap({
          'file': MultipartFile.fromBytes(
            file.bytes ?? await File(file.path!).readAsBytes(),
            filename: file.name,
          ),
        }),
        scoped: false,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restauración completada. Actualiza la copia local.'),
          ),
        );
    } else {
      final response = await context.read<Dio>().get(
        '/admin/backup',
        options: service
            .options(service.scope)
            .copyWith(responseType: ResponseType.bytes),
      );
      final folder = await getTemporaryDirectory();
      final file = File(
        '${folder.path}/raices-backup-${DateTime.now().millisecondsSinceEpoch}.sql',
      );
      await file.writeAsBytes(List<int>.from(response.data as List));
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Respaldo PostgreSQL de Raíces');
    }
  }

  Widget summary(dynamic value) {
    if (value is Map)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in value.entries.where(
            (e) => ![
              'password_hash',
              'token',
              'huella',
              'privada_cifrada',
            ].contains(e.key),
          ))
            if (entry.value is Map || entry.value is List)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(label('${entry.key}')),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: summary(entry.value),
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        label('${entry.key}'),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(child: SelectableText(display(entry.value))),
                  ],
                ),
              ),
        ],
      );
    if (value is List)
      return Column(
        children: [
          for (final row in value)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: summary(row),
              ),
            ),
        ],
      );
    return SelectableText(display(value));
  }

  String display(dynamic value) => value == null
      ? '—'
      : value == true
      ? 'Sí'
      : value == false
      ? 'No'
      : '$value';
  String label(String key) {
    const labels = {
      'id_tenant': 'Inmobiliaria',
      'reportes_ia': 'Reportes con IA',
      'max_sucursales': 'Máximo de sucursales',
      'ci_usuario': 'CI del usuario',
      'fecha_vencimiento_pago': 'Vencimiento',
      'cobrado_total': 'Total cobrado',
      'por_cobrar': 'Por cobrar',
    };
    return labels[key] ??
        '${key[0].toUpperCase()}${key.substring(1).replaceAll('_', ' ')}';
  }

  Widget actionButton(String text, IconData icon, VoidCallback work) => Padding(
    padding: const EdgeInsets.only(right: 8, top: 8),
    child: OutlinedButton.icon(
      onPressed: loading ? null : work,
      icon: Icon(icon, size: 18),
      label: Text(text),
    ),
  );

  Widget record(Map row) {
    final title =
        '${row['titulo'] ?? row['nombre'] ?? row['codigo'] ?? 'Registro'}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (row['inmobiliaria'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${row['inmobiliaria']}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (module == 'propiedades') ...[
              Text(
                '${row['tipo_operacion']} · ${row['precio']} · ${row['estado']}',
              ),
              Text('${row['direccion']}'),
            ],
            if (row['correo'] != null) Text('${row['correo']}'),
            if (row['telefono'] != null) Text('${row['telefono']}'),
            if (module == 'sucursales')
              Text(
                '${row['direccion']} · ${row['activa'] == true ? 'Activa' : 'Inactiva'}',
              ),
            if (module == 'planes')
              Text(
                'Hasta ${row['max_sucursales']} sucursales · IA ${row['reportes_ia'] == true ? 'incluida' : 'no incluida'}',
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Ver información completa'),
              children: [summary(row)],
            ),
            if (canChange)
              Wrap(
                children: [
                  if (module == 'propiedades') ...[
                    actionButton(
                      'Editar',
                      Icons.edit_outlined,
                      () => action(() => property(row)),
                    ),
                    actionButton(
                      'Estado',
                      Icons.swap_horiz,
                      () => edit(
                        'Estado del inmueble',
                        [
                          const WorkspaceField(
                            'estado',
                            'Estado',
                            choices: {
                              'Disponible': 'Disponible',
                              'Reservada': 'Reservada',
                              'Vendida': 'Vendida',
                              'Alquilada': 'Alquilada',
                            },
                          ),
                        ],
                        (v) => request(
                          'PUT',
                          '/modulo_inmuebles/propiedades/${row['id_propiedad']}/estado',
                          v,
                        ),
                        initial: Map<String, dynamic>.from(row),
                      ),
                    ),
                    actionButton(
                      'Añadir foto',
                      Icons.add_photo_alternate_outlined,
                      () => action(() => attachPropertyPhoto(row)),
                    ),
                  ],
                  if (['clientes', 'propietarios'].contains(module))
                    actionButton(
                      'Cambiar usuario',
                      Icons.edit_outlined,
                      () => action(() => person(row)),
                    ),
                  if ([
                    'propiedades',
                    'clientes',
                    'propietarios',
                    'agentes',
                  ].contains(module))
                    actionButton(
                      'Eliminar',
                      Icons.delete_outline,
                      () => remove(row),
                    ),
                  if (module == 'roles')
                    actionButton(
                      'Configurar permisos',
                      Icons.fact_check_outlined,
                      () => action(() => rolePermissions(row)),
                    ),
                  if (module == 'empresas')
                    actionButton('Restablecer administrador', Icons.lock_reset, () async {
                      if (await confirm(
                        'Restablecer contraseña',
                        'La contraseña del administrador se restablecerá al valor configurado por el servidor.',
                      )) {
                        await action(
                          () => request(
                            'PUT',
                            '/admin/empresas/${row['id_tenant']}/reset-admin-password',
                            {},
                            scoped: false,
                          ),
                        );
                      }
                    }),
                  if (module == 'sucursales') ...[
                    actionButton(
                      'Editar',
                      Icons.edit_outlined,
                      () => edit(
                        'Editar sucursal',
                        [
                          const WorkspaceField('nombre', 'Nombre'),
                          const WorkspaceField(
                            'direccion',
                            'Dirección',
                            required: false,
                          ),
                        ],
                        (v) => request(
                          'PUT',
                          '/api/saas/sucursales/${row['id_sucursal']}',
                          {...v, 'activa': row['activa']},
                        ),
                        initial: Map<String, dynamic>.from(row),
                      ),
                    ),
                    actionButton(
                      row['activa'] == true ? 'Desactivar' : 'Activar',
                      Icons.power_settings_new,
                      () => action(() async {
                        await request(
                          'PUT',
                          '/api/saas/sucursales/${row['id_sucursal']}',
                          {
                            'nombre': row['nombre'],
                            'direccion': row['direccion'],
                            'activa': row['activa'] != true,
                          },
                        );
                        await load();
                      }),
                    ),
                    actionButton(
                      'Empleado',
                      Icons.person_add_alt,
                      () => action(() => branchAssignment(row, true)),
                    ),
                    actionButton(
                      'Inmueble',
                      Icons.add_home_outlined,
                      () => action(() => branchAssignment(row, false)),
                    ),
                  ],
                  if (module == 'planes' && auth.isSuperAdmin)
                    actionButton(
                      'Configurar plan',
                      Icons.tune,
                      () => edit(
                        'Límites del plan',
                        [
                          const WorkspaceField('nombre', 'Nombre'),
                          const WorkspaceField(
                            'max_sucursales',
                            'Máximo de sucursales',
                            number: true,
                          ),
                          const WorkspaceField(
                            'reportes_ia',
                            'Reportes IA',
                            choices: {
                              'true': 'Incluidos',
                              'false': 'No incluidos',
                            },
                          ),
                        ],
                        (v) => request(
                          'PUT',
                          '/api/saas/planes/${row['codigo']}',
                          {
                            'nombre': v['nombre'],
                            'max_sucursales': int.parse(v['max_sucursales']!),
                            'reportes_ia': v['reportes_ia'] == 'true',
                          },
                          scoped: false,
                        ),
                        initial: Map<String, dynamic>.from(row),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offline =
        context.watch<Sprint4Service>().offline ||
        context.watch<AuthProvider>().localSession;
    final list = data is List
        ? (data as List)
              .whereType<Map>()
              .where(
                (r) =>
                    jsonEncode(r).toLowerCase().contains(query.toLowerCase()),
              )
              .toList()
        : <Map>[];
    final canCreate =
        canChange &&
        [
          'propiedades',
          'clientes',
          'propietarios',
          'agentes',
          'usuarios',
          'roles',
          'empresas',
          'sucursales',
        ].contains(module);
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[module] ?? 'Administración'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: loading ? null : () => action(create),
              icon: const Icon(Icons.add),
              label: const Text('Crear'),
            )
          : null,
      body: Column(
        children: [
          const CompanyScope(),
          if (loading) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  if (offline)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.cloud_off_outlined),
                        title: Text('Copia local'),
                        subtitle: Text(
                          'Puedes consultar lo descargado. Los cambios de administración necesitan conexión.',
                        ),
                      ),
                    ),
                  if (auth.allTenants &&
                      canChange &&
                      !['empresas', 'roles', 'planes'].contains(module))
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Estás viendo todas las inmobiliarias'),
                        subtitle: Text(
                          'Selecciona una empresa arriba para registrar o modificar sus datos.',
                        ),
                      ),
                    ),
                  if (error.isNotEmpty)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(error),
                      ),
                    ),
                  if (module == 'bitacora') ...[
                    TextField(
                      controller: auditKey,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Llave de bitácora',
                        prefixIcon: Icon(Icons.key),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: loading ? null : load,
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Consultar bitácora'),
                    ),
                  ],
                  if (module == 'respaldos') ...[
                    const Text(
                      'Conserva una copia antes de restaurar. El respaldo incluye todas las inmobiliarias.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: loading
                          ? null
                          : () => action(() => backup(false)),
                      icon: const Icon(Icons.download),
                      label: const Text('Descargar y compartir respaldo SQL'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: loading
                          ? null
                          : () => action(() => backup(true)),
                      icon: const Icon(Icons.restore),
                      label: const Text('Seleccionar archivo y restaurar'),
                    ),
                  ],
                  if (module == 'planes') ...[
                    if (subscription != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: summary(subscription),
                        ),
                      ),
                    if (administrator && auth.canWrite)
                      FilledButton.icon(
                        onPressed: loading
                            ? null
                            : () => action(subscriptionForm),
                        icon: const Icon(Icons.edit_calendar),
                        label: const Text('Administrar suscripción'),
                      ),
                  ],
                  if (data is List) ...[
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (v) => setState(() => query = v),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText:
                            'Buscar en ${titles[module]?.toLowerCase() ?? 'los registros'}',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        '${list.length} registros',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    if (list.isEmpty && !loading)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No hay registros para esta selección. Puedes actualizar o cambiar los filtros.',
                          ),
                        ),
                      ),
                    ...list.map(record),
                  ] else if (data != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: summary(data),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
