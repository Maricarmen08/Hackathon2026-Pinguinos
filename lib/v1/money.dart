String toMinor(String input, {bool zero = false}) {
  final value = input.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,13}(\.\d{1,2})?$').hasMatch(value)) {
    throw const FormatException(
        'Escribe un monto válido con hasta dos decimales.');
  }
  final parts = value.split('.');
  final n = BigInt.parse(parts[0]) * BigInt.from(100) +
      BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
  if (n > BigInt.parse('100000000000000') ||
      (zero ? n < BigInt.zero : n <= BigInt.zero)) {
    throw const FormatException(
        'El monto debe ser positivo y estar dentro del límite.');
  }
  return n.toString();
}

String soles(Object? minor) {
  if (minor == null) return 'Sin historial';
  final n = BigInt.parse(minor.toString()),
      a = BigInt.parse(minor.toString()).abs();
  final integer = (a ~/ BigInt.from(100))
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return '${n.isNegative ? '-' : ''}S/ $integer.${(a % BigInt.from(100)).toString().padLeft(2, '0')}';
}

String limaToday() => DateTime.now()
    .toUtc()
    .subtract(const Duration(hours: 5))
    .toIso8601String()
    .substring(0, 10);
