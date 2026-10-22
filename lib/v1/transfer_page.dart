import 'package:flutter/material.dart';
import 'api_client.dart';
import 'app.dart' show showError;
import 'money.dart';
import '../ui/widgets/finki_components.dart';

class TransferPage extends StatefulWidget {
  final ApiClient api;
  final Json business;
  final List<Json> accounts;
  final Json? proposal;
  final String? extractionId;
  const TransferPage(
      {super.key,
      required this.api,
      required this.business,
      required this.accounts,
      this.proposal,
      this.extractionId});
  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final form = GlobalKey<FormState>(), amount = TextEditingController();
  String? source, target;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    if (widget.proposal?['monto_minor'] != null) {
      final n = BigInt.parse(widget.proposal!['monto_minor'] as String);
      amount.text =
          '${n ~/ BigInt.from(100)}.${(n % BigInt.from(100)).toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate() || busy) return;
    if (source == target) {
      showError(context, const FormatException('Elige dos cuentas distintas.'));
      return;
    }
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Confirmar traslado'),
                content: Text(
                    '${soles(toMinor(amount.text))} entre tus cuentas. No crea una venta ni un gasto.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Corregir')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Confirmar'))
                ]));
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      var payload = <String, dynamic>{
        'id': widget.api.newId(),
        'cuenta_origen_id': source,
        'cuenta_destino_id': target,
        'monto_minor': toMinor(amount.text),
        'fecha': widget.proposal?['fecha'] ?? limaToday(),
        'concepto':
            widget.proposal?['concepto'] ?? 'Traslado entre mis cuentas',
        'movimiento_salida_id': widget.api.newId(),
        'movimiento_entrada_id': widget.api.newId()
      };
      var type = 'REGISTRAR_TRANSFERENCIA';
      if (widget.extractionId != null) {
        payload = {
          'extraccion_id': widget.extractionId,
          'tipo': type,
          'datos': payload
        };
        type = 'CONFIRMAR_PROPUESTA';
      }
      await widget.api.command(
          '/negocios/${widget.business['id']}/comandos', type, payload);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Entre mis cuentas')),
      body: SafeArea(
          child: Form(
              key: form,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                const FinkiNotice(
                    'Solo mueve dinero entre dos cuentas propias. No registra ventas ni gastos.'),
                for (final isSource in [true, false])
                  Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: FinkiSelect(
                          label: isSource ? 'De qué cuenta' : 'A qué cuenta',
                          value: isSource ? source : target,
                          items: widget.accounts
                              .map((a) => DropdownMenuItem<String>(
                                  value: a['id'] as String,
                                  child: Text(a['nombre'] as String)))
                              .toList(),
                          onChanged: busy
                              ? null
                              : (v) => setState(() {
                                    if (isSource) {
                                      source = v;
                                    } else {
                                      target = v;
                                    }
                                  }))),
                TextFormField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Importe', prefixText: 'S/ '),
                    validator: (s) {
                      try {
                        toMinor(s ?? '');
                        return null;
                      } on FormatException catch (e) {
                        return e.message;
                      }
                    }),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: busy ? null : submit,
                    child: const Text('Revisar traslado')),
              ]))));
}
