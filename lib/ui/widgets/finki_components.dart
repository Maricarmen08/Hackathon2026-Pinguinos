import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'finki_brand.dart';

/// Tokens shared by the mobile screens, including their desktop preview.
abstract final class FinkiSpace {
  static const double xs = 4, sm = 8, md = 16, lg = 24, xl = 32;
  static const double contentWidth = 640, formWidth = 480, radius = 20;
}

class FinkiMoneyCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool fillHeight;
  const FinkiMoneyCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      this.fillHeight = false});
  @override
  Widget build(BuildContext context) => Card(
      color: AppTheme.primaryContainer,
      child: Padding(
          padding: const EdgeInsets.all(FinkiSpace.lg - FinkiSpace.xs),
          child: Column(
              mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(label,
                          style: const TextStyle(
                              color: AppTheme.textPrimary, fontSize: 14)))
                ]),
                if (fillHeight) const Spacer(),
                const SizedBox(height: 12),
                if (value.length > 14)
                  Text(value,
                      style: const TextStyle(
                          fontSize: 18,
                          height: 1.4,
                          fontWeight: FontWeight.w700))
                else
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.5))),
              ])));
}

class FinkiSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const FinkiSection(this.title, {super.key, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: AppTheme.textMuted)),
          ],
        ])),
        if (action != null) action!,
      ]));
}

class FinkiNotice extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool warning;
  const FinkiNotice(this.text,
      {super.key, this.icon = Icons.info_outline, this.warning = false});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: warning ? AppTheme.warningSurface : AppTheme.paleBlue,
          borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon,
            size: 20, color: warning ? AppTheme.warning : AppTheme.brandBlue),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
      ]));
}

class FinkiEmpty extends StatelessWidget {
  final String title, message;
  final Widget? action;
  const FinkiEmpty(
      {super.key, required this.title, required this.message, this.action});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(children: [
        const FinkiMascot(variant: FinkiMascotVariant.empty, size: 120),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, height: 1.5)),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ]));
}

class FinkiLoading extends StatelessWidget {
  const FinkiLoading({super.key});
  @override
  Widget build(BuildContext context) => const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        FinkiLogo(height: 144),
        SizedBox(height: 24),
        SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(height: 16),
        Text('Preparando tus cuentas…',
            style: TextStyle(color: AppTheme.textMuted)),
      ]));
}

class FinkiAssistant extends StatelessWidget {
  const FinkiAssistant({super.key});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppTheme.navy, borderRadius: BorderRadius.circular(20)),
      child: const Row(children: [
        Icon(Icons.mic_none_rounded, color: AppTheme.cyan, size: 32),
        SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hablar con Finki',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
          SizedBox(height: 4),
          Text(
              'Próximamente · Voz y lectura de comprobantes. Por ahora, registra con el formulario.',
              style: TextStyle(color: AppTheme.onBrandMuted, height: 1.5)),
        ])),
      ]));
}

enum FinkiButtonKind { primary, secondary, outlined, text, destructive }

class FinkiButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final FinkiButtonKind kind;
  const FinkiButton(
      {super.key,
      required this.label,
      this.icon,
      this.onPressed,
      this.loading = false,
      this.kind = FinkiButtonKind.primary});
  @override
  Widget build(BuildContext context) {
    final content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else if (icon != null)
                Icon(icon, size: 20),
              if (icon != null || loading) const SizedBox(width: 8),
              Flexible(
                  child: Text(loading ? 'Un momento…' : label,
                      textAlign: TextAlign.center)),
            ]));
    final action = loading ? null : onPressed;
    if (kind == FinkiButtonKind.outlined) {
      return OutlinedButton(onPressed: action, child: content);
    }
    if (kind == FinkiButtonKind.text) {
      return TextButton(onPressed: action, child: content);
    }
    return FilledButton(
        onPressed: action,
        style: FilledButton.styleFrom(
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            backgroundColor: kind == FinkiButtonKind.primary
                ? AppTheme.primary
                : kind == FinkiButtonKind.destructive
                    ? AppTheme.errorSurface
                    : AppTheme.primaryContainer,
            foregroundColor: kind == FinkiButtonKind.primary
                ? AppTheme.onBrand
                : kind == FinkiButtonKind.destructive
                    ? AppTheme.expenseRed
                    : AppTheme.primary),
        child: content);
  }
}

/// Native Flutter selection keeps keyboard/touch support and form validation.
class FinkiSelect extends StatelessWidget {
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;
  final bool required;
  const FinkiSelect(
      {super.key,
      required this.label,
      required this.value,
      required this.items,
      required this.onChanged,
      this.required = true});
  double _menuHeight(BuildContext context) {
    // Scaffold removes keyboard insets from its body MediaQuery after resizing.
    // Read the view itself so the popup also respects the keyboard in landscape.
    final view = View.of(context);
    return ((view.physicalSize.height -
                view.viewInsets.bottom -
                view.padding.top -
                view.padding.bottom) /
            view.devicePixelRatio *
            .45)
        .clamp(0, double.infinity);
  }

  @override
  Widget build(BuildContext context) => ButtonTheme(
      // Unaligned DropdownButton inflates its anchor by 16/24 px in Flutter.
      // Keep the native route, focus and Form integration, but use the field's
      // actual rectangle for the popup instead of that expanded anchor.
      alignedDropdown: true,
      child: DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          items: items
              .map((item) => DropdownMenuItem<String>(
                  value: item.value,
                  enabled: item.enabled,
                  onTap: item.onTap,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Expanded(child: item.child),
                        if (item.value == value) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_rounded,
                              size: 18, color: AppTheme.primary)
                        ],
                      ]))))
              .toList(),
          selectedItemBuilder: (_) => items
              .map((item) => Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: item.child))
              .toList(),
          elevation: 3,
          focusColor: AppTheme.primaryContainer,
          dropdownColor: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          menuMaxHeight: _menuHeight(context),
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          itemHeight: null,
          decoration: InputDecoration(labelText: label),
          onChanged: onChanged,
          validator: (v) =>
              required && (v == null || !items.any((item) => item.value == v))
                  ? 'Selecciona una opción válida'
                  : null));
}
