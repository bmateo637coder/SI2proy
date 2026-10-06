import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/contratos_provider.dart';

class ContratosScreen extends StatefulWidget {
  const ContratosScreen({super.key});

  @override
  State<ContratosScreen> createState() => _ContratosScreenState();
}

class _ContratosScreenState extends State<ContratosScreen> {
  String? _filtroEstado;
  String? _ultimoExito;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ContratosProvider>();
      p.addListener(_onProviderChange);
      p.fetchContratos();
    });
  }

  @override
  void dispose() {
    context.read<ContratosProvider>().removeListener(_onProviderChange);
    super.dispose();
  }

  void _onProviderChange() {
    final p = context.read<ContratosProvider>();
    final exito = p.successMessage;
    if (exito != null && exito != _ultimoExito) {
      _ultimoExito = exito;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exito)));
      }
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Pagado':
        return Colors.green;
      case 'En Mora':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _abrirDetalle(BuildContext context, int idContrato) async {
    final provider = context.read<ContratosProvider>();
    await provider.fetchDetalle(idContrato);
    if (!context.mounted) return;
    final detalle = provider.detalle;
    if (detalle == null) {
      if (provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage!)));
      }
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _DetalleContratoSheet(contrato: detalle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ContratosProvider>();
    final user = context.watch<AuthProvider>().user;
    final canCreate = user?.canSeeContratos ?? false;

    List<dynamic> visible = provider.contratos;
    if (_filtroEstado != null && _filtroEstado!.isNotEmpty) {
      visible = visible.where((c) => c.estado == _filtroEstado).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contratos y Pagos'),
        centerTitle: true,
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await context.push<bool>('/contratos/nuevo');
                if (!context.mounted) return;
                if (created == true) {
                  context.read<ContratosProvider>().fetchContratos();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Contrato'),
            )
          : null,
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.errorMessage != null && provider.contratos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${provider.errorMessage}', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => provider.fetchContratos(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: provider.fetchContratos,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: DropdownButtonFormField<String?>(
                          initialValue: _filtroEstado,
                          decoration: const InputDecoration(
                            labelText: 'Filtrar por estado',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Todos los estados')),
                            DropdownMenuItem(value: 'Activo', child: Text('Activo')),
                            DropdownMenuItem(value: 'En Mora', child: Text('En Mora')),
                            DropdownMenuItem(value: 'Pagado', child: Text('Pagado')),
                          ],
                          onChanged: (value) => setState(() => _filtroEstado = value),
                        ),
                      ),
                      Expanded(
                        child: visible.isEmpty
                            ? const Center(child: Text('No hay contratos registrados aún.'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: visible.length,
                                itemBuilder: (context, index) {
                                  final c = visible[index];
                                  return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      onTap: () => _abrirDetalle(context, c.idContrato),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                        child: Text('${c.idContrato}'),
                                      ),
                                      title: Text(
                                        c.propiedad ?? 'Propiedad #${c.idPropiedad}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text('${c.cliente ?? 'Cliente #${c.idCliente}'} · ${c.tipoContrato}'),
                                          Text('Saldo: \$us ${c.saldoPendiente.toStringAsFixed(2)}'),
                                          Text('${c.cuotasPagadas}/${c.cuotasTotales} cuotas pagadas'),
                                        ],
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Chip(
                                            label: Text(c.estado),
                                            labelStyle: TextStyle(
                                              color: _colorEstado(c.estado),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            backgroundColor: _colorEstado(c.estado).withValues(alpha: 0.12),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _DetalleContratoSheet extends StatefulWidget {
  const _DetalleContratoSheet({required this.contrato});

  final dynamic contrato;

  @override
  State<_DetalleContratoSheet> createState() => _DetalleContratoSheetState();
}

class _DetalleContratoSheetState extends State<_DetalleContratoSheet> {
  final _montoController = TextEditingController();
  String _metodoPago = 'Transferencia';
  bool _enviando = false;
  bool _descargandoComprobante = false;

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _registrarPago() async {
    final monto = double.tryParse(_montoController.text.trim());
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un monto válido.')),
      );
      return;
    }
    final c = widget.contrato;
    setState(() => _enviando = true);
    final recibo = await context.read<ContratosProvider>().registrarPago(
          idContrato: c.idContrato,
          monto: monto,
          metodoPago: _metodoPago,
        );
    if (!mounted) return;
    setState(() => _enviando = false);
    final provider = context.read<ContratosProvider>();
    if (recibo != null) {
      _montoController.clear();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pago registrado. Recibo: $recibo')),
      );
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contratos actualizados.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Error al registrar el pago.')),
      );
    }
  }

  Future<void> _compartirComprobante(int idPago) async {
    setState(() => _descargandoComprobante = true);
    final bytes = await context.read<ContratosProvider>().descargarComprobante(idPago);
    if (!mounted) return;
    setState(() => _descargandoComprobante = false);
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener el comprobante.')),
      );
      return;
    }
    await Share.shareXFiles(
      [
        XFile.fromData(bytes, mimeType: 'application/pdf', name: 'comprobante.pdf'),
      ],
      subject: 'Comprobante de pago - Raíces',
      text: 'Comprobante de pago',
      fileNameOverrides: const ['comprobante.pdf'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contrato;
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.isAdministrator ?? false;
    final comprobanteBusy = _descargandoComprobante || context.watch<ContratosProvider>().isDownloadingComprobante;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Contrato #${c.idContrato}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Chip(
                  label: Text(c.estado),
                  labelStyle: TextStyle(
                    color: c.estado == 'Pagado'
                        ? Colors.green
                        : c.estado == 'En Mora'
                            ? Colors.red
                            : Colors.blueGrey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow('Propiedad', c.propiedad ?? '—'),
            _infoRow('Cliente', c.cliente ?? '—'),
            _infoRow('Agente', c.agente ?? '—'),
            _infoRow('Tipo', c.tipoContrato),
            _infoRow('Inicio', c.fechaInicio),
            _infoRow('Monto total', '\$us ${c.montoTotal.toStringAsFixed(2)}'),
            _infoRow('Saldo pendiente', '\$us ${c.saldoPendiente.toStringAsFixed(2)}'),
            _infoRow('Cuotas pagadas', '${c.cuotasPagadas}/${c.cuotasTotales}'),
            const Divider(height: 28),

            // Pago
            Text('Registrar pago', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _montoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto (\$us)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _metodoPago,
              decoration: const InputDecoration(
                labelText: 'Método de pago',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia')),
                DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                DropdownMenuItem(value: 'QR', child: Text('QR')),
              ],
              onChanged: (value) => setState(() => _metodoPago = value ?? 'Transferencia'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: c.saldoPendiente <= 0 || _enviando ? null : _registrarPago,
                child: _enviando
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Confirmar Pago'),
              ),
            ),
            if (c.saldoPendiente <= 0)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Este contrato ya está pagado.',
                    style: TextStyle(color: Colors.green)),
              ),
            const Divider(height: 28),

            // Pagos
            Text('Historial de pagos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (c.pagos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aún no hay pagos registrados.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...c.pagos.map<Widget>((p) => Card(
                    key: ValueKey(p.idPago),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.receipt_long, color: Colors.teal),
                      title: Text('${p.numeroRecibo} · \$us ${p.monto.toStringAsFixed(2)}'),
                      subtitle: Text('${p.metodoPago} · ${p.fechaPago ?? '—'}'),
                      trailing: IconButton(
                        icon: comprobanteBusy
                            ? const SizedBox(
                                height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.picture_as_pdf, color: Colors.red),
                        tooltip: 'Comprobante PDF',
                        onPressed: comprobanteBusy ? null : () => _compartirComprobante(p.idPago),
                      ),
                    ),
                  )),
            const Divider(height: 28),

            // Cuotas
            Text('Plan de cuotas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (c.cuotas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Sin plan de cuotas.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...c.cuotas.map<Widget>((q) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text('${q.numeroCuota}'),
                      ),
                      title: Text('Cuota ${q.numeroCuota} · \$us ${q.monto.toStringAsFixed(2)}'),
                      subtitle: Text('Vence: ${q.fechaVencimiento.split('T').first}'),
                      trailing: Chip(
                        label: Text(q.estado),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: q.estado == 'Pagada'
                              ? Colors.green
                              : q.estado == 'Vencida'
                                  ? Colors.red
                                  : Colors.blueGrey,
                        ),
                      ),
                    ),
                  )),

            if (isAdmin && c.pagos.isEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final ok = await context.read<ContratosProvider>().eliminarContrato(c.idContrato);
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.read<ContratosProvider>().errorMessage ?? 'Error al eliminar.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Eliminar contrato', style: TextStyle(color: Colors.red)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label, style: const TextStyle(color: Colors.grey)),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}