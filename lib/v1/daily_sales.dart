import 'api_client.dart';

/// A server-confirmed civil day with UTC boundaries from the business time zone.
/// A cached amount is never rolled forward to another day or another business.
class DailySales {
  final String day, amount;
  final DateTime start, end;
  const DailySales(this.day, this.amount, this.start, this.end);
  static DailySales? parse(Json? json, String businessId) {
    if (json == null ||
        json['negocio_id'] != businessId ||
        json['fecha'] != json['desde'] ||
        json['fecha'] != json['hasta']) {
      return null;
    }
    final day = json['fecha'], amount = json['ventas_minor'];
    final start =
        DateTime.tryParse(json['vigente_desde_utc']?.toString() ?? '');
    final end = DateTime.tryParse(json['vigente_hasta_utc']?.toString() ?? '');
    if (day is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) ||
        amount is! String ||
        !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(amount) ||
        start == null ||
        end == null ||
        !end.isAfter(start)) {
      return null;
    }
    return DailySales(day, amount, start.toUtc(), end.toUtc());
  }

  bool isToday(DateTime now) =>
      !now.toUtc().isBefore(start) && now.toUtc().isBefore(end);
}
