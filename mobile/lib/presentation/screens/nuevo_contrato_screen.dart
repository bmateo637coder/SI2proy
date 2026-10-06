import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/models/cliente_model.dart';
import '../../data/models/propiedad_model.dart';
import '../providers/clientes_provider.dart';
import '../providers/contratos_provider.dart';
import '../providers/propiedades_provider.dart';

class NuevoContratoScreen extends StatefulWidget {
  const NuevoContratoScreen({super.key});

  @override
  State<NuevoContratoScreen> createState() => _NuevoContratoScreenState();
}

class _NuevoContratoScreenState extends State<NuevoContratoScreen> {
  ClienteModel? _cliente;
  PropiedadModel? _propiedad;
  String _tipoContrato = 'Venta';
  final _montoController = TextEditingController();
  DateTime _fechaInicio = DateTime.now();
  DateTime? _fechaFin;
  final _numCuotasController = TextEditingController();

  List<PropiedadModel> get _propiedadesElegibles => context
      .watch<PropiedadesProvider>()
      .propiedades
      .where((p) => p.estado == 'Disponible' || p.estado == 'Reservada')
      .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final clientes = context.read<ClientesProvider>();
      if (clientes.clientes.isEmpty) clientes.fetchClientes();
      final propiedades = context.read<PropiedadesProvider>();
      if (propiedades.propiedades.isEmpty) propiedades.fetchPropiedades();
    });
  }

  @override
  void dispose() {
    _montoController.dispose();
    _numCuotasController.dispose();
    super.dispose();
  }

  Future<void> _pickerFechaInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _fechaInicio = picked);
  }

  Future<void> _pickerFechaFin() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaFin ?? _fechaInicio,
      firstDate: _fechaInicio,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _fechaFin = picked);
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _crear() async {
    if (_cliente == null || _propiedad == null) {
      _snack('Seleccione cliente y propiedad.');
      return;
    }
    final monto = double.tryParse(_montoController.text.trim());
    if (monto == null || monto <= 0) {
      _snack('Ingrese un monto válido.');
      return;
    }
    final numCuotas = int.tryParse(_numCuotasController.text.trim());
    final creado = await context.read<ContratosProvider>().createContrato(
          idCliente: _cliente!.idCliente,
          idPropiedad: _propiedad!.idPropiedad,
          tipoContrato: _tipoContrato,
          montoTotal: monto,
          fechaInicio: _fmt(_fechaInicio),
          fechaFin: _fechaFin == null ? null : _fmt(_fechaFin!),
          numCuotas: numCuotas,
        );
    if (!mounted) return;
    if (creado) {
      context.pop(true);
    } else {
      _snack(context.read<ContratosProvider>().errorMessage ?? 'Error al crear el contrato.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ContratosProvider>();
    final clientes = context.watch<ClientesProvider>();
    final propiedades = _propiedadesElegibles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Contrato'),
        centerTitle: true,
      ),
      body: provider.isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<ClienteModel?>(
                  initialValue: _cliente,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Cliente *',
                    border: OutlineInputBorder(),
                  ),
                  items: clientes.clientes
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.nombre.isEmpty ? 'CI ${c.ciUsuario}' : c.nombre),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _cliente = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<PropiedadModel?>(
                  initialValue: _propiedad,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Propiedad *',
                    border: OutlineInputBorder(),
                  ),
                  items: propiedades
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text('#${p.idPropiedad} — ${p.titulo} (${p.tipoOperacion})'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _propiedad = value;
                      if (value != null && value.tipoOperacion.isNotEmpty) {
                        _tipoContrato = value.tipoOperacion;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _tipoContrato,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de contrato *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Venta', child: Text('Venta')),
                    DropdownMenuItem(value: 'Alquiler', child: Text('Alquiler')),
                    DropdownMenuItem(value: 'Anticretico', child: Text('Anticrético')),
                  ],
                  onChanged: (value) => setState(() => _tipoContrato = value ?? 'Venta'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _montoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monto total (\$us) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _numCuotasController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'N° de cuotas (opcional, mensual)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha de inicio *'),
                  subtitle: Text(_fmt(_fechaInicio)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickerFechaInicio,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha de fin (opcional)'),
                  subtitle: Text(_fechaFin == null ? '—' : _fmt(_fechaFin!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickerFechaFin,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _crear,
                  child: const Text('Crear Contrato'),
                ),
              ],
            ),
    );
  }
}