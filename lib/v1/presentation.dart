/// Presentation only. API dates and integer cents are never changed here.
const spanishMonths = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre'
];

String firstName(Object? name) =>
    name?.toString().trim().split(RegExp(r'\s+')).firstOrNull ?? '';

String dateEs(Object? value, {String? today}) {
  final raw = value?.toString() ?? '';
  final d = DateTime.tryParse(raw);
  if (d == null) return 'Fecha no disponible';
  final label = '${d.day} de ${spanishMonths[d.month - 1]}';
  return raw == today ? 'Hoy, $label' : '$label de ${d.year}';
}

String periodEs(Object? from, Object? to, {required String today}) {
  final a = DateTime.tryParse(from?.toString() ?? ''),
      b = DateTime.tryParse(to?.toString() ?? '');
  if (a == null || b == null) return 'Periodo no disponible';
  if (from == to) return dateEs(from, today: today);
  if (a.year == b.year && a.month == b.month) {
    return 'Del ${a.day} al ${b.day} de ${spanishMonths[b.month - 1]} de ${b.year}';
  }
  return 'Del ${dateEs(from)} al ${dateEs(to)}';
}

String monthEs(Object? value) {
  final d = DateTime.tryParse('$value-01');
  return d == null
      ? 'Mes no disponible'
      : '${spanishMonths[d.month - 1]} de ${d.year}';
}

String stateEs(Object? value) => switch (value) {
      'CONFIRMADO' => 'Confirmado',
      'ANULADO' => 'Anulado',
      _ => value?.toString() ?? '',
    };

/// Server timestamps are UTC; commercial dates are already local dates.
String timestampEs(Object? value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return 'Fecha no disponible';
  final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
  final parsed = DateTime.tryParse(
      RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(normalized)
          ? normalized
          : '${normalized}Z');
  if (parsed == null) return 'Fecha no disponible';
  final local = parsed.toUtc().subtract(const Duration(hours: 5));
  return '${dateEs(local.toIso8601String().substring(0, 10))} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
