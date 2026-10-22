import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'api_client.dart';
import 'app.dart' show showError;
import 'forms.dart';
import 'transfer_page.dart';
import 'money.dart';
import 'intake_widgets.dart';
import '../ui/widgets/finki_brand.dart';
import '../ui/widgets/finki_components.dart';

class IntakePage extends StatefulWidget {
  final ApiClient api;
  final Json business;
  final List<Json> accounts, categories, people;
  const IntakePage(
      {super.key,
      required this.api,
      required this.business,
      required this.accounts,
      required this.categories,
      required this.people});
  @override
  State<IntakePage> createState() => _IntakePageState();
}

class _IntakePageState extends State<IntakePage> {
  final text = TextEditingController();
  AudioRecorder? _recorder;
  AudioRecorder get recorder => _recorder ??= AudioRecorder();
  final chunks = <int>[];
  StreamSubscription<Uint8List>? stream;
  Timer? timer;
  Json? proposal;
  String? extractionId;
  bool recording = false, busy = false, consent = false;
  bool hasEvidence = false;
  bool picking = false, transcript = false;
  int seconds = 0;
  String? error, analysisKey, analysisId;
  final proposalKey = GlobalKey();
  List<Json> savedProposals = [];
  bool? configured;
  String providerName = 'el proveedor de IA';
  String get root => '/negocios/${widget.business['id']}';
  @override
  void initState() {
    super.initState();
    status();
    restoreProposals();
  }

  Future<void> restoreProposals() async {
    try {
      final data = await widget.api
          .request('GET', '/negocios/${widget.business['id']}/ia/propuestas');
      if (mounted) {
        setState(() => savedProposals = (data['items'] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList());
      }
    } catch (e) {
      if (mounted) {
        setState(() => error =
            'No pudimos cargar tus propuestas. Reintenta cuando tengas conexión.');
      }
    }
  }

  Future<void> status() async {
    try {
      final s = await widget.api
          .request('GET', '/negocios/${widget.business['id']}/ia/estado');
      if (mounted) {
        setState(() {
          configured = s['configurado'] == true;
          providerName = s['proveedor'] == 'Gemini' ? 'Gemini' : 'OpenAI';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          configured = null;
          error = 'No hay conexión con Finki. Puedes registrar manualmente.';
        });
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    stream?.cancel();
    _recorder?.dispose();
    text.dispose();
    super.dispose();
  }

  Future<void> analyze({List<int>? bytes, String? words}) async {
    if (!consent || busy || configured != true) return;
    if (bytes == null && (words?.trim().isEmpty ?? true)) {
      setState(() => error = 'Escribe qué vendiste o gastaste para continuar.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final fingerprint = bytes == null
        ? 'text:${words!.trim()}'
        : 'file:${bytes.length}:${Object.hashAll(bytes)}';
    if (analysisKey != fingerprint) {
      analysisKey = fingerprint;
      analysisId = widget.api.newId();
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await widget.api.request(
          'POST', '$root/ia/analizar?id=$analysisId',
          body: bytes == null ? {'texto': words} : null,
          bytes: bytes,
          headers: {
            'X-Finki-Consent': '1',
            'X-Finki-Consent-Version': 'finki-v4-2026-10-22',
            if (bytes != null) 'Content-Type': 'application/octet-stream'
          });
      if (mounted) {
        setState(() {
          proposal = Map<String, dynamic>.from(data['resultado'] as Map);
          extractionId = data['id'] as String;
          hasEvidence = bytes != null;
          transcript = data['transcripcion'] is String;
          if (transcript) text.text = data['transcripcion'] as String;
          consent = false;
        });
        await restoreProposals();
        revealProposal();
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException
            ? e.message
            : 'No pudimos interpretar esta entrada. Reintenta o registra manualmente.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> photo(ImageSource source) async {
    if (!consent || busy || recording || picking || configured != true) return;
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
          requestFullMetadata: false);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 7 * 1024 * 1024) {
        throw const FormatException('Elige una foto de menos de 7 MB.');
      }
      if (mounted) setState(() => picking = false);
      await analyze(bytes: bytes);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is FormatException
            ? e.message
            : 'No pudimos abrir la imagen. Revisa el permiso de cámara o elige otra foto.');
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void revealProposal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = proposalKey.currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(target,
            duration: const Duration(milliseconds: 300), alignment: 0.08);
      }
    });
  }

  Future<void> cancelVoice() async {
    timer?.cancel();
    await _recorder?.stop();
    await stream?.cancel();
    chunks.clear();
    if (mounted) setState(() => recording = false);
  }

  Future<void> voice() async {
    if (busy || picking) return;
    if (!recording && (!consent || configured != true)) return;
    if (recording) setState(() => picking = true);
    try {
      if (recording) {
        timer?.cancel();
        await recorder.stop();
        await stream?.cancel();
        if (!mounted) return;
        setState(() => recording = false);
        if (chunks.isEmpty) {
          throw const FormatException(
              'No escuché audio. Prueba otra vez o escríbelo.');
        }
        final size = chunks.length.clamp(0, 1440000);
        final wav = Uint8List(44 + size), h = ByteData.sublistView(wav);
        wav.setRange(0, 4, 'RIFF'.codeUnits);
        h.setUint32(4, 36 + size, Endian.little);
        wav.setRange(8, 16, 'WAVEfmt '.codeUnits);
        h.setUint32(16, 16, Endian.little);
        h.setUint16(20, 1, Endian.little);
        h.setUint16(22, 1, Endian.little);
        h.setUint32(24, 16000, Endian.little);
        h.setUint32(28, 32000, Endian.little);
        h.setUint16(32, 2, Endian.little);
        h.setUint16(34, 16, Endian.little);
        wav.setRange(36, 40, 'data'.codeUnits);
        h.setUint32(40, size, Endian.little);
        wav.setRange(44, wav.length, chunks);
        await analyze(bytes: wav);
      } else {
        setState(() => picking = true);
        if (!await recorder.hasPermission()) {
          throw const FormatException(
              'Permite usar el micrófono o escribe el registro.');
        }
        if (!mounted) return;
        chunks.clear();
        final audio = await recorder.startStream(const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1));
        stream = audio.listen((data) {
          if (chunks.length < 1440000) chunks.addAll(data);
        }, onError: (Object e) {
          cancelVoice();
          if (mounted) {
            setState(() => error =
                'No pudimos grabar. Revisa el micrófono y vuelve a intentar.');
          }
        });
        if (!mounted) {
          await cancelVoice();
          return;
        }
        setState(() {
          recording = true;
          picking = false;
          seconds = 0;
          error = null;
        });
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() => seconds++);
          if (seconds >= 45 && recording) voice();
        });
      }
    } catch (e) {
      await cancelVoice();
      if (mounted) {
        setState(() => error = e is FormatException
            ? e.message
            : 'No pudimos grabar. Puedes escribir el registro.');
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> changeType() async {
    final kind = await chooseIntakeType(context);
    if (kind != null && mounted) await review(kind);
  }

  Future<void> discard(Json saved) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('¿Descartar esta propuesta?'),
                content: const Text(
                    'Saldrá de tus pendientes. No elimina ventas, cobros ni pagos confirmados. Su evidencia se conserva en Finki.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Conservar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Descartar'))
                ]));
    if (yes != true || !mounted || busy) return;
    setState(() => busy = true);
    try {
      await widget.api.command('$root/comandos', 'DESCARTAR_PROPUESTA', {
        'extraccion_id': saved['id'],
        'expected_version': saved['version']?.toString() ?? '1'
      });
      if (!mounted) return;
      if (extractionId == saved['id']) {
        setState(() {
          proposal = null;
          extractionId = null;
          hasEvidence = false;
        });
      }
      await restoreProposals();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> review(String purpose) async {
    Json row = {'proposal': proposal, 'extraccion_id': extractionId};
    if (purpose == 'COBRO' || purpose == 'PAGO') {
      try {
        final data = await widget.api.all(
            '/negocios/${widget.business['id']}/pendientes?direccion=${purpose == 'COBRO' ? 'COBRAR' : 'PAGAR'}');
        if (!mounted) return;
        final chosen = await showModalBottomSheet<Json>(
            context: context,
            isScrollControlled: true,
            builder: (c) => SafeArea(
                    child: ListView(shrinkWrap: true, children: [
                  const ListTile(title: Text('¿A qué pendiente corresponde?')),
                  if (data.isEmpty)
                    const ListTile(
                        title: Text(
                            'No hay pendientes. No se creará una venta automáticamente.')),
                  for (final item in data)
                    ListTile(
                        title: Text(item['concepto'] as String),
                        subtitle:
                            Text('Pendiente ${soles(item['pendiente_minor'])}'),
                        onTap: () => Navigator.pop(c, item))
                ])));
        if (chosen == null || !mounted) return;
        row = {...chosen, ...row};
      } catch (e) {
        if (mounted) showError(context, e);
        return;
      }
    }
    if (!mounted) return;
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => purpose == 'TRANSFERENCIA'
            ? TransferPage(
                api: widget.api,
                business: widget.business,
                accounts: widget.accounts,
                proposal: proposal,
                extractionId: extractionId)
            : EntryForm(
                api: widget.api,
                kind: ['COBRO', 'PAGO'].contains(purpose) ? 'payment' : purpose,
                business: widget.business,
                row: row,
                accounts: widget.accounts,
                categories: widget.categories,
                people: widget.people)));
    if (result == true && mounted) Navigator.pop(context, true);
  }

  Future<void> linkExisting() async {
    try {
      final rows = await widget.api.all(
          '/negocios/${widget.business['id']}/historial?estado=CONFIRMADO');
      if (!mounted) return;
      final chosen = await showModalBottomSheet<Json>(
          context: context,
          isScrollControlled: true,
          builder: (c) => SafeArea(
                  child: ListView(shrinkWrap: true, children: [
                const ListTile(title: Text('Elige el registro que ya hiciste')),
                if (rows.isEmpty)
                  const ListTile(
                      title: Text(
                          'Aún no hay registros confirmados. Usa «Revisar» para crear uno.')),
                for (final row in rows)
                  ListTile(
                      title: Text(row['concepto'] as String),
                      subtitle: Text(
                          '${row['fecha_operacion']} · ${soles(row['total_minor'])}'),
                      onTap: () => Navigator.pop(c, row))
              ])));
      if (chosen == null || !mounted) return;
      String table = 'operaciones', id = chosen['id'] as String;
      if (proposal?['es_pago'] == true) {
        final detail = await widget.api.request(
            'GET', '/negocios/${widget.business['id']}/operaciones/$id');
        final matches = (detail['movimientos'] as List)
            .where((m) =>
                m['estado'] == 'CONFIRMADO' &&
                (proposal?['monto_minor'] == null ||
                    m['monto_minor'] == proposal!['monto_minor']))
            .toList();
        if (matches.length != 1) {
          throw const FormatException(
              'No se encontró un único cobro o pago del mismo importe. Revisa el detalle antes de vincular.');
        }
        table = 'movimientos';
        id = matches.single['id'] as String;
      }
      if (!mounted) return;
      final yes = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('Vincular comprobante'),
                  content: const Text(
                      'Se adjuntará al registro elegido. No crea una venta, cobro ni pago adicional.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Volver')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Confirmar'))
                  ]));
      if (yes != true) return;
      await widget.api.command('/negocios/${widget.business['id']}/comandos',
          'CONFIRMAR_PROPUESTA', {
        'extraccion_id': extractionId,
        'tipo': 'VINCULAR_EVIDENCIA',
        'datos': {'tabla': table, 'id': id}
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !recording,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && recording) {
          await cancelVoice();
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
          appBar: AppBar(
              toolbarHeight: 76,
              title: const FinkiBrandHeader(subtitle: 'Tu asistente')),
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          maxWidth: FinkiSpace.contentWidth),
                      child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                          children: [
                            IntakeCapture(
                                text: text,
                                consent: consent,
                                busy: busy,
                                recording: recording,
                                picking: picking,
                                seconds: seconds,
                                configured: configured,
                                provider: providerName,
                                error: error,
                                transcript: transcript,
                                onConsent: (v) => setState(() => consent = v),
                                onVoice: voice,
                                onCancel: cancelVoice,
                                onCamera: () => photo(ImageSource.camera),
                                onGallery: () => photo(ImageSource.gallery),
                                onAnalyze: () => analyze(words: text.text),
                                onManual: changeType,
                                onRetry: () async {
                                  await status();
                                  await restoreProposals();
                                }),
                            if (proposal != null) ...[
                              const SizedBox(height: 24),
                              IntakeProposalCard(
                                  key: proposalKey,
                                  proposal: proposal!,
                                  enabled: !busy && !recording && !picking,
                                  hasEvidence: hasEvidence,
                                  onReview: () => intakeTypes
                                          .containsKey(proposal!['intencion'])
                                      ? review(proposal!['intencion'] as String)
                                      : changeType(),
                                  onChange: changeType,
                                  onLink: linkExisting),
                            ],
                            if (savedProposals.isNotEmpty)
                              const FinkiSection('Por revisar',
                                  subtitle:
                                      'Las propuestas aún no son registros.'),
                            for (final saved in savedProposals)
                              PendingIntakeCard(
                                  row: saved,
                                  enabled: !busy && !recording && !picking,
                                  onDiscard: () => discard(saved),
                                  onReview: () {
                                    setState(() {
                                      proposal = Map<String, dynamic>.from(
                                          saved['resultado'] as Map);
                                      extractionId = saved['id'] as String;
                                      hasEvidence =
                                          saved['tipo_entrada'] != 'TEXTO';
                                      transcript =
                                          saved['transcripcion'] is String;
                                      if (transcript) {
                                        text.text =
                                            saved['transcripcion'] as String;
                                      }
                                    });
                                    revealProposal();
                                  }),
                          ]))))));
}
