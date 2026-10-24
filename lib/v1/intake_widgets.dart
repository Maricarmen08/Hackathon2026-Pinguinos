import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../ui/widgets/finki_components.dart';
import 'api_client.dart';
import 'money.dart';
import 'presentation.dart';
import 'receipt_details.dart';

const intakeTypes = <String, (String, String, IconData)>{
  'VENTA': ('Venta', 'Revisar venta', Icons.storefront_outlined),
  'GASTO_OPERATIVO': ('Gasto', 'Revisar gasto', Icons.shopping_bag_outlined),
  'COMPRA_MERCADERIA': ('Compra', 'Revisar compra', Icons.inventory_2_outlined),
  'COBRO': ('Cobro de un fiado', 'Revisar abono', Icons.call_received_rounded),
  'PAGO': ('Pago de una deuda', 'Revisar pago', Icons.call_made_rounded),
  'TRANSFERENCIA': (
    'Traslado entre mis cuentas',
    'Revisar traslado',
    Icons.swap_horiz_rounded
  ),
};

Future<String?> chooseIntakeType(BuildContext context) =>
    showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (c) => SafeArea(
            child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .8),
                child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    children: [
                      const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('¿Qué quieres registrar?',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700))),
                      for (final item in intakeTypes.entries)
                        ListTile(
                            minVerticalPadding: 12,
                            leading: Icon(item.value.$3),
                            title: Text(item.value.$1),
                            subtitle: Text(switch (item.key) {
                              'COBRO' => 'Me pagaron una venta fiada',
                              'PAGO' => 'Pagué una compra o gasto pendiente',
                              'TRANSFERENCIA' =>
                                'Moví mi dinero; no es una venta ni un gasto',
                              _ => 'Un registro nuevo en mi negocio'
                            }),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(c, item.key)),
                    ]))));

Future<void> showIntakePrivacy(BuildContext context, String provider) =>
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (c) => SafeArea(
            child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(c).height * .85),
                child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    children: [
                      Text('Cómo se usan mis datos',
                          style: Theme.of(c).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      Text(
                          'Finki envía la entrada que elijas a $provider para transcribirla o proponer un registro. El procesamiento no ocurre únicamente en tu celular.'),
                      const SizedBox(height: 12),
                      if (provider == 'Gemini')
                        const Text(
                            'En el nivel gratuito, Google puede usar el contenido para mejorar sus productos. Evita documentos con datos personales; usa información anonimizada cuando sea posible.'),
                      if (provider == 'OpenAI')
                        const Text(
                            'OpenAI recibe la entrada para procesarla conforme a las condiciones de su servicio.'),
                      const SizedBox(height: 12),
                      const Text(
                          'No envíes contraseñas, claves, códigos de seguridad, tarjetas ni documentos de identidad innecesarios. Recorta los datos que no hagan falta.'),
                      const SizedBox(height: 12),
                      const Text(
                          'Puedes retirar la autorización antes del envío, cancelar una grabación y elegir el formulario manual. Los permisos de cámara y micrófono son distintos de esta autorización. Si usas el dictado del teclado, revisa también sus ajustes de privacidad.'),
                      const SizedBox(height: 12),
                      const Text(
                          'El envío aceptado queda registrado con fecha, usuario y proveedor. Finki conserva la propuesta y, si adjuntaste un archivo, la evidencia con acceso limitado a tu negocio. Descartar una propuesta no borra su evidencia ni revoca un envío ya realizado. No se guarda una operación financiera hasta tu confirmación.'),
                      const SizedBox(height: 20),
                      FilledButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Entendido')),
                    ]))));

class IntakeCapture extends StatelessWidget {
  final TextEditingController text;
  final bool consent, busy, recording, picking, transcript;
  final bool preparingVoice, transcribingVoice;
  final bool imageText, analyzingImage;
  final VoidCallback? onRetake;
  final int seconds;
  final bool? configured;
  final String provider;
  final String? error;
  final VoidCallback? onCloud;
  final bool needsHelp;
  final ValueChanged<bool> onConsent;
  final VoidCallback onVoice,
      onCancel,
      onCamera,
      onGallery,
      onAnalyze,
      onManual,
      onRetry;
  const IntakeCapture(
      {super.key,
      required this.text,
      required this.consent,
      required this.busy,
      required this.recording,
      required this.picking,
      required this.seconds,
      required this.configured,
      required this.provider,
      required this.onConsent,
      required this.onVoice,
      required this.onCancel,
      required this.onCamera,
      required this.onGallery,
      required this.onAnalyze,
      required this.onManual,
      required this.onRetry,
      this.error,
      this.onCloud,
      this.needsHelp = false,
      this.preparingVoice = false,
      this.transcribingVoice = false,
      this.imageText = false,
      this.analyzingImage = false,
      this.onRetake,
      this.transcript = false});
  @override
  Widget build(BuildContext context) {
    final ready = !busy && !picking;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Hablar con Finki',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      const Text('Cuéntame qué vendiste o gastaste',
          style: TextStyle(color: AppTheme.textMuted)),
      const SizedBox(height: 20),
      if (!recording) ...[
        FilledButton.icon(
            onPressed: ready ? onVoice : null,
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(76),
                textStyle:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            icon: const Icon(Icons.mic_none_rounded, size: 32),
            label: const Text('Hablar')),
        const SizedBox(height: 10),
        Text(
            'Toca y dime, por ejemplo: «Vendí 50 $currencyWord de arroz» o «Gasté 20 $currencyWord en pasajes».',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 14, height: 1.4)),
        const SizedBox(height: 20),
      ],
      // El permiso solo se pide si la ayuda por internet existe, y una sola vez.
      if (configured == true && !consent)
        Card(
            margin: EdgeInsets.zero,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          controlAffinity: ListTileControlAffinity.leading,
                          subtitle: const Text(
                              'Solo se envía contenido si eliges ayuda por internet.'),
                          value: consent,
                          onChanged: busy || recording || picking
                              ? null
                              : (v) => onConsent(v == true),
                          title: const Text(
                              'Acepto enviar mi voz, texto o imagen a un servicio de IA externo para preparar una propuesta.',
                              style: TextStyle(fontSize: 14, height: 1.4))),
                      Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: TextButton.icon(
                              onPressed: () =>
                                  showIntakePrivacy(context, provider),
                              icon: const Icon(Icons.privacy_tip_outlined,
                                  size: 18),
                              label: const Text('Cómo se usan mis datos'))),
                    ]))),
        if (configured == true && consent)
        Row(children: [
          const Icon(Icons.check_circle_outline,
              size: 18, color: AppTheme.success),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('Ayuda por internet activada.',
                  style: TextStyle(fontSize: 14))),
          TextButton(
              onPressed:
                  busy || recording || picking ? null : () => onConsent(false),
              child: const Text('Quitar permiso')),
        ]),
      const SizedBox(height: 16),
      if (needsHelp && configured != true) ...[
        const FinkiNotice(
            'La ayuda por internet no está disponible por ahora. Puedes seguir con los datos que reconoció tu celular o registrar manualmente.'),
        TextButton(
            onPressed: onRetry, child: const Text('Comprobar disponibilidad')),
      ],
      if (recording) ...[
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppTheme.errorSurface,
                borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              const Icon(Icons.mic, color: AppTheme.error, size: 36),
              const SizedBox(height: 8),
              Text('Grabando · 00:${seconds.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('Máximo 45 segundos'),
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: onVoice,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Detener y revisar')),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: onCancel, child: const Text('Cancelar grabación')),
            ])),
      ] else ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: ready ? onCamera : null,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label:
                      const Text('Tomar foto', textAlign: TextAlign.center))),
          const SizedBox(width: 12),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: ready ? onGallery : null,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Elegir imagen',
                      textAlign: TextAlign.center))),
        ]),
        const SizedBox(height: 20),
        TextField(
            controller: text,
            enabled: !busy && !picking,
            maxLength: imageText ? 6000 : 1000,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
                labelText: imageText
                    ? 'Texto de la imagen · puedes corregirlo'
                    : transcript
                        ? 'Esto escuché · puedes corregirlo'
                        : 'O escríbelo aquí…',
                hintText: 'Vendí 50 $currencyWord de arroz',
                counterText: '')),
        if (imageText)
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                  icon: const Icon(Icons.unfold_more),
                  label: const Text('Ver texto completo'),
                  onPressed: ready
                      ? () => showDialog<void>(
                          context: context,
                          builder: (c) =>
                              AlertDialog(
                                  title:
                                      const Text('Texto reconocido completo'),
                                  content: SizedBox(
                                      width: double.maxFinite,
                                      height: MediaQuery.sizeOf(c).height * .55,
                                      child: TextField(
                                          controller: text,
                                          maxLength: 6000,
                                          maxLines: null,
                                          expands: true,
                                          decoration: const InputDecoration(
                                              alignLabelWithHint: true,
                                              labelText:
                                                  'Revisa o corrige el texto'))),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(c),
                                        child: const Text('Listo'))
                                  ]))
                      : null)),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
            onPressed: ready ? onAnalyze : null,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(
                transcript ? 'Interpretar texto corregido' : 'Interpretar')),
      ],
      if (needsHelp && !recording) ...[
        const SizedBox(height: 12),
        TextButton.icon(
            onPressed: !busy && !picking && consent && configured == true
                ? onCloud
                : null,
            icon: const Icon(Icons.help_outline),
            label: const Text('Pedir ayuda por internet')),
        if (!consent)
          const Text(
              'Para pedir ayuda por internet, acepta la autorización de envío.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      ],
      if (busy || picking) ...[
        const SizedBox(height: 16),
        const LinearProgressIndicator(),
        const SizedBox(height: 10),
        Text(
            analyzingImage
                ? 'Analizando imagen en tu celular…'
                : preparingVoice
                    ? 'Preparando el micrófono del celular…'
                    : transcribingVoice
                        ? 'Transcribiendo tu grabación en el celular…'
                        : picking
                            ? 'Elige una imagen para continuar…'
                            : 'Preparando tu propuesta…',
            textAlign: TextAlign.center),
        if (transcribingVoice)
          TextButton(
              onPressed: onCancel, child: const Text('Cancelar transcripción')),
      ],
      if (error != null) ...[
        const SizedBox(height: 16),
        FinkiNotice(error!, warning: true),
        if (imageText && onRetake != null)
          TextButton.icon(
              onPressed: ready ? onRetake : null,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Repetir fotografía')),
        TextButton(
            onPressed: onManual, child: const Text('Continuar manualmente')),
      ],
    ]);
  }
}

class IntakeProposalCard extends StatelessWidget {
  final Json proposal;
  final ReceiptDetails? receipt;
  final bool enabled, hasEvidence;
  final VoidCallback onReview, onChange, onLink;
  const IntakeProposalCard(
      {super.key,
      required this.proposal,
      this.receipt,
      required this.onReview,
      required this.onChange,
      required this.onLink,
      required this.enabled,
      required this.hasEvidence});
  @override
  Widget build(BuildContext context) {
    final type = intakeTypes[proposal['intencion']], ambiguous = type == null;
    final tone = switch (proposal['intencion']) {
      'VENTA' || 'COBRO' => AppTheme.success,
      'GASTO_OPERATIVO' || 'COMPRA_MERCADERIA' || 'PAGO' => AppTheme.expenseRed,
      _ => AppTheme.navy
    };
    return Card(
        margin: EdgeInsets.zero,
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Esto entendí',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(type?.$3 ?? Icons.help_outline_rounded,
                        color: ambiguous ? AppTheme.warning : tone),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            proposal['concepto']?.toString() ??
                                (ambiguous
                                    ? 'Necesito tu ayuda con este registro'
                                    : type.$1),
                            style: Theme.of(context).textTheme.titleLarge)),
                  ]),
                  const SizedBox(height: 12),
                  if (receipt?.merchant != null) ...[
                    Text(receipt!.merchant!,
                        style: const TextStyle(color: AppTheme.textMuted)),
                    if (receipt!.taxId != null)
                      Text('RUC: ${receipt!.taxId}',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 13)),
                    const SizedBox(height: 10),
                  ],
                  Text(
                      proposal['monto_minor'] == null
                          ? 'Falta el monto'
                          : soles(proposal['monto_minor']),
                      style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: proposal['monto_minor'] == null
                              ? AppTheme.warning
                              : tone)),
                  if (receipt != null && receipt!.items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final item in receipt!.items)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Expanded(
                                child: Text(
                                    '${item.quantity == null ? '' : '${item.quantity} × '}${item.name}')),
                            const SizedBox(width: 8),
                            Text(soles(item.amountMinor)),
                          ])),
                  ],
                  if (receipt != null && proposal['medio'] != null)
                    Text('Medio de pago: ${proposal['medio']}',
                        style: const TextStyle(color: AppTheme.textMuted)),
                  if (receipt != null && proposal['referencia'] != null)
                    Text('Referencia: ${proposal['referencia']}',
                        style: const TextStyle(color: AppTheme.textMuted)),
                  if (proposal['fecha'] != null) ...[
                    const SizedBox(height: 6),
                    Text(dateEs(proposal['fecha'], today: limaToday()),
                        style: const TextStyle(color: AppTheme.textMuted))
                  ],
                  const SizedBox(height: 14),
                  Text(
                      ambiguous
                          ? '¿Fue una venta, un gasto o una compra?'
                          : 'Entendí que es: ${type.$1}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (proposal['es_pago'] == true) ...[
                    const SizedBox(height: 12),
                    const FinkiNotice(
                        'Si corresponde a una venta ya registrada, elige abono o adjunta el comprobante. Así evitas duplicarla.')
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                      onPressed: enabled ? onReview : null,
                      icon: Icon(ambiguous
                          ? Icons.checklist_rounded
                          : Icons.arrow_forward_rounded),
                      label: Text(
                          ambiguous ? 'Elegir tipo de registro' : type.$2)),
                  if (!ambiguous) ...[
                    const SizedBox(height: 6),
                    TextButton(
                        onPressed: enabled ? onChange : null,
                        child: const Text('Cambiar tipo'))
                  ],
                  if (hasEvidence) ...[
                    const Divider(height: 24),
                    TextButton.icon(
                        onPressed: enabled ? onLink : null,
                        icon: const Icon(Icons.attach_file),
                        label:
                            const Text('Ya lo registré: adjuntar comprobante'))
                  ],
                  const SizedBox(height: 6),
                  const Text('Revisarás los datos antes de confirmar.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ])));
  }
}

class PendingIntakeCard extends StatelessWidget {
  final Json row;
  final bool enabled;
  final VoidCallback onReview, onDiscard;
  const PendingIntakeCard(
      {super.key,
      required this.row,
      required this.onReview,
      required this.onDiscard,
      required this.enabled});
  @override
  Widget build(BuildContext context) {
    final p = Map<String, dynamic>.from(row['resultado'] as Map);
    return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Text(
                        p['concepto']?.toString() ?? 'Registro por revisar',
                        style: Theme.of(context).textTheme.titleMedium)),
                const SizedBox(width: 8),
                const DecoratedBox(
                    decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.all(Radius.circular(8))),
                    child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text('Pendiente',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.navy)))),
              ]),
              const SizedBox(height: 8),
              Text(
                  '${intakeTypes[p['intencion']]?.$1 ?? 'Tipo por definir'}${p['monto_minor'] == null ? '' : ' · ${soles(p['monto_minor'])}'}'),
              const SizedBox(height: 4),
              Text(timestampEs(row['creado_en']),
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 4, children: [
                OutlinedButton(
                    onPressed: enabled ? onReview : null,
                    child: const Text('Revisar')),
                TextButton.icon(
                    onPressed: enabled ? onDiscard : null,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Descartar')),
              ]),
            ])));
  }
}
