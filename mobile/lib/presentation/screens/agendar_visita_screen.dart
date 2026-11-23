import 'package:flutter/material.dart';

import '../../data/models/propiedad_model.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/services/sprint4_service.dart';
import '../providers/auth_provider.dart';

class AgendarVisitaScreen extends StatefulWidget {
  final PropiedadModel propiedad;

  const AgendarVisitaScreen({super.key, required this.propiedad});

  @override
  State<AgendarVisitaScreen> createState() => _AgendarVisitaScreenState();
}

class _AgendarVisitaScreenState extends State<AgendarVisitaScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _notasController = TextEditingController();
  bool _submitting = false;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _confirmarVisita() async {
    if (_submitting) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona fecha y hora'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final auth = context.read<AuthProvider>();
      final service = context.read<Sprint4Service>();
      int? customer;
      if (service.staff) {
        if (!auth.canWrite)
          throw StateError(
            'Selecciona una inmobiliaria concreta antes de agendar.',
          );
        final customers =
            await service.get('/modulo_inmuebles/clientes') as List;
        if (!mounted) return;
        customer = await showDialog<int>(
          context: context,
          builder: (c) => SimpleDialog(
            title: const Text('Cliente de la visita'),
            children: [
              if (customers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Registra un cliente antes de agendar.'),
                ),
              for (final client in customers)
                SimpleDialogOption(
                  onPressed: () =>
                      Navigator.pop(c, client['id_cliente'] as int),
                  child: Text('${client['nombre']}'),
                ),
            ],
          ),
        );
        if (customer == null) return;
      }
      final date = _selectedDate!, time = _selectedTime!;
      final moment = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      final result = await service.mutate('POST', '/api/visitas', {
        'id_propiedad': widget.propiedad.idPropiedad,
        if (customer != null) 'id_cliente': customer,
        'fecha_hora': moment.toUtc().toIso8601String(),
        'comentario': _notasController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['pendiente'] == true
                ? 'Visita guardada en el teléfono. Se confirmará al sincronizar.'
                : 'Visita confirmada por el servidor.',
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError ? '${e.message}' : 'No se pudo confirmar la visita. Revisa Sincronización de servicios.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Agendar Visita'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.propiedad.titulo,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.propiedad.direccion,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            Text('Selecciona la Fecha', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Toca para seleccionar fecha',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedDate != null
                            ? Colors.black87
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text('Selecciona la Hora', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: theme.colorScheme.primary),
                    const SizedBox(width: 16),
                    Text(
                      _selectedTime != null
                          ? _selectedTime!.format(context)
                          : 'Toca para seleccionar hora',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedTime != null
                            ? Colors.black87
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text('Notas Adicionales', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _notasController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Ej. Necesito ver especialmente el patio trasero...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),

            const SizedBox(height: 40),
            FilledButton(
              onPressed: _submitting ? null : _confirmarVisita,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Confirmar Visita',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
