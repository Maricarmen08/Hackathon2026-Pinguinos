import 'dart:math' as math;
import 'package:flutter/painting.dart';

class OcrLine {
  final String text;
  final Rect box;
  final double angle;
  const OcrLine(this.text, this.box, [this.angle = 0]);
}

/// Reconstruct spatial rows, rather than trusting block/column enumeration.
/// Only joins non-overlapping columns at the same baseline; never invents text.
String orderOcrLines(List<OcrLine> lines, String raw) {
  final valid = lines
      .where((l) =>
          l.text.trim().isNotEmpty && l.box.height > 0 && l.box.width > 0)
      .toList();
  if (valid.isEmpty) return raw;
  final angles = valid.map((l) => l.angle).toList()..sort();
  final median = angles[angles.length ~/ 2];
  final quarter = (median / 90).round() * 90;
  final radians =
      ((median - quarter).abs() <= 15 ? quarter : 0) * math.pi / 180;
  final c = math.cos(radians), s = math.sin(radians);
  final transformed = valid.map((l) {
    final p = l.box.center;
    return OcrLine(
        l.text.trim(),
        Rect.fromCenter(
            center: Offset(c * p.dx + s * p.dy, -s * p.dx + c * p.dy),
            width: c.abs() * l.box.width + s.abs() * l.box.height,
            height: s.abs() * l.box.width + c.abs() * l.box.height));
  }).toList()
    ..sort((a, b) => a.box.center.dy.compareTo(b.box.center.dy));
  final rows = <List<OcrLine>>[];
  for (final line in transformed) {
    List<OcrLine>? closest;
    var best = double.infinity;
    for (final row in rows.reversed.take(4)) {
      final anchor = row.first.box;
      final distance = (anchor.center.dy - line.box.center.dy).abs();
      final threshold = math.min(anchor.height, line.box.height) * .65;
      final overlap = row.any((l) =>
          math.min(l.box.right, line.box.right) >
          math.max(l.box.left, line.box.left));
      if (!overlap && distance <= threshold && distance < best) {
        closest = row;
        best = distance;
      }
    }
    if (closest == null) {
      rows.add([line]);
    } else {
      closest.add(line);
    }
  }
  return rows.map((row) {
    row.sort((a, b) => a.box.left.compareTo(b.box.left));
    return row.map((l) => l.text).join(' ');
  }).join('\n');
}
