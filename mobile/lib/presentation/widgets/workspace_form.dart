import 'package:flutter/material.dart';

import '../../data/services/api_error.dart';

class WorkspaceField {
  const WorkspaceField(
    this.key,
    this.label, {
    this.required = true,
    this.number = false,
    this.secret = false,
    this.multiline = false,
    this.date = false,
    this.choices,
  });
  final String key, label;
  final bool required, number, secret, multiline, date;
  final Map<String, String>? choices;
}

Future<void> workspaceForm(
  BuildContext context,
  String title,
  List<WorkspaceField> fields,
  Future<void> Function(Map<String, String>) save, {
  Map<String, dynamic> initial = const {},
}) async {
  final controllers = {
    for (final f in fields)
      f.key: TextEditingController(text: '${initial[f.key] ?? ''}'),
  };
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  final page = MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => StatefulBuilder(
      builder: (c, update) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      error!,
                      style: TextStyle(color: Theme.of(c).colorScheme.error),
                    ),
                  ),
                for (final f in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: f.choices != null
                        ? DropdownButtonFormField<String>(
                            key: ValueKey(
                              '${f.key}-${controllers[f.key]!.text}',
                            ),
                            initialValue:
                                f.choices!.containsKey(controllers[f.key]!.text)
                                ? controllers[f.key]!.text
                                : null,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: f.label),
                            items: f.choices!.entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(
                                      e.value,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            validator: (v) =>
                                f.required && (v == null || v.isEmpty)
                                ? 'Selecciona una opción'
                                : null,
                            onChanged: busy
                                ? null
                                : (v) => controllers[f.key]!.text = v ?? '',
                          )
                        : TextFormField(
                            key: ValueKey('field-${f.key}'),
                            controller: controllers[f.key],
                            enabled: !busy,
                            obscureText: f.secret,
                            keyboardType: f.number
                                ? const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  )
                                : f.multiline
                                ? TextInputType.multiline
                                : TextInputType.text,
                            minLines: f.multiline ? 3 : 1,
                            maxLines: f.secret
                                ? 1
                                : f.multiline
                                ? 5
                                : 1,
                            readOnly: f.date,
                            onTap: f.date
                                ? () async {
                                    final picked = await showDatePicker(
                                      context: c,
                                      initialDate:
                                          DateTime.tryParse(
                                            controllers[f.key]!.text,
                                          ) ??
                                          DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null)
                                      update(
                                        () => controllers[f.key]!.text = picked
                                            .toIso8601String()
                                            .substring(0, 10),
                                      );
                                  }
                                : null,
                            decoration: InputDecoration(
                              labelText: f.label,
                              suffixIcon: f.date
                                  ? const Icon(Icons.calendar_month)
                                  : null,
                            ),
                            validator: (v) {
                              if (f.required && (v ?? '').trim().isEmpty)
                                return 'Este campo es obligatorio';
                              if (f.number &&
                                  (v ?? '').isNotEmpty &&
                                  num.tryParse(v!.replaceAll(',', '.')) == null)
                                return 'Ingresa un número válido';
                              return null;
                            },
                          ),
                  ),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          update(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await save({
                              for (final e in controllers.entries)
                                e.key: e.value.text.trim(),
                            });
                            if (c.mounted) Navigator.pop(c);
                          } catch (e) {
                            if (c.mounted)
                              update(() {
                                error = apiError(e);
                                busy = false;
                              });
                          }
                        },
                  icon: const Icon(Icons.check),
                  label: Text(busy ? 'Guardando…' : 'Guardar cambios'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await Navigator.of(context).push(page);
  await page.completed;
  for (final controller in controllers.values) {
    controller.dispose();
  }
}
