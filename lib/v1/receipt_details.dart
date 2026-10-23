import 'money.dart';

class ReceiptItem {
  final String name, amountMinor;
  final String? quantity;
  const ReceiptItem(this.name, this.amountMinor, this.quantity);
}

class ReceiptDetails {
  final String? merchant, taxId;
  final List<ReceiptItem> items;
  const ReceiptDetails(this.merchant, this.taxId, this.items);
  factory ReceiptDetails.parse(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final receipt = RegExp(r'\b(boleta|factura|ticket)\b', caseSensitive: false)
        .hasMatch(text);
    if (!receipt) return const ReceiptDetails(null, null, []);
    final items = <ReceiptItem>[];
    for (final line in lines) {
      final match = RegExp(
              r'^(?:(\d+(?:[.,]\d+)?)\s+)?([A-Za-zÁÉÍÓÚÜÑáéíóúüñ][A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9 ._-]*?)\s+S\s*/\.?\s*(\d+(?:[.,]\d{2}))\s*$',
              caseSensitive: false)
          .firstMatch(line);
      if (match == null) continue;
      final name = match[2]!.trim();
      if (RegExp(
              r'\b(total|subtotal|igv|importe|monto|pago|vuelto|descuento|ruc|fecha|caja)\b',
              caseSensitive: false)
          .hasMatch(name)) {
        continue;
      }
      try {
        items.add(ReceiptItem(name, toMinor(match[3]!), match[1]));
      } catch (_) {/* unreadable price stays absent */}
    }
    final first = lines.firstOrNull;
    final merchant = first != null &&
            RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]').hasMatch(first) &&
            !RegExp(r'\b(ruc|boleta|factura|ticket|fecha|hora|caja|total)\b|s\s*/',
                    caseSensitive: false)
                .hasMatch(first)
        ? first
        : null;
    final tax = RegExp(r'\bRUC\s*:?\s*(\d{11})\b', caseSensitive: false)
        .firstMatch(text)
        ?.group(1);
    return ReceiptDetails(merchant, tax, items);
  }
  String? get concept =>
      items.isEmpty ? null : items.map((i) => i.name).join(' · ');
}
