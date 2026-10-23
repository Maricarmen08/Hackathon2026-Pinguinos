import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum FinkiMascotVariant { welcome, compact, empty, confirmation }

/// Use complete existing artwork in headers as well as illustrations.
class FinkiMascot extends StatelessWidget {
  final FinkiMascotVariant variant;
  final double size;
  const FinkiMascot(
      {super.key, this.variant = FinkiMascotVariant.welcome, this.size = 160});
  @override
  Widget build(BuildContext context) {
    final compact = variant == FinkiMascotVariant.compact;
    final illustration = Image.asset('assets/branding/finki_logo_display.png',
        fit: BoxFit.contain,
        semanticLabel: 'Finki completo, tu asistente',
        filterQuality: FilterQuality.high);
    return SizedBox(
        width: compact ? size : size * 4 / 3,
        height: size,
        child: variant == FinkiMascotVariant.empty ||
                variant == FinkiMascotVariant.confirmation
            ? DecoratedBox(
                decoration: const BoxDecoration(
                    color: AppTheme.secondaryContainer, shape: BoxShape.circle),
                child: Padding(
                    padding: const EdgeInsets.all(12), child: illustration))
            : illustration);
  }
}

class FinkiLogo extends StatelessWidget {
  final double height;
  const FinkiLogo({super.key, this.height = 160});

  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Logo de FINKI',
      child: ExcludeSemantics(child: FinkiMascot(size: height)));
}

class FinkiRobot extends StatelessWidget {
  final double size;
  const FinkiRobot({super.key, this.size = 48});
  @override
  Widget build(BuildContext context) =>
      FinkiMascot(variant: FinkiMascotVariant.compact, size: size);
}

class FinkiBrandHeader extends StatelessWidget {
  final String subtitle;
  const FinkiBrandHeader({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) => Row(children: [
        const FinkiRobot(size: 44),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('FINKI',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                        color: AppTheme.navy)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
              ]),
        ),
      ]);
}
