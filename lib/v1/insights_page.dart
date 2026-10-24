import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_client.dart';
import '../ui/widgets/finki_brand.dart';

class InsightsPage extends StatefulWidget {
  final ApiClient api;
  final String businessId;
  const InsightsPage({super.key, required this.api, required this.businessId});
  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final question = TextEditingController();
  final answerKey = GlobalKey();
  String? answer, error, cachedAt, asked;
  String source = 'REGISTROS';
  bool busy = false;
  bool unsupported = false, externalPaused = false;
  List<Json> clarificationOptions = [];
  static const suggestions = <String, String>{
    '¿Cuánto vendí hoy?': '¿Cuánto vendí hoy?',
    '¿Cuánto vendí este mes?': '¿Cuánto vendí este mes?',
    '¿Quién me debe?': '¿Quién me debe?',
    '¿Cuánto gasté esta semana?': '¿Cuánto gasté esta semana?',
    '¿En qué gasto más?': '¿En qué gasto más?',
    '¿Cuánto cobré esta semana?': '¿Cuánto cobré esta semana?',
    '¿Cuánto gasté en mercadería?': '¿Cuánto gasté en mercadería?',
    '¿Vendí más que el mes pasado?': '¿Vendí más que el mes pasado?',
    '¿Cómo va mi negocio?': 'Mi resumen semanal',
  };
  Future<void> ask(String input, {bool external = false}) async {
    final q = input.trim();
    if (busy || q.isEmpty) return;
    FocusScope.of(context).unfocus();
    question.text = q;
    final owner = widget.api.userId;
    final key =
        'insights:v2:$owner:${widget.businessId}:${base64Url.encode(utf8.encode(q.toLowerCase()))}';
    setState(() {
      busy = true;
      answer = null;
      error = null;
      cachedAt = null;
      asked = q;
      unsupported = false;
      clarificationOptions = [];
    });
    try {
      final r = await widget.api.request(
          'POST', '/negocios/${widget.businessId}/consultas',
          body: {'pregunta': q, if (external) 'consentimiento_externo': true});
      if (widget.api.userId != owner) return;
      if (mounted) {
        setState(() {
          answer = r['respuesta'] as String;
          source = r['fuente'] as String? ?? 'REGISTROS';
          clarificationOptions = (r['opciones'] as List? ?? [])
              .map((value) => Map<String, dynamic>.from(value as Map))
              .toList();
        });
      }
      if (owner != null) {
        // Exact question, user and business only. Never derive new totals from a cache.
        try {
          await widget.api.store.write(
              key,
              jsonEncode({
                'at': DateTime.now().toIso8601String(),
                'answer': r['respuesta'],
                'source': source,
                'options': clarificationOptions,
              }));
        } catch (_) {/* A cache write must not hide a valid server answer. */}
      }
    } on ApiException catch (e) {
      if (widget.api.userId != owner) return;
      unsupported = e.code == 'QUESTION_UNSUPPORTED';
      if (external && e.status == 503) externalPaused = true;
      if (e.status == 0 && owner != null) {
        try {
          final raw = await widget.api.store.read(key);
          if (raw != null && mounted) {
            final saved = jsonDecode(raw) as Map;
            setState(() {
              answer = saved['answer'] as String;
              source = saved['source'] as String? ?? 'REGISTROS';
              clarificationOptions = (saved['options'] as List? ?? [])
                  .map((value) => Map<String, dynamic>.from(value as Map))
                  .toList();
              cachedAt = saved['at'] as String;
            });
          }
        } catch (_) {/* An invalid cache is not financial evidence. */}
      }
      if (mounted && answer == null) {
        setState(() => error = e.status == 0
            ? 'No hay internet y todavía no tengo guardada esta respuesta. Conéctate e inténtalo otra vez.'
            : e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            error = 'No pude responderte. Inténtalo otra vez.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = answerKey.currentContext;
          if (mounted && target != null) {
            Scrollable.ensureVisible(target,
                duration: const Duration(milliseconds: 350), alignment: 0.1);
          }
        });
      }
    }
  }

  Future<void> requestExternalHelp() async {
    final original = asked;
    if (busy || original == null || externalPaused) return;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                scrollable: true,
                title: const Text(
                    '¿Quieres que la IA te ayude a entender tu pregunta?'),
                content: const Text(
                    'Con tu autorización se enviará a Gemini una versión filtrada de tu pregunta, con vocabulario financiero. No se enviarán tus registros, ventas, deudas ni saldos.\n\nEvita incluir nombres, teléfonos u otros datos personales. También puedes seguir usando las sugerencias sin ayuda externa.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Ahora no')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Autorizar y continuar')),
                ]));
    if (accepted == true && mounted && question.text.trim() == original) {
      await ask(original, external: true);
    }
  }

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: const FinkiBrandHeader(subtitle: 'Mis preguntas')),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('Pregúntale a Finki',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'Toca una pregunta o escribe la tuya. Te respondo con lo que tienes registrado en tu negocio.'),
          const SizedBox(height: 16),
          TextField(
              controller: question,
              maxLength: 300,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Tu pregunta', hintText: 'Ejemplo: ¿alguien me debe?'),
              onChanged: (_) => setState(() => unsupported = false),
              onSubmitted: busy ? null : ask),
          FilledButton.icon(
              onPressed: busy || question.text.trim().isEmpty
                  ? null
                  : () => ask(question.text),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chat_bubble_outline),
              label: Text(busy
                  ? 'Consultando tus registros…'
                  : 'Consultar mis registros')),
          const SizedBox(height: 16),
          Text('Preguntas fáciles, toca una:',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in suggestions.entries)
              ActionChip(
                  tooltip: entry.value,
                  onPressed: busy ? null : () => ask(entry.value),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  label: Text(entry.key, style: const TextStyle(fontSize: 15))),
          ]),
          const SizedBox(height: 8),
          const Text(
              'Puedes decir: hoy, ayer, esta semana, este mes o del 01/10/2026 al 23/10/2026.',
              style: TextStyle(fontSize: 14)),
          if (answer != null || error != null)
            Card(
                key: answerKey,
                child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(asked ?? '',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 10),
                          if (cachedAt != null)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                    'Sin conexión · Respuesta histórica guardada el ${DateTime.tryParse(cachedAt!)?.toLocal().toString().split('.').first ?? cachedAt}. El periodo y los saldos son los de esa consulta; pueden haber cambiado.',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                          SelectableText(answer ?? error!,
                              style:
                                  const TextStyle(fontSize: 18, height: 1.5)),
                          if (clarificationOptions.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final option in clarificationOptions)
                                OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () =>
                                            ask(option['pregunta'] as String),
                                    child: Text(option['titulo'] as String)),
                            ]),
                          ],
                          if (unsupported) ...[
                            const SizedBox(height: 16),
                            const Text(
                                'No entendí tu pregunta. Prueba con otras palabras, toca una de las preguntas de arriba o pídeme ayuda.'),
                            OutlinedButton(
                              onPressed: busy || externalPaused
                                  ? null
                                  : requestExternalHelp,
                              child:
                                  const Text('Ayudarme a entender mi pregunta'),
                            ),
                          ],
                          if (externalPaused)
                            const Text(
                                'Ayuda externa pausada. Puedes seguir consultando tus registros con las sugerencias.'),
                          if (answer != null && cachedAt == null)
                            Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                    source == 'ORIENTACION' ||
                                            source == 'ACLARACION'
                                        ? 'Finki · Ayuda de uso.'
                                        : 'Fuente: registros del negocio seleccionado.',
                                    style: const TextStyle(fontSize: 12))),
                        ]))),
          const SizedBox(height: 24),
        ])),
      );
}
