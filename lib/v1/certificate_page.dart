import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'api_client.dart';
import 'app.dart' show showError;
import 'money.dart';
import 'presentation.dart';
import '../ui/widgets/finki_brand.dart';
import '../ui/widgets/finki_components.dart';

class CertificatePage extends StatefulWidget {
  final ApiClient api;
  final Json business;
  const CertificatePage({super.key, required this.api, required this.business});
  @override
  State<CertificatePage> createState() => _CertificatePageState();
}

class _CertificatePageState extends State<CertificatePage> {
  late String from, to;
  Json? summary;
  Uint8List? pdf;
  String? reportId;
  List<Json> recent = [];
  bool busy = false;
  @override
  void initState() {
    super.initState();
    from = widget.business['inicio_historial'] as String;
    to = limaToday();
    preview();
    loadRecent();
  }

  String get root => '/negocios/${widget.business['id']}';
  Future<void> preview() async {
    setState(() {
      busy = true;
      summary = null;
      pdf = null;
      reportId = null;
    });
    try {
      final data = await widget.api
          .request('GET', '$root/indicadores?desde=$from&hasta=$to');
      if (mounted) setState(() => summary = data);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> choosePeriod() async {
    final dates = await showDateRangePicker(
        context: context,
        firstDate: DateTime.parse(widget.business['inicio_historial']),
        lastDate: DateTime.parse(limaToday()),
        initialDateRange:
            DateTimeRange(start: DateTime.parse(from), end: DateTime.parse(to)),
        helpText: 'Periodo de mi constancia');
    if (dates == null || !mounted) return;
    from = dates.start.toIso8601String().substring(0, 10);
    to = dates.end.toIso8601String().substring(0, 10);
    await preview();
  }

  Future<void> generate() async {
    if (busy || summary == null) return;
    setState(() => busy = true);
    try {
      if (reportId == null) {
        final id = widget.api.newId();
        await widget.api.command('$root/comandos', 'GENERAR_CONSTANCIA',
            {'id': id, 'desde': from, 'hasta': to});
        reportId = id;
      }
      final file =
          await widget.api.request('GET', '$root/constancias/$reportId');
      if (mounted) {
        setState(() {
          pdf = base64Decode(file['pdf_base64'] as String);
          summary = Map<String, dynamic>.from(file['indicadores'] as Map);
        });
        await loadRecent();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadRecent() async {
    try {
      final data = await widget.api
          .request('GET', '$root/constancias?limit=20&offset=0');
      if (mounted) {
        setState(() => recent = (data['items'] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList());
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> recover(Json row) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final data =
          await widget.api.request('GET', '$root/constancias/${row['id']}');
      if (mounted) {
        setState(() {
          reportId = row['id'] as String;
          pdf = base64Decode(data['pdf_base64'] as String);
          summary = Map<String, dynamic>.from(data['indicadores'] as Map);
          from = summary!['desde'] as String;
          to = summary!['hasta'] as String;
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(bool share) async {
    try {
      if (share) {
        await Printing.sharePdf(
            bytes: pdf!, filename: 'FINKI-constancia-$reportId.pdf');
      } else {
        await Printing.layoutPdf(
            name: 'FINKI-constancia-$reportId', onLayout: (_) async => pdf!);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const FinkiBrandHeader(subtitle: 'Mi constancia')),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Mi constancia', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
            'Un resumen de lo que registraste en Finki para presentar la actividad de tu negocio.'),
        const SizedBox(height: 16),
        OutlinedButton.icon(
            onPressed: busy ? null : choosePeriod,
            icon: const Icon(Icons.date_range),
            label: Text(periodEs(from, to, today: limaToday()))),
        if (busy)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator())),
        if (summary != null) ...[
          Card(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: [
                  for (final entry in {
                    'Ventas registradas': 'ventas_minor',
                    'Cobros recibidos': 'cobros_ventas_minor',
                    'Gastos registrados': 'gastos_minor',
                    'Compras registradas': 'compras_minor',
                    'Me deben al cierre': 'por_cobrar_minor',
                    'Debo pagar al cierre': 'por_pagar_minor',
                    'Resultado simplificado':
                        'resultado_operativo_simplificado_minor'
                  }.entries)
                    ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        title: Text(entry.key),
                        subtitle: Text(soles(summary![entry.value]),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700))),
                ])),
          ),
          const SizedBox(height: 12),
          Text(
              'Promedio mensual de ventas: ${summary!['promedio_mensual_ventas_minor'] == null ? 'Aún no hay meses completos' : soles(summary!['promedio_mensual_ventas_minor'])}'),
          Text(
              '${summary!['meses_completos']} meses completos. ${summary!['meses_con_informacion'] ?? 0} meses con registros en este periodo.'),
          const SizedBox(height: 16),
          const FinkiNotice(
              'El resultado simplificado resta compras y gastos a las ventas. No es utilidad neta. La constancia usa tus registros: no es una certificación oficial ni garantiza un crédito.'),
          if (widget.api.pending != null ||
              widget.api.localEntries.isNotEmpty ||
              widget.api.offline)
            const FinkiNotice(
                'Para generar tu constancia, conecta Finki y sincroniza los registros pendientes desde Inicio.'),
          if (pdf == null)
            FilledButton.icon(
                onPressed: busy ||
                        widget.api.pending != null ||
                        widget.api.localEntries.isNotEmpty ||
                        widget.api.offline
                    ? null
                    : generate,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(reportId == null
                    ? 'Generar constancia'
                    : 'Recuperar PDF generado')),
        ],
        if (pdf != null) ...[
          const SizedBox(height: 16),
          const FinkiNotice('Tu constancia está lista.',
              icon: Icons.check_circle_outline),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: () => open(false),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir o descargar PDF')),
          OutlinedButton.icon(
              onPressed: () => open(true),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Compartir constancia')),
        ],
        if (summary == null && !busy)
          OutlinedButton(onPressed: preview, child: const Text('Reintentar')),
        if (recent.isNotEmpty) const FinkiSection('Constancias anteriores'),
        for (final row in recent)
          ListTile(
              title: Text(
                  periodEs(row['desde'], row['hasta'], today: limaToday())),
              subtitle: Text(timestampEs(row['generado_en'])),
              trailing: const Icon(Icons.picture_as_pdf_outlined),
              onTap: busy ? null : () => recover(row)),
      ])));
}
