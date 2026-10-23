import 'dart:async';
import 'package:flutter/material.dart';
import 'local_draft.dart';
import 'local_entry.dart';
import 'api_client.dart';
import 'app.dart';
import 'money.dart';
import 'presentation.dart';
import '../ui/widgets/finki_brand.dart';
import '../ui/widgets/finki_components.dart';
import '../core/theme/app_theme.dart';

const operationLabels = {
  'VENTA': 'Venta',
  'GASTO_OPERATIVO': 'Gasto',
  'COMPRA_MERCADERIA': 'Compra de mercadería'
};

class EntryForm extends StatefulWidget {
  final ApiClient api;
  final String kind;
  final Json? business, row;
  final List<Json> accounts, categories, people;
  const EntryForm(
      {super.key,
      required this.api,
      required this.kind,
      this.business,
      this.row,
      required this.accounts,
      required this.categories,
      required this.people});
  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  final key = GlobalKey<FormState>();
  final name = TextEditingController(),
      amount = TextEditingController(),
      partial = TextEditingController(),
      extra = TextEditingController(),
      date = TextEditingController(text: limaToday());
  String mode = 'CONTADO', categoryType = 'VENTA', accountType = 'EFECTIVO';
  String? channel = 'EFECTIVO', category, person, account;
  bool busy = false;
  LocalDraft? draft;
  bool draftQueued = false;
  bool draftEdited = false,
      restoringDraft = false,
      restoredDraft = false,
      submitted = false;
  String get kind => widget.kind;
  bool get operation => operationLabels.containsKey(kind);
  String get title =>
      operationLabels[kind] ??
      {
        'business': 'Mi negocio',
        'businessEdit': 'Editar mi negocio',
        'account': 'Nueva cuenta',
        'category': 'Nueva categoría',
        'person': 'Cliente o proveedor',
        'payment': 'Abono o pago'
      }[kind]!;
  String get root => '/negocios/${widget.business!['id']}';
  @override
  void initState() {
    super.initState();
    if (kind == 'businessEdit') {
      name.text = widget.business?['nombre'] ?? '';
      extra.text = widget.business?['rubro'] ?? '';
    }
    if (operation && widget.row?['initial_mode'] == 'CREDITO') mode = 'CREDITO';
    category = widget.categories
        .where((c) => c['tipo'] == kind)
        .firstOrNull?['id'] as String?;
    account = widget.accounts.firstOrNull?['id'] as String?;
    final proposal = widget.row?['proposal'] as Map?;
    if (proposal != null) {
      name.text = proposal['concepto'] as String? ?? '';
      final minor = proposal['monto_minor'];
      if (minor != null) {
        final value = BigInt.parse(minor as String);
        amount.text =
            '${value ~/ BigInt.from(100)}.${(value % BigInt.from(100)).toString().padLeft(2, '0')}';
      }
      date.text = proposal['fecha'] as String? ?? limaToday();
      channel = proposal['medio'] as String?;
      if (operation && proposal['fiado'] == true) mode = 'CREDITO';
      final candidates = widget.people
          .where((p) =>
              p['nombre'].toString().toLowerCase() ==
              proposal['persona']?.toString().toLowerCase())
          .toList();
      if (candidates.length == 1) person = candidates.single['id'] as String;
    }
    if ((operation || kind == 'payment') &&
        widget.api.userId != null &&
        widget.row?['proposal'] == null) {
      draft = LocalDraft(widget.api.store,
          'draft-v4:${widget.api.userId}:${widget.business?['id']}:$kind:${widget.row?['id'] ?? 'new'}');
      for (final controller in [name, amount, partial, extra, date]) {
        controller.addListener(draftChanged);
      }
      restoreDraft();
    }
  }

  Json get draftValue => {
        'name': name.text,
        'amount': amount.text,
        'partial': partial.text,
        'date': date.text,
        'mode': mode,
        'channel': channel,
        'category': category,
        'person': person,
        'account': account
      };
  void draftChanged() {
    if (draft == null || restoringDraft || submitted) return;
    draftEdited = true;
    if (draftQueued) return;
    draftQueued = true;
    scheduleMicrotask(() {
      draftQueued = false;
      if (mounted && !submitted) {
        unawaited(draft?.save(draftValue).catchError((Object _) {}) ??
            Future.value());
      }
    });
  }

  Future<void> restoreDraft() async {
    try {
      final value = await draft?.read();
      if (!mounted || draftEdited || value == null) return;
      restoringDraft = true;
      setState(() {
        name.text = value['name'] as String? ?? '';
        amount.text = value['amount'] as String? ?? '';
        partial.text = value['partial'] as String? ?? '';
        date.text = value['date'] as String? ?? limaToday();
        if (['CONTADO', 'CREDITO', 'PARCIAL'].contains(value['mode'])) {
          mode = value['mode'] as String;
        }
        if (['EFECTIVO', 'YAPE', 'PLIN', 'TRANSFERENCIA', 'OTRO']
            .contains(value['channel'])) {
          channel = value['channel'] as String;
        }
        if (widget.categories.any((c) => c['id'] == value['category'])) {
          category = value['category'] as String;
        }
        if (widget.people.any((c) => c['id'] == value['person'])) {
          person = value['person'] as String;
        }
        if (widget.accounts.any((c) => c['id'] == value['account'])) {
          account = value['account'] as String;
        }
        restoredDraft = true;
      });
    } catch (_) {
      /* A damaged local draft must never block a new manual entry. */
    } finally {
      restoringDraft = false;
    }
  }

  @override
  void dispose() {
    if (draftEdited && !submitted) {
      unawaited(
          draft?.save(draftValue).catchError((Object _) {}) ?? Future.value());
    }
    for (final c in [name, amount, partial, extra, date]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget text(TextEditingController c, String label,
          {bool required = true, int max = 120, bool money = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
              controller: c,
              enabled: !busy,
              maxLength: money ? null : max,
              keyboardType: money
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : c == extra && kind == 'person'
                      ? TextInputType.phone
                      : TextInputType.text,
              decoration: InputDecoration(
                  labelText: label,
                  prefixText: money ? 'S/ ' : null,
                  counterText: '',
                  hintText: money ? '0.00' : null),
              validator: (v) {
                if (required && v!.trim().isEmpty) return 'Completa este campo';
                if (c == extra &&
                    kind == 'person' &&
                    v!.trim().isNotEmpty &&
                    !RegExp(r'^\+?[1-9][0-9]{7,14}$').hasMatch(v.trim())) {
                  return 'Ingresa un teléfono válido, sin espacios';
                }
                if (money && v!.isNotEmpty) {
                  try {
                    toMinor(v);
                  } on FormatException catch (e) {
                    return e.message;
                  }
                }
                return null;
              }));
  Widget select(String label, String? value,
          List<DropdownMenuItem<String>> items, ValueChanged<String?> update,
          {bool required = true}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: FinkiSelect(
              value: value,
              label: label,
              required: required,
              items: items,
              onChanged: busy
                  ? null
                  : (value) {
                      update(value);
                      draftChanged();
                    }));
  List<DropdownMenuItem<String>> options(List<Json> rows) => rows
      .map((r) => DropdownMenuItem(
          value: r['id'] as String,
          child: Text(r['nombre'] as String, overflow: TextOverflow.ellipsis)))
      .toList();
  List<DropdownMenuItem<String>> labels(Map<String, String> values) =>
      values.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList();
  DateTime get earliestDate {
    var first = DateTime.tryParse(widget.business?['inicio_historial'] ?? '') ??
        DateTime(1000);
    if (kind == 'business') return DateTime(1000);
    final values = [
      if (kind == 'payment') widget.row?['fecha_operacion'],
      if (kind == 'payment' || operation && mode != 'CREDITO')
        widget.accounts
            .where((a) => a['id'] == account)
            .firstOrNull?['fecha_apertura'],
    ];
    for (final value in values) {
      final d = DateTime.tryParse(value?.toString() ?? '');
      if (d != null && d.isAfter(first)) first = d;
    }
    return first;
  }

  Widget get dateField => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
          key: ValueKey('date-${date.text}'),
          initialValue: dateEs(date.text),
          readOnly: true,
          validator: (_) => DateTime.parse(date.text).isBefore(earliestDate) ||
                  date.text.compareTo(limaToday()) > 0
              ? 'Elige una fecha dentro del historial y no futura.'
              : null,
          decoration: InputDecoration(
              labelText: kind == 'business' || kind == 'businessEdit'
                  ? 'Inicio de tu historial'
                  : kind == 'account'
                      ? 'Fecha de apertura'
                      : 'Fecha',
              suffixIcon: const Icon(Icons.calendar_month)),
          onTap: busy
              ? null
              : () async {
                  final now = DateTime.parse(limaToday());
                  final current = DateTime.tryParse(date.text) ?? now;
                  final chosen = await showDatePicker(
                      context: context,
                      initialDate: current.isBefore(earliestDate)
                          ? earliestDate
                          : current.isAfter(now)
                              ? now
                              : current,
                      firstDate: earliestDate,
                      lastDate: now);
                  if (chosen != null && mounted) {
                    setState(() =>
                        date.text = chosen.toIso8601String().substring(0, 10));
                  }
                }));
  Json movement(String value, String concept) => {
        'id': widget.api.newId(),
        'cuenta_id': account,
        'monto_minor': value,
        'fecha_movimiento': date.text,
        'canal': channel,
        'concepto':
            concept.length > 240 ? '${concept.substring(0, 237)}...' : concept
      };
  Future<void> submit() async {
    if (busy || !key.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      late String type, path;
      late Json payload;
      if (kind == 'business') {
        type = 'CREAR_NEGOCIO';
        path = '/negocios';
        payload = {
          'id': widget.api.newId(),
          'nombre': name.text.trim(),
          'rubro': extra.text.trim(),
          'inicio_historial': date.text
        };
      } else if (kind == 'businessEdit') {
        type = 'ACTUALIZAR_NEGOCIO';
        path = '$root/comandos';
        if (widget.business?['version'] == null) {
          throw const FormatException(
              'Actualiza el negocio antes de editarlo.');
        }
        payload = {
          'expected_version': widget.business!['version'].toString(),
          'nombre': name.text.trim(),
          'rubro': extra.text.trim()
        };
      } else if (kind == 'account') {
        type = 'CREAR_CUENTA';
        path = '$root/cuentas';
        payload = {
          'id': widget.api.newId(),
          'nombre': name.text.trim(),
          'tipo': accountType,
          'fecha_apertura': date.text,
          'saldo_inicial_minor': '0'
        };
      } else if (kind == 'category') {
        type = 'CREAR_CATEGORIA';
        path = '$root/categorias';
        payload = {
          'id': widget.api.newId(),
          'nombre': name.text.trim(),
          'tipo': categoryType
        };
      } else if (kind == 'person') {
        type = 'CREAR_TERCERO';
        path = '$root/terceros';
        payload = {
          'id': widget.api.newId(),
          'nombre': name.text.trim(),
          if (extra.text.trim().isNotEmpty) 'telefono': extra.text.trim()
        };
      } else if (operation) {
        final total = toMinor(amount.text);
        final credit = mode != 'CONTADO';
        final paid = mode == 'CONTADO'
            ? total
            : mode == 'PARCIAL'
                ? toMinor(partial.text)
                : '0';
        if (mode == 'PARCIAL' && BigInt.parse(paid) >= BigInt.parse(total)) {
          throw const FormatException(
              'El pago parcial debe ser menor al total.');
        }
        type = 'REGISTRAR_OPERACION';
        path = '$root/operaciones';
        payload = {
          'operacion': {
            'id': widget.api.newId(),
            'tipo': kind,
            'concepto': name.text.trim(),
            'total_minor': total,
            'fecha_operacion': date.text,
            'condicion': credit ? 'CREDITO' : 'CONTADO',
            'categoria_id': category,
            if (credit) 'tercero_id': person
          },
          'pagos_iniciales': [
            if (paid != '0')
              {
                ...movement(paid, name.text.trim()),
                'aplicacion_id': widget.api.newId()
              }
          ]
        };
      } else {
        final total = toMinor(amount.text), row = widget.row!;
        if (BigInt.parse(total) >
            BigInt.parse(row['pendiente_minor'] as String)) {
          throw const FormatException(
              'El abono no puede superar el saldo pendiente.');
        }
        final incoming = ['VENTA', 'SALDO_CXC'].contains(row['tipo']);
        type = incoming ? 'REGISTRAR_COBRO' : 'REGISTRAR_PAGO';
        path = '$root/${incoming ? 'cobros' : 'pagos'}';
        payload = {
          'movimiento': movement(
              total, '${incoming ? 'Abono' : 'Pago'}: ${row['concepto']}'),
          'aplicaciones': [
            {
              'id': widget.api.newId(),
              'operacion_id': row['id'],
              'monto_minor': total
            }
          ]
        };
      }
      if (!mounted) return;
      final accepted = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  scrollable: true,
                  title: const Text('Confirmar registro'),
                  content: Text(operation
                      ? '$title: ${name.text.trim()}\nTotal: ${soles(toMinor(amount.text))}\n${mode == 'CONTADO' ? 'Pagado por completo' : mode == 'PARCIAL' ? 'Abono inicial: ${soles(toMinor(partial.text))}' : 'Queda pendiente'}\nFecha: ${dateEs(date.text)}'
                      : kind == 'payment'
                          ? 'Abono: ${soles(toMinor(amount.text))}\nFecha: ${dateEs(date.text)}'
                          : '$title: ${name.text.trim()}'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Corregir')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Confirmar'))
                  ]));
      if (accepted != true) return;
      if (widget.row?['extraccion_id'] != null) {
        payload = {
          'extraccion_id': widget.row!['extraccion_id'],
          'tipo': type,
          'datos': payload
        };
        type = 'CONFIRMAR_PROPUESTA';
        path = '$root/comandos';
      } else if (widget.row?['local_entry'] != null) {
        payload = localConfirmation(
            Map<String, dynamic>.from(widget.row!['local_entry'] as Map),
            type,
            payload);
        type = 'CONFIRMAR_PROPUESTA_LOCAL';
        path = '$root/comandos';
      }
      final outcome = await widget.api.command(path, type, payload);
      submitted = true;
      // A cleanup error must not turn an accepted financial command into a retry.
      try {
        await draft?.clearAfterSubmission();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(outcome['local'] == true
                ? 'Guardado en este celular. Pendiente de sincronizar.'
                : kind == 'VENTA'
                    ? '¡Listo! Tu venta quedó registrada.'
                    : kind == 'payment'
                        ? '¡Listo! Tu abono o pago quedó registrado.'
                        : '¡Listo! Registro guardado en tu negocio.')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsAccount = kind == 'payment' || operation && mode != 'CREDITO';
    return PopScope(
        canPop: !busy,
        child: Scaffold(
            appBar: AppBar(
                toolbarHeight: 76, title: FinkiBrandHeader(subtitle: title)),
            body: SafeArea(
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth: FinkiSpace.formWidth),
                        child: Form(
                            key: key,
                            child: ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  Text(title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall),
                                  const SizedBox(height: 8),
                                  Text(
                                      kind == 'VENTA'
                                          ? 'Registra lo que vendiste, al contado o fiado.'
                                          : kind == 'COMPRA_MERCADERIA'
                                              ? 'Mercadería que compras para vender en tu negocio.'
                                              : kind == 'GASTO_OPERATIVO'
                                                  ? 'Servicios y gastos para que tu negocio funcione.'
                                                  : kind == 'business' ||
                                                          kind == 'businessEdit'
                                                      ? 'Cuéntanos cómo se llama y a qué se dedica.'
                                                      : kind == 'payment'
                                                          ? 'Un abono reduce el pendiente; no crea otra venta.'
                                                          : 'Organiza los datos de tu negocio.',
                                      style: const TextStyle(
                                          color: AppTheme.textMuted)),
                                  const SizedBox(height: 24),
                                  if (restoredDraft)
                                    const Padding(
                                        padding: EdgeInsets.only(bottom: 16),
                                        child: FinkiNotice(
                                            'Recuperamos tu borrador. Revísalo antes de confirmar.')),
                                  if (widget.api.pending != null)
                                    const Card(
                                        child: Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Text(
                                                'Hay un envío pendiente. Vuelve a Inicio y reintenta el mismo envío antes de registrar otro.'))),
                                  if (kind == 'payment') ...[
                                    Text(widget.row!['concepto'] as String,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    Text(
                                        'Total ${soles(widget.row!['total_minor'])} · Abonado ${soles(widget.row!['liquidado_minor'])}'),
                                    Text(
                                        'Pendiente ${soles(widget.row!['pendiente_minor'])}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22)),
                                    const SizedBox(height: 20),
                                  ] else
                                    text(
                                        name,
                                        operation
                                            ? '¿Qué vendiste o pagaste?'
                                            : 'Nombre',
                                        max: operation
                                            ? 240
                                            : kind == 'person' ||
                                                    kind == 'business' ||
                                                    kind == 'businessEdit'
                                                ? 120
                                                : 80),
                                  if (kind == 'business' ||
                                      kind == 'businessEdit')
                                    text(extra, 'Rubro del negocio', max: 80),
                                  if (kind == 'person')
                                    text(extra, 'Celular (opcional)',
                                        required: false, max: 16),
                                  if (kind == 'account') ...[
                                    select(
                                        'Tipo',
                                        accountType,
                                        labels({
                                          'EFECTIVO': 'Efectivo',
                                          'YAPE': 'Yape',
                                          'PLIN': 'Plin',
                                          'BANCO': 'Banco'
                                        }),
                                        (v) =>
                                            setState(() => accountType = v!)),
                                    const Text(
                                        'La cuenta empieza con saldo S/ 0.00. No se crea ningún ingreso inicial.'),
                                    const SizedBox(height: 16),
                                  ],
                                  if (kind == 'category')
                                    select(
                                        'Usar en',
                                        categoryType,
                                        labels(operationLabels),
                                        (v) =>
                                            setState(() => categoryType = v!)),
                                  if (operation) ...[
                                    text(amount, 'Importe total', money: true),
                                    if (widget.row?['proposal'] != null &&
                                        channel == null &&
                                        mode == 'CONTADO') ...[
                                      Text(
                                          kind == 'VENTA'
                                              ? '¿Cómo te pagaron?'
                                              : '¿Cómo pagaste?',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 8),
                                      Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            for (final choice in {
                                              'EFECTIVO': 'Efectivo',
                                              'YAPE': 'Yape',
                                              'PLIN': 'Plin',
                                              'TRANSFERENCIA': 'Transferencia',
                                              'CREDITO': kind == 'VENTA'
                                                  ? 'Fiado'
                                                  : 'Pendiente',
                                              'OTRO': 'Otro'
                                            }.entries)
                                              ActionChip(
                                                  label: Text(choice.value),
                                                  onPressed: busy
                                                      ? null
                                                      : () => setState(() {
                                                            if (choice.key ==
                                                                'CREDITO') {
                                                              mode = 'CREDITO';
                                                            } else {
                                                              channel =
                                                                  choice.key;
                                                            }
                                                          })),
                                          ]),
                                      const SizedBox(height: 16),
                                    ],
                                    select(
                                        'Categoría',
                                        category,
                                        options(widget.categories
                                            .where((c) => c['tipo'] == kind)
                                            .toList()),
                                        (v) => setState(() => category = v),
                                        required: false),
                                    if (widget.categories
                                        .where((c) => c['tipo'] == kind)
                                        .isEmpty)
                                      const Text(
                                          'La categoría es opcional. Puedes crear una desde Inicio.'),
                                    select(
                                        '¿Cómo se paga?',
                                        mode,
                                        labels({
                                          'CONTADO': 'Pago completo',
                                          'CREDITO': kind == 'VENTA'
                                              ? 'Fiado · sin abono'
                                              : 'Pendiente · sin pago',
                                          'PARCIAL': 'Pago parcial'
                                        }),
                                        (v) => setState(() => mode = v!)),
                                    if (mode != 'CONTADO')
                                      select(
                                          kind == 'VENTA'
                                              ? 'Cliente'
                                              : 'Proveedor',
                                          person,
                                          options(widget.people),
                                          (v) => setState(() => person = v)),
                                    if (mode != 'CONTADO' &&
                                        widget.people.isEmpty)
                                      const Text(
                                          'Primero registra un cliente o proveedor desde Inicio.'),
                                    if (mode == 'PARCIAL')
                                      text(partial, 'Abono inicial',
                                          money: true),
                                  ],
                                  if (kind == 'payment')
                                    text(amount, 'Monto del abono',
                                        money: true),
                                  if (needsAccount) ...[
                                    select(
                                        'Cuenta del dinero',
                                        account,
                                        options(widget.accounts),
                                        (v) => setState(() => account = v),
                                        required: !(widget.accounts.isEmpty &&
                                            channel == 'EFECTIVO')),
                                    if (widget.accounts.isEmpty)
                                      const Text(
                                          'Si cobras o pagas en efectivo, Finki preparará tu cuenta con saldo inicial cero. Para Yape, Plin o banco elige primero una cuenta desde Inicio.'),
                                    select(
                                        'Medio de pago',
                                        channel,
                                        labels({
                                          'EFECTIVO': 'Efectivo',
                                          'YAPE': 'Yape',
                                          'PLIN': 'Plin',
                                          'TRANSFERENCIA': 'Transferencia',
                                          'OTRO': 'Otro'
                                        }),
                                        (v) => setState(() => channel = v!)),
                                  ],
                                  if (kind != 'person' &&
                                      kind != 'category' &&
                                      kind != 'businessEdit')
                                    dateField,
                                  const SizedBox(height: 12),
                                  const Text(
                                      'Podrás revisar los datos antes de confirmar.',
                                      style:
                                          TextStyle(color: AppTheme.textMuted),
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                      onPressed:
                                          busy || widget.api.pending != null
                                              ? null
                                              : submit,
                                      style: FilledButton.styleFrom(
                                          minimumSize:
                                              const Size.fromHeight(56)),
                                      icon: Icon(busy
                                          ? Icons.hourglass_top
                                          : Icons.check_circle_outline),
                                      label: Text(busy
                                          ? 'Guardando…'
                                          : 'Revisar y guardar')),
                                  if (widget.api.pending != null)
                                    TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => Navigator.pop(context),
                                        child: const Text('Volver al inicio')),
                                ])))))));
  }
}
