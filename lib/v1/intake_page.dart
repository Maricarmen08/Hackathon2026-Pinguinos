import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'local_speech.dart';
import 'local_ocr.dart';
import 'local_rules.dart';
import 'local_entry.dart';
import 'local_media.dart';
import 'receipt_details.dart';
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
  final Future<XFile?> Function(ImageSource)? pickImage;
  const IntakePage(
      {super.key,
      required this.api,
      required this.business,
      required this.accounts,
      required this.categories,
      required this.people,
      this.pickImage});
  @override
  State<IntakePage> createState() => _IntakePageState();
}

class _IntakePageState extends State<IntakePage> {
  final text = TextEditingController();
  AudioRecorder? _recorder;
  AudioRecorder get recorder => _recorder ??= AudioRecorder();
  final chunks = <int>[];
  final localSpeech = LocalSpeech(),
      localOcr = LocalOcr(),
      rules = LocalRules();
  bool nativeAvailable = false, nativeListening = false;
  bool offlineVoiceAvailable = false,
      preparingVoice = false,
      transcribingVoice = false;
  late final Future<Map<String, dynamic>> speechCapabilities;
  String source = 'TEXTO';
  Json? localEntry;
  Uint8List? imageBytes;
  String? evidenceId, draftId;
  List<Json> localDrafts = [];
  String get draftKey =>
      'local-proposals-v1:${widget.api.userId}:${widget.business['id']}';
  String evidenceKey(String id) =>
      'local-evidence:${widget.api.userId}:${widget.business['id']}:$id';
  StreamSubscription<Uint8List>? stream;
  Timer? timer;
  Json? proposal;
  String? extractionId;
  bool recording = false, busy = false, consent = false;
  bool hasEvidence = false;
  bool picking = false, transcript = false;
  bool analyzingImage = false;
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
    speechCapabilities = localSpeech.capabilities();
    speechCapabilities.then((c) {
      if (mounted) {
        setState(() {
          nativeAvailable =
              c['onDevice'] == true && c['spanishInstalled'] != false;
          offlineVoiceAvailable = c['offlineModel'] == true;
        });
      }
    });
  }

  Future<void> restoreProposals() async {
    List<Json> remote = [];
    try {
      if (widget.api.userId != null) {
        final raw = await widget.api.store.read(draftKey);
        if (raw != null) {
          localDrafts = (jsonDecode(raw) as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
        }
      }
      final data = await widget.api.request('GET', '$root/ia/propuestas');
      remote = (data['items'] as List? ?? []).map((r) {
        final row = Map<String, dynamic>.from(r as Map);
        if (row['tipo_entrada'] == 'AUDIO' &&
            row['transcripcion'] is String &&
            row['resultado'] is Map) {
          row['resultado'] = rules.reconcileVoice(
              row['transcripcion'] as String,
              Map<String, dynamic>.from(row['resultado'] as Map));
        }
        return row;
      }).toList();
    } catch (_) {}
    if (mounted) setState(() => savedProposals = [...localDrafts, ...remote]);
  }

  Future<void> persistLocal() async {
    if (localEntry == null || widget.api.userId == null) return;
    draftId ??= widget.api.newId();
    final draft = <String, dynamic>{
      'id': draftId,
      'local': true,
      'version': '1',
      'entrada': localEntry,
      'resultado': proposal,
      'tipo_entrada': source == 'VOZ' ? 'AUDIO' : source,
      'transcripcion': source == 'VOZ' ? text.text : null,
      'creado_en': DateTime.now().toUtc().toIso8601String()
    };
    final next = [draft, ...localDrafts.where((d) => d['id'] != draftId)];
    await widget.api.store.write(draftKey, jsonEncode(next));
    localDrafts = next;
    if (mounted) {
      setState(() => savedProposals = [
            ...next,
            ...savedProposals.where((d) => d['local'] != true)
          ]);
    }
  }

  Future<void> forgetLocal(String? id) async {
    if (id == null || widget.api.userId == null) return;
    localDrafts = localDrafts.where((d) => d['id'] != id).toList();
    await widget.api.store.write(draftKey, jsonEncode(localDrafts));
  }

  Future<void> selectSaved(Json saved) async {
    if (saved['local'] == true) {
      final entry = Map<String, dynamic>.from(saved['entrada'] as Map);
      setState(() {
        localEntry = entry;
        source = entry['tipo'] as String;
        draftId = saved['id'] as String;
        extractionId = null;
        evidenceId = entry['comprobante_id'] as String?;
        proposal = Map<String, dynamic>.from(entry['propuesta'] as Map);
        text.text = entry['texto'] as String;
        hasEvidence = evidenceId != null;
        transcript = source == 'VOZ';
      });
      imageBytes = null;
      if (evidenceId != null) {
        try {
          final raw = await widget.api.store.read(evidenceKey(evidenceId!));
          if (raw != null) {
            imageBytes = await readLocalMedia(
                (jsonDecode(raw) as Map)['token'] as String);
          }
        } catch (_) {}
      }
    } else {
      setState(() {
        localEntry = null;
        imageBytes = null;
        evidenceId = null;
        draftId = null;
        proposal = Map<String, dynamic>.from(saved['resultado'] as Map);
        extractionId = saved['id'] as String;
        hasEvidence = saved['tipo_entrada'] != 'TEXTO';
        transcript = saved['transcripcion'] is String;
        if (transcript) {
          text.text = saved['transcripcion'] as String;
          source = 'VOZ';
        }
      });
    }
    revealProposal();
  }

  Future<void> interpretLocal() async {
    if (busy || recording || picking) return;
    if (text.text.trim().isEmpty) {
      setState(() => error = 'Escribe qué vendiste o gastaste para continuar.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => busy = true);
    try {
      final value = rules.interpret(text.text, source: source);
      draftId ??= widget.api.newId();
      setState(() {
        proposal = value;
        extractionId = null;
        localEntry = {
          'id_local': draftId,
          'tipo': source,
          'texto': value['texto_visible'],
          'propuesta': value,
          'comprobante_id': evidenceId
        };
        hasEvidence = evidenceId != null;
        error = null;
      });
      await persistLocal();
      revealProposal();
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'No pudimos conservar la propuesta. Revisa el espacio del celular y vuelve a intentar.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> status() async {
    try {
      final s = await widget.api
          .request('GET', '/negocios/${widget.business['id']}/ia/estado');
      if (mounted) {
        setState(() {
          configured = s['configurado'] == true && s['disponible'] != false;
          providerName = s['proveedor'] == 'Gemini' ? 'Gemini' : 'OpenAI';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          configured = null;
          // Local interpretation remains available.
        });
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    stream?.cancel();
    if (nativeListening || preparingVoice) unawaited(localSpeech.cancel());
    _recorder?.dispose();
    text.dispose();
    super.dispose();
  }

  Future<void> analyze({List<int>? bytes, String? words}) async {
    if (!consent || busy || configured != true) return;
    if (bytes == null && source != 'IMAGEN' && words != null) {
      final local = rules.interpret(words);
      if (local['intencion'] != 'DESCONOCIDO' && local['monto_minor'] != null) {
        await interpretLocal();
        return;
      }
    }
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
          localEntry = null;
          proposal = Map<String, dynamic>.from(data['resultado'] as Map);
          extractionId = data['id'] as String;
          hasEvidence = bytes != null;
          transcript = data['transcripcion'] is String;
          if (transcript) {
            text.text = data['transcripcion'] as String;
            source = 'VOZ';
            proposal = rules.reconcileVoice(text.text, proposal!);
          }
          consent = false;
        });
        // The external proposal replaces this local draft, rather than leaving
        // two independently confirmable versions of the same input.
        await forgetLocal(draftId);
        draftId = null;
        await restoreProposals();
        revealProposal();
      }
    } catch (e) {
      if (mounted) {
        if (e is ApiException && e.code == 'AI_QUOTA_EXHAUSTED') {
          configured = false;
        }
        setState(() => error = e is ApiException
            ? e.message
            : 'No pudimos interpretar esta entrada. Reintenta o registra manualmente.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> photo(ImageSource origin, {bool replaceCurrent = false}) async {
    if (busy || recording || picking) return;
    setState(() {
      picking = true;
      error = null;
    });
    try {
      // Keep original resolution/quality and EXIF; no crop or resize is requested.
      final file = widget.pickImage != null
          ? await widget.pickImage!(origin)
          : await ImagePicker()
              .pickImage(source: origin, requestFullMetadata: false);
      if (file == null || !mounted) return;
      setState(() => analyzingImage = true);
      if (await file.length() > 7 * 1024 * 1024) {
        throw const FormatException('Elige una foto de hasta 7 MB.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > 7 * 1024 * 1024) {
        throw const FormatException('Elige una foto de hasta 7 MB.');
      }
      if (!localOcr.supported) {
        setState(() {
          imageBytes = bytes;
          source = 'IMAGEN';
        });
        throw const FormatException(
            'En esta plataforma puedes pedir ayuda con la imagen o escribir los datos.');
      }
      if (widget.api.userId == null) {
        throw const FormatException(
            'Abre tu cuenta antes de guardar imágenes.');
      }
      final token = await saveLocalMedia(bytes);
      String? reuseDraft =
          replaceCurrent && source == 'IMAGEN' ? draftId : null;
      String? reuseEvidence;
      // Re-reading identical original bytes updates the existing local pending.
      for (final saved in localDrafts) {
        final entry = saved['entrada'] as Map?;
        final existingEvidence = entry?['comprobante_id'] as String?;
        if (entry?['tipo'] != 'IMAGEN' || existingEvidence == null) continue;
        final raw = await widget.api.store.read(evidenceKey(existingEvidence));
        if (raw != null && (jsonDecode(raw) as Map)['token'] == token) {
          reuseDraft = saved['id'] as String;
          reuseEvidence = existingEvidence;
          break;
        }
      }
      final id = reuseEvidence ?? widget.api.newId();
      await widget.api.store
          .write(evidenceKey(id), jsonEncode({'token': token}));
      String recognized, rawOcr;
      try {
        final result = await localOcr.readDetailed(file.path);
        recognized = result.text;
        rawOcr = result.rawText;
      } catch (_) {
        recognized = '';
        rawOcr = '';
      }
      if (!mounted) return;
      await widget.api.store.write(
          evidenceKey(id),
          jsonEncode({
            'token': token,
            'bytes': bytes.length,
            'ocr_raw': rawOcr,
            'ocr_ordered': recognized,
          }));
      if (!mounted) return;
      setState(() {
        imageBytes = bytes;
        evidenceId = id;
        source = 'IMAGEN';
        draftId = reuseDraft;
        transcript = false;
        picking = false;
        analyzingImage = false;
        text.text =
            recognized.isEmpty ? 'Imagen pendiente de lectura' : recognized;
      });
      await interpretLocal();
      if (recognized.isEmpty && mounted) {
        setState(() => error =
            'No pude leer esta imagen. Puedes completar los datos o pedir ayuda.');
      } else if (proposal?['monto_minor'] == null && mounted) {
        setState(() => error =
            'No pude identificar un total explícito. Revisa el texto completo, repite la fotografía o completa los datos manualmente.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is FormatException
            ? e.message
            : 'No pudimos abrir la imagen. Revisa los permisos e intenta otra vez.');
      }
    } finally {
      if (mounted) {
        setState(() {
          picking = false;
          analyzingImage = false;
        });
      }
    }
  }

  Future<void> voice() async {
    if (busy || picking) return;
    if (recording) {
      if (nativeListening) {
        await localSpeech.stop();
      } else {
        await cloudVoice();
      }
      return;
    }
    setState(() {
      preparingVoice = true;
      busy = true;
      error = null;
    });
    await speechCapabilities;
    if (!mounted) return;
    if (!nativeAvailable && !offlineVoiceAvailable) {
      setState(() {
        preparingVoice = false;
        busy = false;
      });
      if (!consent || configured != true) {
        setState(() => error =
            'La voz sin conexión no está disponible en español. Puedes escribir o autorizar la grabación alternativa por internet.');
        return;
      }
      final use = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('Transcribir con ayuda por internet'),
                  content: const Text(
                      'Esta grabación se enviará al servicio externo para transcribirla e interpretarla. Necesita conexión y cuota disponible.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Volver')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Grabar'))
                  ]));
      if (use == true && mounted) await cloudVoice();
      return;
    }
    try {
      // Vosk supports a manually bounded continuous session; native services
      // may finish themselves at a phrase endpoint. Keep native when unbundled.
      await localSpeech.prepare(
          preferNative: nativeAvailable && !offlineVoiceAvailable);
    } catch (_) {
      if (mounted) {
        setState(() {
          preparingVoice = false;
          busy = false;
          offlineVoiceAvailable = false;
          error =
              'No pudimos preparar la voz del celular. Puedes escribir o pedir ayuda por internet con tu autorización.';
        });
      }
      return;
    }
    if (!mounted) {
      await localSpeech.cancel();
      return;
    }
    final previousText = text.text;
    setState(() {
      preparingVoice = true;
      busy = true;
      nativeListening = true;
      recording = false;
      seconds = 0;
      error = null;
    });
    var interpretFinal = false;
    try {
      final words = await localSpeech.listen((partial) {
        if (mounted) text.text = partial;
      }, onReady: () {
        if (!mounted || recording || transcribingVoice) return;
        setState(() {
          preparingVoice = false;
          busy = false;
          recording = true;
        });
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => seconds++);
          if (seconds >= 45) {
            timer?.cancel();
            localSpeech.stop();
          }
        });
      }, onProcessing: () {
        timer?.cancel();
        if (mounted) {
          setState(() {
            recording = false;
            preparingVoice = false;
            transcribingVoice = true;
            busy = true;
          });
        }
      }).timeout(const Duration(seconds: 150));
      if (mounted) {
        setState(() {
          text.text = words;
          transcript = true;
          source = 'VOZ';
          imageBytes = null;
          evidenceId = null;
          localEntry = null;
          draftId = null;
        });
        interpretFinal = words.trim().isNotEmpty;
      }
      if (words.trim().isEmpty && mounted) {
        setState(() =>
            error = 'No escuché una frase. Intenta otra vez o escríbela.');
      }
    } on PlatformException catch (e) {
      if (mounted) {
        text.text = previousText;
        if (e.code != 'CANCELLED') {
          setState(() => error = switch (e.code) {
                'PERMISSION_REQUIRED' =>
                  'Permite usar el micrófono en los ajustes del celular e intenta otra vez.',
                'MIC_UNAVAILABLE' =>
                  'Android no pudo iniciar el micrófono. Cierra otras grabaciones e intenta otra vez.',
                'MIC_BUSY' =>
                  'El micrófono está ocupado. Cierra la otra aplicación que lo usa e intenta otra vez.',
                'MIC_DISCONNECTED' =>
                  'Android desconectó el dispositivo de audio. Conéctalo nuevamente e intenta otra vez.',
                'MIC_READ_ERROR' =>
                  'Android interrumpió la lectura del micrófono. No se creó ninguna propuesta.',
                'AUDIO_INTERRUPTED' =>
                  'La grabación se interrumpió al salir de FINKI o cambiar de aplicación. No se creó ninguna propuesta.',
                'NO_SPEECH' ||
                'SPEECH_6' ||
                'SPEECH_7' =>
                  'No escuché una frase clara. Habla cerca del micrófono o escríbela.',
                _ =>
                  'No pudimos reconocer la voz. Intenta otra vez o escribe el registro. No se envió audio por internet.',
              });
        }
      }
    } catch (_) {
      if (mounted) {
        text.text = previousText;
        setState(() => error =
            'La grabación terminó sin resultado. Puedes escribir el registro.');
      }
    } finally {
      timer?.cancel();
      await localSpeech.cancel();
      if (mounted) {
        setState(() {
          recording = false;
          nativeListening = false;
          preparingVoice = false;
          transcribingVoice = false;
          busy = false;
        });
      }
    }
    // Only the completed utterance becomes a local draft, after capture ends.
    // Reinterpretation reuses its draftId; no financial command is submitted.
    if (mounted && interpretFinal) await interpretLocal();
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
    if (nativeListening) await localSpeech.cancel();
    await _recorder?.stop();
    await stream?.cancel();
    chunks.clear();
    if (mounted) setState(() => recording = false);
  }

  Future<void> cloudVoice() async {
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
          if (seconds >= 45 && recording) cloudVoice();
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
      if (saved['local'] == true) {
        await forgetLocal(saved['id'] as String);
        if (draftId == saved['id']) {
          localEntry = null;
          proposal = null;
          draftId = null;
        }
        await restoreProposals();
        return;
      }
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
    Json row = {
      'proposal': proposal,
      'extraccion_id': extractionId,
      'local_entry': localEntry
    };
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
                extractionId: extractionId,
                localEntry: localEntry)
            : EntryForm(
                api: widget.api,
                kind: ['COBRO', 'PAGO'].contains(purpose) ? 'payment' : purpose,
                business: widget.business,
                row: row,
                accounts: widget.accounts,
                categories: widget.categories,
                people: widget.people)));
    if (result == true && mounted) {
      try {
        await forgetLocal(draftId);
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    }
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
      final link = <String, dynamic>{
        'extraccion_id': extractionId,
        'tipo': 'VINCULAR_EVIDENCIA',
        'datos': {'tabla': table, 'id': id}
      };
      await widget.api.command(
          '$root/comandos',
          localEntry == null
              ? 'CONFIRMAR_PROPUESTA'
              : 'CONFIRMAR_PROPUESTA_LOCAL',
          localEntry == null
              ? link
              : localConfirmation(localEntry!, 'VINCULAR_EVIDENCIA',
                  {'tabla': table, 'id': id}));
      try {
        await forgetLocal(draftId);
      } catch (_) {}
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                IntakeCapture(
                                    text: text,
                                    consent: consent,
                                    busy: busy,
                                    recording: recording,
                                    picking: picking,
                                    preparingVoice: preparingVoice,
                                    imageText: source == 'IMAGEN',
                                    analyzingImage: analyzingImage,
                                    onRetake: () => photo(ImageSource.camera,
                                        replaceCurrent: true),
                                    transcribingVoice: transcribingVoice,
                                    seconds: seconds,
                                    configured: configured,
                                    provider: providerName,
                                    error: error,
                                    transcript: transcript,
                                    onConsent: (v) =>
                                        setState(() => consent = v),
                                    onVoice: voice,
                                    onCancel: cancelVoice,
                                    onCamera: () => photo(ImageSource.camera),
                                    onGallery: () => photo(ImageSource.gallery),
                                    onAnalyze: interpretLocal,
                                    onCloud: () => analyze(
                                        bytes: imageBytes,
                                        words: imageBytes == null
                                            ? text.text
                                            : null),
                                    needsHelp: (localEntry != null &&
                                            (proposal?['intencion'] ==
                                                    'DESCONOCIDO' ||
                                                proposal?['monto_minor'] ==
                                                    null)) ||
                                        error != null,
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
                                      receipt: source == 'IMAGEN'
                                          ? ReceiptDetails.parse(
                                              proposal!['texto_visible']
                                                      as String? ??
                                                  '')
                                          : null,
                                      enabled: !busy && !recording && !picking,
                                      hasEvidence: hasEvidence,
                                      onReview: () => intakeTypes.containsKey(
                                              proposal!['intencion'])
                                          ? review(
                                              proposal!['intencion'] as String)
                                          : changeType(),
                                      onChange: changeType,
                                      onLink: linkExisting),
                                ],
                              ],
                            ),
                            if (savedProposals.isNotEmpty)
                              const FinkiSection('Por revisar',
                                  subtitle:
                                      'Las propuestas aún no son registros.'),
                            for (final saved in savedProposals)
                              PendingIntakeCard(
                                  row: saved,
                                  enabled: !busy && !recording && !picking,
                                  onDiscard: () => discard(saved),
                                  onReview: () => selectSaved(saved)),
                          ]))))));
}
