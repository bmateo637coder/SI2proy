Map<String, dynamic> localCommercialPlan(String text) {
  var t = text.toLowerCase();
  for (final e in {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u'}.entries) {
    t = t.replaceAll(e.key, e.value);
  }
  bool has(String pattern) => RegExp(pattern).hasMatch(t);
  final category = has('anticr')
      ? 'Anticretico'
      : has('alquil|renta|arriend')
      ? 'Alquiler'
      : has('visit|conocer|ver el|ver la|recorrer')
      ? 'Visita'
      : has('precio|cuanto|costo|rebaja|descuento|negoci')
      ? 'Precio'
      : has('compr|venta|adquirir')
      ? 'Compra'
      : 'Otro';
  final urgency =
      has('urgente|hoy|ya mismo|inmediat|firmar|cerrar trato|reservar')
      ? 'Alta'
      : has('solo informacion|curiosidad|mas adelante|el proximo ano')
      ? 'Baja'
      : 'Media';
  final action =
      {
        'Visita': 'Coordinar fecha y confirmar la visita',
        'Precio': 'Preparar propuesta y revisar presupuesto',
        'Compra': 'Seleccionar inmuebles para compra',
        'Alquiler': 'Revisar requisitos y opciones de alquiler',
        'Anticretico': 'Revisar condiciones de anticrético',
      }[category] ??
      'Aclarar necesidades y preferencias';
  final titles = [
    'Contactar al interesado y validar sus datos',
    action,
    'Registrar resultado y siguiente contacto en la oportunidad',
  ];
  return {
    'categoria': category,
    'urgencia': urgency,
    'modo': 'reglas_offline',
    'justificacion': 'Clasificación por palabras clave; el servidor revisará el plan al sincronizar.',
    'estado': 'Pendiente',
    'tareas': List.generate(
      titles.length,
      (i) => {
        'titulo': titles[i],
        'completada': false,
        'vence': DateTime.now()
            .add(
              Duration(
                days:
                    (urgency == 'Alta'
                        ? 0
                        : urgency == 'Baja'
                        ? 3
                        : 1) +
                    i,
              ),
            )
            .toIso8601String()
            .substring(0, 10),
      },
    ),
  };
}
