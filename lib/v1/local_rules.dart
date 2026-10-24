import 'api_client.dart';
import 'money.dart';
import 'receipt_details.dart';

String _plain(String value) {
  var text = value.toLowerCase();
  for (final pair
      in {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'}.entries) {
    text = text.replaceAll(pair.key, pair.value);
  }
  return text.replaceAll(RegExp('[\u0300-\u036f]'), '').replaceAllMapped(
      RegExp(
          r'\bveinti\s+(un|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve)\b'),
      (m) => 'veinti${m[1]}');
}

const _small = {
  'un': 1,
  'uno': 1,
  'una': 1,
  'dos': 2,
  'tres': 3,
  'cuatro': 4,
  'cinco': 5,
  'seis': 6,
  'siete': 7,
  'ocho': 8,
  'nueve': 9,
  'diez': 10,
  'once': 11,
  'doce': 12,
  'trece': 13,
  'catorce': 14,
  'quince': 15,
  'dieciseis': 16,
  'diecisiete': 17,
  'dieciocho': 18,
  'diecinueve': 19,
  'veinte': 20,
  'veintiuno': 21,
  'veintiun': 21,
  'veintidos': 22,
  'veintitres': 23,
  'veinticuatro': 24,
  'veinticinco': 25,
  'veintiseis': 26,
  'veintisiete': 27,
  'veintiocho': 28,
  'veintinueve': 29
};
const _tens = {
  'veinte': 20,
  'treinta': 30,
  'cuarenta': 40,
  'cincuenta': 50,
  'sesenta': 60,
  'setenta': 70,
  'ochenta': 80,
  'noventa': 90
};
const _hundreds = {
  'cien': 100,
  'ciento': 100,
  'doscientos': 200,
  'trescientos': 300,
  'cuatrocientos': 400,
  'quinientos': 500,
  'seiscientos': 600,
  'setecientos': 700,
  'ochocientos': 800,
  'novecientos': 900
};
int? _belowThousand(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  var n = 0;
  if (words.isEmpty) return null;
  if (_hundreds.containsKey(words.first)) {
    n = _hundreds[words.removeAt(0)]!;
    if (words.isEmpty) return n;
  }
  if (words.length == 1 && _small.containsKey(words.first)) {
    return n + _small[words.first]!;
  }
  if (_tens.containsKey(words.first)) {
    n += _tens[words.removeAt(0)]!;
    if (words.isEmpty) return n;
    if (words.length == 2 &&
        words.first == 'y' &&
        (_small[words.last] ?? 99) < 10) {
      return n + _small[words.last]!;
    }
  }
  return null;
}

/// Texto con varios renglones, cada uno con su importe:
/// "comida para perro 10 soles, hueso de juguete 15 soles".
/// Devuelve los renglones solo si TODO el texto encaja; si no, lista vacía
/// y se conserva el comportamiento anterior (pedir el total).
List<ReceiptItem> parseMoneyList(String text) {
  final plain = _plain(text);
  final source = plain.length == text.length ? text : plain;
  final words = [..._small.keys, ..._tens.keys, ..._hundreds.keys, 'mil', 'y']
      .join('|');
  final amount = RegExp(
      '(\\d+(?:[.,]\\d{1,2})?|(?:(?:$words)\\s+){0,6}(?:$words))\\s+(?:sol(?:es)?|pesos?|dolar(?:es)?|bolivianos?)\\b');
  final found = amount.allMatches(plain).toList();
  if (found.length < 2) return const [];
  // "Vendí 50 soles de arroz, vendí 10 soles de aceite": el nombre va
  // después del importe y el mismo verbo puede repetirse.
  final lead = RegExp(r'^\s*((?:vendi|gaste|compre|pague|cobre|fie)\b)?\s*$')
      .firstMatch(plain.substring(0, found.first.start));
  if (lead != null) {
    final first = lead[1];
    final verbs = RegExp(r'(?:vendi|gaste|compre|pague|cobre|fie)\b');
    final named = <ReceiptItem>[];
    for (var i = 0; i < found.length; i++) {
      final m = found[i];
      final end = i + 1 < found.length ? found[i + 1].start : plain.length;
      var seg = plain.substring(m.end, end);
      var shown = source.substring(m.end, end);
      if (i + 1 < found.length) {
        final tail = RegExp(
                r'[\s,;.]*(?:\b(?:y|e|mas)\b)?\s*(?:(vendi|gaste|compre|pague|cobre|fie)\b)?\s*$')
            .firstMatch(seg)!;
        if (tail[1] != null && tail[1] != first) return const [];
        seg = seg.substring(0, tail.start);
        shown = shown.substring(0, tail.start);
      }
      final head = RegExp(r'^[\s,;.:]*(?:(?:de|del|en|por|para)\s+)?')
          .firstMatch(seg)!;
      shown = shown.substring(head.end).replaceFirst(RegExp(r'[\s,;.:]+$'), '');
      if (!RegExp(r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ][A-Za-zÁÉÍÓÚÜÑáéíóúüñ ._-]{1,59}$')
              .hasMatch(shown) ||
          verbs.hasMatch(_plain(shown)) ||
          RegExp(r'\b(?:cada|c/u|unidad)\b', caseSensitive: false)
              .hasMatch(shown)) {
        return const [];
      }
      final raw = m[1]!;
      final minor = _numeric(raw) ??
          (() {
            final n = _spoken(raw);
            return n == null || n <= 0
                ? null
                : (BigInt.from(n) * BigInt.from(100)).toString();
          })();
      if (minor == null) return const [];
      named.add(ReceiptItem(shown[0].toUpperCase() + shown.substring(1), minor, null));
    }
    return named;
  }
  final items = <ReceiptItem>[];
  var from = 0;
  for (var i = 0; i < found.length; i++) {
    final m = found[i];
    var name = source.substring(from, m.start);
    from = m.end;
    name = name
        .replaceFirst(RegExp(r'^(?:[\s,;.:]|\b(?:y|e|mas)\b)+', caseSensitive: false), '')
        .replaceFirst(RegExp(r'[\s,;.:]+$'), '');
    // Un verbo (vendí, gasté...) solo se acepta al inicio; si aparece entre
    // renglones son varias operaciones y se pide el total.
    final verb = RegExp(r'^(?:vendi|gaste|compre|pague|cobre|fie)\b\s*')
        .firstMatch(_plain(name));
    if (verb != null) {
      if (i > 0) return const [];
      name = name.substring(verb.end);
    }
    if (!RegExp(r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ][A-Za-zÁÉÍÓÚÜÑáéíóúüñ ._-]{1,59}$')
            .hasMatch(name) ||
        RegExp(r'\b(?:cada|c/u|unidad)\b', caseSensitive: false)
            .hasMatch(name)) {
      return const [];
    }
    final raw = m[1]!;
    final minor = _numeric(raw) ??
        (() {
          final n = _spoken(raw);
          return n == null || n <= 0
              ? null
              : (BigInt.from(n) * BigInt.from(100)).toString();
        })();
    if (minor == null) return const [];
    items.add(ReceiptItem(name[0].toUpperCase() + name.substring(1), minor, null));
  }
  // Nada de texto suelto después del último importe.
  if (RegExp(r'[a-z0-9]').hasMatch(plain.substring(found.last.end))) {
    return const [];
  }
  return items;
}

int? _spoken(String value) {
  final parts = value.trim().split(RegExp(r'\s*\bmil\b\s*'));
  if (parts.length == 1) return _belowThousand(value);
  if (parts.length != 2) return null;
  final thousands = parts.first.isEmpty ? 1 : _belowThousand(parts.first),
      rest = parts.last.isEmpty ? 0 : _belowThousand(parts.last);
  return thousands == null || rest == null ? null : thousands * 1000 + rest;
}

String? _numeric(String raw) {
  var value = raw.trim();
  if (value.contains(' ')) {
    if (!RegExp(r'^\d{1,3}(?: \d{3})+(?:[.,]\d{1,2})?$').hasMatch(value)) {
      return null;
    }
    value = value.replaceAll(' ', '');
  }
  if (value.contains(',') && value.contains('.')) {
    final decimal = value.lastIndexOf(',') > value.lastIndexOf('.') ? ',' : '.';
    final thousands = decimal == ',' ? '.' : ',';
    if (!RegExp('^\\d{1,3}(?:\\$thousands\\d{3})*\\$decimal\\d{2}\$')
        .hasMatch(value)) {
      return null;
    }
    value = value.replaceAll(thousands, '').replaceAll(decimal, '.');
  } else if (RegExp(r'^\d{1,3}(?:[,.]\d{3})+$').hasMatch(value)) {
    value = value.replaceAll(RegExp(r'[,.]'), '');
  } else {
    value = value.replaceAll(',', '.');
  }
  try {
    return toMinor(value);
  } catch (_) {
    return null;
  }
}

/// Deterministic proposals only. These rules never create financial records.
class LocalRules {
  /// Cloud audio transcription still goes through the same local intent rules.
  /// Only resolve an unambiguous voice intent when both amounts agree. Image
  /// payment classification and server extraction identities remain unchanged.
  Json reconcileVoice(String transcription, Json remote) {
    final local = interpret(transcription, source: 'VOZ');
    if (local['intencion'] == 'DESCONOCIDO' ||
        local['monto_minor'] == null ||
        local['monto_minor'] != remote['monto_minor']) {
      return remote;
    }
    return {
      ...remote,
      'intencion': local['intencion'],
      'es_pago': false,
      'pregunta': null,
    };
  }

  Json interpret(String input, {String source = 'TEXTO', String? today}) {
    final text = input.trim(),
        plain = _plain(text),
        date = today ?? limaToday();
    final image = source == 'IMAGEN';
    final payment = image &&
        RegExp(r'\b(yape|plin|yapeaste|transferencia|transferiste|pago recibido)\b')
            .hasMatch(plain);
    final intents = <String>{};
    if (RegExp(r'\b(vendi|venta|vendido|fie|fiado)\b').hasMatch(plain)) {
      intents.add('VENTA');
    }
    if (RegExp(r'\b(gaste|gasto)\b').hasMatch(plain) ||
        RegExp(r'\bpague\s+(?:la\s+|el\s+|mi\s+|los\s+|las\s+)?(?:luz|agua|alquiler|internet|pasajes?|sueldos?|telefono|gas|recibo)\b')
            .hasMatch(plain)) {
      intents.add('GASTO_OPERATIVO');
    }
    if (RegExp(r'\b(compre|compra)\b').hasMatch(plain)) {
      intents.add('COMPRA_MERCADERIA');
    }
    if (RegExp(r'\b(abono|abonaron|me pago|me pagaron|me cancelo|me cancelaron|me devolvieron)\b')
            .hasMatch(plain) ||
        RegExp(r'\bcobre\b').hasMatch(plain) &&
            RegExp(r'\b(deuda|fiado|pendiente|cuenta)\b').hasMatch(plain)) {
      intents.add('COBRO');
    }
    if (RegExp(r'\bpague\b').hasMatch(plain) &&
        RegExp(r'\b(deuda|pendiente|proveedor)\b').hasMatch(plain)) {
      intents.add('PAGO');
    }
    if (RegExp(r'\b(entre mis cuentas|a mi otra cuenta)\b').hasMatch(plain)) {
      intents.add('TRANSFERENCIA');
    }
    var kind = !image && intents.length == 1 ? intents.single : 'DESCONOCIDO';
    if (RegExp(r'\b(no|nunca)\s+(vendi|gaste|compre|fie|pague)\b')
        .hasMatch(plain)) {
      kind = 'DESCONOCIDO';
    }
    final amounts = <String>{};
    var ambiguousAmount = false;
    final listItems = parseMoneyList(text);
    final listed = listItems.length >= 2 && intents.length <= 1;
    if (listed) {
      amounts.add(listItems
          .fold<BigInt>(BigInt.zero, (sum, i) => sum + BigInt.parse(i.amountMinor))
          .toString());
    }
    final vocabulary = [
      ..._small.keys,
      ..._tens.keys,
      ..._hundreds.keys,
      'mil',
      'y',
      'cero'
    ].join('|');
    final pair = RegExp(
        '((?:(?:$vocabulary)\\s+){0,8}(?:$vocabulary|\\d+))\\s+con\\s+((?:(?:$vocabulary)\\s+){0,4}(?:$vocabulary|\\d+))\\s+(?:sol(?:es)?|pesos?|dolar(?:es)?|bolivianos?)\\b');
    final moneyText = plain.replaceAllMapped(pair, (m) {
      final whole = m[1] == 'cero' ? 0 : int.tryParse(m[1]!) ?? _spoken(m[1]!);
      final cents = m[2] == 'cero' ? 0 : int.tryParse(m[2]!) ?? _spoken(m[2]!);
      if (whole == null || cents == null || cents > 99) {
        return ' importe por aclarar ';
      }
      return '$whole.${cents.toString().padLeft(2, '0')} soles';
    });
    final totals = RegExp(
        r'^\s*(?:importe total|monto total|total(?: a pagar)?|monto|importe)\s*[:\-]?\s*(?:s\s*/\.?\s*)?(\d[\d., ]*)\s*(?:soles)?\s*$',
        multiLine: true);
    if (image) {
      final matches = totals.allMatches(plain).toList();
      final explicit = matches
          .where((m) => RegExp(r'^\s*(?:total\b|importe total\b|monto total\b)')
              .hasMatch(m[0]!))
          .toList();
      for (final m in explicit.isNotEmpty ? explicit : matches) {
        final n = _numeric(m[1]!);
        if (n != null) amounts.add(n);
      }
    }
    final receipt = image &&
        RegExp(r'\b(boleta|ticket|factura|subtotal|igv)\b').hasMatch(plain);
    if (amounts.isEmpty && !receipt) {
      for (final pattern in [
        RegExp(r'\bs/\.?\s*(\d(?:[\d., ]*\d)?)'),
        RegExp(r'\b(\d(?:[\d., ]*\d)?)\s*(?:sol(?:es)?|pesos?|dolar(?:es)?|bolivianos?)\b')
      ]) {
        for (final m in pattern.allMatches(moneyText)) {
          // Do not turn a partially recognised mixed number into its last digit:
          // "doscientos y 3 soles" needs review, it does not mean S/3.
          final prefix = moneyText.substring(0, m.start).trimRight();
          if (RegExp('\\b(?:$vocabulary)\\s*\$').hasMatch(prefix)) {
            ambiguousAmount = true;
            continue;
          }
          final n = _numeric(m[1]!);
          if (n != null) amounts.add(n);
        }
      }
      final numberWords = [
        ..._small.keys,
        ..._tens.keys,
        ..._hundreds.keys,
        'mil',
        'y'
      ].join('|');
      final spoken = RegExp(
          '((?:(?:$numberWords)\\s+){0,8}(?:$numberWords))\\s+(?:sol(?:es)?|pesos?|dolar(?:es)?|bolivianos?)\\b');
      for (final m in spoken.allMatches(moneyText)) {
        final n = _spoken(m[1]!);
        if (n != null && n > 0) {
          amounts.add((BigInt.from(n) * BigInt.from(100)).toString());
        }
      }
    }
    // Currency may be omitted only in an explicit, bounded commercial clause.
    // Never treat a product count ("vendí 3 panes") as money.
    if (!image && amounts.isEmpty && kind != 'DESCONOCIDO') {
      final atom =
          '(\\d+(?:[.,]\\d{1,2})?|(?:(?:$vocabulary)\\s+){0,8}(?:$vocabulary))';
      final patterns = <RegExp>[
        if (kind == 'COMPRA_MERCADERIA' ||
            kind == 'GASTO_OPERATIVO' ||
            kind == 'VENTA')
          RegExp('\\bpor\\s+$atom\\s*\$'),
        if (kind == 'VENTA' && plain.contains('fiado'))
          RegExp('\\bfiado\\s+$atom\\s+de\\s+'),
        if (kind == 'COBRO')
          RegExp('^me\\s+(?:abonaron|abono|pagaron|pago)\\s+$atom\\s*\$'),
      ];
      for (final pattern in patterns) {
        final candidate = pattern.firstMatch(plain)?.group(1);
        final numeric = candidate == null ? null : _numeric(candidate);
        final spoken = candidate == null ? null : _spoken(candidate);
        final n = numeric ??
            (spoken == null || spoken <= 0
                ? null
                : (BigInt.from(spoken) * BigInt.from(100)).toString());
        if (n != null) amounts.add(n);
      }
      // More than one numeric value requires review, even in these clauses.
      if (RegExp(r'\d+(?:[.,]\d+)?').allMatches(plain).length > 1) {
        ambiguousAmount = true;
      }
    }
    // "3 gaseosas a 2 soles" or "2 soles cada una" is a unit price, not the
    // total: never save S/2.00 for a S/6.00 sale. The user is asked for the total.
    if (!image &&
        kind != 'DESCONOCIDO' &&
        (RegExp(r'\b(cada\s+(?:uno|una|u)|c\s*/\s*u|la\s+unidad|por\s+unidad|x\s+unidad)\b')
                .hasMatch(plain) ||
            RegExp(r'\b(?:[2-9]|\d{2,}|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|docena|media docena)\s+(?!(?:sol(?:es)?|pesos?|dolar(?:es)?|bolivianos?)\b|s/)(?:[a-z]+\s+){0,3}(?:a|x)\s+(?:s/\.?\s*)?\d')
                .hasMatch(plain))) {
      ambiguousAmount = true;
    }
    String? amount = amounts.length == 1 ? amounts.single : null;
    if (ambiguousAmount ||
        RegExp(r'\b(millon|millones|billon|billones)\b').hasMatch(plain)) {
      amount = null;
    }
    if (RegExp(r'(^|[^0-9a-z])[-−]\s*\d').hasMatch(plain)) amount = null;
    final cents =
        RegExp(r'\b(?:sol(?:es)?|pesos?|dolar(?:es)?|bolivianos?)\s+con\s+([a-z ]+|\d{1,2})\s+cent(?:imos|avos)\b')
            .firstMatch(plain);
    if (cents != null && amount != null) {
      final coin = int.tryParse(cents[1]!.trim()) ?? _spoken(cents[1]!);
      if (coin == null ||
          coin > 99 ||
          BigInt.parse(amount) % BigInt.from(100) != BigInt.zero) {
        amount = null;
      } else {
        amount = (BigInt.parse(amount) + BigInt.from(coin)).toString();
      }
    }
    if (amount != null &&
        BigInt.parse(amount) > BigInt.parse('100000000000000')) {
      amount = null;
    }
    String? when;
    final explicitDates = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b')
        .allMatches(plain)
        .map((m) => '${m[3]}-${m[2]!.padLeft(2, '0')}-${m[1]!.padLeft(2, '0')}')
        .toSet();
    explicitDates.addAll(
        RegExp(r'\b\d{4}-\d{2}-\d{2}\b').allMatches(plain).map((m) => m[0]!));
    const months = {
      'ene': 1,
      'enero': 1,
      'feb': 2,
      'febrero': 2,
      'mar': 3,
      'marzo': 3,
      'abr': 4,
      'abril': 4,
      'may': 5,
      'mayo': 5,
      'jun': 6,
      'junio': 6,
      'jul': 7,
      'julio': 7,
      'ago': 8,
      'agosto': 8,
      'sep': 9,
      'set': 9,
      'septiembre': 9,
      'setiembre': 9,
      'oct': 10,
      'octubre': 10,
      'nov': 11,
      'noviembre': 11,
      'dic': 12,
      'diciembre': 12
    };
    for (final m
        in RegExp(r'\b(\d{1,2})\s+(?:de\s+)?([a-z]+)\.?\s+(?:de\s+)?(\d{4})\b')
            .allMatches(plain)) {
      final month = months[m[2]];
      if (month != null) {
        explicitDates.add(
            '${m[3]}-${month.toString().padLeft(2, '0')}-${m[1]!.padLeft(2, '0')}');
      }
    }
    if (explicitDates.length == 1) {
      final value = explicitDates.single, d = DateTime.tryParse(value);
      if (d != null && d.toIso8601String().startsWith(value)) when = value;
    } else if (explicitDates.isEmpty &&
        RegExp(r'\bhoy\b').hasMatch(plain) &&
        !RegExp(r'\bayer\b').hasMatch(plain)) {
      when = date;
    } else if (explicitDates.isEmpty &&
        RegExp(r'\bayer\b').hasMatch(plain) &&
        !RegExp(r'\bhoy\b').hasMatch(plain)) {
      when = DateTime.parse(date)
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
    }
    String? person;
    if (kind == 'VENTA' && RegExp(r'\b(fie|fiado)\b').hasMatch(plain)) {
      person = RegExp(r'\ba\s+([a-zñ]+(?:\s+[a-zñ]+){0,2})\s*$')
          .firstMatch(plain)
          ?.group(1);
    } else if (kind == 'COBRO') {
      person = RegExp(
              r'^(?:hoy\s+|ayer\s+)?([a-zñ]+(?:\s+[a-zñ]+){0,2})\s+me\s+(?:abono|pago)\b')
          .firstMatch(plain)
          ?.group(1);
    }
    if (person != null) person = person[0].toUpperCase() + person.substring(1);
    final channels = <String>{
      if (RegExp(r'\befectivo\b').hasMatch(plain)) 'EFECTIVO',
      if (RegExp(r'\b(yape|yapeaste)\b').hasMatch(plain)) 'YAPE',
      if (RegExp(r'\bplin\b').hasMatch(plain)) 'PLIN',
      if (!image && RegExp(r'\btransferencia\b').hasMatch(plain))
        'TRANSFERENCIA',
    };
    // A wallet receipt may say "transferencia exitosa": the explicit wallet
    // identifies the medium, while transferencia alone is a generic fallback.
    if (channels.isEmpty && RegExp(r'\btransferencia\b').hasMatch(plain)) {
      channels.add('TRANSFERENCIA');
    }
    final medium = channels.length == 1 ? channels.single : null;
    String? reference;
    if (image) {
      final ref = RegExp(
              r'(?:referencia|(?:numero|nro\.?|n[°ºo.]?)\s*(?:de\s*)?operacion|operacion)\s*[:#]?\s*(?:(?:numero|nro\.?|n[°ºo.]?)\s*[:#]?\s*)?([a-z0-9-]{4,50})')
          .firstMatch(plain)
          ?.group(1);
      if (ref != null && RegExp(r'\d').hasMatch(ref)) {
        reference = ref.toUpperCase();
      }
    }
    var concept = RegExp(
            r'\b(?:sol(?:es)?|pesos?|dolar(?:es)?|bolivianos?)\s+(?:de|en|son)\s+(.+?)(?:\s+(?:por yape|por plin|en efectivo|ayer|hoy)|$)')
        .firstMatch(plain)
        ?.group(1);
    if (kind == 'VENTA' && plain.contains('fiado') && concept == null) {
      concept =
          RegExp(r'\bfiado\s+(?:\d+(?:[.,]\d{1,2})?|[a-z ]+)\s+de\s+(.+)$')
              .firstMatch(plain)
              ?.group(1);
    }
    if (kind == 'COMPRA_MERCADERIA' && plain.contains('mercaderia')) {
      concept = 'Mercadería';
    }
    if (kind == 'VENTA' && person != null && concept == null) {
      concept = 'Fiado a $person';
    }
    if (kind == 'COBRO') {
      concept = person == null ? 'Abono recibido' : 'Abono de $person';
    }
    if (kind == 'PAGO' && concept == null) concept = 'Pago de deuda';
    if (image) {
      final labels = RegExp(
              r'^\s*(?:concepto|descripcion|detalle)\s*:\s*(\S[^\r\n]*)$',
              multiLine: true,
              caseSensitive: false)
          .allMatches(text)
          .map((m) => m[1]!.trim())
          .toSet();
      concept = labels.length == 1
          ? labels.single
          : payment
              ? 'Comprobante de pago'
              : null;
      concept ??= ReceiptDetails.parse(text).concept;
    }
    if (listed) concept = listItems.map((i) => i.name).join(' · ');
    if (concept != null && concept.length > 240) {
      concept = concept.substring(0, 240);
    }
    return {
      'intencion': kind,
      'monto_minor': amount,
      'concepto': concept,
      'fecha': when,
      'persona': person,
      'referencia': reference,
      'medio': medium,
      'fiado': kind == 'VENTA' &&
          RegExp(r'\b(fie|fiado|a\s+credito|queda(?:ron)?\s+debiendo|quedo\s+debiendo|me\s+deb(?:e|en))\b')
              .hasMatch(plain),
      'es_pago': payment,
      'pregunta': kind == 'DESCONOCIDO'
          ? (RegExp(r'\bme\s+(?:yapearon|plinearon|depositaron|transfirieron)\b|\bcobre\b')
                  .hasMatch(plain)
              ? '¿Fue una venta nueva o te pagaron una deuda?'
              : '¿Fue una venta, un gasto o un cobro?')
          : amount == null
              ? '¿Cuánto fue en total?'
              : null,
      'texto_visible': text.length > 6000 ? text.substring(0, 6000) : text
    };
  }
}
