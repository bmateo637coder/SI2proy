import 'package:flutter/material.dart';
import '../../data/models/propiedad_model.dart';
import 'package:go_router/go_router.dart';

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

  void _confirmarVisita() {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona fecha y hora'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // TODO: Conectar con el backend para guardar la visita
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Visita agendada con éxito!'),
        backgroundColor: Colors.green,
      ),
    );
    context.pop(); // Volver al detalle
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
      appBar: AppBar(
        title: const Text('Agendar Visita'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.propiedad.titulo,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.propiedad.direccion,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            Text('Selecciona la Fecha', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                    const SizedBox(width: 16),
                    Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Toca para seleccionar fecha',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedDate != null ? Colors.black87 : Colors.grey[600],
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                        color: _selectedTime != null ? Colors.black87 : Colors.grey[600],
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
              onPressed: _confirmarVisita,
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
